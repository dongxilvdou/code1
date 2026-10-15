extends RefCounted
## Shared mesh and material helpers for the current garden villa.
var root: Node3D
var mats := {}
var rng := RandomNumberGenerator.new()
var serial := 0

func materials() -> void:
	material("brass",Color(.40,.30,.16),"",1,.75,.29)
	material("terra",Color(.40,.19,.115),"",1,0,.9)
	var glow := material("glow",Color(1,.94,.83))
	glow.emission_enabled = true
	glow.emission = Color(1,.92,.78)
	glow.emission_energy_multiplier = 1.3

func attach(node: Node, parent: Node = null) -> void:
	if parent == null: parent = root
	parent.add_child(node)
	node.owner = root
	serial += 1
	if node.name == "" or str(node.name).begins_with("@"):
		node.name = "Detail_%04d" % serial

func material(key: String, color: Color, texture: String = "", scale_uv: float = 1.0, metal: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if texture != "":
		m.albedo_texture = load("res://assets/" + texture + ".png")
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * scale_uv
	mats[key] = m
	return m

func mesh_obj(mesh: Mesh, pos: Vector3, mat_key: String, parent: Node = null) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.position = pos
	obj.material_override = mats[mat_key]
	attach(obj,parent)
	return obj

func box(label: String, pos: Vector3, size: Vector3, mat_key: String, solid: bool = true, parent: Node = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var obj := mesh_obj(mesh,pos,mat_key,parent)
	obj.name = label + "_%04d" % serial
	if solid:
		var body := StaticBody3D.new()
		attach(body,obj)
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		attach(shape,body)
	return obj

func cylinder(pos: Vector3, radius: float, height: float, mat_key: String, top: float = -1.0, parent: Node = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 24
	return mesh_obj(mesh,pos,mat_key,parent)

func rod(a: Vector3, b: Vector3, radius: float, mat_key: String, parent: Node = null) -> MeshInstance3D:
	var obj := cylinder((a+b)*.5,radius,a.distance_to(b),mat_key,-1,parent)
	obj.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	return obj

func plaque(text: String, pos: Vector3, yaw: float = 0, size: int = 32, color: Color = Color(.76,.68,.47)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.rotation.y = yaw
	l.font_size = size
	l.pixel_size = .003
	l.modulate = color
	l.outline_size = 0
	attach(l)
	return l

