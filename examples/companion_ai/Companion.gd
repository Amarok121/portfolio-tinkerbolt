@tool
@icon("res://Assets/Icons/npc.svg")
class_name Companion extends CharacterBody2D

signal companion_switched_to
signal companion_switched_from
signal order_completed
signal combat_state_changed(is_in_combat: bool)
signal equipment_changed

# 기본 컴포넌트들
@onready var stat_component = $StatComponent
@onready var health_component = $StatComponent/HealthComponent
@onready var energy_component = $StatComponent/EnergyComponent
@onready var heat_component = $StatComponent/HeatComponent
@onready var status_effect_component = $StatComponent/StatusEffectComponent
@onready var animation_tree = $AnimationTree
@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D  # 기본 단일 스프라이트 (호환성용)
@onready var sprites_container = $Sprites  # 다중 스프라이트 컨테이너 (마시 등)
@onready var sprite_manager = null  # 스프라이트 매니저 (마시 전용)

# 동료 전용 컴포넌트들
@onready var companion_ai = $CompanionAI
@onready var navigation_agent = $NavigationAgent2D
@onready var detection_area = $DetectionArea
@onready var state_machine = $StateMachine

# 카메라 (플레이어 조작 시 사용)
@onready var camera: Camera2D = $Camera2D

# 고급 기능 컴포넌트들
@onready var ghost_component = $GhostComponent
@onready var dash_component = $DashComponent
@onready var jump_component = $JumpComponent

# 스킬 시스템
@onready var skill_component = $Skills/SkillComponent

# 상태 관리
@export var companion_name: String = "Companion"
@export var companion_id: String = ""  # 고유 식별자
@export var is_player_controlled: bool = false
@export var auto_pilot_enabled: bool = true

# 피격 상태 (HealthComponent 호환성)
var taking_damage: bool = false

# 플레이어와 동일한 상태 변수들 (호환성을 위해 추가)
@export var on_event: bool = false
@export var isAttack: bool = false
@export var isDash: bool = false
var z_height: float = 0.0
var z_velocity: float = 0.0

# 플레이어 참조
var main_player: CharacterBody2D = null
var current_target: CharacterBody2D = null

# 동료 설정
@export var follow_distance: float = 80.0
@export var combat_range: float = 150.0
@export var move_speed: float = 150.0  # 플레이어와 동일한 기본 속도
@export var run_speed: float = 250.0   # 플레이어보다 약간 빠른 달리기 속도

# 상태
var current_behavior: String = "follow"  # follow, combat, idle, execute_order
var is_in_combat: bool = false
var current_order: Dictionary = {}

# 입력 처리 (플레이어 조작 시)
var input_vector: Vector2 = Vector2.ZERO
var is_running: bool = false
var is_guarding: bool = false

# 열 상태 변화 모니터링
func _on_heat_changed(new_heat: float, old_heat: float):
	# print_debug("🔥 Heat changed for ", companion_name, ": ", old_heat, " -> ", new_heat)
	# print_debug("  - Change amount: ", new_heat - old_heat)
	# print_debug("  - Current heat: ", new_heat, "/", heat_component.MAX_HEAT)
	
	# 열이 66% 이상일 때 특별한 효과 (나중에 구현)
	if new_heat >= heat_component.MAX_HEAT * 0.66:
		# print_debug("  🚨 High heat detected! Special effects enabled!")
		pass

func _ready():
	if Engine.is_editor_hint():
		return
	
	# 고유 ID가 없으면 자동 생성
	if companion_id.is_empty():
		companion_id = _generate_unique_id()
	
	setup_companion()
	print_debug("Companion '", companion_name, "' initialized with ID: ", companion_id)
	
	# 열 상태 모니터링 시작
	if heat_component:
		heat_component.heat_changed.connect(_on_heat_changed)
		# print_debug("🔥 Heat monitoring started for: ", companion_name)
	
	# 동료 전용 스탯 변경 시그널 연결
	if stat_component:
		stat_component.companion_stats_changed.connect(_on_companion_stats_changed)

func _on_companion_stats_changed():
	"""동료 스탯 변경 시 호출 (무기 타입 갱신)"""
	if stat_component and stat_component.has_method("_update_weapon_types"):
		stat_component._update_weapon_types()

func setup_skills_system():
	"""Skills 시스템 초기화 (플레이어와 동일한 방식)"""
	var skills_node = get_node_or_null("Skills")
	if not skills_node:
		print_debug("Skills node not found in scene for companion: ", companion_name)
		return
	
	# SkillManager 스크립트가 이미 적용되어 있는지 확인
	if skills_node and not skills_node.get_script():
		var skill_manager_script = load("res://Assets/PreFabs/Entity/Companion/Scripts/companion_skill_manager.gd")
		if skill_manager_script:
			skills_node.set_script(skill_manager_script)
			skills_node.companion = self
			print_debug("CompanionSkillManager initialized for: ", companion_name)
		else:
			print_debug("CompanionSkillManager script not found")
	
	# 기본 공격 스킬이 이미 씬에 있는지 확인
	var attack_skill = get_node_or_null("Skills/Marsh_Attack")
	if attack_skill:
		if not attack_skill.get_script():
			var attack_skill_script = load("res://Assets/PreFabs/Entity/Companion/Scripts/skills/Marsh_Attack.gd")
			if attack_skill_script:
				attack_skill.set_script(attack_skill_script)
				print_debug("Marsh_Attack skill script applied for: ", companion_name)
			else:
				print_debug("Marsh_Attack skill script not found")
		
		# Marsh_Attack 스크립트가 있으면 companion 변수 설정
		if attack_skill.has_method("initialize"):
			attack_skill.initialize(self)
			print_debug("Marsh_Attack initialized with companion: ", companion_name)
		else:
			print_debug("Marsh_Attack initialize method not found")
	
	print_debug("Skills system setup completed for companion: ", companion_name)
	
	# CombatAI 초기화
	var combat_ai = get_node_or_null("CombatAI")
	if combat_ai and combat_ai.has_method("initialize"):
		if combat_ai.initialize(self):
			print_debug("CombatAI initialized for: ", companion_name)
		else:
			print_debug("CombatAI initialization failed for: ", companion_name)
	else:
		print_debug("CombatAI not found or initialize method missing for: ", companion_name)

func _generate_unique_id() -> String:
	"""동료의 고유 ID를 생성합니다."""
	# 🔥 더 안정적인 ID 생성: 이름 기반 + 간단한 해시
	var name_hash = companion_name.hash()
	var scene_hash = get_tree().current_scene.scene_file_path.hash() if get_tree().current_scene else 0
	
	# 씬 전환 시에도 동일한 ID를 유지할 수 있도록 간단한 해시 사용
	var stable_id = abs(name_hash + scene_hash) % 1000000
	return "companion_%s_%d" % [companion_name, stable_id]

func setup_companion():
	"""동료 초기 설정"""
	# 카메라 기본적으로 비활성화 (플레이어 조작 시에만 활성화)
	if camera:
		camera.enabled = false
	
	# 스프라이트 시스템 초기화
	setup_sprite_system()
	
	# 상태 머신 초기화
	if state_machine:
		# CompanionStateMachine 스크립트 설정
		if not state_machine.get_script():
			var state_machine_script = load("res://Assets/PreFabs/Entity/Companion/Scripts/CompanionStateMachine.gd")
			state_machine.set_script(state_machine_script)
		
		# State Machine 초기화 (안전하게)
		if state_machine.has_method("initialize"):
			state_machine.initialize(self)
			print_debug("State Machine initialized for: ", companion_name)
		else:
			print_debug("State Machine initialize method not found for: ", companion_name)
	
	# Skills 시스템 초기화 (플레이어와 동일한 방식)
	setup_skills_system()
	
	# 패시브 시스템 초기화
	setup_passive_system()
	
	# 기본 장비 설정
	setup_default_equipment()
	
	# AI 초기화
	if companion_ai:
		companion_ai.setup(self)

func setup_default_equipment():
	"""동료 기본 장비 설정"""
	# 동료별 기본 무기 설정
	match companion_name:
		"Marsh":
			equip_weapon("Sword", "right_arm")  # Marsh는 기본적으로 검 사용
		_:
			equip_weapon("Fists", "right_arm")  # 기본값: 맨손
	
	print_debug("Default equipment set for: ", companion_name, " - ", get_equipment_info())
	
	# 내비게이션 설정
	if navigation_agent:
		navigation_agent.target_desired_distance = 15.0
		navigation_agent.path_desired_distance = 10.0
		navigation_agent.path_max_distance = 50.0
	
	# 신호 연결
	if health_component:
		health_component.health_depleted.connect(_on_health_depleted)
	
	# GlobalController에 등록 (플레이어 참조 설정 후에 수행됨)
	# GlobalController.register_companion(self)  # 이제 World.gd에서 호출
	
	print_debug("Companion setup complete: ", companion_name, " AI enabled: ", companion_ai != null)

func setup_sprite_system():
	"""스프라이트 시스템 초기화 - 단일/다중 스프라이트 자동 감지"""
	if sprites_container and sprites_container.get_child_count() > 0:
		# 다중 스프라이트 시스템 (마시 등)
		print_debug("Setting up multi-sprite system for: ", companion_name)
		
		# 마시 전용 스프라이트 매니저 생성
		if companion_name == "Marsh":
			sprite_manager = preload("res://Assets/PreFabs/Entity/Companion/Scripts/MarshSpriteManager.gd").new()
			sprites_container.add_child(sprite_manager)
			# 스프라이트 매니저를 컨테이너의 첫 번째 자식으로 이동
			sprites_container.move_child(sprite_manager, 0)
			print_debug("MarshSpriteManager created for: ", companion_name)
			
			# MarshSpriteManager가 AnimationTree를 찾을 수 있도록 지연 초기화
			call_deferred("ensure_sprite_manager_ready")
		
		# 기본 sprite 참조를 다중 스프라이트의 첫 번째로 설정 (호환성)
		var first_sprite = sprites_container.get_child(sprites_container.get_child_count() - 1)  # 마지막 스프라이트 (최상위 레이어)
		if first_sprite is Sprite2D:
			sprite = first_sprite
			print_debug("Primary sprite set to: ", first_sprite.name)
	else:
		# 단일 스프라이트 시스템 (기존 동료들)
		print_debug("Using single-sprite system for: ", companion_name)
		if not sprite:
			sprite = $Sprite2D

