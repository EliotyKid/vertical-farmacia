class_name PharmacyCustomer
extends CharacterBody3D

signal state_changed(customer: PharmacyCustomer, new_state: State)
signal departed(customer: PharmacyCustomer)
signal order_created(customer: PharmacyCustomer, order: CustomerOrder)
signal order_completed(customer: PharmacyCustomer, order: CustomerOrder)
signal delivery_rejected(customer: PharmacyCustomer, delivered_item: ItemData)
signal order_abandoned(customer: PharmacyCustomer, order: CustomerOrder)
signal patience_changed(customer: PharmacyCustomer, ratio: float)

enum State {
	ENTERING,
	WALKING_TO_COUNTER,
	WAITING,
	ORDER_ACTIVE,
	RECEIVING,
	LEAVING,
	FAILED,
	COMPLAINING,
}

enum Archetype { COMMON, RUSHED, SPECIAL }

@export_range(0.5, 6.0, 0.1) var move_speed: float = 2.2
@export_range(0.05, 1.0, 0.05) var arrival_distance: float = 0.2
@export var requested_item: ItemData
@export_range(0, 10000, 1) var order_reward: int = 20
@export_range(5.0, 180.0, 1.0) var patience_duration: float = 45.0

@onready var state_label: Label3D = %StateLabel
@onready var body_mesh: MeshInstance3D = %BodyMesh
@onready var head_mesh: MeshInstance3D = %HeadMesh
@onready var patience_bar: MeshInstance3D = %PatienceBar
@onready var patience_text: Label3D = %PatienceText

var current_state: State = State.ENTERING
var counter_position: Vector3
var exit_position: Vector3
var _wait_remaining: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var current_order: CustomerOrder
var _walk_feedback_time: float = 0.0
var _patience_remaining: float
var archetype: Archetype = Archetype.COMMON
var archetype_label: String = "COMUM"


func setup(counter_target: Vector3, exit_target: Vector3) -> void:
	counter_position = counter_target
	exit_position = exit_target
	_patience_remaining = patience_duration


func update_queue_position(target: Vector3) -> void:
	counter_position = target


func configure_order(item: ItemData) -> void:
	requested_item = item
	if requested_item != null:
		order_reward = requested_item.sell_price


func configure_archetype(new_archetype: Archetype, configured_patience: float) -> void:
	archetype = new_archetype
	patience_duration = maxf(configured_patience, 5.0)
	match archetype:
		Archetype.RUSHED:
			archetype_label = "APRESSADO"
		Archetype.SPECIAL:
			archetype_label = "ESPECIAL"
		_:
			archetype_label = "COMUM"


func _ready() -> void:
	$Interactable.interacted.connect(_on_interacted)
	_apply_customer_visual()
	_update_state_label()
	call_deferred("_change_state", State.WALKING_TO_COUNTER)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	match current_state:
		State.WALKING_TO_COUNTER:
			_move_toward(counter_position)
			if _horizontal_distance_to(counter_position) <= arrival_distance:
				_wait_remaining = 0.5
				_change_state(State.WAITING)
		State.WAITING:
			_stop_horizontal_movement()
			_wait_remaining -= delta
			if _wait_remaining <= 0.0:
				_create_order()
		State.ORDER_ACTIVE:
			_update_patience(delta)
			if _horizontal_distance_to(counter_position) > arrival_distance:
				_move_toward(counter_position)
			else:
				_stop_horizontal_movement()
		State.LEAVING:
			_move_toward(exit_position)
			if _horizontal_distance_to(exit_position) <= arrival_distance:
				departed.emit(self)
				queue_free()
		_:
			_stop_horizontal_movement()

	_update_walk_feedback(delta)
	move_and_slide()


func get_state_name() -> String:
	return State.keys()[current_state].capitalize()


func get_order_wait_time() -> float:
	return clampf(patience_duration - _patience_remaining, 0.0, patience_duration)


func can_player_interact(_player: PharmacyPlayer) -> bool:
	return current_state == State.ORDER_ACTIVE and current_order != null


func get_contextual_interaction_text() -> String:
	if current_order == null or current_order.requested_item == null:
		return "Atender cliente"
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	var carry := player.get_node_or_null("CarryController") as CarryController if player != null else null
	if carry == null or carry.current_item == null:
		return "Pedido: %s" % current_order.requested_item.display_name
	return "Entregar %s" % carry.current_item.get_display_name()


func _create_order() -> void:
	if requested_item == null:
		push_warning("Cliente sem item configurado para o pedido.")
		_change_state(State.FAILED)
		_wait_remaining = 2.0
		return
	current_order = CustomerOrder.new()
	current_order.requested_item = requested_item
	current_order.quantity = 1
	current_order.reward = order_reward
	_change_state(State.ORDER_ACTIVE)
	order_created.emit(self, current_order)
	_update_patience_visual()


