@tool
extends Control

# This script is temporarily simplified to debug scene loading issues.

const TextDialogueNodeScene = preload("res://addons/dialogue_editor/text_dialogue_node.tscn")
const ChoiceDialogueNodeScene = preload("res://addons/dialogue_editor/choice_dialogue_node.tscn")
const StartDialogueNodeScene = preload("res://addons/dialogue_editor/start_dialogue_node.tscn")
const ConditionalIncludeNodeScene = preload("res://addons/dialogue_editor/conditional_include_node.tscn")
const DialogueFile = preload("res://Assets/Dialogues/Scripts/dialogue_file.gd")
const NpcInfo = preload("res://Assets/Dialogues/Scripts/npc_info.gd")
const Action = preload("res://Assets/Actions/scripts/action.gd")
const DialogueGraphNode = preload("res://addons/dialogue_editor/dialogue_graph_node.gd")

@onready var graph_edit: GraphEdit = $VBoxContainer/HSplitContainer/GraphEdit
@onready var inspector_panel: PanelContainer = $VBoxContainer/HSplitContainer/InspectorScroller/InspectorPanel
@onready var add_text_node_button: Button = $VBoxContainer/TopMenu/HBoxContainer/AddTextNodeButton
@onready var add_choice_node_button: Button = $VBoxContainer/TopMenu/HBoxContainer/AddChoiceNodeButton
@onready var add_conditional_include_node_button: Button = $VBoxContainer/TopMenu/HBoxContainer/AddConditionalIncludeNodeButton
@onready var add_start_node_button: Button = $VBoxContainer/TopMenu/HBoxContainer/AddStartNodeButton
@onready var npc_info_mode_option: OptionButton = $VBoxContainer/TopMenu/HBoxContainer/NPCInfoModeOption
@onready var save_button: Button = $VBoxContainer/TopMenu/HBoxContainer/SaveButton
@onready var load_button: Button = $VBoxContainer/TopMenu/HBoxContainer/LoadButton
@onready var save_dialog: FileDialog = $SaveDialog
@onready var load_dialog: FileDialog = $LoadDialog

var dialogue_file: DialogueFile
var is_loading: bool = false
var node_id_counter: int = 0
var selected_node: DialogueGraphNode = null

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	
	_clear_graph() # Initialize everything
	
	# Initialize NPC info mode options
	npc_info_mode_option.add_item("Individual NPC Info (Per Node)", 0)
	npc_info_mode_option.add_item("Global NPC Info (Legacy)", 1)
	npc_info_mode_option.selected = 0  # Default to individual mode
	
	inspector_panel.set_main_editor(self)
	graph_edit.node_selected.connect(_on_node_selected)
	graph_edit.node_deselected.connect(_on_node_deselected)
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	add_text_node_button.pressed.connect(_on_add_text_node_button_pressed)
	add_choice_node_button.pressed.connect(_on_add_choice_node_button_pressed)
	add_conditional_include_node_button.pressed.connect(_on_add_conditional_include_node_button_pressed)
	add_start_node_button.pressed.connect(_on_add_start_node_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	save_dialog.file_selected.connect(_on_save_dialog_file_selected)
	load_dialog.file_selected.connect(_on_load_dialog_file_selected)

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint():
		return
	
	# Handle Delete key to delete selected node
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE and selected_node:
			_on_node_close_request(selected_node)
			get_viewport().set_input_as_handled()

func _setup_node_close_functionality(node: GraphNode) -> void:
	"""Setup close button and connect close request signal for a node."""
	if node and is_instance_valid(node):
		node.close_request.connect(Callable(self, "_on_node_close_request").bind(node))

func _on_add_text_node_button_pressed() -> void:
	_add_dialogue_node(TextDialogueNodeScene)

func _on_add_choice_node_button_pressed() -> void:
	_add_dialogue_node(ChoiceDialogueNodeScene)

func _on_add_conditional_include_node_button_pressed() -> void:
	_add_dialogue_node(ConditionalIncludeNodeScene)

func _on_add_start_node_button_pressed() -> void:
	# Check if a StartNode already exists by checking its script
	for node in graph_edit.get_children():
		var script = node.get_script()
		if script and script.resource_path == "res://addons/dialogue_editor/start_dialogue_node.gd":
			push_warning("A Start Node already exists in the graph.")
			return
			
	var node = StartDialogueNodeScene.instantiate()
	node.id = "start"
	node.position_offset = graph_edit.scroll_offset + graph_edit.size / 2
	graph_edit.add_child(node)
	# Enable close button and connect the close request signal for node deletion (after adding to graph)
	call_deferred("_setup_node_close_functionality", node)
	# Start node itself doesn't have data, it's just a starting point
	# dialogue_file.add_node_data(node.id, node.get_data())

func _add_dialogue_node(scene: PackedScene) -> void:
	var new_node = scene.instantiate()
	new_node.name = "DialogueNode_%d" % node_id_counter
	node_id_counter += 1
	graph_edit.add_child(new_node)
	# Center the node approximately
	new_node.position_offset = (graph_edit.scroll_offset + graph_edit.size / 2) / graph_edit.zoom
	# Enable close button and connect the close request signal for node deletion (after adding to graph)
	call_deferred("_setup_node_close_functionality", new_node)

func _on_node_selected(node: Node) -> void:
	if node is DialogueGraphNode:
		selected_node = node
		inspector_panel.set_selected_node(node)

func _on_node_deselected(node: Node) -> void:
	if inspector_panel.get_selected_node() == node:
		selected_node = null
		inspector_panel.set_selected_node(null)

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.connect_node(from_node, from_port, to_node, to_port)

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)

