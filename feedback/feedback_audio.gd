class_name FeedbackAudio
extends Node

const SAMPLE_RATE := 22050

@export_range(-40.0, 0.0, 1.0) var effects_volume_db: float = -12.0
@export_range(-40.0, 0.0, 1.0) var footsteps_volume_db: float = -20.0
@export_range(0.2, 1.0, 0.05) var walk_step_interval: float = 0.48

var _player: PharmacyPlayer
var _step_remaining: float = 0.0
var _step_alternate: bool = false
var _customer_urgency_levels: Dictionary = {}
var _inspection_warning_active: bool = false


func _ready() -> void:
	call_deferred("_connect_gameplay")


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.is_on_floor() and Vector2(_player.velocity.x, _player.velocity.z).length() > 0.8 and _player.controls_enabled:
		_step_remaining -= delta
		if _step_remaining <= 0.0:
			_step_alternate = not _step_alternate
			_play_tone(105.0 if _step_alternate else 92.0, 0.055, footsteps_volume_db, 0.18, 0.8)
			var speed_ratio: float = Vector2(_player.velocity.x, _player.velocity.z).length() / _player.walk_speed
			_step_remaining = walk_step_interval / maxf(speed_ratio, 1.0)
	else:
		_step_remaining = 0.0


func _connect_gameplay() -> void:
	_player = get_tree().get_first_node_in_group("player") as PharmacyPlayer
	if _player != null:
		var carry := _player.get_node_or_null("CarryController") as CarryController
		var wallet := _player.get_node_or_null("Wallet") as Wallet
		if carry != null:
			carry.carried_item_changed.connect(_on_carried_item_changed)
		if wallet != null:
			wallet.money_changed.connect(_on_money_changed)

	for shelf: PharmacyShelf in get_tree().get_nodes_in_group("storage_feedback"):
		shelf.item_placed.connect(_on_item_placed)

	var terminal := get_tree().get_first_node_in_group("supplier_terminal") as SupplierTerminal
	if terminal != null:
		terminal.item_purchased.connect(_on_item_purchased)
		terminal.delivery_arrived.connect(_on_delivery_arrived)

	var station := get_tree().get_first_node_in_group("crafting_station") as StationInput
	if station != null:
		station.ingredient_inserted.connect(_on_ingredient_inserted)
		station.craft_started.connect(_on_craft_started)
		station.craft_completed.connect(_on_craft_completed)
		station.craft_failed.connect(_on_craft_failed)
		station.explosion_triggered.connect(_on_explosion_triggered)

	var spawner := get_tree().get_first_node_in_group("customer_spawner") as CustomerSpawner
	if spawner != null:
		spawner.customer_spawned.connect(_on_customer_spawned)
		if spawner.active_customer != null:
			_on_customer_spawned(spawner.active_customer)

	var inspection := get_tree().get_first_node_in_group("inspection_manager") as InspectionManager
	if inspection != null:
		inspection.inspection_status_changed.connect(_on_inspection_status_changed)
		inspection.inspection_resolved.connect(_on_inspection_resolved)


func _on_carried_item_changed(item: WorldItem) -> void:
	if item != null:
		_play_tone(420.0, 0.09, effects_volume_db, 0.28, 1.45)


func _on_item_placed(_item: WorldItem, _slot_index: int) -> void:
	_play_tone(185.0, 0.1, effects_volume_db, 0.32, 0.72)


func _on_ingredient_inserted(_item: WorldItem, _slot_index: int) -> void:
	_play_tone(260.0, 0.11, effects_volume_db, 0.3, 1.25)


func _on_money_changed(_new_amount: int, difference: int) -> void:
	if difference > 0:
		_play_tone(620.0, 0.16, effects_volume_db, 0.25, 1.5)
	elif difference < 0:
		_play_tone(310.0, 0.11, effects_volume_db, 0.3, 0.8)


func _on_item_purchased(_item_data: ItemData, _price: int) -> void:
	_play_tone(520.0, 0.08, effects_volume_db - 3.0, 0.2, 1.3)


func _on_delivery_arrived(_item_data: ItemData, _quantity: int) -> void:
	_play_tone(560.0, 0.2, effects_volume_db, 0.25, 1.5)


