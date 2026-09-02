class_name InteractionController
extends Node

signal prompt_changed(visible: bool, text: String)
signal target_changed(target: Node)

@export var raycast: RayCast3D

var current_target: Node


func _ready() -> void:
	add_to_group("interaction_controller")


func _physics_process(_delta: float) -> void:
	var player := get_parent() as PharmacyPlayer
	if player == null or not player.controls_enabled:
		_clear_target()
		return
	var next_target: Node = _get_raycast_target()
	if next_target != current_target:
		if current_target != null and current_target.has_method("set_highlighted"):
			current_target.set_highlighted(false)
		current_target = next_target
		if current_target != null and current_target.has_method("set_highlighted"):
			current_target.set_highlighted(true)
		target_changed.emit(current_target)
		_update_prompt()
	elif current_target != null:
		_update_prompt()

	if Input.is_action_just_pressed("interact") and current_target != null:
		if current_target.can_interact(player):
			current_target.interact(player)
			_update_prompt()


func _get_raycast_target() -> Node:
	if raycast == null or not raycast.is_colliding():
		return null
	var collider := raycast.get_collider() as Node
	if collider == null:
		return null
	var component := collider.get_node_or_null("Interactable")
	if component != null:
		return component
	if collider.get_parent() != null:
		return collider.get_parent().get_node_or_null("Interactable")
	return null


func _update_prompt() -> void:
	var player := get_parent() as PharmacyPlayer
	var should_show: bool = current_target != null and current_target.can_interact(player)
	var text: String = current_target.get_interaction_text() if should_show else ""
	prompt_changed.emit(should_show, text)


func _clear_target() -> void:
	if current_target == null:
		return
	if current_target.has_method("set_highlighted"):
		current_target.set_highlighted(false)
	current_target = null
	target_changed.emit(null)
	prompt_changed.emit(false, "")