func _on_save_button_pressed() -> void:
	save_dialog.popup_centered()

func _on_load_button_pressed() -> void:
	if is_loading:
		push_warning("A dialogue is already being loaded. Please wait.")
		return
	load_dialog.popup_centered()

func _on_save_dialog_file_selected(path: String) -> void:
	var start_node: GraphNode = null
	for node in graph_edit.get_children():
		var script = node.get_script()
		if script and script.resource_path == "res://addons/dialogue_editor/start_dialogue_node.gd":
			if start_node != null:
				push_error("Multiple Start Nodes found in the graph. Only one is allowed.")
				return
			start_node = node
	
	if start_node == null:
		push_error("No Start Node found in the graph. Cannot save.")
		return

	# Determine file type based on extension
	var file_extension = path.get_extension().to_lower()
	var data_to_save = {}
	
	if file_extension == "json":
		# Save as runtime dialogue file (compiled)
		data_to_save = _compile_graph(start_node)
	else:
		# Save as editor graph file (for loading back into editor)
		data_to_save = _save_graph_data()
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.new().stringify(data_to_save, "\t"))
		file.close()
		print("Saved file as: ", file_extension.to_upper(), " format")

func _compile_graph(p_start_node: GraphNode) -> Dictionary:
	var connections = graph_edit.get_connection_list()
	
	# Find the actual first node connected to the start node
	var first_node_name = ""
	for conn in connections:
		if conn.from_node == p_start_node.name:
			first_node_name = conn.to_node
			break
	
	var steps = []
	if first_node_name != "":
		steps = _traverse_and_compile(first_node_name, connections)
	
	# Check NPC info mode
	var use_global_npc_info = npc_info_mode_option.selected == 1
	
	if use_global_npc_info:
		# Legacy format with global NPC info
		var global_npc_info = _extract_global_npc_info()
		return {
			"dialogues": [
				{
					"id": dialogue_file.id,
					"npc_info": global_npc_info,
					"steps": _remove_npc_info_from_steps(steps)
				}
			]
		}
	else:
		# New format with individual NPC info per node
		return {
			"dialogues": [
				{
					"id": dialogue_file.id,
					"steps": steps
				}
			]
		}

