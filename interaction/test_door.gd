extends Node3D

@export var open_angle: float = 95.0
@export var animation_duration: float = 0.35

var _is_open: bool = false
var _is_moving: bool = false


func _ready() -> void:
	$Interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: PharmacyPlayer) -> void:
	if _is_moving:
		return
	_is_open = not _is_open
	_is_moving = true
	$Interactable.enabled = false
	var target_angle := open_angle if _is_open else 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation_degrees:y", target_angle, animation_duration)
	await tween.finished
	_is_moving = false
	$Interactable.enabled = true
	$Interactable.interaction_text = "Fechar porta" if _is_open else "Abrir porta"