func ensure_sprite_manager_ready():
	"""스프라이트 매니저가 준비되었는지 확인하고 초기화"""
	if sprite_manager and sprite_manager.has_method("initialize_animation_tree"):
		print_debug("Ensuring sprite manager is ready...")
		sprite_manager.initialize_animation_tree()
	else:
		print_debug("Sprite manager not ready yet, will retry...")
		call_deferred("ensure_sprite_manager_ready")

func _physics_process(delta):
	if Engine.is_editor_hint():
		return
	
	delta *= Global.slow_factor
	
	if is_player_controlled:
		# 플레이어 조작 중 - 입력 처리 및 물리 처리
		handle_player_input()
		# 🔥 상태 머신이 활성화되어 있으면 여기서 move_and_slide 호출하지 않음
		if not state_machine or not state_machine.current_state:
			move_and_slide()
	else:
		# AI 모드 - AI가 velocity를 설정하고 여기서 물리 처리
		if auto_pilot_enabled and companion_ai:
			companion_ai.process_ai(delta)
			# 🔥 상태 머신이 활성화되어 있으면 여기서 move_and_slide 호출하지 않음
			if not state_machine or not state_machine.current_state:
				move_and_slide()
			
			# 🔥 AI 모드에서 velocity 정리 (관성 제거)
			cleanup_ai_velocity()
	
	# 모든 모드에서 애니메이션 업데이트
	update_animation()

func cleanup_ai_velocity():
	"""AI 모드에서 velocity의 관성을 제거하여 플레이어와 동일한 이동 느낌 구현"""
	if not companion_ai or not companion_ai.use_instant_velocity:
		return
	
	# 🔥 main_player가 유효한지 확인
	if not main_player or not is_instance_valid(main_player):
		return
	
	# 🔥 목표 위치에 가까우면 즉시 정지 (더 정확한 거리 계산)
	var distance_to_player = global_position.distance_to(main_player.global_position)
	if distance_to_player <= companion_ai.follow_distance:
		velocity = Vector2.ZERO
		return
	
	# 🔥 velocity가 너무 작으면 완전히 정지 (관성 제거)
	if velocity.length() < companion_ai.instant_stop_threshold:
		velocity = Vector2.ZERO

func _input(event):
	if not is_player_controlled:
		return
	
	# 플레이어 조작 중일 때만 입력 처리
	handle_input_events(event)
	
	# 열 부스트 스킬 (R 키)
	if event.is_action_pressed("heat_boost"):
		# print_debug("🔥 R key pressed for Heat Boost!")
		# print_debug("  - Event details: ", event)
		# print_debug("  - is_player_controlled: ", is_player_controlled)
		# print_debug("  - GlobalController.active_unit: ", GlobalController.active_unit.name if GlobalController.active_unit else "null")
		
		if skill_component:
			# print_debug("  ✅ SkillComponent found")
			var result = skill_component.execute_skill_by_id("heat_boost")
			# print_debug("  📊 Skill execution result: ", result)
		else:
			# print_debug("  ❌ SkillComponent not found!")
			# print_debug("  - Skills node: ", get_node_or_null("Skills"))
			# print_debug("  - SkillComponent node: ", get_node_or_null("Skills/SkillComponent"))
			pass
	
	# 임시: 동료 에너지 회복 (T 키)
	if event.is_action_pressed("test"):
		if energy_component:
			energy_component.energy = energy_component.MAX_ENERGY
			# print_debug("🔋 Companion energy restored to max!")
	
	# F키로 전투 AI 상태 확인 (디버그용)
	if event.is_action_pressed("ui_accept"):  # F키
		debug_combat_ai_status()
	
	# 상태 머신에도 입력 전달 (상태 머신이 입력을 처리하는 경우)
	if state_machine and state_machine.current_state and state_machine.current_state.has_method("handle_input"):
		state_machine.current_state.handle_input(event)
	
	# 마우스 위치 업데이트 (공격 방향 계산용)
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		update_mouse_direction()

func handle_player_input():
	"""플레이어 직접 조작 시 입력 처리 (상태 머신 전용)"""
	if not is_player_controlled:
		return
	
	# 현재 활성 유닛이 자신이 아니면 입력 차단
	if GlobalController.active_unit != self:
		return
	
	# 이벤트 중이거나 공격 중이면 입력 무시
	if EventManager.is_event_ongoing:
		velocity = Vector2.ZERO
		return
	
	# 디버그: 입력 상태 확인
	# print_debug("Marsh input debug - is_player_controlled: ", is_player_controlled, " active_unit: ", GlobalController.active_unit.name if GlobalController.active_unit else "null")
	
	# 이동 입력 (플레이어와 동일한 방식)
	var input_left = "Input_A"
	var input_right = "Input_D"
	var input_up = "Input_W"
	var input_down = "Input_S"
	input_vector = Input.get_vector(input_left, input_right, input_up, input_down)
	# WASD 키만 사용 (상하좌우 키 차단)
	if input_vector == Vector2.ZERO:
		# 상하좌우 키는 무시하고 WASD 액션만 사용
		var left = Input.is_action_pressed("Input_A")
		var right = Input.is_action_pressed("Input_D")
		var up = Input.is_action_pressed("Input_W")
		var down = Input.is_action_pressed("Input_S")
		input_vector = Vector2(int(right) - int(left), int(down) - int(up))
	
	# 달리기 입력 (Space 키)
	is_running = Input.is_key_pressed(KEY_SPACE)
	
	# 가드 입력 (Shift 키)
	is_guarding = Input.is_key_pressed(KEY_SHIFT)
	
	# 대시 중이면 대시 속도 사용
	if dash_component and dash_component.is_dashing:
		velocity = dash_component.get_dash_velocity()
	else:
		# 일반 이동 속도 계산
		var current_speed = run_speed if is_running else move_speed
		velocity = input_vector.normalized() * current_speed * Global.slow_factor
	
	# 디버그: 입력 벡터와 속도 확인
	# print_debug("Marsh movement debug - input_vector: ", input_vector, " velocity: ", velocity, " is_running: ", is_running)
	
	# 애니메이션 업데이트
	update_animation()

func handle_input_events(event: InputEvent):
	"""키 이벤트 처리 (공격, 스킬 등)"""
	if not is_player_controlled:
		return
	
	# 현재 활성 유닛이 자신이 아니면 입력 차단
	if GlobalController.active_unit != self:
		return
	
	# 공격 입력 처리 (좌클릭)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_attack_input()
	
	# 스킬 입력 처리 (우클릭)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_handle_skill_input()
	
	# 대시 입력 처리 (스페이스 키)
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		_handle_dash_input()
	
	# 점프 입력 처리 (F 키)
	if event is InputEventKey and event.keycode == KEY_F and event.pressed:
		_handle_jump_input()

func _handle_attack_input():
	"""공격 입력 처리 - 콤보 시스템과 연동"""
	if not is_player_controlled:
		return
	
	# Skills 노드에서 Marsh_Attack 찾기
	var skills_node = get_node_or_null("Skills")
	if not skills_node:
		print_debug("Skills node not found for attack input")
		return
	
	var marsh_attack = skills_node.get_node_or_null("Marsh_Attack")
	if not marsh_attack:
		print_debug("Marsh_Attack not found in Skills node")
		return
	
	# Marsh_Attack이 초기화되었는지 확인
	if not marsh_attack.companion:
		print_debug("Marsh_Attack not initialized, attempting to initialize...")
		marsh_attack.initialize(self)
	
	# 콤보 시스템과 연동하여 공격 실행
	if marsh_attack.has_method("start_combo") and marsh_attack.has_method("continue_combo"):
		if not marsh_attack.is_combo_active:
			# 콤보 시작
			print_debug("Starting Marsh attack combo...")
			marsh_attack.start_combo()
		else:
			# 콤보 계속
			print_debug("Continuing Marsh attack combo...")
			marsh_attack.continue_combo()
	elif marsh_attack.has_method("execute_combo"):
		# 기존 방식 (자동 콤보)
		print_debug("Executing Marsh attack combo (legacy mode)...")
		marsh_attack.execute_combo()
	else:
		print_debug("Marsh_Attack combo methods not found")

func _handle_skill_input():
	"""스킬 입력 처리"""
	if not is_player_controlled:
		return
	
	print_debug("Skill input received for companion: ", companion_name)
	# TODO: 스킬 시스템 구현

func _handle_dash_input():
	"""대시 입력 처리"""
	if not is_player_controlled:
		return
	
	if dash_component and dash_component.has_method("execute_dash"):
		print_debug("Executing dash for companion: ", companion_name)
		dash_component.execute_dash()
	else:
		print_debug("Dash component not available for companion: ", companion_name)

func _handle_jump_input():
	"""점프 입력 처리"""
	if not is_player_controlled:
		return
	
	if jump_component and jump_component.has_method("jump"):
		print_debug("Executing jump for companion: ", companion_name)
		jump_component.jump()
	else:
		print_debug("Jump component not available for companion: ", companion_name)

func update_mouse_direction():
	"""마우스 방향을 업데이트하여 공격 방향과 애니메이션에 사용 - 공격 방향 기반"""
	if not is_player_controlled:
		return
	
	# 월드 좌표계 기준으로 마우스 위치 가져오기
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	
	# 디버그: 동료 위치와 마우스 위치 확인
	print_debug("Companion: Global position: %s, Mouse position: %s, Distance: %s" % [
		global_position, mouse_pos, global_position.distance_to(mouse_pos)
	])
	
	# 애니메이션 트리에 방향 전달 (BlendSpace2D가 올바르게 설정됨)
	if animation_tree:
		animation_tree.set("parameters/StateMachine/Idle/blend_position", direction)
		animation_tree.set("parameters/StateMachine/Walk/blend_position", direction)
		animation_tree.set("parameters/StateMachine/Slash/blend_position", direction)
		animation_tree.set("parameters/StateMachine/DoubleThrust/blend_position", direction)
		animation_tree.set("parameters/StateMachine/Thrust/blend_position", direction)
	
	print_debug("Marsh mouse direction updated - direction: %s" % [direction])