func _traverse_and_compile(from_node_name: StringName, connections: Array) -> Array:
	var steps := []
	var current_node_name: StringName = from_node_name
	
	while current_node_name != "":
		var current_node: DialogueGraphNode = graph_edit.get_node(NodePath(current_node_name))
		var next_node_name: StringName = ""

		var node_type = current_node.get_node_type_string()

		if node_type == "text":
			var text_actions: Array = current_node.dialogue_data.get("actions", [])
			var serialized_actions = []
			for action in text_actions:
				if action is Action:
					var action_data = action.get_save_data()
					# Ensure quest_step is an integer if it's a quest action
					if action_data.get("action_type") == 0: # UPDATE_QUEST
						action_data["quest_step"] = int(action_data.get("quest_step", "0"))
					serialized_actions.append(action_data)

			var text_step = {
				"type": "text",
				"npc_info": current_node.dialogue_data.get("npc_info", NpcInfo.new()).get_save_data(),
				"text": current_node.dialogue_data.get("text", {"ko": "", "en": ""}),
				"actions": serialized_actions
			}
			steps.append(text_step)
			
			# Find next node
			for conn in connections:
				if conn.from_node == current_node_name:
					next_node_name = conn.to_node
					break
		
		elif node_type == "choice":
			var choice_step = {
				"type": "choice",
				"npc_info": current_node.dialogue_data.get("npc_info", NpcInfo.new()).get_save_data(),
				"choices": []
			}
			
			for i in range(current_node.dialogue_data.get("choices", []).size()):
				var choice_data: Dictionary = current_node.dialogue_data["choices"][i]
				var choice_text = choice_data.get("text", {"ko": "","en": ""})
				var choice_actions: Array = choice_data.get("actions", [])
				
				var serialized_actions = []
				for action in choice_actions:
					if action is Action:
						var action_data = action.get_save_data()
						# Ensure quest_step is an integer if it's a quest action
						if action_data.get("action_type") == 0: # UPDATE_QUEST
							action_data["quest_step"] = int(action_data.get("quest_step", "0"))
						serialized_actions.append(action_data)

				var branch_next_node_name: StringName = ""
				for conn in connections:
					if conn.from_node == current_node_name and conn.from_port == i:
						branch_next_node_name = conn.to_node
						break
				
				var next_steps = []
				if branch_next_node_name != "":
					next_steps = _traverse_and_compile(branch_next_node_name, connections)
					
				choice_step["choices"].append({
					"text": choice_text,
					"actions": serialized_actions,
					"next": next_steps
				})
			
			steps.append(choice_step)
			# Choice node is the end of a linear path
			next_node_name = ""
		
		elif node_type == "conditional_include":
			var include_step = {
				"type": "conditional_include",
				"include_id": current_node.dialogue_data.get("include_id", "")
			}
			steps.append(include_step)
			
			# Find next node
			for conn in connections:
				if conn.from_node == current_node_name:
					next_node_name = conn.to_node
					break
					
		current_node_name = next_node_name
		
	return steps

func _on_load_dialog_file_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: %s" % path)
		return
		
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse JSON: %s" % json.get_error_message())
		return

	var graph_data = json.data
	if not graph_data is Dictionary:
		push_error("Invalid JSON format. Root must be a dictionary.")
		return

	_clear_graph()
	
	# Check if this is a runtime dialogue file (has "dialogues" key) or editor graph file (has "nodes" key)
	if graph_data.has("dialogues"):
		# This is a runtime dialogue file, convert it to editor format
		_load_runtime_dialogue_file(graph_data)
	elif graph_data.has("nodes"):
		# This is an editor graph file, load it directly
		_load_editor_graph_file(graph_data)
	else:
		push_error("Unknown file format. File must have either 'dialogues' or 'nodes' key.")