func _on_customer_spawned(customer: PharmacyCustomer) -> void:
	customer.order_created.connect(_on_order_created)
	customer.order_completed.connect(_on_order_completed)
	customer.delivery_rejected.connect(_on_delivery_rejected)
	customer.order_abandoned.connect(_on_order_abandoned)
	customer.patience_changed.connect(_on_patience_changed)
	customer.departed.connect(_on_customer_departed)
	_customer_urgency_levels[customer] = 0


func _on_order_created(_customer: PharmacyCustomer, _order: CustomerOrder) -> void:
	_play_tone(480.0, 0.18, effects_volume_db, 0.22, 1.35)


func _on_order_completed(_customer: PharmacyCustomer, _order: CustomerOrder) -> void:
	_play_tone(740.0, 0.22, effects_volume_db, 0.2, 1.45)


func _on_delivery_rejected(_customer: PharmacyCustomer, _item: ItemData) -> void:
	_play_tone(190.0, 0.24, effects_volume_db, 0.35, 0.55)


func _on_order_abandoned(_customer: PharmacyCustomer, _order: CustomerOrder) -> void:
	_play_tone(135.0, 0.34, effects_volume_db, 0.38, 0.45)


func _on_patience_changed(customer: PharmacyCustomer, ratio: float) -> void:
	var new_level := 2 if ratio <= 0.25 else (1 if ratio <= 0.5 else 0)
	var previous_level := int(_customer_urgency_levels.get(customer, 0))
	if new_level > previous_level:
		_play_tone(410.0 if new_level == 1 else 330.0, 0.16, effects_volume_db, 0.3, 0.72)
	_customer_urgency_levels[customer] = new_level


func _on_customer_departed(customer: PharmacyCustomer) -> void:
	_customer_urgency_levels.erase(customer)


func _on_inspection_status_changed(status: String, urgent: bool) -> void:
	var is_warning := urgent and status.begins_with("POLÍCIA EM")
	if is_warning and not _inspection_warning_active:
		_play_tone(760.0, 0.32, effects_volume_db + 1.0, 0.3, 0.7)
	_inspection_warning_active = is_warning


func _on_inspection_resolved(passed: bool, _fine: int, _confiscated: int) -> void:
	if passed:
		_play_tone(660.0, 0.22, effects_volume_db, 0.22, 1.35)
	else:
		_play_tone(120.0, 0.42, effects_volume_db + 1.0, 0.4, 0.55)


func _on_craft_started(_recipe: RecipeData) -> void:
	_play_tone(280.0, 0.22, effects_volume_db, 0.28, 1.8)


func _on_craft_completed(_recipe: RecipeData, _output: WorldItem) -> void:
	_play_tone(680.0, 0.25, effects_volume_db, 0.22, 1.55)


func _on_craft_failed() -> void:
	_play_tone(150.0, 0.3, effects_volume_db, 0.42, 0.45)


func _on_explosion_triggered(_explosion: CraftingExplosion) -> void:
	_play_noise(0.42, effects_volume_db + 4.0)


func _play_tone(frequency: float, duration: float, volume_db: float, amplitude: float, end_ratio: float) -> void:
	var frames := maxi(int(SAMPLE_RATE * duration), 1)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase: float = 0.0
	for frame: int in range(frames):
		var progress := float(frame) / float(frames)
		var current_frequency := frequency * lerpf(1.0, end_ratio, progress)
		phase += TAU * current_frequency / SAMPLE_RATE
		var envelope := sin(PI * progress) * (1.0 - progress * 0.35)
		data.encode_s16(frame * 2, int(sin(phase) * envelope * amplitude * 32767.0))
	_play_stream(_make_stream(data), volume_db)


func _play_noise(duration: float, volume_db: float) -> void:
	var frames := maxi(int(SAMPLE_RATE * duration), 1)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 7319
	for frame: int in range(frames):
		var progress := float(frame) / float(frames)
		var envelope := pow(1.0 - progress, 2.0)
		var sample := random.randf_range(-1.0, 1.0) * envelope * 0.72
		data.encode_s16(frame * 2, int(sample * 32767.0))
	_play_stream(_make_stream(data), volume_db)


func _make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _play_stream(stream: AudioStreamWAV, volume_db: float) -> void:
	var audio_player := AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.volume_db = volume_db
	add_child(audio_player)
	audio_player.finished.connect(audio_player.queue_free)
	audio_player.play()
