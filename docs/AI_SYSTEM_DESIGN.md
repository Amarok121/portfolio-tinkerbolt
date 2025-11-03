# AI System Design

## 📋 개요

TinkerB0lt의 AI 시스템은 동료 캐릭터의 행동을 제어하는 복합적인 아키텍처입니다. 행동 트리, 상태 머신, 그리고 전투 AI의 조합으로 구성되어 있으며, 플레이어와 자연스럽게 협력하는 지능형 AI를 목표로 합니다.

## 🏗️ 아키텍처

### 시스템 계층 구조

```
CompanionAI (기본 AI)
├── 행동 결정 (Behavior Decision)
│   ├── FOLLOW_PLAYER
│   ├── COMBAT_ENGAGE
│   ├── EXECUTE_ORDER
│   ├── IDLE
│   └── GUARD_POSITION
├── 경로 찾기 (Pathfinding)
│   ├── NavigationAgent2D (기본)
│   └── RayCast Pathfinder (폴백)
├── 타겟 관리 (Target Management)
│   ├── 적 탐지 (Threat Detection)
│   ├── 우선순위 큐 (Priority Queue)
│   └── 타겟 유효성 검사 (Validation)
└── CompanionCombatAI (전투 AI)
    ├── Heat 관리 (Heat Management)
    ├── 콤보 시스템 (Combo System)
    └── 공격 타이밍 결정 (Attack Timing)
```

### 설계 패턴

1. **행동 트리 패턴**: 행동 선택 로직
2. **상태 머신 패턴**: 세부 행동 구현
3. **컴포넌트 패턴**: 기능별 분리 (CombatAI, Navigation 등)
4. **옵저버 패턴**: 시그널 기반 통신

## 🎯 CompanionAI (기본 AI)

### 핵심 책임

#### 1. 행동 결정 (Behavior Decision)

```gdscript
enum CompanionBehavior {
    FOLLOW_PLAYER,      # 플레이어 추적
    COMBAT_ENGAGE,     # 전투 참여
    EXECUTE_ORDER,     # 명령 실행
    IDLE,              # 대기
    GUARD_POSITION     # 경계
}
```

**행동 선택 우선순위:**
1. 명령 실행 중 → EXECUTE_ORDER
2. 적 발견 → COMBAT_ENGAGE
3. 기본 → FOLLOW_PLAYER

#### 2. 플레이어 추적 시스템

**특징:**
- **거리 기반 움직임**: `follow_distance` 내에서는 정지
- **빠른 추적**: 일정 거리 이상 벗어나면 속도 증가
- **속도 동기화**: 플레이어 속도에 맞춘 자연스러운 이동
- **텔레포트**: 너무 멀어지면 순간이동

**구현 세부사항:**
```gdscript
func process_follow_behavior(_delta: float) -> void:
    var distance_to_player = companion.global_position.distance_to(player.global_position)
    
    if distance_to_player <= follow_distance:
        # 즉시 정지
        target_velocity = Vector2.ZERO
        apply_smoothed_velocity(_delta, target_velocity)
        return
    
    # 목표 속도 계산
    var next_pos = navigation_agent.get_next_path_position()
    target_velocity = calculate_target_velocity(next_pos)
    apply_smoothed_velocity(_delta, target_velocity)
```

#### 3. 경로 찾기 시스템

**2단계 시스템:**

**1단계: NavigationAgent2D (기본)**
- Godot의 Navigation 메시 사용
- 최적 경로 자동 계산
- 장애물 회피 지원

**2단계: RayCast Pathfinder (폴백)**
- Navigation 메시가 없을 때 사용
- 8방향 RayCast로 장애물 감지
- 최적 방향 선택 (타겟 방향과의 일치도 계산)

```gdscript
func get_raycast_direction() -> Vector2:
    # 8방향 RayCast로 최적 경로 찾기
    var best_direction = Vector2.ZERO
    var best_score = -1.0
    
    for raycast in raycasts:
        if not raycast.is_colliding():
            var dot_product = target_direction.dot(ray_direction)
            if dot_product > best_score:
                best_score = dot_product
                best_direction = ray_direction
    
    return best_direction
```

#### 4. 타겟 관리 시스템

**타겟 탐지:**
- `detection_range` 내 적 탐지
- PhysicsShapeQuery를 사용한 효율적인 감지
- 감지된 적을 `detected_enemies` 배열에 저장

**우선순위 큐:**
- 거리순으로 정렬된 타겟 목록
- 가장 가까운 적을 우선 공격
- 타겟 상실 시 자동으로 다음 타겟 선택

**타겟 유효성 검사:**
- 주기적으로 타겟 유효성 확인 (5 FPS)
- 무효한 타겟 자동 제거
- 거리 초과 시 추적 포기

```gdscript
func validate_targets_optimized():
    # 무효한 타겟 제거
    var valid_enemies: Array[Node2D] = []
    for enemy in detected_enemies:
        if is_instance_valid(enemy) and distance <= max_pursuit_distance:
            valid_enemies.append(enemy)
    
    detected_enemies = valid_enemies
```

## ⚔️ CompanionCombatAI (전투 AI)

### 핵심 책임

#### 1. Heat 관리 시스템

**개념:**
- 동료는 "Heat" 시스템을 가짐 (과열 메커니즘)
- Heat가 일정 범위를 유지해야 효율적 전투 가능
- Heat Boost 스킬로 Heat 관리

