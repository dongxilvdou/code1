extends Node3D
## Continuous anatomical mesh, weighted skeleton, planted paw inverse kinematics.
@export var animate := true
@export_enum("game", "idle", "walk", "run", "crouch", "jump", "stretch", "sit", "tailwag") var preview_pose := "game"
var gait := 0.0
var speed := 0.0
var crouching := false
var airborne := false
var vertical_speed := 0.0
var curious := 0.0
var legs: Array = []
var skeleton: Skeleton3D
var rig_data: Dictionary = {}
var rest_points: Array[Vector3] = []
var bone_ids := {}
var clock := 0.0
var motion_amount := 0.0
var low_amount := 0.0
var meow_time := 0.0
var previous_rotations: Array[Quaternion] = []
var previous_positions: Array[Vector3] = []
var last_state := ""
var transition_remaining := 0.0

func _ready() -> void:
	if not has_node("Skeleton3D"):build_model()
	configure_rig()
	scale = Vector3.ONE

func configure_rig() -> void:
	skeleton = get_node("Skeleton3D")
	rig_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/calico_anatomy.json"))
	legs = rig_data.legs
	rest_points.clear()
	for info in rig_data.bones:rest_points.append(vector(info.position))
	for i in range(skeleton.get_bone_count()):bone_ids[str(skeleton.get_bone_name(i))] = i

func vector(a: Array) -> Vector3:
	return Vector3(a[0],a[1],a[2])

func build_model() -> void:
	rig_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/calico_anatomy.json"))
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	var skin := Skin.new()
	skin.resource_name = "Calico_47_Bone_Skin"
	for i in range(rig_data.bones.size()):
		var info: Dictionary = rig_data.bones[i]
		skeleton.add_bone(info.name)
		skeleton.set_bone_parent(i,int(info.parent))
		var p := vector(info.position)
		var local := p
		if info.parent>=0:local -= vector(rig_data.bones[int(info.parent)].position)
		skeleton.set_bone_rest(i,Transform3D(Basis.IDENTITY,local))
		skin.add_bind(i,Transform3D(Basis.IDENTITY,-p))
	skeleton.reset_bone_poses()
	var f := FileAccess.open("res://assets/models/calico_anatomy.bin",FileAccess.READ)
	var bytes := f.get_buffer(f.get_length())
	var mesh := ArrayMesh.new()
	mesh.resource_name = "Calico_Continuous_Realtime"
	for data in rig_data.surfaces:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var raw := floats(bytes,data.positions)
		var verts := PackedVector3Array()
		verts.resize(data.vertices)
		for i in range(data.vertices):verts[i] = Vector3(raw[i*3],raw[i*3+1],raw[i*3+2])
		arrays[Mesh.ARRAY_VERTEX] = verts
		raw = floats(bytes,data.normals)
		var normals := PackedVector3Array()
		normals.resize(data.vertices)
		for i in range(data.vertices):normals[i] = Vector3(raw[i*3],raw[i*3+1],raw[i*3+2])
		arrays[Mesh.ARRAY_NORMAL] = normals
		raw = floats(bytes,data.uv)
		var uvs := PackedVector2Array()
		uvs.resize(data.vertices)
		for i in range(data.vertices):uvs[i] = Vector2(raw[i*2],raw[i*2+1])
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		if data.has("tangents"):arrays[Mesh.ARRAY_TANGENT] = floats(bytes,data.tangents)
		raw = floats(bytes,data.colors)
		var colors := PackedColorArray()
		colors.resize(data.vertices)
		for i in range(data.vertices):colors[i] = Color(raw[i*4],raw[i*4+1],raw[i*4+2],raw[i*4+3])
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_BONES] = bytes.slice(data.joints[0],data.joints[0]+data.joints[1]).to_int32_array()
		arrays[Mesh.ARRAY_WEIGHTS] = floats(bytes,data.weights)
		arrays[Mesh.ARRAY_INDEX] = bytes.slice(data.indices_data[0],data.indices_data[0]+data.indices_data[1]).to_int32_array()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_name(mesh.get_surface_count()-1,data.name)
		mesh.surface_set_material(mesh.get_surface_count()-1,make_material(data.name))
	mesh.custom_aabb = AABB(Vector3(-.20,-.12,-.50),Vector3(.4,.90,1.02))
	ResourceSaver.save(mesh,"res://assets/models/calico_high.res",ResourceSaver.FLAG_CHANGE_PATH)
	mesh.take_over_path("res://assets/models/calico_high.res")
	make_paw_meshes(mesh)
	var body := MeshInstance3D.new()
	body.name = "AnatomicalMesh"
	body.mesh = mesh
	body.skin = skin
	body.skeleton = NodePath("../Skeleton3D")
	body.layers = 2
	add_child(body)
	set_meta("model_stats",rig_data.stats)