func update_animation_from_attack_direction(attack_direction: Vector2):
	"""공격 방향을 기반으로 애니메이션 블렌딩 업데이트"""
	if not animation_tree:
		return
	
	# 애니메이션 트리에 공격 방향 전달 (BlendSpace2D가 올바르게 설정됨)
	animation_tree.set("parameters/StateMachine/Idle/blend_position", attack_direction)
	animation_tree.set("parameters/StateMachine/Walk/blend_position", attack_direction)
	animation_tree.set("parameters/StateMachine/Slash/blend_position", attack_direction)
	animation_tree.set("parameters/StateMachine/DoubleThrust/blend_position", attack_direction)
	animation_tree.set("parameters/StateMachine/Thrust/blend_position", attack_direction)
	
	print_debug("Marsh animation updated from attack direction: %s" % [attack_direction])



func switch_to_player_control():
	"""플레이어 조작 모드로 전환"""
	# print_debug("Switching to player control: ", companion_name)
	
	# 1단계: 상태 머신을 즉시 Idle로 강제 전환 (AI 내비게이션 차단)
	if state_machine:
		var idle_state = state_machine.get_state_by_name("CompanionStateIdle")
		if idle_state and state_machine.has_method("change_state"):
			state_machine.change_state(idle_state)
			# print_debug("Companion ", companion_name, " state immediately changed to Idle to block AI navigation")
	
	# 2단계: AI 동작 완료 대기 또는 강제 정지
	if companion_ai and companion_ai.is_enabled:
		if companion_ai.is_ready_for_player_control():
			# print_debug("AI action completed, safe to switch to player control")
			pass
		else:
			# print_debug("AI action in progress, forcing stop for player control")
			companion_ai.force_stop_for_player_control()
	
	is_player_controlled = true
	auto_pilot_enabled = false
	
	# 카메라 활성화
	if camera:
		camera.enabled = true
		camera.make_current()
	
	# AI 비활성화 및 모든 AI 상태 리셋
	if companion_ai:
		companion_ai.set_enabled(false)
		companion_ai.reset_ai_state()  # AI 상태 완전 리셋
	
	# 기존 명령 취소
	cancel_current_order()
	
	# 물리 상태 즉시 초기화 (AI의 velocity 제거)
	velocity = Vector2.ZERO
	
	# 입력 상태 초기화
	input_vector = Vector2.ZERO
	is_running = false
	is_guarding = false
	
	# 3단계: 플레이어 조작 모드용 상태로 전환 (이미 Idle 상태이므로 추가 전환 불필요)
	# reset_to_player_control_state()  # 이미 Idle 상태이므로 호출하지 않음
	
	emit_signal("companion_switch_to")

func switch_to_ai_control():
	"""AI 조작 모드로 전환"""
	# print_debug("Switching to AI control: ", companion_name)
	
	is_player_controlled = false
	auto_pilot_enabled = true
	
	# 카메라 비활성화
	if camera:
		camera.enabled = false
	
	# AI 활성화
	if companion_ai:
		companion_ai.set_enabled(true)
		# AI 행동 상태를 기본 추적 모드로 설정
		companion_ai.set_behavior(companion_ai.CompanionBehavior.FOLLOW_PLAYER)
		companion_ai.retarget_to_player_now()
		# 내비게이션 목표를 플레이어 위치로 재설정 (이전 목표 제거)
		if companion_ai.player:
			companion_ai.navigation_agent.target_position = companion_ai.player.global_position
			# print_debug("CompanionAI: Navigation target reset to player position for AI control")
			
			# 빠른 추적 활성화: 플레이어와의 거리 확인
			var distance_to_player = global_position.distance_to(companion_ai.player.global_position)
			if distance_to_player > companion_ai.fast_follow_distance:
				# print_debug("CompanionAI: Fast follow mode activated - distance: ", distance_to_player)
				pass
	
	# 입력 상태 초기화
	input_vector = Vector2.ZERO
	is_running = false
	is_guarding = false
	velocity = Vector2.ZERO  # 물리 상태도 초기화
	
	# 상태 머신을 적절한 AI 상태로 전환
	reset_to_ai_state()
	
	emit_signal("companion_switched_from")

func reset_to_ai_state():
	"""AI 모드로 전환 시 적절한 상태로 리셋"""
	if not state_machine:
		# print_debug("State machine not found for companion: ", companion_name)
		return
	
	# 현재 플레이어와의 거리 확인
	var target_state: Node = null
	
	if companion_ai and companion_ai.player and is_instance_valid(companion_ai.player):
		var distance_to_player = global_position.distance_to(companion_ai.player.global_position)
		
		# 거리에 따라 적절한 상태 결정
		if distance_to_player > companion_ai.follow_distance * 1.2:
			# 플레이어가 멀면 Following 상태로
			target_state = state_machine.get_state_by_name("CompanionStateFollowing")
			# print_debug("Resetting to Following state - distance: ", distance_to_player)
		else:
			# 플레이어가 가까우면 Idle 상태로
			target_state = state_machine.get_state_by_name("CompanionStateIdle")
			# print_debug("Resetting to Idle state - distance: ", distance_to_player)
	else:
		# 플레이어 참조가 없으면 기본 Idle 상태
		target_state = state_machine.get_state_by_name("CompanionStateIdle")
		# print_debug("Resetting to Idle state - no player reference")
	
	# 상태 전환 실행
	if target_state and state_machine.has_method("change_state"):
		state_machine.change_state(target_state)
		# print_debug("Companion ", companion_name, " state reset to: ", target_state.get_script().get_global_name() if target_state.get_script() else target_state.name)
	else:
		# print_debug("Could not reset state for companion: ", companion_name, " - target_state: ", target_state)
		pass

func reset_to_player_control_state():
	"""플레이어 조작 모드로 전환 시 적절한 상태로 리셋"""
	if not state_machine:
		print_debug("State machine not found for companion: ", companion_name)
		return
	
	# 플레이어 조작 모드에서는 Idle 상태로 시작 (AI 내비게이션 완전 차단)
	var idle_state = state_machine.get_state_by_name("CompanionStateIdle")
	
	if idle_state and state_machine.has_method("change_state"):
		state_machine.change_state(idle_state)
		print_debug("Companion ", companion_name, " state reset to Idle for AI navigation blocking")
		
		# 입력 벡터를 즉시 업데이트하여 첫 프레임부터 입력 감지
		call_deferred("update_input_vector_immediately")
	else:
		print_debug("Could not reset to player control state for companion: ", companion_name)

func update_input_vector_immediately():
	"""플레이어 조작 모드 전환 직후 입력 벡터를 즉시 업데이트"""
	if not is_player_controlled:
		return
	
	# AI에서 온 velocity가 남아있을 수 있으므로 먼저 리셋
	if velocity != Vector2.ZERO:
		print_debug("Companion ", companion_name, " resetting leftover AI velocity: ", velocity)
		velocity = Vector2.ZERO
	
	# 현재 WASD 입력 상태를 즉시 확인하여 input_vector 업데이트
	var left = Input.is_action_pressed("Input_A")
	var right = Input.is_action_pressed("Input_D")
	var up = Input.is_action_pressed("Input_W")
	var down = Input.is_action_pressed("Input_S")
	
	input_vector = Vector2(int(right) - int(left), int(down) - int(up))
	
	print_debug("Companion ", companion_name, " input vector updated immediately: ", input_vector)
	
	# 입력이 있으면 즉시 velocity 설정
	if input_vector != Vector2.ZERO:
		var dir = input_vector.normalized()
		var speed = run_speed if is_running else move_speed
		velocity = dir * speed * Global.slow_factor
		print_debug("Companion ", companion_name, " velocity set immediately: ", velocity)
	else:
		# 입력이 없으면 velocity를 확실히 0으로 설정
		velocity = Vector2.ZERO
		print_debug("Companion ", companion_name, " no input - velocity set to zero")

func set_main_player(player: CharacterBody2D):
	"""메인 플레이어 설정"""
	# null 체크 및 유효성 검사 추가
	if not player or not is_instance_valid(player):
		print_debug("WARNING: Invalid player passed to set_main_player for companion: ", companion_name)
		main_player = null
		if companion_ai:
			companion_ai.set_player(null)
		return
	
	main_player = player
	if companion_ai:
		companion_ai.set_player(player)

func give_order(order_type: String, target_position: Vector2 = Vector2.ZERO, target_entity: Node2D = null):
	"""동료에게 명령 전달"""
	if is_player_controlled:
		print_debug("Cannot give order - companion is player controlled")
		return
	
	current_order = {
		"type": order_type,
		"target_position": target_position,
		"target_entity": target_entity,
		"timestamp": Time.get_ticks_msec()
	}
	
	if companion_ai:
		companion_ai.execute_order(current_order)

func cancel_current_order():
	"""현재 명령 취소"""
	current_order.clear()
	if companion_ai:
		companion_ai.cancel_order()

func perform_attack():
	"""공격 수행"""
	var skill = get_node_or_null("Skills/Marsh_Attack")
	if skill:
		if skill.has_method("trigger_next_step_by_click") and skill.trigger_next_step_by_click():
			return
		elif skill.has_method("execute_combo"):
			skill.execute_combo()
			return
	print_debug(companion_name, " performs attack (no skill found)")

func use_skill(skill_index: int):
	"""스킬 사용"""
	# TODO: 스킬 시스템 연동
	print_debug(companion_name, " uses skill ", skill_index)

# === 장비 시스템 ===

# 동료별 무기 제한 설정 (인스펙터에서 수정 가능)
# Combat_manager의 WeaponType enum 사용
@export var allowed_weapon_types: Array[CombatManager.WeaponType] = [CombatManager.WeaponType.SWORD, CombatManager.WeaponType.FISTS, CombatManager.WeaponType.SMG]

