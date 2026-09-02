class_name PharmacyShelf
extends StaticBody3D

signal item_placed(item: WorldItem, slot_index: int)
signal item_retrieved(item: WorldItem, slot_index: int)

@export var accepts_categories: Array[ItemData.Category] = [ItemData.Category.MEDICINE, ItemData.Category.CRAFTED_PRODUCT]
@export var storage_name: String = "prateleira"

@onready var interactable: InteractableComponent = $Interactable
@onready var status_label: Label3D = %StatusLabel
@onready var slots: Array[Marker3D] = [
	%Slot1,
	%Slot2,
	%Slot3,
	%Slot4,
	%Slot5,
	%Slot6,
]

var stored_items: Array[WorldItem] = []


func _ready() -> void:
	add_to_group("storage_feedback")
	stored_items.resize(slots.size())
	interactable.interacted.connect(_on_interacted)
	_update_status()


func can_player_interact(player: PharmacyPlayer) -> bool:
	var carry := player.get_node_or_null("CarryController") as CarryController
	if carry == null:
		return false
	if carry.current_item != null:
		return true
	return _last_occupied_slot() >= 0


func get_contextual_interaction_text() -> String:
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	if player == null:
		return "Usar %s" % storage_name
	var carry := player.get_node_or_null("CarryController") as CarryController
	if carry != null and carry.current_item != null:
		if not _accepts_item(carry.current_item):
			return "Item incompatível com %s" % storage_name
		if _first_empty_slot() < 0:
			return "%s cheio" % storage_name.capitalize()
		return "Guardar %s" % carry.current_item.get_display_name()
	var index := _last_occupied_slot()
	return "Retirar %s" % stored_items[index].get_display_name() if index >= 0 else "%s vazio" % storage_name.capitalize()


func _on_interacted(player: PharmacyPlayer) -> void:
	var carry := player.get_node_or_null("CarryController") as CarryController
	if carry == null:
		return
	if carry.current_item != null:
		_store_from(carry)
	else:
		_retrieve_to(carry)


func _store_from(carry: CarryController) -> void:
	var slot_index := _first_empty_slot()
	if slot_index < 0 or not _accepts_item(carry.current_item):
		return
	var item := carry.place_current_item(self, slots[slot_index].global_transform)
	if item == null:
		return
	stored_items[slot_index] = item
	item_placed.emit(item, slot_index)
	_update_status()


func _retrieve_to(carry: CarryController) -> void:
	var slot_index := _last_occupied_slot()
	if slot_index < 0:
		return
	var item := stored_items[slot_index]
	stored_items[slot_index] = null
	item.set_stored(false)
	if carry.try_pick_up(item):
		item_retrieved.emit(item, slot_index)
	else:
		stored_items[slot_index] = item
		item.set_stored(true)
	_update_status()


func _accepts_item(item: WorldItem) -> bool:
	return item.item_data != null and item.item_data.category in accepts_categories


func _first_empty_slot() -> int:
	for index: int in range(stored_items.size()):
		if stored_items[index] == null:
			return index
	return -1


func _last_occupied_slot() -> int:
	for index: int in range(stored_items.size() - 1, -1, -1):
		if stored_items[index] != null:
			return index
	return -1


func _update_status() -> void:
	var occupied := 0
	for item: WorldItem in stored_items:
		if item != null:
			occupied += 1
	status_label.text = "%s\n%d / %d" % [storage_name.to_upper(), occupied, slots.size()]
