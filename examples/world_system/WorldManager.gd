extends Node
class_name WorldManager

## 월드 매니저 - 월드 시스템의 중앙 관리자
## 게임 시작 시 모든 월드를 등록하고 관리합니다

var registry: WorldRegistry
var current_world_data: WorldData

# 싱글톤 패턴을 위한 참조
static var instance: WorldManager

func _ready() -> void:
	# 싱글톤 설정
	if instance == null:
		instance = self
	else:
		queue_free()
		return
	
	# 레지스트리 초기화
	registry = WorldRegistry.new()
	
	# 게임의 모든 월드 등록
	_register_all_worlds()
	
	print_debug("WorldManager initialized with %d worlds" % registry.worlds.size())

func _register_all_worlds() -> void:
	"""모든 월드를 레지스트리에 등록합니다."""
	
	# 1. 기존 수동 월드들 등록
	_register_manual_world("Dawn_Platform", 
		"res://Assets/PreFabs/Scenes/Levels/Tutorial/dawn_platform.tscn",  # World.tscn → dawn_platform.tscn
		Vector2(0, 0),
		[2, 1001]  # basic_items
	)
	
	_register_manual_world("Dawn_Room",
		"res://Assets/PreFabs/Scenes/Levels/Tutorial/dawn_room.tscn",
		Vector2(280, 165),
		[]
	)
	
	# TODO: 다른 월드들도 추가
	# _register_manual_world("NewWorld", ...)
	
	# 2. 절차적 생성 가능한 월드 등록
	# TODO: 절차적 월드 설정 추가
	# _register_procedural_world("RandomDungeon", {...})
	
	# 3. 허브 월드 등록
	# TODO: 허브 월드 설정 추가
	# _register_hub_world("MainHub", {...})

func _register_manual_world(world_name: String, scene_path: String, 
		init_point: Vector2, basic_items: Array = []) -> void:
	"""수동으로 만든 월드를 등록합니다."""
	
	if not ResourceLoader.exists(scene_path):
		push_warning("World scene not found: %s" % scene_path)
		return
	
	var world_data = WorldData.new()
	world_data.world_id = world_name.to_lower().replace(" ", "_")
	world_data.world_name = world_name
	world_data.world_type = 0  # MANUAL
	world_data.scene_path = scene_path
	world_data.player_init_point = init_point
	world_data.basic_items = basic_items
	
	registry.register_world(world_data)
	print_debug("Registered manual world: %s" % world_name)

func _register_procedural_world(world_name: String, config: Dictionary) -> void:
	"""절차적 생성 가능한 월드를 등록합니다."""
	
	var world_data = WorldData.new()
	world_data.world_id = world_name.to_lower().replace(" ", "_")
	world_data.world_name = world_name
	world_data.world_type = 1  # PROCEDURAL
	world_data.procedural_config = config
	
	registry.register_world(world_data)
	print_debug("Registered procedural world: %s" % world_name)

func _register_hub_world(world_name: String, config: Dictionary) -> void:
	"""허브 월드를 등록합니다."""
	
	var world_data = WorldData.new()
	world_data.world_id = world_name.to_lower().replace(" ", "_")
	world_data.world_name = world_name
	world_data.world_type = 2  # HUB
	world_data.hub_config = config
	
	registry.register_world(world_data)
	print_debug("Registered hub world: %s" % world_name)

## 월드 이름으로 월드를 로드합니다
func load_world_by_name(world_name: String) -> Node2D:
	"""월드 이름으로 월드 인스턴스를 생성합니다."""
	
	var world_data = registry.get_world_by_name(world_name)
	if not world_data:
		push_error("World not found: %s" % world_name)
		return null
	
	current_world_data = world_data
	var world = world_data.create_world_instance()
	
	if world:
		# 월드 설정 적용
		world.world_name = world_data.world_name
		world.world_id = world_data.world_id
		world.world_type = world_data.world_type
		world.world_data = world_data
	
	return world

## 월드 ID로 월드를 로드합니다
func load_world_by_id(world_id: String) -> Node2D:
	"""월드 ID로 월드 인스턴스를 생성합니다."""
	
	var world_data = registry.get_world_data(world_id)
	if not world_data:
		push_error("World ID not found: %s" % world_id)
		return null
	
	current_world_data = world_data
	var world = world_data.create_world_instance()
	
	if world:
		# 월드 설정 적용
		world.world_name = world_data.world_name
		world.world_id = world_data.world_id
		world.world_type = world_data.world_type
		world.world_data = world_data
	
	return world

## 모든 등록된 월드 목록을 반환합니다
func get_all_worlds() -> Array[WorldData]:
	return registry.worlds.values()

## 허브 월드만 반환합니다
func get_hub_worlds() -> Array[WorldData]:
	return registry.get_hub_worlds()

## 절차적 생성 월드만 반환합니다
func get_procedural_worlds() -> Array[WorldData]:
	return registry.get_procedural_worlds()

## 월드 레지스트리 참조를 반환합니다
func get_registry() -> WorldRegistry:
	return registry