func can_equip_weapon(weapon_name: String) -> bool:
	"""동료가 해당 무기를 장착할 수 있는지 확인"""
	var weapon_type = CombatManager.get_weapon_type(weapon_name)
	var can_equip = weapon_type in allowed_weapon_types
	
	print_debug("CompanionEquipment: %s can equip %s (%s): %s" % [
		companion_name, 
		weapon_name, 
		CombatManager.weapon_type_to_string(weapon_type), 
		"YES" if can_equip else "NO"
	])
	
	return can_equip

func equip_weapon(weapon_name: String, slot: String = "right_arm") -> bool:
	"""동료에게 무기 장착"""
	if not stat_component:
		print_debug("CompanionEquipment: No StatComponent found")
		return false
	
	# 무기 제한 검사
	if not can_equip_weapon(weapon_name):
		print_debug("CompanionEquipment: %s cannot equip %s - weapon type not allowed" % [companion_name, weapon_name])
		return false
	
	match slot:
		"right_arm":
			stat_component.current_right_arm = weapon_name
		"left_arm":
			stat_component.current_left_arm = weapon_name
		_:
			print_debug("CompanionEquipment: Invalid slot: ", slot)
			return false
	
	print_debug("CompanionEquipment: Equipped %s in %s for %s" % [weapon_name, slot, companion_name])
	
	# 스킬들에게 장비 변경 알림
	var skills_node = get_node_or_null("Skills")
	if skills_node:
		for skill in skills_node.get_children():
			if skill.has_method("on_equipment_changed"):
				skill.on_equipment_changed()
	
	return true

func unequip_weapon(slot: String = "right_arm") -> bool:
	"""동료의 무기 해제"""
	if not stat_component:
		return false
	
	var old_weapon = ""
	match slot:
		"right_arm":
			old_weapon = stat_component.current_right_arm
			stat_component.current_right_arm = ""
		"left_arm":
			old_weapon = stat_component.current_left_arm
			stat_component.current_left_arm = ""
		_:
			print_debug("CompanionEquipment: Invalid slot: ", slot)
			return false
	
	print_debug("CompanionEquipment: Unequipped %s from %s for %s" % [old_weapon, slot, companion_name])
	
	# 스킬들에게 장비 변경 알림
	var skills_node = get_node_or_null("Skills")
	if skills_node:
		for skill in skills_node.get_children():
			if skill.has_method("on_equipment_changed"):
				skill.on_equipment_changed()
	
	return true

func get_equipped_weapon(slot: String = "right_arm") -> String:
	"""장착된 무기 가져오기 (하위 호환성 유지)"""
	return get_equipped_item(slot)

func get_equipped_item(slot: String) -> String:
	"""지정된 슬롯의 장착된 아이템 가져오기"""
	if not stat_component or not stat_component.stat:
		return ""
	
	# 플레이어와 동일한 장비 슬롯 시스템 사용
	if stat_component.stat.equipment_slots.has(slot):
		var item = stat_component.stat.equipment_slots[slot]
		if item:
			return item.name
		return ""
	
	# 하위 호환성을 위한 기존 시스템
	match slot:
		"right_arm":
			return stat_component.current_right_arm if stat_component.current_right_arm else ""
		"left_arm":
			return stat_component.current_left_arm if stat_component.current_left_arm else ""
		_:
			return ""

func get_equipment_info() -> Dictionary:
	"""동료의 장비 정보 반환"""
	var equipment_info = {}
	
	# 모든 장비 슬롯 정보 수집
	if stat_component and stat_component.stat:
		for slot in stat_component.stat.equipment_slots:
			var item = stat_component.stat.equipment_slots[slot]
			if item:
				equipment_info[str(slot)] = {
					"name": item.name,
					"type": item.get_class(),
					"serial_number": item.serial_number if item.has_method("get") and item.get("serial_number") else ""
				}
			else:
				equipment_info[str(slot)] = null
	
	# 하위 호환성을 위한 기존 필드들
	equipment_info["right_arm"] = get_equipped_weapon("right_arm")
	equipment_info["left_arm"] = get_equipped_weapon("left_arm")
	equipment_info["has_weapon"] = get_equipped_weapon("right_arm") != "" or get_equipped_weapon("left_arm") != ""
	
	return equipment_info

# === 동료 상태 저장/불러오기 시스템 ===

func save_companion_state() -> Dictionary:
	"""동료의 현재 상태를 저장 데이터로 반환"""
	print_debug("🔥 Companion.save_companion_state() called for: ", companion_name)
	print_debug("  - Current heat: ", heat_component.heat if heat_component else "N/A")
	print_debug("  - Has Marsh_Attack node: ", has_node("Skills/Marsh_Attack"))
	
	var save_data = {
		"companion_id": companion_id,  # 고유 ID 추가
		"companion_name": companion_name,
		"scene_path": get_scene_file_path(),  # 씬 경로 추가
		"position": global_position,
		"equipment": get_equipment_info(),  # 전체 장비 정보 저장
		"stats": {},
		"ai_state": {
			"current_behavior": companion_ai.current_behavior if companion_ai else "FOLLOW_PLAYER",
			"is_player_controlled": is_player_controlled
		},
		"timestamp": Time.get_unix_time_from_system()  # 저장 시간 추가
	}
	
	# 스탯 정보 저장
	if stat_component and stat_component.stat:
		save_data["stats"] = {
			"health": health_component.health if health_component else 0,
			"max_health": health_component.MAX_HEALTH if health_component else 0,
			"energy": energy_component.energy if energy_component else 0,
			"max_energy": energy_component.MAX_ENERGY if energy_component else 0,
			"heat": heat_component.heat if heat_component else 0,
			"max_heat": heat_component.MAX_HEAT if heat_component else 0
		}
	
	# 🔥 HeatAttackManager 상태 저장 추가
	var marsh_attack_node = get_node_or_null("Skills/Marsh_Attack")
	if marsh_attack_node and marsh_attack_node.heat_attack_manager:
		save_data["heat_attack_manager"] = marsh_attack_node.heat_attack_manager.save_heat_state()
		print_debug("🔥 HeatAttackManager state saved for: ", companion_name)
	else:
		print_debug("⚠️ HeatAttackManager not found for: ", companion_name)
	
	# 🔥 StatusEffectComponent 상태 효과 저장 추가
	if status_effect_component:
		save_data["status_effects"] = status_effect_component.save_status_effects()
		print_debug("🔥 StatusEffectComponent state saved for: ", companion_name)
	else:
		print_debug("⚠️ StatusEffectComponent not found for: ", companion_name)
	
	print_debug("CompanionEquipment: Saved state for %s - Equipment: %s" % [companion_name, save_data.equipment])
	return save_data

func load_companion_state(state_data: Dictionary):
	"""저장된 상태 데이터로 동료 상태 복원"""
	print_debug("🔥 Companion.load_companion_state() called for: ", companion_name)
	print_debug("  - State data keys: ", state_data.keys())
	print_debug("  - Has heat_attack_manager: ", state_data.has("heat_attack_manager"))
	
	# ID와 이름으로 데이터 검증
	if not state_data.has("companion_id") or not state_data.has("companion_name"):
		print_debug("CompanionEquipment: Missing ID or name in state data for %s" % companion_name)
		return false
	
	# 🔥 ID 매칭을 더 유연하게 처리: 이름이 일치하면 ID가 달라도 허용
	var id_matches = state_data.companion_id == companion_id
	var name_matches = state_data.companion_name == companion_name
	
	if not name_matches:
		print_debug("CompanionEquipment: Name mismatch for %s (saved: %s vs current: %s)" % [
			companion_name, state_data.companion_name, companion_name
		])
		return false
	
	if not id_matches:
		print_debug("CompanionEquipment: ID mismatch for %s (saved: %s vs current: %s) - but name matches, proceeding with load" % [
			companion_name, state_data.companion_id, companion_id
		])
		# ID가 달라도 이름이 일치하면 계속 진행 (씬 전환 시 새로운 ID 생성되는 경우)
	else:
		print_debug("CompanionEquipment: ID and name both match for %s" % companion_name)
	
	print_debug("CompanionEquipment: Loading state for %s" % companion_name)
	
	# 위치 복원
	if state_data.has("position"):
		global_position = state_data.position
		print_debug("CompanionEquipment: Position restored to %s" % global_position)
	
	# 장비 복원
	if state_data.has("equipment"):
		var equipment = state_data.equipment
		
		# 전체 장비 슬롯 복원
		if stat_component and stat_component.stat:
			for slot_key in equipment:
				# 기존 하위 호환성 필드들은 건너뛰기
				if slot_key in ["right_arm", "left_arm", "has_weapon"]:
					continue
				
				var slot_data = equipment[slot_key]
				if slot_data and slot_data is Dictionary and slot_data.has("name"):
					# 아이템 이름으로 장비 복원
					var item_name = slot_data.name
					if item_name != "":
						_equip_item_to_slot(item_name, slot_key)
						print_debug("Restored %s to slot %s" % [item_name, slot_key])
		
		# 하위 호환성을 위한 기존 무기 복원
		if equipment.has("right_arm") and equipment.right_arm != "":
			equip_weapon(equipment.right_arm, "right_arm")
		if equipment.has("left_arm") and equipment.left_arm != "":
			equip_weapon(equipment.left_arm, "left_arm")
		
		print_debug("CompanionEquipment: Equipment restored - Right: %s, Left: %s" % [
			get_equipped_weapon("right_arm"), 
			get_equipped_weapon("left_arm")
		])



	# 스탯 복원
	if state_data.has("stats") and stat_component and stat_component.stat:
		var stats = state_data.stats
		if health_component and stats.has("health"):
			health_component.health = stats.health
		if energy_component and stats.has("energy"):
			energy_component.energy = stats.energy
		if heat_component and stats.has("heat"):
			heat_component.heat = stats.heat
		print_debug("CompanionEquipment: Stats restored")
	
	# AI 상태 복원
	if state_data.has("ai_state") and companion_ai:
		var ai_state = state_data.ai_state
		if ai_state.has("current_behavior"):
			companion_ai.current_behavior = ai_state.current_behavior
		if ai_state.has("is_player_controlled"):
			is_player_controlled = ai_state.is_player_controlled
		print_debug("CompanionEquipment: AI state restored")
	
	# 🔥 HeatAttackManager 상태 복원 추가
	if state_data.has("heat_attack_manager"):
		var marsh_attack_node = get_node_or_null("Skills/Marsh_Attack")
		if marsh_attack_node and marsh_attack_node.heat_attack_manager:
			marsh_attack_node.heat_attack_manager.load_heat_state(state_data.heat_attack_manager)
			print_debug("🔥 HeatAttackManager state restored for: ", companion_name)
		else:
			print_debug("⚠️ HeatAttackManager not found for restoration: ", companion_name)
	else:
		print_debug("ℹ️ No HeatAttackManager state to restore for: ", companion_name)
	
	# 🔥 StatusEffectComponent 상태 효과 복원 추가
	if state_data.has("status_effects") and status_effect_component:
		var success = status_effect_component.load_status_effects(state_data.status_effects)
		if success:
			print_debug("🔥 StatusEffectComponent state restored for: ", companion_name)
		else:
			print_debug("⚠️ StatusEffectComponent state restoration failed for: ", companion_name)
	else:
		print_debug("ℹ️ No StatusEffectComponent state to restore for: ", companion_name)
	
	return true

