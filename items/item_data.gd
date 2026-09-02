class_name ItemData
extends Resource

enum Category {
	MEDICINE,
	INGREDIENT,
	CRAFTED_PRODUCT,
	MISC,
}

@export var id: StringName
@export var display_name: String = "Item"
@export var category: Category = Category.MISC
@export_range(0, 10000, 1) var buy_price: int = 0
@export_range(0, 10000, 1) var sell_price: int = 0
@export_range(1, 99, 1) var stack_size: int = 1
@export var tags: Array[StringName] = []
@export var placeholder_color: Color = Color.WHITE
