class_name CarryController
extends Node

signal carried_item_changed(item: WorldItem)

@export var hold_marker: Marker3D

var current_item: WorldItem


func _unhandled_input(event: InputEvent) -> void:
	var player := get_parent() as PharmacyPlayer
	if player != null and player.controls_enabled and event.is_action_pressed("drop_item"):
		drop_item()


func _physics_process(_delta: float) -> void:
	if current_item != null and is_instance_valid(current_item) and hold_marker != null:
		current_item.global_transform = hold_marker.global_transform


func try_pick_up(item: WorldItem) -> bool:
	var network_state := get_node_or_null("/root/NetworkWorldState")
	if network_state != null and network_state.is_network_active():
		return network_state.request_pick_up(item, get_parent() as PharmacyPlayer)
	if current_item != null or item == null or hold_marker == null:
		return false
	item.reparent(get_parent().get_parent(), true)
	current_item = item
	current_item.set_carried(true)
	current_item.linear_velocity = Vector3.ZERO
	current_item.angular_velocity = Vector3.ZERO
	current_item.global_transform = hold_marker.global_transform
	current_item.play_pickup_feedback()
	carried_item_changed.emit(current_item)
	return true


func drop_item() -> WorldItem:
	if current_item == null:
		return null
	var network_state := get_node_or_null("/root/NetworkWorldState")
	if network_state != null and network_state.is_network_active():
		network_state.request_drop(get_parent() as PharmacyPlayer)
		return current_item
	var dropped_item := current_item
	current_item = null
	dropped_item.reparent(get_parent().get_parent(), true)
	dropped_item.global_position = hold_marker.global_position
	dropped_item.set_carried(false)
	dropped_item.linear_velocity = Vector3.ZERO
	carried_item_changed.emit(null)
	return dropped_item


func place_current_item(target_parent: Node, target_transform: Transform3D) -> WorldItem:
	if current_item == null:
		return null
	var placed_item := current_item
	current_item = null
	placed_item.reparent(target_parent, true)
	placed_item.global_transform = target_transform
	placed_item.set_stored(true)
	placed_item.play_placement_feedback()
	carried_item_changed.emit(null)
	return placed_item


func consume_current_item() -> ItemData:
	if current_item == null:
		return null
	var network_state := get_node_or_null("/root/NetworkWorldState")
	if network_state != null and network_state.is_network_active() and not network_state.is_host():
		return null
	var consumed_data := current_item.item_data
	var consumed_item := current_item
	current_item = null
	carried_item_changed.emit(null)
	consumed_item.queue_free()
	return consumed_data


func is_carrying_item() -> bool:
	return current_item != null

func apply_network_item(item: WorldItem) -> void:
	if current_item == item:
		return
	current_item = item
	carried_item_changed.emit(current_item)

func clear_network_item(item: WorldItem) -> void:
	if current_item != item:
		return
	current_item = null
	carried_item_changed.emit(null)
