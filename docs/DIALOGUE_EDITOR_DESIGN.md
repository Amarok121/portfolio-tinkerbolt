# Dialogue Editor Plugin Design

## 📋 개요

Dialogue Editor는 Godot 에디터 내에서 노드 기반으로 대화 시스템을 시각적으로 제작할 수 있는 커스텀 플러그인입니다. GraphEdit API를 활용하여 복잡한 대화 분기를 직관적인 그래프 형태로 편집할 수 있습니다.

## 🏗️ 아키텍처

### 시스템 구조

```
Dialogue Editor Plugin
├── EditorPlugin (메인 플러그인)
│   └── DialogueEditor (메인 에디터 UI)
│       ├── GraphEdit (노드 그래프)
│       ├── InspectorPanel (속성 편집)
│       └── FileDialogs (저장/로드)
├── DialogueGraphNode (기본 노드 클래스)
│   ├── TextDialogueNode (텍스트 노드)
│   ├── ChoiceDialogueNode (선택 노드)
│   ├── StartDialogueNode (시작 노드)
│   └── ConditionalIncludeNode (조건부 포함 노드)
└── 데이터 변환 시스템
    ├── Graph → JSON (컴파일)
    └── JSON → Graph (로드)
```

### 설계 패턴

1. **플러그인 패턴**: EditorPlugin 기반
2. **컴포지트 패턴**: 다양한 노드 타입 통합
3. **빌더 패턴**: Graph에서 JSON으로 변환
4. **2-Pass 알고리즘**: 복잡한 그래프 로드

## 🎨 노드 시스템

### 노드 타입

#### 1. Start Node (시작 노드)
- **역할**: 대화의 시작점
- **특징**: 입력 포트 없음, 출력 포트 1개
- **제약**: 그래프당 1개만 존재 가능

#### 2. Text Node (텍스트 노드)
- **역할**: NPC의 대사 표시
- **속성**:
  - 다국어 텍스트 (한국어/영어)
  - NPC 정보 (이름, 아바타, 애니메이션)
  - 액션 (퀘스트 진행, 이벤트 트리거 등)
- **연결**: 입력 1개, 출력 1개 (선형 진행)

#### 3. Choice Node (선택 노드)
- **역할**: 플레이어에게 선택지 제공
- **속성**:
  - 여러 선택지 (각각 다국어)
  - 선택지별 액션
  - NPC 정보
- **연결**: 입력 1개, 출력 여러 개 (선택지 수만큼)

#### 4. Conditional Include Node (조건부 포함 노드)
- **역할**: 다른 대화 파일을 조건부로 포함
- **속성**: Include ID
- **특징**: 런타임에서 동적으로 대화 삽입

### 노드 인터페이스

```gdscript
class DialogueGraphNode extends GraphNode:
    var dialogue_data: Dictionary = {}
    
    func update_ui_from_data() -> void:
        # 노드의 UI를 데이터에서 업데이트
    
    func get_node_type_string() -> String:
        # 노드 타입 반환 ("text", "choice", etc.)
    
    signal close_request
```

## 📁 파일 형식

### 1. Editor Graph File (*.dgraph)

**용도**: 에디터에서 다시 편집 가능한 형식

```json
{
    "nodes": [
        {
            "name": "DialogueNode_1",
            "type": "text",
            "position_x": 100,
            "position_y": 200,
            "data": {
                "text": {"ko": "...", "en": "..."},
                "npc_info": {...},
                "actions": [...]
            }
        }
    ],
    "connections": [
        {
            "from_node": "DialogueNode_1",
            "from_port": 0,
            "to_node": "DialogueNode_2",
            "to_port": 0
        }
    ]
}
```

### 2. Runtime Dialogue File (*.json)

**용도**: 게임에서 실제로 사용하는 컴파일된 형식

```json
{
    "dialogues": [
        {
            "id": "dialogue_001",
            "steps": [
                {
                    "type": "text",
                    "text": {"ko": "...", "en": "..."},
                    "npc_info": {...},
                    "actions": [...]
                },
                {
                    "type": "choice",
                    "choices": [
                        {
                            "text": {"ko": "...", "en": "..."},
                            "actions": [...],
                            "next": [...]
                        }
                    ]
                }
            ]
        }
    ]
}
```

## 🔄 컴파일 시스템 (Graph → JSON)