func make_paw_meshes(mesh: ArrayMesh) -> void:
	var source: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	for side in [-1,1]:
		var kept := PackedInt32Array()
		for i in range(0,indices.size(),3):
			var valid := true
			for j in range(3):
				var p := vertices[indices[i+j]]
				if p.y>.10 or p.z>-.125 or p.x*side<0:valid = false
			if valid:
				for j in range(3):kept.append(indices[i+j])
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var remap := {}
		var used := PackedInt32Array()
		var compact_indices := PackedInt32Array()
		for old_index in kept:
			if not remap.has(old_index):
				remap[old_index] = used.size()
				used.append(old_index)
			compact_indices.append(remap[old_index])
		for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR]:
			var compact = source[channel].slice(0,0)
			for old_index in used:compact.append(source[channel][old_index])
			arrays[channel] = compact
		arrays[Mesh.ARRAY_INDEX] = compact_indices
		var paw := ArrayMesh.new()
		paw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		paw.surface_set_material(0,mesh.surface_get_material(0))
		ResourceSaver.save(paw,"res://assets/models/paw_%s.res" % ("left" if side<0 else "right"))

func floats(bytes: PackedByteArray, span: Array) -> PackedFloat32Array:
	return bytes.slice(span[0],span[0]+span[1]).to_float32_array()

func make_material(key: String) -> Material:
	if rig_data.get("version",2)>=3:
		var material := StandardMaterial3D.new()
		material.resource_name = "Calico_Atlas_"+key
		material.albedo_texture = load("res://assets/models/textures/calico_%s_basecolor.png" % key)
		material.normal_enabled = true
		material.normal_texture = load("res://assets/models/textures/calico_%s_normal.png" % key)
		material.normal_scale = .65
		material.roughness_texture = load("res://assets/models/textures/calico_%s_roughness.png" % key)
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.metallic_specular = .28 if key=="coat" else .5
		if key=="eyes":
			material.clearcoat_enabled = true
			material.clearcoat = .7
			material.clearcoat_roughness = .12
		if key=="features":material.cull_mode = BaseMaterial3D.CULL_DISABLED
		return material
	if key=="coat":
		var fur := ShaderMaterial.new()
		fur.resource_name = "Calico_Fur_Detail"
		fur.shader = load("res://shaders/cat_fur.gdshader")
		return fur
	var m := StandardMaterial3D.new()
	m.resource_name = "Calico_"+key
	var colors := {"lid":Color(.09,.074,.061),"eye":Color(.16,.19,.095),"iris":Color(.53,.45,.15),"pupil":Color(.013,.020,.016),"glint":Color(.86,.91,.82),"inner_ear":Color(.43,.245,.22),"whisker":Color(.77,.74,.66),"claw":Color(.48,.43,.35),"nose":Color(.30,.13,.12),"mouth":Color(.055,.030,.025)}
	m.albedo_color = colors.get(key,Color.WHITE)
	m.roughness = .82
	if key in ["eye","iris","pupil"]:
		m.roughness = .17
		m.clearcoat_enabled = true
		m.clearcoat = .9
		m.clearcoat_roughness = .06
	if key=="inner_ear":m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func meow() -> void:
	meow_time = .65

