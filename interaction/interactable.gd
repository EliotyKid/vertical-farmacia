class_name InteractableComponent
extends Node

signal interacted(player: PharmacyPlayer)

@export var interaction_text: String = "Interagir"
@export var enabled: bool = true

var _highlighted: bool = false
var _highlight_material: StandardMaterial3D


func can_interact(_player: PharmacyPlayer) -> bool:
	if not enabled:
		return false
	var owner_node := _get_behavior_owner()
	if owner_node.has_method("can_player_interact"):
		return owner_node.can_player_interact(_player)
	return true


func get_interaction_text() -> String:
	var owner_node := _get_behavior_owner()
	if owner_node.has_method("get_contextual_interaction_text"):
		return owner_node.get_contextual_interaction_text()
	return interaction_text


func interact(player: PharmacyPlayer) -> void:
	if not can_interact(player):
		return
	interacted.emit(player)


func _get_behavior_owner() -> Node:
	var direct_owner := get_parent()
	if direct_owner.has_method("can_player_interact") or direct_owner.has_method("get_contextual_interaction_text"):
		return direct_owner
	var parent_owner := direct_owner.get_parent()
	return parent_owner if parent_owner != null else direct_owner


func set_highlighted(value: bool) -> void:
	if _highlighted == value:
		return
	_highlighted = value
	if _highlight_material == null:
		_highlight_material = StandardMaterial3D.new()
		_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_highlight_material.albedo_color = Color(0.35, 0.95, 0.72, 0.24)
		_highlight_material.emission_enabled = true
		_highlight_material.emission = Color(0.15, 0.8, 0.45)
		_highlight_material.emission_energy_multiplier = 1.6
		_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for child: Node in get_parent().find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		mesh.material_overlay = _highlight_material if value else null