### 순회 알고리즘

**선형 노드 처리:**
```
Start → Text1 → Text2 → Text3
```

**분기 노드 처리:**
```
Choice
├─ 선택지1 → TextA → TextB
└─ 선택지2 → TextC → TextD
```

### 구현 핵심

```gdscript
func _traverse_and_compile(from_node_name: StringName, connections: Array) -> Array:
    var steps := []
    var current_node_name: StringName = from_node_name
    
    while current_node_name != "":
        var current_node = graph_edit.get_node(current_node_name)
        
        if node_type == "text":
            # 텍스트 스텝 생성
            steps.append({
                "type": "text",
                "text": current_node.dialogue_data.get("text"),
                "actions": serialize_actions(current_node.dialogue_data.get("actions"))
            })
            
            # 다음 노드 찾기
            for conn in connections:
                if conn.from_node == current_node_name:
                    current_node_name = conn.to_node
                    break
        
        elif node_type == "choice":
            # 선택지 스텝 생성
            var choice_step = {
                "type": "choice",
                "choices": []
            }
            
            for i in range(choices.size()):
                # 각 선택지의 분기 재귀적으로 컴파일
                var next_steps = _traverse_and_compile(choice_branch_node, connections)
                choice_step["choices"].append({
                    "text": choice_text,
                    "next": next_steps
                })
            
            steps.append(choice_step)
            break  # 선택 노드는 분기 끝
    
    return steps
```

## 🔄 로드 시스템 (JSON → Graph)

### 2-Pass 알고리즘

복잡한 그래프 구조(여러 분기가 하나로 합쳐지는 경우)를 올바르게 로드하기 위해 2단계 접근법을 사용합니다.

#### Pass 1: 노드 생성 (Creation Pass)

**목표**: 모든 고유한 노드를 중복 없이 생성

```gdscript
func _create_all_nodes_pass(steps: Array, node_cache: Dictionary):
    for step in steps:
        var step_key = _get_step_cache_key(step)  # 고유 키 생성
        
        if not node_cache.has(step_key):
            # 새 노드 생성
            var new_node = _create_single_node(step)
            graph_edit.add_child(new_node)
            node_cache[step_key] = new_node.name
        
        # 선택지의 분기도 재귀적으로 처리
        if step.get("type") == "choice":
            for choice in step.get("choices", []):
                _create_all_nodes_pass(choice.get("next", []), node_cache)
```

**핵심**: `_get_step_cache_key()`로 동일한 내용의 노드는 하나만 생성

#### Pass 2: 노드 연결 (Connection Pass)

**목표**: 생성된 노드들을 올바르게 연결

```gdscript
func _connect_all_nodes_pass(steps: Array, node_cache: Dictionary):
    for i in range(steps.size()):
        var step = steps[i]
        var step_key = _get_step_cache_key(step)
        var current_node_name = node_cache[step_key]
        
        if step_type == "choice":
            # 선택지별로 분기 연결
            for port_idx in range(choices.size()):
                var next_steps = choices[port_idx].get("next", [])
                var next_step_key = _get_step_cache_key(next_steps[0])
                if node_cache.has(next_step_key):
                    graph_edit.connect_node(
                        current_node_name, port_idx,
                        node_cache[next_step_key], 0
                    )
                    _connect_all_nodes_pass(next_steps, node_cache)
        else:
            # 선형 노드 연결
            if i + 1 < steps.size():
                var next_step_key = _get_step_cache_key(steps[i+1])
                graph_edit.connect_node(
                    current_node_name, 0,
                    node_cache[next_step_key], 0
                )
```

### 문제 해결: 비동기 노드 추가

**문제**: `add_child()`는 즉시 실행되지 않고 프레임 끝에서 처리됨

**해결**: `call_deferred()` 사용

```gdscript
# 모든 connect_node 호출을 지연시켜 노드가 완전히 준비된 후 연결
graph_edit.connect_node.call_deferred(
    from_node_name, from_port,
    to_node_name, to_port
)
```

### 데이터 역직렬화

**문제**: JSON의 Dictionary를 Resource 객체로 변환 필요

**해결**: 역직렬화 헬퍼 함수

