class_name ShelfSlot
extends Area3D

@onready var item_marker: Marker3D = %ItemMarker
@onready var interactable: InteractableComponent = %Interactable

var shelf: PharmacyShelf
var stored_item: WorldItem
var slot_index: int = -1

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func setup(owner_shelf: PharmacyShelf, index: int) -> void:
	shelf = owner_shelf
	slot_index = index

func can_player_interact(player: PharmacyPlayer) -> bool:
	if shelf == null:
		return false
	var carry := player.get_node_or_null("CarryController") as CarryController
	if carry == null:
		return false
	if carry.current_item != null:
		return stored_item == null
	return stored_item != null

func get_contextual_interaction_text() -> String:
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	var carry := player.get_node_or_null("CarryController") as CarryController if player != null else null
	if carry != null and carry.current_item != null:
		if not shelf.accepts_item(carry.current_item):
			return "Item incompatível com %s" % shelf.storage_name
		return "Colocar %s neste espaço" % carry.current_item.get_display_name()
	if stored_item != null:
		return "Retirar %s" % stored_item.get_display_name()
	return "Espaço vazio"

func _on_interacted(player: PharmacyPlayer) -> void:
	if shelf == null:
		return
	var carry := player.get_node_or_null("CarryController") as CarryController
	if carry == null:
		return
	if carry.current_item != null:
		shelf.store_in_slot(self, carry)
	else:
		shelf.retrieve_from_slot(self, carry)
