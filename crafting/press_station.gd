class_name PressStation
extends StaticBody3D

signal ingredient_inserted(item: WorldItem, slot_index: int)
signal press_performed(current: int, required: int)
signal craft_completed(recipe: RecipeData, output: WorldItem)

@export var recipes: Array[RecipeData] = []
@export var world_item_scene: PackedScene
@export_range(1, 10, 1) var required_presses: int = 4
@export_range(0.05, 1.0, 0.05) var press_cooldown: float = 0.3

@onready var interactable: InteractableComponent = %Interactable
@onready var status_label: Label3D = %StatusLabel
@onready var lever: MeshInstance3D = %Lever
@onready var slots: Array[Marker3D] = [%InputSlot1, %InputSlot2]

var ingredients: Array[WorldItem] = []
var active_recipe: RecipeData
var current_presses: int = 0
var _cooldown_remaining: float = 0.0

func _ready() -> void:
	add_to_group("secondary_station")
	ingredients.resize(slots.size())
	interactable.interacted.connect(_on_interacted)
	_update_status()

func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)

func can_player_interact(player: PharmacyPlayer) -> bool:
	var carry := player.get_node_or_null("CarryController") as CarryController
	if carry == null:
		return false
	if carry.current_item != null:
		return _first_empty_slot() >= 0
	return active_recipe != null or _last_occupied_slot() >= 0

func get_contextual_interaction_text() -> String:
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	var carry := player.get_node_or_null("CarryController") as CarryController if player != null else null
	if carry != null and carry.current_item != null:
		if carry.current_item.item_data == null or carry.current_item.item_data.category != ItemData.Category.INGREDIENT:
			return "A prensa aceita apenas ingredientes"
		return "Inserir %s na prensa" % carry.current_item.get_display_name()
	if active_recipe != null:
		return "Acionar prensa (%d/%d)" % [current_presses, required_presses]
	if _ingredient_count() >= 2:
		return "Combinação incompatível — retirar item"
	var index := _last_occupied_slot()
	return "Retirar %s" % ingredients[index].get_display_name() if index >= 0 else "Prensa vazia"

func _on_interacted(player: PharmacyPlayer) -> void:
	var network_lab := get_node_or_null("/root/NetworkLabState")
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_lab != null and network_session != null and network_session._steam_peer != null:
		network_lab.request_press_interaction()
		return
	var carry := player.get_node_or_null("CarryController") as CarryController
	if carry == null:
		return
	if carry.current_item != null:
		_insert_from(carry)
	elif active_recipe != null:
		_perform_press()
	else:
		_remove_to(carry)

func network_authority_interact(peer_id: int, world_state: Node) -> void:
	if world_state == null:
		return
	var carried := world_state.get_carried_item(peer_id) as WorldItem
	if carried != null:
		var index := _first_empty_slot()
		if carried.item_data == null or carried.item_data.category != ItemData.Category.INGREDIENT or index < 0:
			return
		var item := world_state.authority_store_carried(peer_id, slots[index].global_transform) as WorldItem
		if item != null:
			ingredients[index] = item
			ingredient_inserted.emit(item, index)
			active_recipe = _find_recipe()
			current_presses = 0
			_update_status()
	elif active_recipe != null:
		_perform_press()
	else:
		var index := _last_occupied_slot()
		if index >= 0:
			var item := ingredients[index]
			if world_state.authority_pick_up_item(peer_id, item.network_item_id):
				ingredients[index] = null
				active_recipe = _find_recipe()
				current_presses = 0
				_update_status()

func get_network_snapshot() -> Dictionary:
	var ingredient_ids: Array[int] = []
	for item: WorldItem in ingredients:
		ingredient_ids.append(item.network_item_id if item != null else 0)
	return {
		"ingredients": ingredient_ids,
		"recipe_path": active_recipe.resource_path if active_recipe != null else "",
		"presses": current_presses,
		"cooldown": _cooldown_remaining,
	}

