class_name PlayerStateMachine extends Node

var states: Array[Node]
var prev_state: Node
var current_state: Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	delta *= Global.slow_factor
	
	# 활성 유닛이 아니면 프로세스 처리 중단 (AI 모드는 허용)
	var player = get_parent() as player_movement
	if player and GlobalController.active_unit != player and not player.is_ai_controlled:
		return
	
	if current_state:
		change_state(current_state.process(delta))
	pass

func _physics_process(delta: float) -> void:
	delta *= Global.slow_factor
	
	# 활성 유닛이 아니면 물리 처리 중단 (AI 모드는 허용)
	var player = get_parent() as player_movement
	if player and GlobalController.active_unit != player and not player.is_ai_controlled:
		return
	
	if current_state:
		change_state(current_state.physics(delta))
	pass

func _input(event: InputEvent) -> void:
	var player = get_parent() as player_movement
	if not player:
		return
	
	# 플레이어가 AI 제어 모드일 때는 입력 차단 (G키 제외)
	if player.is_ai_controlled:
		if event.is_action_pressed("switch_unit"):
			return  # GlobalController가 처리하도록 허용
		else:
			get_viewport().set_input_as_handled()  # 다른 모든 입력 차단
			return
	
	# 현재 활성 유닛이 자신이 아니면 입력 차단
	if GlobalController.active_unit != player:
		get_viewport().set_input_as_handled()
		return
	
	if current_state:
		change_state(current_state.handle_input(event))
	pass

func initialize(_player: player_movement) -> void:
	states = []

	# Add existing child states
	for c in get_children():
		if c.has_method("init") and c.has_method("enter") and c.has_method("exit"):
			states.append(c)
	
	# Dynamically create and add DashState if it doesn't exist
	var dash_state_exists = false
	for state in states:
		if state.get_script() and state.get_script().get_global_name() == "PlayerStateDash":
			dash_state_exists = true
			break
	
	if not dash_state_exists:
		var dash_state = Node.new()
		var dash_script = load("res://Assets/PreFabs/Player/scripts/states/player_state_dash.gd")
		dash_state.set_script(dash_script)
		dash_state.name = "DashState"
		add_child(dash_state)
		states.append(dash_state)
		print_debug("DashState created dynamically")
	
	# Dynamically create and add DashAttackState if it doesn't exist
	var dash_attack_state_exists = false
	for state in states:
		if state.get_script() and state.get_script().get_global_name() == "PlayerStateDashAttack":
			dash_attack_state_exists = true
			break
	
	if not dash_attack_state_exists:
		var dash_attack_state = Node.new()
		var dash_attack_script = load("res://Assets/PreFabs/Player/scripts/states/player_state_dash_attack.gd")
		dash_attack_state.set_script(dash_attack_script)
		dash_attack_state.name = "DashAttackState"
		add_child(dash_attack_state)
		states.append(dash_attack_state)
		print_debug("DashAttackState created dynamically")
	
	# Initialize all states
	for s in states:
		s.player = _player
		s.state_machine = self
		s.init()

	if states.size() > 0:
		change_state(states[0])
		process_mode = Node.PROCESS_MODE_INHERIT
		print_debug("State Machine enabled with process_mode: ", process_mode)
	pass

func change_state(new_state: Node) -> void:
	if new_state == null || new_state == current_state:
		return
	
	if current_state:
		current_state.exit()

	prev_state = current_state
	current_state = new_state
	current_state.enter()
	
	# Debug output for state changes
	# if prev_state and prev_state.get_script():
	# 	var prev_name = prev_state.get_script().get_global_name() if prev_state.get_script().get_global_name() else "Unknown"
	# 	var curr_name = current_state.get_script().get_global_name() if current_state.get_script().get_global_name() else "Unknown"
	# 	print_debug("Player state changed from ", prev_name, " to ", curr_name)
	# else:
	# 	var curr_name = current_state.get_script().get_global_name() if current_state.get_script().get_script().get_global_name() else "Unknown"
	# 	print_debug("Player initial state: ", curr_name)

func force_state(state_name: String) -> void:
	for state in states:
		if state.get_script() and state.get_script().get_global_name() == state_name:
			change_state(state)
			return

func get_current_state() -> Node:
	return current_state

func get_previous_state() -> Node:
	return prev_state 