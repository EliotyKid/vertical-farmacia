class_name StationInput
extends StaticBody3D

signal ingredient_inserted(item: WorldItem, slot_index: int)
signal ingredient_removed(item: WorldItem, slot_index: int)
signal craft_started(recipe: RecipeData)
signal craft_completed(recipe: RecipeData, output: WorldItem)
signal craft_failed()
signal explosion_triggered(explosion: CraftingExplosion)

@export var recipes: Array[RecipeData] = []
@export var world_item_scene: PackedScene
@export var explosion_scene: PackedScene
@export_range(0.5, 10.0, 0.5) var failure_warning_time: float = 1.5
@export_range(0.5, 15.0, 0.5) var cooldown_time: float = 3.0

@onready var status_label: Label3D = %StatusLabel
@onready var progress_mesh: MeshInstance3D = %ProgressMesh
@onready var slots: Array[Marker3D] = [%InputSlot1, %InputSlot2, %InputSlot3]

var ingredients: Array[WorldItem] = []
var is_crafting: bool = false
var active_recipe: RecipeData
var _craft_remaining: float = 0.0
var _failure_pending: bool = false
var _cooldown_remaining: float = 0.0


func _ready() -> void:
	add_to_group("crafting_station")
	ingredients.resize(slots.size())
	$Interactable.interacted.connect(_on_interacted)
	_update_status()


func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
		status_label.text = "CALDEIRA EM RECUPERAÇÃO\n%.1fs" % _cooldown_remaining
		_set_progress(_cooldown_remaining / cooldown_time, Color("e27954"))
		if _cooldown_remaining <= 0.0:
			_update_status()
		return
	if not is_crafting:
		return
	_craft_remaining = maxf(_craft_remaining - delta, 0.0)
	if _failure_pending:
		status_label.text = "MISTURA INSTÁVEL!\n%.1fs" % _craft_remaining
		_set_progress(_craft_remaining / failure_warning_time, Color("ff493d"))
	else:
		status_label.text = "FABRICANDO %s\n%.1fs" % [active_recipe.display_name.to_upper(), _craft_remaining]
		_set_progress(_craft_remaining / active_recipe.craft_time, Color("55e79c"))
	if _craft_remaining <= 0.0:
		if _failure_pending:
			_complete_failure()
		else:
			_complete_craft()


func can_player_interact(player: PharmacyPlayer) -> bool:
	if is_crafting or _cooldown_remaining > 0.0:
		return false
	var carry := player.get_node_or_null("CarryController") as CarryController
	if carry == null:
		return false
	if carry.current_item != null:
		return true
	return _last_occupied_slot() >= 0


func get_contextual_interaction_text() -> String:
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	var carry := player.get_node_or_null("CarryController") as CarryController if player != null else null
	if carry != null and carry.current_item != null:
		if carry.current_item.item_data == null or carry.current_item.item_data.category != ItemData.Category.INGREDIENT:
			return "A caldeira aceita apenas ingredientes"
		if _first_empty_slot() < 0:
			return "Entrada da caldeira cheia"
		return "Inserir %s" % carry.current_item.get_display_name()
	var matched_recipe := _find_matching_recipe()
	if matched_recipe != null:
		return "Fabricar %s" % matched_recipe.display_name
	if _ingredient_count() >= 2:
		return "Testar mistura instável"
	var index := _last_occupied_slot()
	return "Retirar %s" % ingredients[index].get_display_name() if index >= 0 else "Caldeira vazia"


func _on_interacted(player: PharmacyPlayer) -> void:
	var carry := player.get_node_or_null("CarryController") as CarryController
	if carry == null:
		return
	if carry.current_item != null:
		_insert_from(carry)
	else:
		var matched_recipe := _find_matching_recipe()
		if matched_recipe != null:
			_start_craft(matched_recipe)
		elif _ingredient_count() >= 2:
			_start_failure()
		else:
			_remove_to(carry)


