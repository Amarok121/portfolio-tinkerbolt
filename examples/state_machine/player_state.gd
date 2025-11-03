class_name PlayerState extends Node

# Stores a reference to the player that this state belongs to
var player: player_movement
var state_machine: Node

func init() -> void:
	pass

func enter() -> void:
	pass

func exit() -> void:
	pass

func process(_delta: float) -> Node:
	_delta *= Global.slow_factor
	if player and player.animation_tree:
		player.animation_tree.set("parameters/TimeScale/scale", Global.slow_factor)
	return null

func physics(_delta: float) -> Node:
	if player and player.animation_tree:
		player.animation_tree.set("parameters/TimeScale/scale", Global.slow_factor)
	return null

func handle_input(_event: InputEvent) -> Node:
	return null

# Helper function to check if current state has a specific name
func is_state(state_name: String) -> bool:
	if get_script():
		return get_script().get_global_name() == state_name
	return false 