func _process(delta: float) -> void:
	if not animate or not is_instance_valid(skeleton):return
	clock += delta
	meow_time = maxf(0,meow_time-delta)
	motion_amount = move_toward(motion_amount,clampf(speed/1.38,0,1),delta*4)
	low_amount = move_toward(low_amount,1.0 if crouching else 0.0,delta*4)
	var state := preview_pose
	if state=="game":state = "jump" if airborne else "crouch" if crouching else "run" if speed>2.0 else "walk" if speed>.12 else "idle"
	var amount := motion_amount if preview_pose=="game" else 1.0 if state in ["walk","run"] else 0.0
	var duty := .42 if state=="run" else .64
	var stride_length := .28 if state=="run" else .22
	# Match planted-phase travel to actual movement speed rather than skating in place.
	gait += delta*TAU*speed*duty/stride_length
	if preview_pose!="game":gait = clock*TAU/(.42 if state=="run" else .72)
	if state!=last_state:
		transition_remaining = .18
		last_state = state
	previous_rotations.clear()
	previous_positions.clear()
	for i in range(skeleton.get_bone_count()):
		previous_rotations.append(skeleton.get_bone_pose_rotation(i))
		previous_positions.append(skeleton.get_bone_pose_position(i))
	var pose_phase := gait
	if state=="jump":
		pose_phase = clampf(.5-vertical_speed*.045,.14,.88)*TAU if preview_pose=="game" else fposmod(clock,1.0)*TAU
	pose_model(state,pose_phase,clock,amount,low_amount if preview_pose=="game" else 1.0 if state=="crouch" else 0.0)
	if transition_remaining>0:
		var blend := minf(1.0,delta/maxf(delta,transition_remaining))
		for i in range(skeleton.get_bone_count()):
			skeleton.set_bone_pose_rotation(i,previous_rotations[i].slerp(skeleton.get_bone_pose_rotation(i),blend))
			skeleton.set_bone_pose_position(i,previous_positions[i].lerp(skeleton.get_bone_pose_position(i),blend))
		transition_remaining = maxf(0,transition_remaining-delta)

func rotate_bone(label: String, angles: Vector3) -> void:
	skeleton.set_bone_pose_rotation(bone_ids[label],Quaternion.from_euler(angles))

func pose_model(state: String, phase: float, time: float, amount: float = 1.0, crouch_mix: float = 0.0) -> void:
	skeleton.reset_bone_poses()
	var stretch := 1.0 if state=="stretch" else 0.0
	var jump := maxf(0.0,sin(clampf(phase/TAU,0,1)*PI)) if state=="jump" else 0.0
	var sit := 1.0 if state=="sit" else 0.0
	var root_y := -.060*crouch_mix-.010*stretch-.105*sit + sin(time*2.5)*.0015 + sin(phase*2)*.004*amount
	skeleton.set_bone_pose_position(bone_ids.root,Vector3(0,root_y,0))
	var pelvis := skeleton.get_bone_rest(bone_ids.pelvis).origin
	skeleton.set_bone_pose_position(bone_ids.pelvis,pelvis+Vector3(0,.015*stretch,0))
	rotate_bone("pelvis",Vector3(.045*jump+.48*sit,0,sin(phase)*.017*amount))
	rotate_bone("lumbar",Vector3(-.19*stretch-.035*crouch_mix,0,-sin(phase)*.013*amount))
	rotate_bone("thorax",Vector3(-.17*stretch, sin(phase)*.012*amount,0))
	rotate_bone("neck",Vector3(.26*stretch-.10*jump-.48*sit,sin(time*.7)*.025,0))
	rotate_bone("head",Vector3(.08*stretch,curious*.11+sin(time*.65)*.018,0))
	rotate_bone("jaw",Vector3(.12*sin(meow_time/.65*PI),0,0))
	for side in [-1,1]:
		rotate_bone("ear_L" if side<0 else "ear_R",Vector3(sin(time*1.1+side)*.025,0,side*(.055*crouch_mix+.025*sin(time*.9))))
	for i in range(rig_data.tail_bones.size()):
		var index: int = rig_data.tail_bones[i]
		var wag := 2.8 if state=="tailwag" else 1.0
		skeleton.set_bone_pose_rotation(index,Quaternion.from_euler(Vector3(sin(time*1.4-i*.34)*.018-crouch_mix*.012-.025*sit,0,sin(time*1.6-i*.31)*.034*wag)))
	skeleton.force_update_all_bone_transforms()
	for i in range(legs.size()):
		var leg: Dictionary = legs[i]
		var ids: Array = leg.bones
		var target := vector(leg.points[4])
		var cycle := fposmod(phase/TAU+([0.0,.5,.75,.25][i] if state!="run" else [.0,.08,.48,.56][i]),1)
		var lift := 0.0
		var duty := .42 if state=="run" else .64
		var reach := .14 if state=="run" else .11
		if cycle<duty:
			target.z += lerpf(-reach,reach,cycle/duty)*amount
		else:
			var t := (cycle-duty)/(1-duty)
			target.z += lerpf(reach,-reach,t)*amount
			lift = sin(t*PI)*(.043 if state!="run" else .064)*amount
			target.y += lift
		if stretch>0:target.z += -.084 if leg.front else .024
		if sit>0:target.z += -.018 if leg.front else .012
		if jump>0:
			target.y += .068 if leg.front else .080
			target.z += -.018 if leg.front else .045
		var scapula := skeleton.get_bone_rest(ids[0]).origin
		skeleton.set_bone_pose_position(ids[0],scapula+Vector3(0,sin(phase+i*PI)*.007*amount,0))
		skeleton.force_update_all_bone_transforms()
		solve_leg(leg,target,lift)
	skeleton.force_update_all_bone_transforms()

