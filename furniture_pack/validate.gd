extends SceneTree
var failures: Array = []
var report: Array = []

func _initialize() -> void:
	call_deferred("validate")

func inspect(node: Node, record: Dictionary, stats: Dictionary) -> void:
	if node is Node3D and node != node.owner and node.scale != Vector3.ONE:
		# Only decorative ellipsoids / oval rings use local scaling.
		if node is CollisionShape3D:failures.append(record.id+": scaled collision")
	if node is MeshInstance3D:
		stats.meshes += 1
		if node.material_override == null:failures.append(record.id+": missing material")
		for s in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for p in verts:
				if not p.is_finite():failures.append(record.id+": non-finite mesh vertex")
			if verts.is_empty():failures.append(record.id+": empty mesh")
	if node is StaticBody3D:
		if node.collision_layer != 1:failures.append(record.id+": wrong collision layer")
	if node is CollisionShape3D:
		stats.colliders += 1
		if node.shape == null or node.disabled:failures.append(record.id+": invalid collider")
	for child in node.get_children():inspect(child,record,stats)

func validate() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://furniture_pack/catalog.json"))
	var routes := {"dining_table":0.0,"dining_chair":0.0,"bed":0.0,"desk":-.25,"garden_bench":0.0}
	var capsule := CapsuleShape3D.new()
	capsule.radius = .096
	capsule.height = .288
	for record in data.items:
		var n: Node3D = load(record.scene).instantiate()
		root.add_child(n)
		await physics_frame
		await physics_frame
		var stats := {"id":record.id,"meshes":0,"colliders":0,"cat_route_samples":0}
		inspect(n,record,stats)
		if n.scale != Vector3.ONE or n.position != Vector3.ZERO:failures.append(record.id+": root is not identity")
		if absf(record.bounds_min_m[1])>.001:failures.append(record.id+": not floor grounded")
		if stats.colliders != record.collision_shapes:failures.append(record.id+": collider count mismatch")
		if routes.has(record.id):
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			query.margin = .002
			# Sweep through the full centre corridor with the actual standing cat capsule.
			var depth: float = record.dimensions_m[2]+.6
			for i in range(41):
				query.transform = Transform3D(Basis.IDENTITY,Vector3(routes[record.id],.149,lerpf(-depth*.5,depth*.5,i/40.0)))
				if not n.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
					failures.append(record.id+": blocked cat corridor at sample "+str(i))
				stats.cat_route_samples += 1
		report.append(stats)
		n.free()
		await physics_frame
	var output := {"items":report,"failures":failures,"capsule_m":{"height":.288,"radius":.096}}
	FileAccess.open("res://furniture_pack/validation.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("FURNITURE_VALIDATE ",JSON.stringify({"scenes":report.size(),"cat_corridor_samples":205,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
