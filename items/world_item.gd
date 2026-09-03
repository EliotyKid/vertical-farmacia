class_name WorldItem
extends RigidBody3D

@export var item_data: ItemData
@export_category("Recovery")
@export var fall_recovery_height: float = -4.0

@onready var interactable: InteractableComponent = $Interactable
@onready var mesh_instance: MeshInstance3D = %MeshInstance3D
@onready var name_label: Label3D = %NameLabel

var _safe_transform: Transform3D
var network_item_id: int = 0


func _ready() -> void:
	add_to_group("network_world_item")
	interactable.interacted.connect(_on_interacted)
	_apply_item_data()
	_safe_transform = global_transform
	call_deferred("mark_current_transform_safe")


func _physics_process(_delta: float) -> void:
	if not freeze and global_position.y < fall_recovery_height:
		global_transform = _safe_transform
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		sleeping = true


func set_carried(is_carried: bool) -> void:
	freeze = is_carried
	interactable.enabled = not is_carried
	if is_carried:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = 1
		collision_mask = 1


func set_stored(is_stored: bool) -> void:
	freeze = is_stored
	interactable.enabled = not is_stored
	collision_layer = 0 if is_stored else 1
	collision_mask = 0 if is_stored else 1
	if not is_stored:
		_safe_transform = global_transform


func mark_current_transform_safe() -> void:
	_safe_transform = global_transform


func play_pickup_feedback() -> void:
	_animate_mesh(Vector3.ONE * 1.18, 0.12)


func play_placement_feedback() -> void:
	_animate_mesh(Vector3(1.12, 0.82, 1.12), 0.15)


func _animate_mesh(punch_scale: Vector3, duration: float) -> void:
	if mesh_instance == null:
		return
	mesh_instance.scale = Vector3.ONE
	var tween := create_tween()
	tween.tween_property(mesh_instance, "scale", punch_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func get_display_name() -> String:
	return item_data.display_name if item_data != null else "Item sem dados"


func _on_interacted(player: PharmacyPlayer) -> void:
	var carry_controller := player.get_node_or_null("CarryController") as CarryController
	if carry_controller != null:
		carry_controller.try_pick_up(self)


func _apply_item_data() -> void:
	if item_data == null:
		push_warning("WorldItem sem ItemData: %s" % get_path())
		return
	interactable.interaction_text = "Pegar %s" % item_data.display_name
	name_label.text = item_data.display_name
	var material := StandardMaterial3D.new()
	material.albedo_color = item_data.placeholder_color
	material.roughness = 0.78
	mesh_instance.material_override = material
