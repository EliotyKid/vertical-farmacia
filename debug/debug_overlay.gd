extends CanvasLayer

@onready var panel: PanelContainer = %Panel
@onready var fps_label: Label = %FPSLabel
@onready var carried_item_label: Label = %CarriedItemLabel
@onready var target_label: Label = %TargetLabel

func _ready() -> void:
	panel.visible = false
	call_deferred("_connect_sources")

func _process(_delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if Input.is_action_just_pressed("debug_toggle"):
		panel.visible = not panel.visible

func _connect_sources() -> void:
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	if player != null:
		var carry := player.get_node_or_null("CarryController") as CarryController
		if carry != null:
			carry.carried_item_changed.connect(_on_carried_item_changed)
			_on_carried_item_changed(carry.current_item)
	var controller := get_tree().get_first_node_in_group("interaction_controller") as InteractionController
	if controller != null:
		controller.target_changed.connect(_on_target_changed)

func _on_carried_item_changed(item: WorldItem) -> void:
	carried_item_label.text = "Carregando: %s" % (item.get_display_name() if item != null else "nada")

func _on_target_changed(target: Node) -> void:
	target_label.text = "Alvo: %s" % (target.get_parent().name if target != null else "nenhum")
