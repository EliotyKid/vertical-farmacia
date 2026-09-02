class_name CraftingExplosion
extends Node3D

@export_range(1.0, 15.0, 0.5) var knockback_strength: float = 10.0

@onready var blast_mesh: MeshInstance3D = %BlastMesh
@onready var blast_light: OmniLight3D = %BlastLight
@onready var blast_area: Area3D = %BlastArea
@onready var smoke_mesh: MeshInstance3D = %SmokeMesh


func _ready() -> void:
	blast_mesh.scale = Vector3.ONE * 0.15
	smoke_mesh.scale = Vector3.ONE * 0.25
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(blast_mesh, "scale", Vector3.ONE * 3.8, 0.42)
	tween.tween_property(blast_light, "light_energy", 0.0, 0.55)
	tween.tween_property(smoke_mesh, "scale", Vector3.ONE * 2.7, 0.8).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(smoke_mesh, "position:y", 1.2, 0.8)
	await get_tree().physics_frame
	for body: Node3D in blast_area.get_overlapping_bodies():
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position, knockback_strength)
	await tween.finished
	queue_free()