func update_animation():
	# print_debug("Companion ", companion_name, " update_animation - velocity: ", velocity, " sprite_manager: ", sprite_manager != null)

	# 애니메이션에서 '정지' 판단 임계값
	var anim_stop_threshold = 6.0

	# 플레이어 직접 조작 시(우선순위): velocity 기반으로만 처리
	if is_player_controlled and GlobalController.active_unit == self:
		if sprite_manager:
			if velocity.length() < anim_stop_threshold:
				# 정지 처리 강제
				sprite_manager.update_movement_animation(Vector2.ZERO)
				sprite_manager.set_animation_speed(1.0 * Global.slow_factor)
			else:
				sprite_manager.update_movement_animation(velocity)
				sprite_manager.set_animation_speed((1.5 if is_running else 1.0) * Global.slow_factor)
		elif animation_tree:
			var is_moving = velocity.length() >= anim_stop_threshold
			animation_tree.set("parameters/StateMachine/conditions/walk", is_moving)
			animation_tree.set("parameters/StateMachine/conditions/idle", not is_moving)
			if is_moving:
				animation_tree.set("parameters/StateMachine/Walk/blend_position", velocity.normalized())
				animation_tree.set("parameters/StateMachine/Idle/blend_position", velocity.normalized())
			else:
				animation_tree.set("parameters/StateMachine/Walk/blend_position", Vector2.ZERO)
				animation_tree.set("parameters/StateMachine/Idle/blend_position", Vector2.ZERO)
		return

	# AI/기본 모드: 기존 로직 유지하되 작은 속도는 idle로 강제
	if sprite_manager:
		if velocity.length() < anim_stop_threshold:
			sprite_manager.update_movement_animation(Vector2.ZERO)
			sprite_manager.set_animation_speed(1.0 * Global.slow_factor)
		else:
			sprite_manager.update_movement_animation(velocity)
			sprite_manager.set_animation_speed((1.5 if is_running else 1.0) * Global.slow_factor)

	elif animation_tree:
		var is_moving = velocity.length() >= anim_stop_threshold
		animation_tree.set("parameters/StateMachine/conditions/walk", is_moving)
		animation_tree.set("parameters/StateMachine/conditions/idle", not is_moving)
		if is_moving:
			var blend_position = velocity.normalized()
			animation_tree.set("parameters/StateMachine/Walk/blend_position", blend_position)
			animation_tree.set("parameters/StateMachine/Idle/blend_position", blend_position)
		else:
			animation_tree.set("parameters/StateMachine/Walk/blend_position", Vector2.ZERO)
			animation_tree.set("parameters/StateMachine/Idle/blend_position", Vector2.ZERO)
	else:
		print_debug("No animation system available")

func _on_health_depleted():
	"""체력 고갈 시 처리"""
	print_debug("Companion ", companion_name, " health depleted")
	
	# 플레이어 조작 중이었다면 AI로 전환
	if is_player_controlled:
		GlobalController.switch_to_main_player()
	
	# 사망 처리
	queue_free()

func _notification(what):
	"""노드 생명주기 알림 처리"""
	if what == NOTIFICATION_PREDELETE:
		# 노드가 삭제되기 전에 정리 작업 수행
		cleanup_companion()

func cleanup_companion():
	"""동료 정리 작업"""
	# GlobalController에서 제거 (안전하게 확인 후 호출)
	if is_instance_valid(GlobalController) and GlobalController.has_method("unregister_companion"):
		GlobalController.unregister_companion(self)
		print_debug("Companion unregistered from GlobalController: ", companion_name)
	
	# CompanionAI 정리
	if companion_ai and companion_ai.has_method("cleanup"):
		companion_ai.cleanup()

func _exit_tree():
	"""노드 제거 시 정리"""
	# 추가적인 정리 작업이 필요한 경우
	pass

func get_status_info() -> Dictionary:
	"""동료 상태 정보 반환"""
	return {
		"name": companion_name,
		"is_player_controlled": is_player_controlled,
		"health": health_component.health if health_component else 0,
		"max_health": health_component.MAX_HEALTH if health_component else 100,
		"energy": energy_component.energy if energy_component else 0,
		"current_behavior": current_behavior,
		"is_in_combat": is_in_combat
	}

# 플레이어와 동일한 인터페이스 메서드들
func move_to_point(target_pos: Vector2, _speed_override: float = -1):
	"""특정 지점으로 이동"""
	if is_player_controlled:
		return  # 플레이어 조작 중에는 강제 이동 불가
	
	give_order("move_to", target_pos)

func set_target(target: CharacterBody2D):
	"""타겟 설정"""
	current_target = target
	if companion_ai:
		companion_ai.set_target(target)

# === 패시브 시스템 ===

func setup_passive_system():
	"""동료 패시브 시스템 초기화"""
	# StatusEffectComponent가 이미 있는지 확인
	if not stat_component:
		print_debug("StatComponent not found for companion: ", companion_name)
		return
	
	var status_effect_component = stat_component.get_node_or_null("StatusEffectComponent")
	if not status_effect_component:
		# StatusEffectComponent 생성
		var StatusEffectComponentClass = preload("res://Assets/StatusEffects/StatusEffectComponent.gd")
		status_effect_component = StatusEffectComponentClass.new()
		status_effect_component.name = "StatusEffectComponent"
		stat_component.add_child(status_effect_component)
		print_debug("StatusEffectComponent created for companion: ", companion_name)
	
	# 동료별 기본 패시브 적용
	apply_default_passives()
	
	print_debug("Passive system initialized for companion: ", companion_name)

func apply_default_passives():
	"""동료별 기본 패시브 효과 적용"""
	var status_effect_component = stat_component.get_node_or_null("StatusEffectComponent")
	if not status_effect_component:
		return
	
	match companion_name:
		"Marsh":
			# Marsh 전용 패시브: 검술 마스터 (공격 속도 +15%)
			var sword_master_effect = StatusEffect.new()
			sword_master_effect.id = "sword_master"
			sword_master_effect.effect_name = "Sword Master"
			sword_master_effect.description = "Increases attack speed by 15%"
			sword_master_effect.duration = -1  # 영구 효과
			sword_master_effect.effect_type = StatusEffect.EffectType.BUFF
			sword_master_effect.keywords.append("ATTACK_SPEED_BOOST")
			sword_master_effect.stat_modifiers["ATTACK_SPEED"] = 0.15
			
			status_effect_component.add_effect(sword_master_effect)
			print_debug("Applied Sword Master passive to Marsh")
		
		_:
			# 기본 동료 패시브: 충성심 (체력 +10%)
			var loyalty_effect = StatusEffect.new()
			loyalty_effect.id = "companion_loyalty"
			loyalty_effect.effect_name = "Loyalty"
			loyalty_effect.description = "Increases maximum health by 10%"
			loyalty_effect.duration = -1  # 영구 효과
			loyalty_effect.effect_type = StatusEffect.EffectType.BUFF
			loyalty_effect.stat_modifiers["MAX_HEALTH"] = 0.1
			
			status_effect_component.add_effect(loyalty_effect)
			print_debug("Applied Loyalty passive to ", companion_name)

func get_attack_speed_multiplier() -> float:
	"""공격 속도 배수 반환 (패시브 효과 포함)"""
	var base_multiplier = 1.0
	
	if stat_component and stat_component.has_node("StatusEffectComponent"):
		var status_component = stat_component.get_node("StatusEffectComponent")
		if status_component.has_method("get_stat_modifier"):
			var attack_speed_bonus = status_component.get_stat_modifier("ATTACK_SPEED")
			base_multiplier += attack_speed_bonus
	
	# 장비 보너스도 추가 가능
	var equipment_info = get_equipment_info()
	if equipment_info.get("right_arm", "") == "Dagger":
		base_multiplier += 0.25  # 단검: +25% 공격 속도
	elif equipment_info.get("right_arm", "") == "Bow":
		base_multiplier += 0.1   # 활: +10% 공격 속도
	
	return base_multiplier

func apply_attack_speed_to_animation():
	"""공격 속도를 애니메이션에 적용"""
	var speed_multiplier = get_attack_speed_multiplier()
	
	# 애니메이션 트리 타임스케일 조정
	if animation_tree:
		animation_tree.set("parameters/TimeScale/scale", speed_multiplier)
		print_debug("Applied attack speed multiplier ", speed_multiplier, " to ", companion_name)
	
	# 스프라이트 매니저가 있다면 해당 매니저에도 적용
	if sprite_manager and sprite_manager.has_method("set_animation_speed"):
		sprite_manager.set_animation_speed(speed_multiplier)

func get_companion_stat(stat_name: String) -> float:
	"""동료의 스탯 반환 (패시브 효과 포함)"""
	if not stat_component or not stat_component.stat:
		return 0.0
	
	var base_value = 0.0
	
	# 기본 스탯 값 가져오기
	match stat_name:
		"ATTACK_POWER":
			base_value = stat_component.stat.ATTACK_POWER
		"MAX_HEALTH":
			base_value = stat_component.stat.MAX_HEALTH
		"SPEED":
			base_value = stat_component.stat.SPEED
		"FORTITUDE":
			base_value = stat_component.stat.FORTITUDE
		_:
			if stat_name in stat_component.stat:
				base_value = stat_component.stat[stat_name]
	
	# 패시브 효과 적용
	if stat_component.has_node("StatusEffectComponent"):
		var status_component = stat_component.get_node("StatusEffectComponent")
		if status_component.has_method("get_stat_modifier"):
			var modifier = status_component.get_stat_modifier(stat_name)
			base_value += base_value * modifier  # 백분율 보너스
	
	return base_value

