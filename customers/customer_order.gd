class_name CustomerOrder
extends Resource

@export var requested_item: ItemData
@export_range(1, 99, 1) var quantity: int = 1
@export_range(0, 10000, 1) var reward: int = 0


func matches(item: WorldItem) -> bool:
	return item != null and item.item_data != null and requested_item != null and item.item_data.id == requested_item.id
