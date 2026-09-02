class_name RecipeData
extends Resource

enum StationType {
	CAULDRON,
	PRESS,
	MIXER,
	HEATER,
	PACKAGING,
}

@export var id: StringName
@export var display_name: String = "Receita"
@export var required_ingredients: Array[ItemData] = []
@export var output_item: ItemData
@export_range(0.1, 60.0, 0.1) var craft_time: float = 3.0
@export_range(0.0, 1.0, 0.01) var failure_chance: float = 0.0
@export var station_type: StationType = StationType.CAULDRON


func matches(items: Array[WorldItem]) -> bool:
	var present_ids: Array[StringName] = []
	for item: WorldItem in items:
		if item != null and item.item_data != null:
			present_ids.append(item.item_data.id)
	if present_ids.size() != required_ingredients.size():
		return false
	for required: ItemData in required_ingredients:
		var found_index := present_ids.find(required.id)
		if found_index < 0:
			return false
		present_ids.remove_at(found_index)
	return present_ids.is_empty()