func equip_item_to_slot_smart(item_name: String, slot_key: String) -> bool:
	"""동료에게 아이템을 스마트하게 장착하는 공개 메서드"""
	print_debug("=== EQUIP ITEM TO SLOT SMART ===")
	print_debug("Companion: ", companion_name)
	print_debug("Item: ", item_name)
	print_debug("Slot: ", slot_key)
	
	# 플레이어 인벤토리에서 아이템 찾기
	var item = _find_item_in_player_inventory(item_name)
	if not item:
		print_debug("Item not found in player inventory: ", item_name)
		return false
	
	print_debug("Found item in player inventory: ", item.name, " (", item.get_class(), ")")
	
	# 아이템 타입 확인
	if not item is EquipmentItem:
		print_debug("Item is not an EquipmentItem: ", item_name)
		return false
	
	print_debug("Item is EquipmentItem - proceeding with equipment")
	
	# 슬롯 키 변환 (UI에서 사용하는 형식을 내부 형식으로 변환)
	var internal_slot_key = _convert_ui_slot_to_internal(slot_key)
	print_debug("Converted slot key: ", slot_key, " -> ", internal_slot_key)
	if internal_slot_key == "":
		print_debug("Invalid slot key: ", slot_key)
		return false
	
	# 직접 장착
	var result = _equip_item_to_slot_direct(item, internal_slot_key)
	if result:
		print_debug("Successfully equipped ", item_name, " to ", slot_key)
	else:
		print_debug("Failed to equip ", item_name, " to ", slot_key)
	
	return result

func equip_item_to_slot_smart_direct(item: InvItem, slot_key: String) -> bool:
	"""아이템 객체를 직접 받아서 동료에게 장착하는 메서드"""
	print_debug("=== EQUIP ITEM TO SLOT SMART DIRECT ===")
	print_debug("Companion: ", companion_name)
	print_debug("Item: ", item.name if item else "null")
	print_debug("Slot: ", slot_key)
	
	if not item:
		print_debug("Item is null - cannot equip")
		return false
	
	# 아이템 타입 확인
	if not item is EquipmentItem:
		print_debug("Item is not an EquipmentItem: ", item.name)
		return false
	
	print_debug("Item is EquipmentItem - proceeding with equipment")
	
	# 슬롯 키 변환 (UI에서 사용하는 형식을 내부 형식으로 변환)
	var internal_slot_key = _convert_ui_slot_to_internal(slot_key)
	print_debug("Converted slot key: ", slot_key, " -> ", internal_slot_key)
	if internal_slot_key == "":
		print_debug("Invalid slot key: ", slot_key)
		return false
	
	# 직접 장착
	var result = _equip_item_to_slot_direct(item, internal_slot_key)
	if result:
		print_debug("Successfully equipped ", item.name, " to ", slot_key)
	else:
		print_debug("Failed to equip ", item.name, " to ", slot_key)
	
	return result

func unequip_item_from_slot_smart(slot_key: String) -> bool:
	"""슬롯에서 아이템을 해제하는 메서드"""
	print_debug("=== UNEQUIP ITEM FROM SLOT SMART ===")
	print_debug("Companion: ", companion_name)
	print_debug("Slot: ", slot_key)
	
	# 슬롯 키 변환 (UI에서 사용하는 형식을 내부 형식으로 변환)
	var internal_slot_key = _convert_ui_slot_to_internal(slot_key)
	print_debug("Converted slot key: ", slot_key, " -> ", internal_slot_key)
	if internal_slot_key == "":
		print_debug("Invalid slot key: ", slot_key)
		return false
	
	# 슬롯 인덱스 변환
	var slot_index = _convert_slot_key_to_index(internal_slot_key)
	print_debug("Converted slot index: ", slot_index)
	if slot_index == null:
		print_debug("Invalid slot index for: ", internal_slot_key)
		return false
	
	# 해당 슬롯에서 아이템 해제
	if stat_component and stat_component.stat and stat_component.stat.equipment_slots.has(slot_index):
		var item = stat_component.stat.equipment_slots[slot_index]
		if item:
			_unequip_item_from_slot(slot_index)
			print_debug("Successfully unequipped item from slot: ", slot_key)
			return true
		else:
			print_debug("No item in slot: ", slot_key)
			return false
	else:
		print_debug("Slot not found or stat component missing: ", slot_key)
		return false

func _convert_ui_slot_to_internal(ui_slot: String) -> String:
	"""UI에서 사용하는 슬롯 이름을 내부 슬롯 키로 변환"""
	match ui_slot:
		"Head": return "HEAD"
		"Torso": return "TORSO"
		"Right Arm": return "RIGHT_ARM"
		"Left Arm": return "LEFT_ARM"
		"Legs": return "LEGS"
		_: return ""

func _equip_item_to_slot(item_name: String, slot_key: String):
	"""아이템을 지정된 슬롯에 장비합니다. (기본 버전)"""
	return _equip_item_to_slot_smart(item_name, slot_key)

func _equip_item_to_slot_smart(item_name: String, slot_key: String) -> bool:
	"""스마트한 장비 복원 시스템 - 플레이어와 동일한 방식"""
	print_debug("Smart equipment restoration for %s in slot %s" % [item_name, slot_key])
	
	# 1단계: 플레이어 인벤토리에서 정확한 아이템 찾기 (시리얼 번호 포함)
	var item = _find_item_in_player_inventory_with_serial(item_name, slot_key)
	if item:
		print_debug("✓ Found exact item %s (SN: %s) in player inventory" % [item_name, item.serial_number if item.has_method("get") and item.get("serial_number") else "N/A"])
		return _equip_item_to_slot_direct(item, slot_key)
	
	# 2단계: 유사한 아이템 찾기 (타입 기반)
	var similar_item = _find_similar_item_in_inventory(item_name, slot_key)
	if similar_item:
		print_debug("✓ Found similar item %s for %s, using as replacement" % [similar_item.name, item_name])
		return _equip_item_to_slot_direct(similar_item, slot_key)
	
	# 3단계: 장비 슬롯을 비워둠 (아이템이 없는 경우)
	print_debug("⚠ No suitable item found for %s in slot %s - leaving slot empty" % [item_name, slot_key])
	_clear_slot(slot_key)
	return true  # 슬롯을 비우는 것도 성공으로 간주

func _clear_slot(slot_key: String):
	"""지정된 슬롯을 비웁니다."""
	if not stat_component or not stat_component.stat:
		return
	
	var slot_index = _convert_slot_key_to_index(slot_key)
	if slot_index == null:
		print_debug("Invalid slot key for clearing: %s" % slot_key)
		return
	
	# 슬롯에 아이템이 있다면 해제
	if stat_component.stat.equipment_slots.has(slot_index):
		var current_item = stat_component.stat.equipment_slots[slot_index]
		if current_item:
			_unequip_item_from_slot(slot_index)
			print_debug("Cleared slot %s (removed %s)" % [slot_key, current_item.name])
		else:
			print_debug("Slot %s is already empty" % slot_key)
	else:
		print_debug("Slot %s does not exist in equipment slots" % slot_key)

func _find_item_in_player_inventory(item_name: String):
	"""플레이어 인벤토리에서 정확한 아이템을 찾습니다."""
	if not Global.world or not Global.world.player or not Global.world.player.inventory:
		return null
	
	var inventory = Global.world.player.inventory
	if inventory.has_method("find_item_by_name"):
		return inventory.find_item_by_name(item_name)
	
	# fallback: 직접 검색
	if inventory.has_method("get") and inventory.get("inv") and inventory.inv.has_method("get_slots"):
		var slots = inventory.inv.get_slots()
		for slot in slots:
			if slot and slot.item and slot.item.name == item_name:
				return slot.item
	
	return null

func _find_item_in_player_inventory_with_serial(item_name: String, slot_key: String):
	"""플레이어 인벤토리에서 정확한 아이템을 찾습니다 (시리얼 번호 포함)."""
	if not Global.world or not Global.world.player or not Global.world.player.inventory:
		return null
	
	var inventory = Global.world.player.inventory
	var target_serial = _get_stored_serial_number(item_name, slot_key)
	
	# 인벤토리에서 시리얼 번호가 일치하는 아이템 찾기
	if inventory.has_method("get") and inventory.get("inv") and inventory.inv.has_method("get_slots"):
		var slots = inventory.inv.get_slots()
		for slot in slots:
			if slot and slot.item and slot.item.name == item_name:
				# 시리얼 번호가 저장되어 있다면 정확히 일치하는지 확인
				if target_serial != null and slot.item.has_method("get") and slot.item.get("serial_number") == target_serial:
					print_debug("Found exact item with matching serial number: %s (SN: %s)" % [item_name, target_serial])
					return slot.item
				# 시리얼 번호가 없다면 이름만으로 반환
				elif target_serial == null:
					print_debug("Found item by name (no serial number stored): %s" % item_name)
					return slot.item
		
		# 시리얼 번호가 일치하지 않으면 이름만으로 찾기
		if target_serial != null:
			for slot in slots:
				if slot and slot.item and slot.item.name == item_name:
					print_debug("Found item by name (serial number mismatch): %s (stored: %s, found: %s)" % [
						item_name, target_serial, slot.item.serial_number if slot.item.has_method("get") and slot.item.get("serial_number") else "N/A"
					])
					return slot.item
	
	return null

func _get_stored_serial_number(item_name: String, slot_key: String):
	"""저장된 아이템의 시리얼 번호를 가져옵니다."""
	# GlobalController에서 보관된 장비 정보 확인
	if GlobalController.has_method("get_stored_companion_equipment"):
		var stored_equipment = GlobalController.get_stored_companion_equipment(companion_id)
		if stored_equipment.has(slot_key) and stored_equipment[slot_key] is Dictionary:
			var slot_data = stored_equipment[slot_key]
			if slot_data.has("serial_number") and slot_data.serial_number != "":
				return slot_data.serial_number
	
	return null