func solve_leg(leg: Dictionary, paw_target: Vector3, lift: float) -> void:
	var ids: Array = leg.bones
	var upper: int = ids[1]
	var mid: int = ids[2]
	var end: int = ids[3]
	var a := skeleton.get_bone_global_pose(upper).origin
	var r1 := rest_points[mid]-rest_points[upper]
	var r2 := rest_points[end]-rest_points[mid]
	var l1 := r1.length()
	var l2 := r2.length()
	var target := paw_target+rest_points[end]-rest_points[ids[4]]
	var distance := clampf(a.distance_to(target),absf(l1-l2)+.002,l1+l2-.0006)
	var direction := (target-a).normalized()
	var bend := Vector3(0,0,1 if leg.front else -1)
	bend = (bend-direction*direction.dot(bend)).normalized()
	var along := (l1*l1-l2*l2+distance*distance)/(2*distance)
	var knee := a+direction*along+bend*sqrt(maxf(0,l1*l1-along*along))
	var ankle := a+direction*distance
	skeleton.set_bone_global_pose(upper,Transform3D(Basis(Quaternion(r1.normalized(),(knee-a).normalized())),a))
	skeleton.set_bone_global_pose(mid,Transform3D(Basis(Quaternion(r2.normalized(),(ankle-knee).normalized())),knee))
	var rest_foot := rest_points[ids[4]]-rest_points[end]
	skeleton.set_bone_global_pose(end,Transform3D(Basis(Quaternion(rest_foot.normalized(),(paw_target-ankle).normalized())),ankle))
	skeleton.set_bone_global_pose(ids[4],Transform3D(Basis.IDENTITY,paw_target))
	var toe := paw_target+rest_points[ids[5]]-rest_points[ids[4]]
	skeleton.set_bone_global_pose(ids[5],Transform3D(Basis(Vector3.RIGHT,-lift*2.1),toe))

func bake_animation_library() -> void:
	configure_rig()
	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	animation_player.root_node = NodePath("..")
	add_child(animation_player)
	var library := AnimationLibrary.new()
	for state in ["idle","walk","run","crouch","jump","stretch","sit","tailwag"]:
		var animation := Animation.new()
		animation.resource_name = "Calico_"+state
		animation.length = .72 if state=="walk" else .42 if state=="run" else 3.927 if state in ["idle","sit","tailwag"] else 1.0
		animation.loop_mode = Animation.LOOP_NONE if state=="jump" else Animation.LOOP_LINEAR
		var pos_tracks: Array[int] = []
		var rot_tracks: Array[int] = []
		for i in range(skeleton.get_bone_count()):
			var path := NodePath("Skeleton3D:"+str(skeleton.get_bone_name(i)))
			var p := animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(p,path)
			pos_tracks.append(p)
			var r := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(r,path)
			rot_tracks.append(r)
		for frame in range(25):
			var time := animation.length*frame/24.0
			pose_model(state,(frame if state=="jump" else frame%24)/24.0*TAU,time if frame<24 else 0.0,1.0 if state in ["walk","run"] else 0.0,1.0 if state=="crouch" else 0.0)
			for i in range(skeleton.get_bone_count()):
				animation.position_track_insert_key(pos_tracks[i],time,skeleton.get_bone_pose_position(i))
				animation.rotation_track_insert_key(rot_tracks[i],time,skeleton.get_bone_pose_rotation(i))
		library.add_animation(state,animation)
	ResourceSaver.save(library,"res://assets/models/calico_poses.res")
	library.take_over_path("res://assets/models/calico_poses.res")
	animation_player.add_animation_library("poses",library)
	skeleton.reset_bone_poses()