func _load_runtime_dialogue_file(graph_data: Dictionary) -> void:
	"""Loads a runtime file using a robust 2-pass approach: create then connect."""
	var dialogue = graph_data.get("dialogues", [])[0]
	if not dialogue: return

	is_loading = true
	
	_clear_graph()
	var start_node = _create_start_node_for_load(Vector2(100, 300))
	
	dialogue_file.id = dialogue.get("id", "")

	# Detect NPC info mode from loaded file
	npc_info_mode_option.selected = _detect_npc_info_mode(graph_data)
	
	var steps = dialogue.get("steps", [])
	if steps.is_empty():
		_on_loading_complete()
		return
	
	var global_npc_info = dialogue.get("npc_info", {})
	var node_cache := {} # [step_key: String]: node_name: StringName

	# --- Pass 1: Create all unique nodes without connecting them ---
	_create_all_nodes_pass(steps, global_npc_info, Vector2(400, 150), node_cache)
	
	# --- Pass 2: Connect the nodes that were created in Pass 1 ---
	_connect_all_nodes_pass(steps, node_cache)

	# --- Final Connection: Connect the StartNode to the first dialogue node ---
	var first_step_key = _get_step_cache_key(steps[0])
	if node_cache.has(first_step_key):
		var first_node_name = node_cache[first_step_key]
		# No longer using get_node, using the direct reference from _create_start_node_for_load
		graph_edit.connect_node.call_deferred(start_node.name, 0, first_node_name, 0)

	# Set a final deferred call to mark loading as complete
	call_deferred("_on_loading_complete")

func _on_loading_complete() -> void:
	is_loading = false
	print("Dialogue loading process finished.")

func _create_all_nodes_pass(steps: Array, global_npc_info: Dictionary, start_pos: Vector2, node_cache: Dictionary, visited_keys: Dictionary = {}) -> void:
	"""Recursively traverses the JSON step tree and creates a GraphNode for each unique step."""
	var current_pos = start_pos
	for step in steps:
		var step_key = _get_step_cache_key(step)
		if visited_keys.has(step_key): continue
		visited_keys[step_key] = true
		
		if not node_cache.has(step_key):
			var new_node = _create_single_node(step, global_npc_info, current_pos)
			if new_node:
				graph_edit.add_child(new_node)
				node_cache[step_key] = new_node.name
				current_pos.x += 350
				# Enable close button and connect the close request signal for node deletion
				call_deferred("_setup_node_close_functionality", new_node)

		if step.get("type") == "choice":
			for choice in step.get("choices", []):
				var next_steps = choice.get("next", [])
				_create_all_nodes_pass(next_steps, global_npc_info, current_pos, node_cache, visited_keys)


func _connect_all_nodes_pass(steps: Array, node_cache: Dictionary, processed_keys: Dictionary = {}) -> void:
	"""Recursively traverses the JSON and connects the already-created nodes."""
	for i in range(steps.size()):
		var step = steps[i]
		var step_key = _get_step_cache_key(step)
		if processed_keys.has(step_key): continue
		processed_keys[step_key] = true
		
		var current_node_name = node_cache.get(step_key)
		if not current_node_name:
			push_warning("Could not find node for key in connect pass: " + step_key)
			continue
			
		var step_type = step.get("type", "")
		
		if step_type == "choice":
			# Connect choice branches and recurse into them
			var choices = step.get("choices", [])
			for port_idx in range(choices.size()):
				var next_steps = choices[port_idx].get("next", [])
				if not next_steps.is_empty():
					var next_step_key = _get_step_cache_key(next_steps[0])
					if node_cache.has(next_step_key):
						var next_node_name = node_cache[next_step_key]
						graph_edit.connect_node.call_deferred(current_node_name, port_idx, next_node_name, 0)
						_connect_all_nodes_pass(next_steps, node_cache, processed_keys)
		else:
			# Connect linear node and continue down the current list
			if i + 1 < steps.size():
				var next_step_key = _get_step_cache_key(steps[i+1])
				if node_cache.has(next_step_key):
					var next_node_name = node_cache[next_step_key]
					graph_edit.connect_node.call_deferred(current_node_name, 0, next_node_name, 0)