func _find_similar_item_in_inventory(item_name: String, slot_key: String):
	"""슬롯에 적합한 유사한 아이템을 찾습니다."""
	if not Global.world or not Global.world.player or not Global.world.player.inventory:
		return null
	
	var inventory = Global.world.player.inventory
	var target_type = _get_equipment_type_for_slot(slot_key)
	
	# 인벤토리에서 적합한 타입의 아이템 찾기
	if inventory.has_method("get") and inventory.get("inv") and inventory.inv.has_method("get_slots"):
		var slots = inventory.inv.get_slots()
		for slot in slots:
			if slot and slot.item and _is_item_suitable_for_slot(slot.item, slot_key):
				print_debug("Found suitable item %s for slot %s" % [slot.item.name, slot_key])
				return slot.item
	
	return null

# 기본 아이템 생성 함수는 더 이상 사용하지 않음 (슬롯을 비우는 방식으로 변경)
# func _create_default_item_for_slot(slot_key: String):
# 	"""슬롯에 맞는 기본 아이템을 생성합니다."""
# 	var default_item_name = _get_default_item_name_for_slot(slot_key)
# 	
# 	# ItemData를 통해 기본 아이템 생성
# 	if Global.has_method("get_item_data") and Global.item_data:
# 		var item_data = Global.item_data.get_item_by_name(default_item_name)
# 		if item_data:
# 			# 아이템 객체 생성 (실제 구현은 프로젝트의 아이템 시스템에 따라 다름)
# 			var new_item = _create_item_from_data(item_data)
# 			if new_item:
# 				print_debug("Created default item %s for slot %s" % [default_item_name, slot_key])
# 				return new_item
# 	
# 	print_debug("Failed to create default item for slot %s" % slot_key)
# 	return null

func _get_equipment_type_for_slot(slot_key: String) -> String:
	"""슬롯에 적합한 장비 타입을 반환합니다."""
	match slot_key:
		"HEAD": return "helmet"
		"TORSO": return "armor"
		"RIGHT_ARM", "LEFT_ARM": return "weapon"
		"LEGS": return "boots"
		_: return "general"

func _is_item_suitable_for_slot(item, slot_key: String) -> bool:
	"""아이템이 해당 슬롯에 적합한지 확인합니다."""
	if not item or not item.has_method("get"):
		return false
	
	# 아이템의 parts 속성 확인 (예: "Head", "Torso" 등)
	if item.has_method("get") and item.get("parts"):
		var item_parts = item.parts
		match slot_key:
			"HEAD": return item_parts == "Head"
			"TORSO": return item_parts == "Torso"
			"RIGHT_ARM", "LEFT_ARM": return item_parts == "Right Arm" or item_parts == "Left Arm"
			"LEGS": return item_parts == "Legs"
			_: return false
	
	return false

# 기본 아이템 생성 관련 함수들은 더 이상 사용하지 않음 (슬롯을 비우는 방식으로 변경)
# func _get_default_item_name_for_slot(slot_key: String) -> String:
# 	"""슬롯에 맞는 기본 아이템 이름을 반환합니다."""
# 	match slot_key:
# 		"HEAD": return "Basic Helmet"
# 		"TORSO": return "Basic Armor"
# 		"RIGHT_ARM", "LEFT_ARM": return "Basic Sword"
# 		"LEGS": return "Basic Boots"
# 		_: return "Basic Item"

# func _create_item_from_data(item_data):
# 	"""아이템 데이터로부터 아이템 객체를 생성합니다."""
# 	# 이 부분은 프로젝트의 아이템 시스템에 따라 구현이 달라집니다
# 	# 예시: EquipmentItem 클래스가 있다면
# 	if item_data.has_method("create_instance"):
# 		return item_data.create_instance()
# 	elif item_data.has_method("duplicate"):
# 		return item_data.duplicate()
# 	
# 	# fallback: 기본 아이템 생성
# 	return _create_basic_equipment_item(item_data)

# func _create_basic_equipment_item(item_data):
# 	"""기본 장비 아이템을 생성합니다."""
# 	# 프로젝트에 EquipmentItem 클래스가 있다면 사용
# 	var EquipmentItemClass = load("res://Assets/PreFabs/Entity/EquipmentItem.gd")
# 	if EquipmentItemClass:
# 		var item = EquipmentItemClass.new()
# 		item.name = item_data.get("name", "Unknown Item")
# 		# 기본 속성 설정
# 		return item
# 	
# 	# fallback: Dictionary 형태로 반환
# 	return {
# 		"name": item_data.get("name", "Unknown Item"),
# 		"type": "EquipmentItem",
# 		"parts": _get_default_parts_for_slot(item_data.get("slot", "general"))
# 	}

# func _get_default_parts_for_slot(slot: String) -> String:
# 	"""슬롯에 맞는 기본 parts 값을 반환합니다."""
# 	match slot:
# 		"HEAD": return "Head"
# 		"TORSO": return "Torso"
# 		"RIGHT_ARM": return "Right Arm"
# 		"LEFT_ARM": return "Left Arm"
# 		"LEGS": return "Legs"
# 		_: return "General"

func _equip_item_to_slot_direct(item, slot_key: String) -> bool:
	"""아이템을 직접 슬롯에 장비합니다 (플레이어와 동일한 방식)."""
	print_debug("=== _equip_item_to_slot_direct ===")
	print_debug("Item: ", item.name if item else "null")
	print_debug("Slot key: ", slot_key)
	
	if not stat_component or not stat_component.stat:
		print_debug("No stat_component or stat - cannot equip")
		return false
	
	# 무기 제한 검사 (무기 슬롯인 경우)
	if item.has_method("get") and item.get("parts"):
		var parts = item.parts
		if parts in ["Right Arm", "Left Arm"]:  # 무기 슬롯인 경우
			if not can_equip_weapon(item.name):
				print_debug("Cannot equip %s - weapon type not allowed for %s" % [item.name, companion_name])
				return false
	
	# 슬롯 인덱스 변환
	var slot_index = _convert_slot_key_to_index(slot_key)
	print_debug("Converted slot index: ", slot_index)
	if slot_index == null:
		print_debug("Invalid slot key: %s" % slot_key)
		return false
	
	# 기존 장비 해제
	if stat_component.stat.equipment_slots.has(slot_index):
		var old_item = stat_component.stat.equipment_slots[slot_index]
		if old_item:
			_unequip_item_from_slot(slot_index)
	
	# 새 장비 장착 (플레이어와 동일한 방식)
	stat_component.stat.equipment_slots[slot_index] = item
	
	# 스탯 효과 적용 (플레이어와 동일)
	if item.has_method("get") and item.get("parts"):
		var parts = item.parts
		match parts:
			"Head":
				_apply_equipment_effects(item, true)
			"Torso":
				_apply_equipment_effects(item, true)
			"Right Arm", "Left Arm":
				_apply_equipment_effects(item, true)
			"Legs":
				_apply_equipment_effects(item, true)
	
	print_debug("Successfully equipped %s to slot %s with effects applied" % [item.name, slot_key])
	return true

func _apply_equipment_effects(item, is_equipping: bool):
	"""장비 효과를 적용합니다 (플레이어와 동일한 방식)."""
	if not stat_component or not stat_component.stat:
		return
	
	# 플레이어와 동일한 스탯 조정 시스템 사용
	if stat_component.stat.has_method("adjust_stats"):
		stat_component.stat.adjust_stats(item, is_equipping)
		print_debug("Applied equipment effects for %s (equipping: %s)" % [item.name, is_equipping])
	
	# 스탯 변경 시그널 발생 (동료로 식별)
	if stat_component.stat.has_signal("stats_changed"):
		stat_component.stat.stats_changed.emit("companion")

func _convert_slot_key_to_index(slot_key: String):
	"""슬롯 키를 인덱스로 변환합니다."""
	match slot_key:
		"HEAD": return stat_component.stat.EquipmentSlot.HEAD
		"TORSO": return stat_component.stat.EquipmentSlot.TORSO
		"RIGHT_ARM": return stat_component.stat.EquipmentSlot.RIGHT_ARM
		"LEFT_ARM": return stat_component.stat.EquipmentSlot.LEFT_ARM
		"LEGS": return stat_component.stat.EquipmentSlot.LEGS
		_: return null

func _unequip_item_from_slot(slot_index):
	"""지정된 슬롯에서 아이템을 해제합니다."""
	if not stat_component or not stat_component.stat:
		return
	
	if stat_component.stat.equipment_slots.has(slot_index):
		var item = stat_component.stat.equipment_slots[slot_index]
		if item:
			# 스탯 효과 제거
			stat_component.stat.adjust_stats(item, false)
			stat_component.stat.equipment_slots[slot_index] = null
			print_debug("Unequipped item from slot %s" % slot_index)
			
			# UI 업데이트 시그널 발생
			equipment_changed.emit()

func leave_party():
	"""파티를 떠날 때 장비를 안전하게 보관합니다."""
	print_debug("Companion %s is leaving the party - storing equipment" % companion_name)
	
	# 현재 장비 상태를 저장
	var stored_equipment = get_equipment_info()
	
	# GlobalController에 장비 보관 정보 저장
	if GlobalController.has_method("store_companion_equipment"):
		GlobalController.store_companion_equipment(companion_id, stored_equipment)
		print_debug("Equipment stored for companion %s" % companion_name)
	
	# 모든 장비 슬롯에서 아이템 해제
	if stat_component and stat_component.stat:
		for slot in stat_component.stat.equipment_slots:
			if stat_component.stat.equipment_slots[slot]:
				_unequip_item_from_slot(slot)
	
	# 기존 무기 시스템도 해제
	if stat_component:
		stat_component.current_right_arm = ""
		stat_component.current_left_arm = ""
	
	print_debug("Companion %s equipment safely stored and unequipped" % companion_name)

