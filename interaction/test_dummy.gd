extends StaticBody3D

@onready var label: Label3D = %Label
var _interaction_count: int = 0


func _ready() -> void:
	$Interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: PharmacyPlayer) -> void:
	_interaction_count += 1
	label.text = "Interações: %d" % _interaction_count
