class_name RecipeBook
extends StaticBody3D

@export var recipes: Array[RecipeData] = []

@onready var menu: Control = %RecipeBookMenu
@onready var recipe_text: RichTextLabel = %RecipeText

var _active_player: PharmacyPlayer

func _ready() -> void:
	%Interactable.interacted.connect(_on_interacted)
	%CloseButton.pressed.connect(close_book)
	_build_recipe_text()
	menu.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if menu.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_book()
		get_viewport().set_input_as_handled()

func _on_interacted(player: PharmacyPlayer) -> void:
	_active_player = player
	_active_player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.visible = true

func close_book() -> void:
	menu.visible = false
	if _active_player != null:
		_active_player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_active_player = null

func _build_recipe_text() -> void:
	var cauldron_entries: Array[String] = []
	var press_entries: Array[String] = []
	for recipe: RecipeData in recipes:
		if recipe == null or recipe.output_item == null:
			continue
		var entry := _format_recipe(recipe)
		if recipe.station_type == RecipeData.StationType.PRESS:
			press_entries.append(entry)
		elif recipe.station_type == RecipeData.StationType.CAULDRON:
			cauldron_entries.append(entry)
	recipe_text.text = (
		"[font_size=24][color=#73e6ad]CALDEIRA[/color][/font_size]\n"
		+ "Insira os ingredientes, pressione E e alterne Q/R seguindo a direção indicada. Mantenha a estabilidade até o fim.\n\n"
		+ "\n\n".join(cauldron_entries)
		+ "\n\n[font_size=24][color=#d99bea]PRENSA[/color][/font_size]\n"
		+ "Insira os ingredientes, pressione E para iniciar e complete quatro prensagens com E.\n\n"
		+ "\n\n".join(press_entries)
	)

func _format_recipe(recipe: RecipeData) -> String:
	var ingredient_names: Array[String] = []
	for ingredient: ItemData in recipe.required_ingredients:
		if ingredient != null:
			ingredient_names.append(ingredient.display_name)
	return "[b]%s[/b]\n%s  →  [color=#ffe080]%s[/color]" % [
		recipe.display_name,
		" + ".join(ingredient_names),
		recipe.output_item.display_name,
	]
