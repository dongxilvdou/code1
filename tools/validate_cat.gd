extends SceneTree
var failures: Array[String] = []
func expect(condition: bool, description: String) -> void:
	if not condition:failures.append(description)
func _initialize() -> void:
	call_deferred("validate")
func validate() -> void:
	var cat = load("res://scenes/calico.tscn").instantiate()
	root.add_child(cat)
	cat.animate = false
	var skeleton: Skeleton3D = cat.skeleton
	var body: MeshInstance3D = cat.get_node("AnatomicalMesh")
	var bone_count := skeleton.get_bone_count()
	expect(bone_count==47,"Unexpected bone count")
	expect(body.skin.get_bind_count()==bone_count,"Bind count mismatch")
	var triangles := 0
	var vertex_count := 0
	var weight_error := 0.0
	for surface in range(body.mesh.get_surface_count()):
		var arrays: Array = body.mesh.surface_get_arrays(surface)
		vertex_count += arrays[Mesh.ARRAY_VERTEX].size()
		triangles += arrays[Mesh.ARRAY_INDEX].size()/3
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
			var total := 0.0
			for j in range(4):
				total += weights[i*4+j]
				if joints[i*4+j]<0 or joints[i*4+j]>=bone_count:failures.append("Invalid joint index")
			weight_error = maxf(weight_error,absf(total-1))
	# ArrayMesh packs four weights into 16-bit UNORM values; allow its known
	# storage quantization, while the source generator checks float normalization.
	var weight_tolerance := 4.0/65535.0+0.0000001
	expect(weight_error<=weight_tolerance,"Weights exceed GPU quantization tolerance")
	expect(triangles>104532,"Face count did not double")
	for i in range(bone_count):
		var bind := skeleton.get_bone_global_rest(i)*body.skin.get_bind_pose(i)
		expect(bind.origin.length()<.00001,"Incorrect inverse bind for "+str(i))
		expect(skeleton.get_bone_parent(i)<i,"Cyclic or unordered bone hierarchy")
	var arrays: Array = body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var minimum_paw_y := 1.0
	var samples := 0
	for pose in ["idle","walk","run","crouch","jump","stretch"]:
		for frame in range(16):
			cat.pose_model(pose,frame/16.0*TAU,frame/16.0,1.0 if pose in ["walk","run"] else 0.0,1.0 if pose=="crouch" else 0.0)
			var transforms: Array[Transform3D] = []
			for i in range(bone_count):transforms.append(skeleton.get_bone_global_pose(i)*body.skin.get_bind_pose(i))
			for index in range(0,vertices.size(),23):
				var p := Vector3.ZERO
				for j in range(4):p += (transforms[bones[index*4+j]]*vertices[index])*weights[index*4+j]
				if not p.is_finite():failures.append("Non-finite deformation in "+pose)
				expect(p.length()<1.2,"Exploded skin in "+pose)
				if vertices[index].y<.030:minimum_paw_y = minf(minimum_paw_y,p.y)
				samples += 1
	expect(minimum_paw_y>-.010,"Paws sink through the floor: "+str(minimum_paw_y))
	var player: AnimationPlayer = cat.get_node("AnimationPlayer")
	expect(player.get_animation_list().size()==6,"Animation clips missing")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var glb_result := document.append_from_file("res://assets/models/calico_rigged.glb",state)
	expect(glb_result==OK,"GLB round trip failed")
	if glb_result==OK:
		var imported := document.generate_scene(state)
		expect(imported.find_children("*","Skeleton3D",true,false).size()==1,"GLB does not contain the skeleton")
		imported.free()
	var report := {"triangles":triangles,"vertices":vertex_count,"bones":bone_count,"animation_clips":6,"weight_error":weight_error,"weight_tolerance":weight_tolerance,"pose_samples":samples,"minimum_paw_y":minimum_paw_y,"glb_valid":glb_result==OK,"failures":failures}
	print("CALICO_RIG_VALIDATE ",JSON.stringify(report))
	var file := FileAccess.open("res://assets/models/rig_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	cat.free()
	quit(0 if failures.is_empty() else 1)