func apply_network_snapshot(data: Dictionary, world_state: Node) -> void:
	if world_state == null:
		return
	var ids: Array = data.get("ingredients", [])
	for index: int in range(ingredients.size()):
		var item_id := int(ids[index]) if index < ids.size() else 0
		ingredients[index] = world_state.get_item_by_id(item_id) if item_id > 0 else null
	var previous_recipe := active_recipe
	var recipe_path := str(data.get("recipe_path", ""))
	active_recipe = load(recipe_path) as RecipeData if not recipe_path.is_empty() else null
	current_presses = int(data.get("presses", 0))
	_cooldown_remaining = float(data.get("cooldown", 0.0))
	_update_status()
	if previous_recipe != null and active_recipe == null:
		craft_completed.emit(previous_recipe, null)

func apply_network_press_feedback(current: int, required: int) -> void:
	current_presses = current
	press_performed.emit(current, required)
	var tween := create_tween()
	tween.tween_property(lever, "rotation:z", -0.75, 0.1)
	tween.tween_property(lever, "rotation:z", 0.0, 0.16)

func _insert_from(carry: CarryController) -> void:
	var item := carry.current_item
	var index := _first_empty_slot()
	if item == null or item.item_data == null or item.item_data.category != ItemData.Category.INGREDIENT or index < 0:
		return
	item = carry.place_current_item(self, slots[index].global_transform)
	ingredients[index] = item
	ingredient_inserted.emit(item, index)
	active_recipe = _find_recipe()
	current_presses = 0
	_update_status()

func _remove_to(carry: CarryController) -> void:
	var index := _last_occupied_slot()
	if index < 0:
		return
	var item := ingredients[index]
	ingredients[index] = null
	item.set_stored(false)
	if not carry.try_pick_up(item):
		ingredients[index] = item
		item.set_stored(true)
	active_recipe = _find_recipe()
	current_presses = 0
	_update_status()

func _perform_press() -> void:
	if active_recipe == null or _cooldown_remaining > 0.0:
		return
	_cooldown_remaining = press_cooldown
	current_presses += 1
	press_performed.emit(current_presses, required_presses)
	var tween := create_tween()
	tween.tween_property(lever, "rotation:z", -0.75, 0.1)
	tween.tween_property(lever, "rotation:z", 0.0, 0.16)
	_update_status()
	if current_presses >= required_presses:
		_complete_craft()

func _complete_craft() -> void:
	var recipe := active_recipe
	for index: int in range(ingredients.size()):
		if ingredients[index] != null:
			ingredients[index].queue_free()
			ingredients[index] = null
	active_recipe = null
	current_presses = 0
	var output := world_item_scene.instantiate() as WorldItem
	output.item_data = recipe.output_item
	get_parent().add_child(output)
	output.global_position = %OutputMarker.global_position
	output.mark_current_transform_safe()
	craft_completed.emit(recipe, output)
	_update_status()

func _find_recipe() -> RecipeData:
	for recipe: RecipeData in recipes:
		if recipe != null and recipe.station_type == RecipeData.StationType.PRESS and recipe.matches(ingredients):
			return recipe
	return null

func _first_empty_slot() -> int:
	for index: int in range(ingredients.size()):
		if ingredients[index] == null:
			return index
	return -1

func _last_occupied_slot() -> int:
	for index: int in range(ingredients.size() - 1, -1, -1):
		if ingredients[index] != null:
			return index
	return -1

func _ingredient_count() -> int:
	var count := 0
	for item: WorldItem in ingredients:
		if item != null:
			count += 1
	return count

func _update_status() -> void:
	if active_recipe != null:
		status_label.text = "PRENSA: %s\nACIONE %d/%d" % [active_recipe.display_name.to_upper(), current_presses, required_presses]
		return
	var names: Array[String] = []
	for item: WorldItem in ingredients:
		if item != null:
			names.append(item.get_display_name())
	status_label.text = "PRENSA %d/%d\n%s" % [names.size(), slots.size(), ", ".join(names)]
