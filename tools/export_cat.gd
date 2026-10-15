extends SceneTree
func _initialize() -> void:
	call_deferred("export_model")
func export_model() -> void:
	var cat = load("res://scenes/calico.tscn").instantiate()
	root.add_child(cat)
	cat.animate = false
	cat.skeleton.reset_bone_poses()
	var body: MeshInstance3D = cat.get_node("AnatomicalMesh")
	var mesh: ArrayMesh = body.mesh.duplicate()
	var coat := StandardMaterial3D.new()
	coat.vertex_color_use_as_albedo = true
	coat.albedo_color = Color.WHITE
	coat.roughness = .88
	mesh.surface_set_material(0,coat)
	body.mesh = mesh
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_scene(cat,state)
	if result==OK:result = document.write_to_filesystem(state,"res://assets/models/calico_rigged.glb")
	print("CALICO_GLB_EXPORT ",result)
	cat.free()
	quit(0 if result==OK else 1)