**동작:**
```gdscript
func manage_heat():
    var heat_percentage = heat_component.get_heat_percentage()
    
    if heat_percentage < heat_target_min:
        # Heat 부족 → Heat Boost 사용
        use_heat_boost()
    elif heat_percentage > heat_target_max:
        # Heat 과다 → 공격 제한
        limit_attacks()
```

#### 2. 공격 타이밍 결정

**결정 간격:**
- `attack_decision_interval`: 0.05초 (20 FPS)
- 매 프레임이 아닌 간격을 두고 결정하여 성능 최적화

**공격 판단 로직:**
1. 타겟 거리 확인
2. 공격 범위 내인지 확인
3. 콤보 쿨다운 확인
4. Heat 상태 확인

```gdscript
func _process(_delta):
    var distance_to_target = companion.global_position.distance_to(target.global_position)
    
    if distance_to_target <= combat_range:
        if can_attack():
            execute_combat_attack()
```

#### 3. 콤보 시스템

**특징:**
- 연속 공격 콤보 지원
- 콤보 간 쿨다운 관리
- 플레이어와 동일한 공격 시스템 사용

```gdscript
func execute_combat_attack():
    if not marsh_attack.is_combo_active:
        marsh_attack.start_combo()
    else:
        marsh_attack.continue_combo()
```

#### 4. 접근 전략

**3단계 전투 페이즈:**

1. **Approach (접근)**
   - 타겟에게 접근
   - Navigation 또는 직접 경로 사용

2. **Engage (교전)**
   - 공격 범위 내 진입
   - 공격 준비

3. **Maintain (유지)**
   - 적절한 거리 유지
   - Heat 관리하며 연속 공격

## 🔄 AI와 상태 머신 연동

### CompanionAI ↔ CompanionStateMachine

**AI가 상태 전환 결정:**
```gdscript
# CompanionAI에서 상태 전환 결정
if should_follow_player:
    companion.state_machine.change_state(companion.get_state("CompanionStateFollowing"))
elif should_engage_combat:
    companion.state_machine.change_state(companion.get_state("CompanionStateCombat"))
```

**상태 머신에서 AI 연동:**
```gdscript
# CompanionStateFollowing.process()
func process(_delta: float) -> Node:
    var ai = companion.companion_ai
    
    # AI의 추적 로직 실행
    if ai.current_behavior == ai.CompanionBehavior.FOLLOW_PLAYER:
        # AI가 이미 velocity를 설정했으므로 추가 처리 없음
        pass
```

## 🎮 플레이어 조작 모드 지원

### 시점 전환

동료는 AI 모드와 플레이어 조작 모드를 모두 지원:

```gdscript
# AI 모드
if companion.is_ai_controlled:
    # AI가 제어
    companion.companion_ai.process_ai(delta)

# 플레이어 조작 모드
elif companion.is_player_controlled:
    # 플레이어 입력 사용
    companion.state_machine._input(event)
```

### 전환 시 안전 처리

시점 전환 시 모든 AI 액션을 안전하게 중단:

```gdscript
func force_stop_for_player_control():
    is_action_complete = true
    target_velocity = Vector2.ZERO
    companion.velocity = Vector2.ZERO
    reset_navigation_completely()
```

## 📊 최적화 전략

### 1. 업데이트 간격 최적화

**CompanionAI:**
- `update_interval`: 0.05초 (20 FPS)
- 불필요한 연산 최소화

**CompanionCombatAI:**
- `attack_decision_interval`: 0.05초 (20 FPS)
- 타겟 검사 간격: 0.2초 (5 FPS)

### 2. 거리 기반 최적화

- 가까운 적만 자세히 처리
- 먼 적은 간단한 체크만 수행

### 3. 캐싱 시스템

```gdscript
# 접근 방향 캐싱
var cached_approach_direction: Vector2
var approach_direction_cache_duration: float = 0.5
```

## 🎯 주요 특징

### 1. 자연스러운 움직임

- 플레이어 속도에 맞춘 동료 속도
- 즉시 정지/이동으로 반응성 향상
- 부드러운 속도 보간

### 2. 지능형 타겟 선택

- 거리 기반 우선순위
- 자동 타겟 전환
- 전투 중 타겟 유지

### 3. 적응형 행동

- 상황에 따른 행동 변경
- 플레이어 거리에 따른 속도 조절
- 전투 중 공격적 추적 모드

### 4. 장애물 회피

- Navigation 메시 우선 사용
- 없을 경우 RayCast 기반 회피
- 모퉁이 걸림 감지 및 해결

## 🔍 디버깅 및 모니터링

### 상태 모니터링

```gdscript
func get_ai_debug_info() -> Dictionary:
    return {
        "behavior": current_behavior,
        "target": current_target.name if current_target else "None",
        "detected_enemies": detected_enemies.size(),
        "distance_to_player": distance_to_player,
        "is_moving": is_moving
    }
```

### 시그널 시스템

AI 상태 변화를 시그널로 알림:

```gdscript
signal behavior_changed(new_behavior: String)
signal target_acquired(target: Node2D)
signal target_lost
```

---

**이 AI 시스템은 플레이어와 자연스럽게 협력하며, 상황에 맞는 지능적인 행동을 수행하는 동료를 구현합니다.**