```gdscript
func _deserialize_npc_info(npc_data: Dictionary) -> NpcInfo:
    var npc_info = NpcInfo.new()
    if npc_data.has("npc_resource_path"):
        npc_info.npc_resource_path = npc_data["npc_resource_path"]
        npc_info.npc_resource = load(npc_data["npc_resource_path"])
    return npc_info
```

## 🎨 Inspector Panel 시스템

### 동적 UI 생성

노드 선택 시 해당 노드 타입에 맞는 인스펙터를 동적으로 생성:

```gdscript
func _update_inspector():
    _clear_inspector()
    
    if selected_node:
        var node_type = selected_node.get_node_type_string()
        
        if node_type == "text":
            _build_text_node_inspector()
        elif node_type == "choice":
            _build_choice_node_inspector()
```

### 다국어 지원

각 노드의 텍스트는 한국어/영어 동시 편집:

```gdscript
for language in SUPPORTED_LANGUAGES:
    var language_label = Label.new()
    language_label.text = language.to_upper() + ":"
    var text_edit = TextEdit.new()
    text_edit.text = dialogue_data.get("text", {}).get(language, "")
    text_edit.text_changed.connect(_on_text_changed.bind(language))
```

## 🔧 NPC 정보 모드

### 1. Individual NPC Info (Per Node) - 권장

- 각 노드마다 개별 NPC 정보 설정
- 대화 중 NPC 변경 가능
- 복잡한 대화에 적합

### 2. Global NPC Info (Legacy)

- 전체 대화에서 하나의 NPC 정보 사용
- 파일 크기 절약
- 단순한 대화에 적합

## 💡 주요 특징

### 1. 하이브리드 대화 시스템

**JSON 기반**: 선형 대화와 선택지는 JSON으로 관리  
**씬 기반**: 조건부 대화는 씬 노드로 관리  
**조합**: `conditional_include` 노드로 두 시스템 통합

### 2. 액션 시스템

각 노드/선택지에 액션을 첨부할 수 있음:

- **퀘스트 진행**: 특정 퀘스트 단계로 이동
- **이벤트 트리거**: 게임 이벤트 발생
- **플래그 설정**: 게임 상태 변경
- **메서드 호출**: 커스텀 함수 실행

### 3. 실시간 검증

- 저장 시 Start 노드 존재 확인
- 연결 유효성 검사
- 데이터 무결성 확인

## 🎯 사용 예시

### 기본 대화 생성

1. **Add Start Node** 클릭
2. **Add Text Node** 클릭하여 대사 추가
3. 노드들을 드래그하여 연결
4. 인스펙터에서 텍스트 편집
5. **Save** → `.json` 형식으로 저장 (게임용)

### 분기 대화 생성

1. Start Node 추가
2. Text Node 추가 (질문)
3. **Add Choice Node** 추가
4. 선택지 개수 설정
5. 각 선택지를 다른 노드로 연결
6. 각 분기에 Text Node 추가

### 조건부 대화 포함

1. **Add Conditional Include Node** 추가
2. Include ID 설정 (예: "shopkeeper_greeting")
3. 해당 ID의 대화는 런타임에서 씬 노드에서 동적으로 제공

## 🔍 기술적 도전과 해결

### 도전 1: 복잡한 분기 그래프 로드

**문제**: 여러 선택지가 동일한 결과 노드로 이어지는 경우

**해결**: 2-Pass 알고리즘으로 노드 생성과 연결을 분리

### 도전 2: 비동기 노드 추가

**문제**: 노드 추가 직후 연결 시도 시 실패

**해결**: `call_deferred()`로 모든 연결 작업 지연

### 도전 3: 데이터 역직렬화

**문제**: JSON의 Dictionary를 Resource 객체로 변환 필요

**해결**: 역직렬화 헬퍼 함수로 완전한 객체 생성

## 📊 성능 최적화

### 1. 지연 로드

- 대용량 그래프도 부드럽게 로드
- 노드 생성 시 즉시 UI 업데이트하지 않음
- 연결은 모든 노드 생성 후 일괄 처리

### 2. 캐싱

- 노드 참조 캐싱
- 경로 계산 최적화

### 3. 메모리 관리

- 불필요한 노드 즉시 해제
- 역직렬화된 객체 적절히 관리

---

**이 다이얼로그 에디터는 복잡한 대화 시스템을 직관적으로 제작할 수 있게 해주며, JSON과 그래프 형식 간의 완벽한 양방향 변환을 지원합니다.**

