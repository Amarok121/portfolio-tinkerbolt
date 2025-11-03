# 월드 시스템 아키텍처 설계

## 개요

기존의 수동 타일맵 기반 월드를 확장하여 절차적 생성과 허브 월드를 지원하는 시스템으로 리팩토링했습니다.

## 새로운 구조

### 1. WorldData (Resource)
월드의 메타데이터를 저장하는 리소스 클래스입니다.

**주요 속성:**
- `world_id`: 월드 고유 ID
- `world_name`: 월드 표시 이름
- `world_type`: 월드 타입 (MANUAL, PROCEDURAL, HUB)
- `scene_path`: 수동 월드의 씬 파일 경로
- `procedural_config`: 절차적 생성 설정
- `hub_config`: 허브 월드 설정

**월드 타입:**
- `MANUAL (0)`: 수동으로 만들어진 고정 맵 (현재 방식)
- `PROCEDURAL (1)`: 절차적으로 생성된 맵
- `HUB (2)`: 허브 월드 (항상 고정된 구조)

### 2. WorldFactory (Static Class)
다양한 타입의 월드를 생성하는 팩토리 클래스입니다.

**주요 기능:**
- `create_world_from_data()`: WorldData에서 월드 생성
- `create_world_by_type()`: 타입과 설정으로 월드 생성
- `_create_procedural_world()`: 절차적 월드 생성
- `_create_hub_world()`: 허브 월드 생성
- 절차적 생성 함수들: `_generate_dungeon()`, `_generate_open_world()`, `_generate_cave()`

### 3. WorldRegistry (Resource)
모든 월드를 등록하고 관리하는 레지스트리입니다.

**주요 기능:**
- `register_world()`: 월드 등록
- `get_world_data()`: 월드 데이터 조회
- `create_world()`: 월드 생성
- `get_hub_worlds()`: 허브 월드 목록
- `get_procedural_worlds()`: 절차적 생성 월드 목록

### 4. World 클래스 확장
기존 `World` 클래스에 새로운 필드 추가:
- `world_id`: 월드 ID
- `world_type`: 월드 타입
- `world_data`: 월드 데이터 리소스 참조

## 사용 예시

### 기존 씬을 새로운 시스템으로 변환
```gdscript
var world_data = WorldFactory.convert_scene_to_world_data(
	"res://Assets/PreFabs/Scenes/Levels/Tutorial/dawn_room.tscn",
	"Dawn Room"
)

# 월드를 생성
var world = world_data.create_world_instance()
```

### 새로운 절차적 월드 생성
```gdscript
var config = {
	"world_name": "Random Dungeon",
	"generator_type": "dungeon",
	"params": {
		"room_count": 20,
		"room_size_min": Vector2i(5, 5),
		"room_size_max": Vector2i(10, 10)
	}
}

var world = WorldFactory.create_world_by_type(1, config)  # PROCEDURAL
```

### 허브 월드 생성
```gdscript
var hub_config = {
	"world_name": "Main Hub",
	"player_init_point": Vector2(100, 100),
	"hub_scene_path": "res://Assets/PreFabs/Scenes/Hubs/main_hub.tscn"
}

var hub_world = WorldFactory.create_world_by_type(2, hub_config)  # HUB
```

## 확장 계획

### 1. 절차적 생성 구현
TODO: `WorldFactory`의 절차적 생성 함수들 구현
- 던전 생성 알고리즘
- 오픈 월드 지형 생성
- 동굴 시스템 생성

### 2. 허브 월드 시스템
TODO: 허브 월드 전용 기능 구현
- 포탈 시스템
- NPC 상인 관리
- 스토리 진행 추적

### 3. 월드 레지스트리 설정
TODO: 게임 시작 시 모든 월드 등록
```gdscript
# Global.gd나 초기화 스크립트에서
var registry = WorldRegistry.new()
registry.register_world(world_data_1)
registry.register_world(world_data_2)
# ...
```

## 마이그레이션 가이드

### 기존 월드 사용
기존 월드는 그대로 작동합니다. 새로운 시스템은 선택적입니다.

### 새로운 월드 추가 방법

**옵션 1: 기존 씬을 새로운 시스템으로 변환**
```gdscript
# WorldData 리소스 생성
var world_data = WorldFactory.convert_scene_to_world_data(
	"res://Assets/PreFabs/Scenes/Levels/World.tscn",
	"Dawn Platform"
)

# 레지스트리에 등록
registry.register_world(world_data)
```

**옵션 2: 절차적 월드 생성**
```gdscript
# 프로젝트 설정에서 절차적 월드 추가
# 또는 런타임에 동적으로 생성
```

## 장점

1. **확장성**: 새로운 월드 타입 추가가 쉬움
2. **유연성**: 기존 월드와 새로운 시스템 공존 가능
3. **재사용성**: 월드 생성 로직이 중앙화됨
4. **데이터 드리븐**: 월드 설정이 리소스로 관리됨
5. **테스트 용이성**: 다양한 월드 타입 테스트 가능

## 향후 개선사항

- 절차적 생성 알고리즘 완성
- 허브 월드 전용 기능 구현
- 월드 간 연결 시스템 (포탈, 문)
- 월드 세이브/로드 개선
- 월드 미리보기 시스템
