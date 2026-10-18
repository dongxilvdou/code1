extends SceneTree
var failures: Array[String] = []
func expect(condition: bool, description: String) -> void:
	if not condition:failures.append(description)

func validate_imported(cat: Node3D) -> void:
	var skeleton: Skeleton3D = cat.get("skeleton")
	var triangles := 0
	var vertices := 0
	var maximum_weight_error := 0.0
	var textured_materials := 0
	expect(skeleton.get_bone_count()==39,"Imported skeleton count")
	for mesh in cat.get("visuals").find_children("*","MeshInstance3D",true,false):
		var skin: Skin = mesh.skin
		expect(skin!=null,"Imported skin missing")
		if skin==null:continue
		for bind in range(skin.get_bind_count()):
			var name: StringName = skin.get_bind_name(bind)
			var index := skeleton.find_bone(name) if not name.is_empty() else skin.get_bind_bone(bind)
			expect(index>=0,"Unknown skin bind")
			if index>=0:expect((skeleton.get_bone_global_rest(index)*skin.get_bind_pose(bind)).is_equal_approx(Transform3D.IDENTITY),"Incorrect imported inverse bind")
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			vertices += points.size()
			triangles += arrays[Mesh.ARRAY_INDEX].size()/3
			expect(arrays[Mesh.ARRAY_TEX_UV].size()==points.size(),"Imported UVs missing")
			var stride := weights.size()/points.size()
			for i in range(points.size()):
				var total := 0.0
				for j in range(stride):
					total += weights[i*stride+j]
					expect(bones[i*stride+j]>=0 and bones[i*stride+j]<skin.get_bind_count(),"Imported vertex joint out of range")
				maximum_weight_error = maxf(maximum_weight_error,absf(total-1))
			var material: Material = mesh.get_active_material(surface)
			if material is StandardMaterial3D and material.albedo_texture!=null:textured_materials += 1
	expect(maximum_weight_error<.0001,"Imported vertex weights not normalized")
	expect(triangles==8646,"Supplied cat topology unexpectedly changed")
	expect(textured_materials>0,"Supplied fur texture absent")
	for state in ["idle","walk","run","crouch","jump","stretch","sit","tailwag","meow"]:
		expect(cat.get("clips").has(state),"Missing imported action "+state)
		var player: AnimationPlayer = cat.get("animation_player")
		player.play(cat.get("clips")[state],0)
		player.advance(0)
		for phase in [.0,.25,.5,.75]:
			player.seek(player.current_animation_length*phase,true)
			skeleton.force_update_all_bone_transforms()
			for bone in range(skeleton.get_bone_count()):
				var transform := skeleton.get_bone_global_pose(bone)
				expect(transform.origin.is_finite() and transform.basis.is_finite(),"Nonfinite pose in "+state)
	print("IMPORTED_CAT_VALIDATE ",JSON.stringify({"triangles":triangles,"vertices":vertices,"bones":skeleton.get_bone_count(),"clips":9,"maximum_weight_error":maximum_weight_error,"failures":failures}))
	cat.free()
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	call_deferred("validate")
func validate() -> void:
	var cat = load("res://scenes/calico.tscn").instantiate()
	root.add_child(cat)
	cat.animate = false
	if cat.get_script().resource_path.ends_with("imported_cat.gd"):
		validate_imported(cat)
		return
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
	expect(triangles<80000 and triangles>30000,"Realtime triangle budget outside range")
	expect(body.mesh.get_surface_count()==3,"Atlas material count changed")
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
	for pose in ["idle","walk","run","crouch","jump","stretch","sit","tailwag"]:
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
	expect(player.get_animation_list().size()==8,"Animation clips missing")
	for clip in ["idle","walk","run","jump","sit","tailwag"]:
		expect(player.has_animation("poses/"+clip),"Missing clip "+clip)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	state.handle_binary_image_mode = GLTFState.HANDLE_BINARY_IMAGE_MODE_EMBED_AS_UNCOMPRESSED
	var glb_result := document.append_from_file("res://assets/models/calico_rigged.glb",state)
	expect(glb_result==OK,"GLB round trip failed")
	if glb_result==OK:
		expect(state.get_animations().size()==8,"GLB animation clips were lost")
		expect(state.get_materials().size()==3,"GLB atlas materials were lost")
		var imported := document.generate_scene(state)
		expect(imported.find_children("*","Skeleton3D",true,false).size()==1,"GLB does not contain the skeleton")
		root.add_child(imported)
		var imported_rig: Skeleton3D = imported.find_children("*","Skeleton3D",true,false)[0]
		expect(imported_rig.get_bone_count()==47,"Blender changed the joint count")
		var imported_player: AnimationPlayer = imported.find_children("*","AnimationPlayer",true,false)[0]
		for clip in imported_player.get_animation_list():
			imported_player.play(clip)
			imported_player.advance(.25)
			imported_rig.force_update_all_bone_transforms()
			for joint in range(imported_rig.get_bone_count()):
				var point := imported_rig.get_bone_global_pose(joint).origin
				expect(point.is_finite() and point.length()<1.2,"GLB animated joint escaped bounds: "+clip)
		imported.free()
	var report := {"triangles":triangles,"vertices":vertex_count,"bones":bone_count,"animation_clips":8,"weight_error":weight_error,"weight_tolerance":weight_tolerance,"pose_samples":samples,"minimum_paw_y":minimum_paw_y,"glb_valid":glb_result==OK,"failures":failures}
	print("CALICO_RIG_VALIDATE ",JSON.stringify(report))
	var file := FileAccess.open("res://assets/models/rig_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	cat.free()
	quit(0 if failures.is_empty() else 1)