func _create_start_node_for_load(pos: Vector2) -> GraphNode:
	var start_node = StartDialogueNodeScene.instantiate()
	start_node.name = "StartNode"
	start_node.position_offset = pos
	graph_edit.add_child(start_node)
	# Enable close button and connect the close request signal for node deletion (after adding to graph)
	call_deferred("_setup_node_close_functionality", start_node)
	return start_node

func _load_editor_graph_file(graph_data: Dictionary) -> void:
	"""Load an editor graph file directly."""
	print("Loading editor graph file...")
	
	var node_map = {}
	if graph_data.has("nodes"):
		for node_data in graph_data["nodes"]:
			var scene_to_load = null
			var node_type = node_data.get("type", "unknown")
			if node_type == "text":
				scene_to_load = TextDialogueNodeScene
			elif node_type == "choice":
				scene_to_load = ChoiceDialogueNodeScene
			elif node_type == "start":
				scene_to_load = StartDialogueNodeScene
			elif node_type == "conditional_include":
				scene_to_load = ConditionalIncludeNodeScene
			else:
				push_warning("Unknown node type '%s' in save file. Skipping." % node_type)
				continue
			
			var new_node = scene_to_load.instantiate()
			var original_name = node_data["name"]
			new_node.name = "DialogueNode_%d" % node_id_counter
			node_id_counter += 1
			node_map[original_name] = new_node.name
			
			new_node.dialogue_data = node_data.get("data", {})
			new_node.position_offset = Vector2(node_data.get("position_x", 0), node_data.get("position_y", 0))
			new_node.update_ui_from_data()
			graph_edit.add_child(new_node)
			# Enable close button and connect the close request signal for node deletion (after adding to graph)
			call_deferred("_setup_node_close_functionality", new_node)
			
	if graph_data.has("connections"):
		for conn_data in graph_data["connections"]:
			var from_node_name = node_map.get(conn_data.from_node)
			var to_node_name = node_map.get(conn_data.to_node)
			if from_node_name and to_node_name:
				graph_edit.connect_node(from_node_name, conn_data.from_port, to_node_name, conn_data.to_port)

func _create_nodes_from_steps(steps: Array, global_npc_info: Dictionary, start_pos: Vector2, node_cache: Dictionary) -> DialogueGraphNode:
	"""
	Recursively processes a list of steps to build a graph, reusing nodes via a cache.
	Returns the head node of the created chain.
	"""
	if steps.is_empty():
		return null

	# 1. Process the FIRST step in the current list.
	var first_step = steps[0]
	var step_key = _get_step_cache_key(first_step)
	
	var head_node: DialogueGraphNode
	var was_created_now = false
	
	if node_cache.has(step_key):
		# This node already exists in the graph.
		head_node = graph_edit.get_node(node_cache[step_key])
	else:
		# Create the node as it's new.
		head_node = _create_single_node(first_step, global_npc_info, start_pos)
		if not head_node: return null # Should not happen if data is valid
		
		graph_edit.add_child(head_node)
		node_cache[step_key] = head_node.name
		was_created_now = true
		# Enable close button and connect the close request signal for node deletion
		call_deferred("_setup_node_close_functionality", head_node)

	# 2. If the node was NEWLY created, build out its children.
	# If it was found in cache, its children are already built.
	if was_created_now:
		var step_type = first_step.get("type", "")
		
		if step_type == "choice":
			# --- Handle Choice Branches ---
			var choices: Array = first_step.get("choices", [])
			for i in range(choices.size()):
				var next_steps_for_choice: Array = choices[i].get("next", [])
				if not next_steps_for_choice.is_empty():
					var branch_pos = Vector2(head_node.position_offset.x + 350, head_node.position_offset.y + (i * 80))
					var branch_head = _create_nodes_from_steps(next_steps_for_choice, global_npc_info, branch_pos, node_cache)
					if branch_head:
						graph_edit.connect_node.call_deferred(head_node.name, i, branch_head.name, 0)
		else:
			# --- Handle Linear Next Step ---
			var remaining_steps = steps.slice(1)
			if not remaining_steps.is_empty():
				var next_node_pos = Vector2(start_pos.x, start_pos.y + 200)
				var next_node_in_chain = _create_nodes_from_steps(remaining_steps, global_npc_info, next_node_pos, node_cache)
				if next_node_in_chain:
					graph_edit.connect_node.call_deferred(head_node.name, 0, next_node_in_chain.name, 0)

	# 3. Return the head node of this specific chain.
	return head_node

