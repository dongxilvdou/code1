extends SceneTree
var triangles := 0
var vertices := 0
var mesh_count := 0
var skinned_meshes := 0
var bones := 0
func _initialize() -> void:
	var model = load("res://scenes/calico.tscn").instantiate()
	count(model)
	print("CALICO_MODEL_STATS ",JSON.stringify({"triangles":triangles,"vertices":vertices,"meshes":mesh_count,"skinned_meshes":skinned_meshes,"bones":bones}))
	model.free()
	quit()
func count(n: Node) -> void:
	if n is MeshInstance3D:
		mesh_count += 1
		if n.skin:skinned_meshes += 1
		for surface in range(n.mesh.get_surface_count()):
			var arrays: Array = n.mesh.surface_get_arrays(surface)
			vertices += arrays[Mesh.ARRAY_VERTEX].size()
			triangles += arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()/3
	if n is Skeleton3D:bones += n.get_bone_count()
	for c in n.get_children():count(c)
