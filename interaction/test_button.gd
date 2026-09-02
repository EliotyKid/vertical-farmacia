extends StaticBody3D

@onready var button_mesh: MeshInstance3D = %ButtonMesh
@onready var status_label: Label3D = %StatusLabel

var _is_active: bool = false


func _ready() -> void:
	$Interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: PharmacyPlayer) -> void:
	_is_active = not _is_active
	status_label.text = "ON" if _is_active else "OFF"
	var material := button_mesh.get_active_material(0) as StandardMaterial3D
	material.albedo_color = Color("58c878") if _is_active else Color("c34f4f")