func _get_step_cache_key(step: Dictionary) -> String:
	"""Creates a stable cache key for a step, ignoring volatile parts like 'next'."""
	var temp_step = step.duplicate(true)
	if temp_step.get("type") == "choice":
		for choice in temp_step.get("choices", []):
			if choice.has("next"):
				choice.erase("next")
	return JSON.new().stringify(temp_step)


func _create_single_node(step: Dictionary, global_npc_info: Dictionary, pos: Vector2) -> DialogueGraphNode:
	"""Helper to create, configure, and deserialize data for a single node."""
	var new_node: DialogueGraphNode = null
	var step_type: String = step.get("type", "")
	var data_to_set := {}

	if step_type == "text":
		new_node = TextDialogueNodeScene.instantiate()
		var deserialized_npc_info = _deserialize_npc_info(step.get("npc_info", global_npc_info))
		data_to_set = {
			"text": step.get("text", {}),
			"actions": _deserialize_actions(step.get("actions", [])),
			"npc_info": deserialized_npc_info if deserialized_npc_info else NpcInfo.new()
		}
	elif step_type == "choice":
		new_node = ChoiceDialogueNodeScene.instantiate()
		var choices_data = []
		for choice_in_step in step.get("choices", []):
			var c = choice_in_step.duplicate()
			c["actions"] = _deserialize_actions(c.get("actions", []))
			if c.has("next"):
				c.erase("next")
			choices_data.append(c)
		
		var deserialized_npc_info = _deserialize_npc_info(step.get("npc_info", global_npc_info))
		data_to_set = {
			"choices": choices_data,
			"npc_info": deserialized_npc_info if deserialized_npc_info else NpcInfo.new()
		}
	elif step_type == "conditional_include":
		new_node = ConditionalIncludeNodeScene.instantiate()
		data_to_set = {"include_id": step.get("include_id", "")}
	
	if new_node:
		new_node.name = "DialogueNode_%d" % node_id_counter
		node_id_counter += 1
		new_node.position_offset = pos
		new_node.dialogue_data = data_to_set # Set deserialized data
		new_node.update_ui_from_data()

	return new_node

func _deserialize_npc_info(npc_data: Dictionary) -> NpcInfo:
	"""Converts a dictionary from JSON back into an NpcInfo resource object."""
	var npc_info = NpcInfo.new()
	if npc_data and npc_data.has("npc_resource_path"):
		npc_info.npc_resource_path = npc_data["npc_resource_path"]
	return npc_info

func _deserialize_actions(actions_data: Array) -> Array:
	var deserialized_actions: Array = []
	for action_dict in actions_data:
		var action_resource = Action.new()
		action_resource.action_type = action_dict.get("action_type", 0)
		match action_resource.action_type:
			Action.ActionType.UPDATE_QUEST:
				action_resource.quest_id = action_dict.get("quest_id", "")
				action_resource.quest_step = action_dict.get("quest_step", 0)
			Action.ActionType.UPDATE_EVENT:
				action_resource.event_id = action_dict.get("event_id", "")
				action_resource.event_step = action_dict.get("event_step", 0)
			Action.ActionType.SET_FLAG:
				action_resource.flag_name = action_dict.get("flag_name", "")
				action_resource.flag_value = action_dict.get("flag_value", "")
			Action.ActionType.CALL_METHOD:
				action_resource.target_root = action_dict.get("target_root", "world")
				action_resource.target_node_path = action_dict.get("target_node_path", "")
				action_resource.method_name = action_dict.get("method_name", "")
				action_resource.method_args = action_dict.get("method_args", [])
		deserialized_actions.append(action_resource)
	return deserialized_actions