func _insert_from(carry: CarryController) -> void:
	var item := carry.current_item
	var slot_index := _first_empty_slot()
	if item == null or item.item_data == null or item.item_data.category != ItemData.Category.INGREDIENT or slot_index < 0:
		return
	item = carry.place_current_item(self, slots[slot_index].global_transform)
	ingredients[slot_index] = item
	ingredient_inserted.emit(item, slot_index)
	_update_status()


func _remove_to(carry: CarryController) -> void:
	var slot_index := _last_occupied_slot()
	if slot_index < 0:
		return
	var item := ingredients[slot_index]
	ingredients[slot_index] = null
	item.set_stored(false)
	if carry.try_pick_up(item):
		ingredient_removed.emit(item, slot_index)
	else:
		ingredients[slot_index] = item
		item.set_stored(true)
	_update_status()


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


func _find_matching_recipe() -> RecipeData:
	for recipe: RecipeData in recipes:
		if recipe != null and recipe.station_type == RecipeData.StationType.CAULDRON and recipe.matches(ingredients):
			return recipe
	return null


func _start_craft(recipe: RecipeData) -> void:
	if is_crafting or recipe == null:
		return
	is_crafting = true
	active_recipe = recipe
	_craft_remaining = recipe.craft_time
	for item: WorldItem in ingredients:
		if item != null:
			item.visible = false
	craft_started.emit(recipe)


func _start_failure() -> void:
	if is_crafting or _ingredient_count() < 2:
		return
	is_crafting = true
	_failure_pending = true
	active_recipe = null
	_craft_remaining = failure_warning_time
	for item: WorldItem in ingredients:
		if item != null:
			item.visible = false


func _complete_craft() -> void:
	var completed_recipe := active_recipe
	for index: int in range(ingredients.size()):
		if ingredients[index] != null:
			ingredients[index].queue_free()
			ingredients[index] = null
	is_crafting = false
	_failure_pending = false
	active_recipe = null
	_craft_remaining = 0.0
	var output := _spawn_output(completed_recipe.output_item)
	craft_completed.emit(completed_recipe, output)
	_update_status()


func _complete_failure() -> void:
	for index: int in range(ingredients.size()):
		if ingredients[index] != null:
			ingredients[index].queue_free()
			ingredients[index] = null
	is_crafting = false
	_failure_pending = false
	active_recipe = null
	_craft_remaining = 0.0
	_cooldown_remaining = cooldown_time
	var explosion := _spawn_explosion()
	craft_failed.emit()
	if explosion != null:
		explosion_triggered.emit(explosion)


func _spawn_explosion() -> CraftingExplosion:
	if explosion_scene == null:
		push_error("Caldeira sem cena de explosão configurada.")
		return null
	var explosion := explosion_scene.instantiate() as CraftingExplosion
	get_parent().add_child(explosion)
	explosion.global_position = global_position + Vector3.UP * 0.7
	return explosion


func _ingredient_count() -> int:
	var count := 0
	for item: WorldItem in ingredients:
		if item != null:
			count += 1
	return count


func _spawn_output(item_data: ItemData) -> WorldItem:
	if world_item_scene == null or item_data == null:
		push_error("Caldeira sem cena de item ou produto de saída.")
		return null
	var output := world_item_scene.instantiate() as WorldItem
	output.item_data = item_data
	get_parent().add_child(output)
	output.global_position = %OutputMarker.global_position
	output.mark_current_transform_safe()
	return output


func _update_status() -> void:
	var names: Array[String] = []
	for item: WorldItem in ingredients:
		if item != null:
			names.append(item.get_display_name())
	status_label.text = "CALDEIRA %d/%d\n%s" % [names.size(), slots.size(), ", ".join(names)]
	_set_progress(0.0, Color("55e79c"))


func _set_progress(value: float, color: Color) -> void:
	if progress_mesh == null:
		return
	progress_mesh.visible = value > 0.0
	progress_mesh.scale.x = maxf(value, 0.01)
	progress_mesh.position.x = -0.65 * (1.0 - value)
	var material := progress_mesh.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = color
		material.emission = color
