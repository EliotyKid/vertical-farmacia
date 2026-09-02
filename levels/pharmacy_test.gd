extends Node3D

const FRONT_COLOR := Color("c9d7e4")
const LAB_COLOR := Color("b8c8bb")
const WALL_COLOR := Color("e8e5dc")
const FIXTURE_COLOR := Color("61707d")
const COUNTER_COLOR := Color("477b78")
const DELIVERY_COLOR := Color("d6a44b")


func _ready() -> void:
	_build_environment()
	_build_pharmacy()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("87a4ba")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

func _build_pharmacy() -> void:
	var architecture := Node3D.new()
	architecture.name = "Architecture"
	add_child(architecture)

	_add_block(architecture, "FrontFloor", Vector3(0.0, -0.25, 5.0), Vector3(16.0, 0.5, 10.0), FRONT_COLOR)
	_add_block(architecture, "LabFloor", Vector3(0.0, -0.25, -5.0), Vector3(16.0, 0.5, 10.0), LAB_COLOR)
	_add_block(architecture, "LeftWall", Vector3(-8.0, 2.0, 0.0), Vector3(0.35, 4.5, 20.0), WALL_COLOR)
	_add_block(architecture, "RightWall", Vector3(8.0, 2.0, 0.0), Vector3(0.35, 4.5, 20.0), WALL_COLOR)
	_add_block(architecture, "BackWall", Vector3(0.0, 2.0, -10.0), Vector3(16.0, 4.5, 0.35), WALL_COLOR)
	_add_block(architecture, "FrontWallLeft", Vector3(-5.0, 2.0, 10.0), Vector3(6.0, 4.5, 0.35), WALL_COLOR)
	_add_block(architecture, "FrontWallRight", Vector3(5.0, 2.0, 10.0), Vector3(6.0, 4.5, 0.35), WALL_COLOR)
	_add_block(architecture, "DividerLeft", Vector3(-5.25, 1.5, 0.0), Vector3(5.5, 3.5, 0.3), WALL_COLOR)
	_add_block(architecture, "DividerRight", Vector3(5.25, 1.5, 0.0), Vector3(5.5, 3.5, 0.3), WALL_COLOR)

	var fixtures := Node3D.new()
	fixtures.name = "Fixtures"
	add_child(fixtures)
	_add_block(fixtures, "ServiceCounter", Vector3(0.0, 0.65, 2.2), Vector3(5.5, 1.3, 1.1), COUNTER_COLOR)
	_add_block(fixtures, "LabWorkbench", Vector3(-4.9, 0.8, -6.8), Vector3(4.5, 1.6, 1.3), FIXTURE_COLOR)
	_add_block(fixtures, "DeliveryArea", Vector3(-5.4, 0.03, 8.0), Vector3(3.5, 0.06, 2.5), DELIVERY_COLOR, false)

	_add_area_label("PHARMACY", Vector3(0.0, 3.4, 0.25), 96)
	_add_area_label("LABORATORY", Vector3(0.0, 3.4, -9.78), 82)
	_add_area_label("DELIVERY", Vector3(-5.4, 0.1, 8.0), 42, Vector3(-90.0, 0.0, 0.0))


func _add_block(parent: Node3D, node_name: String, location: Vector3, size: Vector3, color: Color, collision: bool = true) -> void:
	var body: Node3D
	if collision:
		body = StaticBody3D.new()
	else:
		body = Node3D.new()
	body.name = node_name
	body.position = location
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	if collision:
		var collision_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision_shape.shape = shape
		body.add_child(collision_shape)


func _add_area_label(text: String, location: Vector3, font_size: int, rotation := Vector3.ZERO) -> void:
	var label := Label3D.new()
	label.name = text.to_pascal_case() + "Label"
	label.text = text
	label.position = location
	label.rotation_degrees = rotation
	label.font_size = font_size
	label.modulate = Color("27343b")
	label.outline_size = 8
	label.outline_modulate = Color(1.0, 1.0, 1.0, 0.8)
	add_child(label)