func _clear_graph():
	graph_edit.clear_connections()
	for node in graph_edit.get_children():
		if node is DialogueGraphNode:
			node.queue_free()
	node_id_counter = 0
	
	dialogue_file = DialogueFile.new()
	dialogue_file.npc_info = NpcInfo.new()
	
	if inspector_panel:
		inspector_panel.set_selected_node(null)

func _extract_global_npc_info() -> Dictionary:
	"""Extract NPC info from the first node that has it, to use as global NPC info."""
	var default_npc_info = NpcInfo.new()
	
	# Find the first node with NPC info
	for node in graph_edit.get_children():
		if node is DialogueGraphNode:
			var npc_info = node.dialogue_data.get("npc_info")
			if npc_info:
				return npc_info.get_save_data()
	
	# If no NPC info found, return default
	return default_npc_info.get_save_data()

func _remove_npc_info_from_steps(steps: Array) -> Array:
	"""Remove npc_info from all steps since it will be stored globally."""
	var cleaned_steps = []
	
	for step in steps:
		var cleaned_step = step.duplicate(true)
		if cleaned_step.has("npc_info"):
			cleaned_step.erase("npc_info")
		
		# Handle nested steps in choices
		if cleaned_step.get("type") == "choice" and cleaned_step.has("choices"):
			for choice in cleaned_step["choices"]:
				if choice.has("next"):
					choice["next"] = _remove_npc_info_from_steps(choice["next"])
		
		cleaned_steps.append(cleaned_step)
	
	return cleaned_steps

func _detect_npc_info_mode(graph_data: Dictionary) -> int:
	"""Detect whether the loaded file uses individual or global NPC info mode."""
	if not graph_data.has("dialogues") or graph_data["dialogues"].size() == 0:
		return 0  # Default to individual mode
	
	var dialogue = graph_data["dialogues"][0]
	
	# Check if there's a global npc_info field
	if dialogue.has("npc_info"):
		return 1  # Global mode
	
	# Check if steps have individual npc_info
	if dialogue.has("steps"):
		for step in dialogue["steps"]:
			if step.has("npc_info"):
				return 0  # Individual mode

	return 0  # Default to individual mode

func _save_graph_data() -> Dictionary:
	"""Save the current graph state for editor loading."""
	var graph_data = {
		"nodes": [],
		"connections": []
	}
	
	# Save all nodes
	for node in graph_edit.get_children():
		if node is DialogueGraphNode:
			var node_data = {
				"name": node.name,
				"type": node.get_node_type_string(),
				"position_x": node.position_offset.x,
				"position_y": node.position_offset.y,
				"data": node.dialogue_data
			}
			graph_data["nodes"].append(node_data)
	
	# Save all connections
	var connections = graph_edit.get_connection_list()
	for conn in connections:
		var conn_data = {
			"from_node": conn.from_node,
			"from_port": conn.from_port,
			"to_node": conn.to_node,
			"to_port": conn.to_port
		}
		graph_data["connections"].append(conn_data)
	
	return graph_data

func _on_node_close_request(node: DialogueGraphNode) -> void:
	"""Handle node close request."""
	if not node:
		return
	
	# Clear inspector panel if this node is selected
	if inspector_panel.get_selected_node() == node:
		inspector_panel.set_selected_node(null)
	
	# Clear selected node reference
	if selected_node == node:
		selected_node = null
	
	# Remove all connections involving this node
	var connections = graph_edit.get_connection_list()
	for conn in connections:
		if conn.from_node == node.name or conn.to_node == node.name:
			graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	
	# Remove the node from the graph
	node.queue_free() 