func _update_patience(delta: float) -> void:
	_patience_remaining = maxf(_patience_remaining - delta, 0.0)
	_update_patience_visual()
	if _patience_remaining <= 0.0:
		_abandon_order()


func _update_patience_visual() -> void:
	var ratio := clampf(_patience_remaining / patience_duration, 0.0, 1.0)
	patience_bar.visible = current_state == State.ORDER_ACTIVE
	patience_text.visible = current_state == State.ORDER_ACTIVE
	patience_bar.scale.x = maxf(ratio, 0.01)
	patience_bar.position.x = -0.45 * (1.0 - ratio)
	var urgency := "URGENTE!" if ratio <= 0.25 else ("ATENÇÃO" if ratio <= 0.5 else "")
	patience_text.text = "%s  %ds" % [urgency, ceili(_patience_remaining)]
	patience_text.modulate = Color("ff6969") if ratio <= 0.25 else (Color("ffd36a") if ratio <= 0.5 else Color.WHITE)
	var material := patience_bar.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = Color("67df83").lerp(Color("ef4f4f"), 1.0 - ratio)
		material.emission = material.albedo_color
	patience_changed.emit(self, ratio)


func _abandon_order() -> void:
	if current_state != State.ORDER_ACTIVE:
		return
	var abandoned_order := current_order
	current_order = null
	_change_state(State.COMPLAINING)
	state_label.text = "DEMOROU DEMAIS!"
	state_label.modulate = Color("ff6969")
	patience_bar.visible = false
	patience_text.visible = false
	order_abandoned.emit(self, abandoned_order)
	_leave_after_delay(1.1)


func _leave_after_delay(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	state_label.modulate = Color.WHITE
	_change_state(State.LEAVING)


func _on_interacted(player: PharmacyPlayer) -> void:
	if current_state != State.ORDER_ACTIVE or current_order == null:
		return
	var carry := player.get_node_or_null("CarryController") as CarryController
	if carry == null or carry.current_item == null:
		return
	if not current_order.matches(carry.current_item):
		delivery_rejected.emit(self, carry.current_item.item_data)
		_play_reaction(false)
		return
	var completed_order := current_order
	_change_state(State.RECEIVING)
	carry.consume_current_item()
	var wallet := player.get_node_or_null("Wallet") as Wallet
	if wallet != null:
		wallet.add_money(completed_order.reward)
	order_completed.emit(self, completed_order)
	_play_reaction(true)
	current_order = null
	_wait_remaining = 0.8
	await get_tree().create_timer(_wait_remaining).timeout
	_change_state(State.LEAVING)


func _move_toward(target: Vector3) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() <= arrival_distance * arrival_distance:
		_stop_horizontal_movement()
		return
	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 0.18)


func _stop_horizontal_movement() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _horizontal_distance_to(target: Vector3) -> float:
	var offset := target - global_position
	offset.y = 0.0
	return offset.length()


func _update_walk_feedback(delta: float) -> void:
	if current_state == State.WALKING_TO_COUNTER or current_state == State.LEAVING:
		_walk_feedback_time += delta * move_speed * 5.5
		var bounce := absf(sin(_walk_feedback_time)) * 0.055
		body_mesh.position.y = bounce
		head_mesh.position.y = 1.03 + bounce
	else:
		body_mesh.position.y = move_toward(body_mesh.position.y, 0.0, delta * 0.8)
		head_mesh.position.y = move_toward(head_mesh.position.y, 1.03, delta * 0.8)


func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	_update_state_label()
	state_changed.emit(self, current_state)


func _update_state_label() -> void:
	if current_state == State.ORDER_ACTIVE and current_order != null:
		state_label.text = "%s • PEDIDO\n%s" % [archetype_label, current_order.requested_item.display_name]
	else:
		state_label.text = get_state_name()


func _apply_customer_visual() -> void:
	var material := StandardMaterial3D.new()
	match archetype:
		Archetype.RUSHED:
			material.albedo_color = Color("d9503f")
		Archetype.SPECIAL:
			material.albedo_color = Color("9258b8")
		_:
			material.albedo_color = Color("db9b3d")
	material.roughness = 0.82
	body_mesh.material_override = material
	head_mesh.material_override = material


func _play_reaction(success: bool) -> void:
	state_label.modulate = Color("6dff9a") if success else Color("ff6969")
	state_label.text = "OBRIGADO!" if success else "ITEM ERRADO!"
	var original_position := body_mesh.position
	var tween := create_tween().set_parallel(true)
	tween.tween_property(body_mesh, "position:y", original_position.y + (0.22 if success else -0.12), 0.16)
	tween.tween_property(head_mesh, "rotation:z", (-0.18 if success else 0.22), 0.16)
	await tween.finished
	var reset := create_tween().set_parallel(true)
	reset.tween_property(body_mesh, "position", original_position, 0.2)
	reset.tween_property(head_mesh, "rotation:z", 0.0, 0.2)
	await get_tree().create_timer(0.35).timeout
	state_label.modulate = Color.WHITE
	_update_state_label()