func rejoin_party():
	"""파티에 다시 합류할 때 장비를 복원합니다."""
	print_debug("Companion %s is rejoining the party - restoring equipment" % companion_name)
	
	# GlobalController에서 보관된 장비 정보 가져오기
	if GlobalController.has_method("get_stored_companion_equipment"):
		var stored_equipment = GlobalController.get_stored_companion_equipment(companion_id)
		
		if stored_equipment:
			# 장비 복원
			for slot_key in stored_equipment:
				# 기존 하위 호환성 필드들은 건너뛰기
				if slot_key in ["right_arm", "left_arm", "has_weapon"]:
					continue
				
				var slot_data = stored_equipment[slot_key]
				if slot_data and slot_data is Dictionary and slot_data.has("name"):
					var item_name = slot_data.name
					if item_name != "":
						_equip_item_to_slot(item_name, slot_key)
						print_debug("Restored %s to slot %s" % [item_name, slot_key])
			
			# 하위 호환성을 위한 기존 무기 복원
			if stored_equipment.has("right_arm") and stored_equipment.right_arm != "":
				equip_weapon(stored_equipment.right_arm, "right_arm")
			if stored_equipment.has("left_arm") and stored_equipment.left_arm != "":
				equip_weapon(stored_equipment.left_arm, "left_arm")
			
			print_debug("Companion %s equipment restored from storage" % companion_name)
		else:
			print_debug("No stored equipment found for companion %s" % companion_name)
	else:
		print_debug("GlobalController does not support equipment storage")

# =========== 스킬 시스템 ===========

# AI 자동 활성화
func try_auto_activate_heat_boost() -> bool:
	"""AI가 자동으로 열 부스트 스킬을 활성화할지 판단"""
	if skill_component and should_auto_activate_heat_boost():
		return skill_component.execute_skill_by_id("heat_boost")
	return false

func should_auto_activate_heat_boost() -> bool:
	"""AI가 열 부스트를 활성화해야 하는지 판단하는 로직"""
	# 기본 조건들
	if not energy_component or not heat_component:
		return false
	
	# 에너지가 충분한가?
	if energy_component.energy < 2:
		return false
	
	# 열이 낮은가? (66% 미만)
	if heat_component.heat >= heat_component.MAX_HEALTH * 0.66:
		return false
	
	# 전투 상태인가?
	if not is_in_combat:
		return false
	
	# 적이 가까이 있는가?
	if current_target and global_position.distance_to(current_target.global_position) < combat_range:
		return true
	
	return false

# 오버클록 모드에서 호출할 함수
func execute_skill_by_command(skill_id: String) -> bool:
	"""명령으로 스킬 실행 (오버클록 모드용)"""
	if skill_component:
		return skill_component.execute_skill_by_id(skill_id)
	return false

# UI에서 스킬 정보 가져오기
func get_companion_skills_info() -> Array[Dictionary]:
	"""동료의 모든 스킬 정보 반환 (UI에서 활용)"""
	if skill_component:
		return skill_component.get_all_skills_info()
	return []

# 스킬 활성화/비활성화 관리
func set_skill_active(skill_id: String, active: bool):
	"""스킬 활성화/비활성화 설정"""
	if skill_component:
		skill_component.set_skill_active(skill_id, active)

func is_skill_active(skill_id: String) -> bool:
	"""스킬 활성 상태 확인"""
	if skill_component:
		return skill_component.is_skill_active(skill_id)
	return false

# AI 상태 반환 (HeatComponent에서 냉각 속도 계산용)
func get_ai_state() -> String:
	"""현재 AI 상태를 문자열로 반환"""
	if state_machine and state_machine.current_state:
		var state_name = state_machine.current_state.get_script().get_global_name()
		match state_name:
			"CompanionStateMoving":
				return "moving"
			"CompanionStateFollowing":
				return "following"
			"CompanionStateCombat":
				return "combat"
			"CompanionStateIdle":
				return "idle"
			"CompanionStateExecuteOrder":
				return "executing"
			_:
				return "unknown"
	return "idle"


func _on_detection_area_body_entered(body: Node2D) -> void:
	"""적 감지 시 호출되는 함수"""
	if not body or not is_instance_valid(body):
		return
	
	if body.is_in_group("Enemies"):
		print_debug("🎯 Enemy detected: ", body.name)
		
		# CompanionAI에 적 알림 (새로운 함수 사용)
		var companion_ai = get_node_or_null("CompanionAI")
		if companion_ai and companion_ai.has_method("add_enemy_to_detection"):
			print_debug("🗡️ Adding enemy to detection list: ", body.name)
			companion_ai.add_enemy_to_detection(body)
		else:
			print_debug("⚠️ CompanionAI not found or add_enemy_to_detection method missing")
		
		# 전투 상태로 변경 (CompanionAI에서 처리하도록 변경)
		# is_in_combat과 current_target은 CompanionAI.acquire_target에서 설정됨

func _on_detection_area_body_exited(body: Node2D) -> void:
	"""적이 감지 범위를 벗어날 때 호출되는 함수"""
	if not body or not is_instance_valid(body):
		return
	
	if body.is_in_group("Enemies"):
		print_debug("🏃 Enemy left detection range: ", body.name)
		
		# CompanionAI에 알림 (즉시 제거하지 않음)
		var companion_ai = get_node_or_null("CompanionAI")
		if companion_ai and companion_ai.has_method("remove_enemy_from_detection"):
			print_debug("📤 Notifying AI about enemy exit: ", body.name)
			companion_ai.remove_enemy_from_detection(body)
		else:
			print_debug("⚠️ CompanionAI not found or remove_enemy_from_detection method missing")

func debug_combat_ai_status():
	"""전투 AI 상태 디버그 정보 출력"""
	print_debug("=== Combat AI Debug Info ===")
	print_debug("📍 Is in combat: ", is_in_combat)
	print_debug("🎯 Current target: ", current_target.name if current_target else "none")
	print_debug("🔥 Heat percentage: %.1f%%" % ((heat_component.heat / heat_component.MAX_HEAT) * 100.0) if heat_component else "N/A")
	
	var combat_ai = get_node_or_null("CombatAI")
	if combat_ai and combat_ai.has_method("get_combat_status"):
		var status = combat_ai.get_combat_status()
		print_debug("🤖 Combat AI Status:")
		for key in status.keys():
			print_debug("  - ", key, ": ", status[key])
	else:
		print_debug("⚠️ CombatAI not found or get_combat_status method missing")
	
	var companion_ai = get_node_or_null("CompanionAI")
	if companion_ai:
		print_debug("🧠 CompanionAI behavior: ", companion_ai.current_behavior)
		print_debug("🎯 CompanionAI target: ", companion_ai.current_target.name if companion_ai.current_target else "none")
		print_debug("🔄 CompanionAI is_enabled: ", companion_ai.is_enabled)
		print_debug("👁️ Detected enemies: ", companion_ai.detected_enemies.size())
		print_debug("📋 Target priority queue: ", companion_ai.target_priority_queue.size())
		print_debug("🔥 Aggressive pursuit: ", companion_ai.aggressive_pursuit_mode)
		print_debug("📏 Max pursuit distance: ", companion_ai.max_pursuit_distance)
		
		# 감지된 적들의 거리 정보
		for i in range(min(3, companion_ai.detected_enemies.size())):  # 최대 3개만 표시
			var enemy = companion_ai.detected_enemies[i]
			if enemy and is_instance_valid(enemy):
				var distance = global_position.distance_to(enemy.global_position)
				print_debug("  - ", enemy.name, ": ", distance, "px")
	else:
		print_debug("⚠️ CompanionAI not found")
	
	print_debug("=============================")

# 동료 상태 정보를 반환하는 함수 (World에서 상태 검증용)
func get_companion_state_info() -> Dictionary:
	"""동료의 현재 상태 정보를 반환합니다."""
	var state_info = {
		"companion_id": companion_id,
		"companion_name": companion_name,
		"position": global_position,
		"health": 0.0,
		"energy": 0.0,
		"heat": 0.0,
		"is_in_combat": is_in_combat,
		"current_behavior": current_behavior
	}
	
	# 컴포넌트 상태 정보 추가
	if health_component:
		state_info.health = health_component.health
		state_info["max_health"] = health_component.MAX_HEALTH
	
	if energy_component:
		state_info.energy = energy_component.energy
		state_info["max_energy"] = energy_component.MAX_ENERGY
	
	if heat_component:
		state_info.heat = heat_component.heat
		state_info["max_heat"] = heat_component.MAX_HEAT
	
	return state_info

# 동료를 기본 상태로 초기화하는 함수 (폴백용)
func initialize_default_state():
	"""동료를 기본 상태로 초기화합니다."""
	print_debug("Initializing default state for companion: %s" % companion_name)
	
	# 기본 위치로 이동 (플레이어 근처)
	if main_player and is_instance_valid(main_player):
		var offset = Vector2(50, 50)
		global_position = main_player.global_position + offset
	else:
		print_debug("WARNING: Cannot set default position - main_player not available for companion: ", companion_name)
	
	# 기본 상태 설정
	current_behavior = "follow"
	is_in_combat = false
	current_order = {}
	
	# 컴포넌트 기본값 설정
	if health_component:
		health_component.health = health_component.MAX_HEALTH
	
	if energy_component:
		energy_component.energy = energy_component.MAX_ENERGY
	
	if heat_component:
		heat_component.heat = 0.0  # 열 상태 리셋
	
	# AI 상태 리셋
	if companion_ai:
		companion_ai.reset_to_default_state()
	
	# 상태 머신 리셋
	if state_machine:
		state_machine.change_state("IdleState")
	
	print_debug("Default state initialization completed for companion: %s" % companion_name)

func clear_all_equipment():
	"""동료의 모든 장비를 해제합니다."""
	print_debug("Clearing all equipment for companion: ", companion_name)
	
	if not stat_component or not stat_component.stat:
		print_debug("No stat component available for equipment clearing")
		return
	
	# 모든 장비 슬롯 비우기
	var equipment_slots = stat_component.stat.equipment_slots
	for slot_index in equipment_slots.keys():
		var current_item = equipment_slots[slot_index]
		if current_item:
			print_debug("Unequipping item: ", current_item.name, " from slot: ", slot_index)
			stat_component.stat.takeoff(slot_index)
	
	print_debug("All equipment cleared for companion: ", companion_name)
