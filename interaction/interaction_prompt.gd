extends PanelContainer

@onready var prompt_label: Label = %PromptLabel

var _was_visible: bool = false
var _pulse_tween: Tween


func _ready() -> void:
	visible = false
	call_deferred("_connect_controller")


func _connect_controller() -> void:
	var controller := get_tree().get_first_node_in_group("interaction_controller")
	if controller == null:
		return
	controller.prompt_changed.connect(_on_prompt_changed)


func _on_prompt_changed(should_show: bool, interaction_text: String) -> void:
	visible = should_show
	prompt_label.text = "[E] %s" % interaction_text
	if should_show and not _was_visible:
		_play_appearance()
	_was_visible = should_show


func _play_appearance() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	_pulse_tween = create_tween().set_parallel(true)
	_pulse_tween.tween_property(self, "modulate:a", 1.0, 0.12)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
