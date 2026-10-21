extends Node3D
## Authored joint poses only. The static collider never drives the visual skeleton.
@export_enum("auto", "stand", "lie", "sleep") var pose_mode := "auto"
var clock := 0.0
var player: AnimationPlayer
var skeleton: Skeleton3D
var fed_time := 0.0
var current_pose := "sleep"
var stand_pose: Array[Transform3D] = []
var lying_pose: Array[Transform3D] = []
var transition_from: Array[Transform3D] = []
var transition_time := 1.0
var was_standing := false
var eyes: Array = []
var tail := -1
var neck := -1
var dog_collision: CollisionShape3D
var head_collision: CollisionShape3D
var head_bone := -1

func _ready() -> void:
	player = find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	skeleton = find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Keep the bind-pose proportions and remove every physics/morph deformation source.
	for modifier in skeleton.find_children("*","SkeletonModifier3D",true,false):modifier.active = false
	skeleton.reset_bone_poses()
	stand_pose = capture_pose()
	var sleep_clip := ""
	for clip in player.get_animation_list():
		if String(clip).ends_with("sleep"):sleep_clip = clip
	assert(not sleep_clip.is_empty(),"Landing dog: missing authored lying pose")
	player.play(sleep_clip,0)
	player.advance(0)
	lying_pose = capture_pose()
	# Freeze the source clip. Pose changes below always start from an absolute pose.
	player.pause()
	for mesh in find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_blend_shape_count()):
			mesh.set_blend_shape_value(i,0.0)
			if mesh.mesh.get_blend_shape_name(i)==&"blink":eyes.append([mesh,i])
	tail = skeleton.find_bone("Dog_Tail_01_02SHJnt")
	neck = skeleton.find_bone("Dog_Neck_01SHJnt")
	head_bone = skeleton.find_bone("Dog_Neck_TopSHJnt")
	dog_collision = get_node("Collision/Dog")
	dog_collision.shape = CapsuleShape3D.new()
	head_collision = CollisionShape3D.new()
	head_collision.name = "Head"
	var head_shape := SphereShape3D.new()
	head_shape.radius = .16
	head_collision.shape = head_shape
	get_node("Collision").add_child(head_collision)
	set_meta("reference_shoulder_m",.512)
	set_pose("sleep",true)

func capture_pose() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for i in range(skeleton.get_bone_count()):
		result.append(Transform3D(Basis(skeleton.get_bone_pose_rotation(i).normalized()),skeleton.get_bone_pose_position(i)))
	return result

func set_pose(value: String, immediate := false) -> void:
	if value not in ["stand","lie","sleep"]:return
	if value!=current_pose or immediate:
		transition_from = capture_pose()
		was_standing = current_pose=="stand"
		current_pose = value
		transition_time = 1.0 if immediate else 0.0
	apply_pose(0.0)

func apply_pose(delta: float) -> void:
	transition_time = minf(1.0,transition_time+delta/1.2)
	var blend := smoothstep(0.0,1.0,transition_time)
	var target := stand_pose if current_pose=="stand" else lying_pose
	for i in range(skeleton.get_bone_count()):
		var a := transition_from[i]
		var b := target[i]
		skeleton.set_bone_pose_position(i,a.origin.lerp(b.origin,blend))
		skeleton.set_bone_pose_rotation(i,a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(),blend))
		skeleton.set_bone_pose_scale(i,Vector3.ONE)
	# Small rigid joint turns are reapplied from the pose, never accumulated each frame.
	if neck>=0 and current_pose!="sleep":
		skeleton.set_bone_pose_rotation(neck,skeleton.get_bone_pose_rotation(neck)*Quaternion(Vector3.UP,sin(clock*.65)*.055*blend))
	if tail>=0 and fed_time>0:
		skeleton.set_bone_pose_rotation(tail,skeleton.get_bone_pose_rotation(tail)*Quaternion(Vector3.UP,sin(clock*5)*.13*blend))
	for entry in eyes:
		var blink := .96 if current_pose=="sleep" else .92 if fmod(clock,5.2)<.13 else 0.0
		entry[0].set_blend_shape_value(entry[1],blink)
	# One static body follows the pose envelope; contacts cannot stretch the bones.
	var standing := blend if current_pose=="stand" else 1.0-blend if was_standing else 0.0
	var shape := dog_collision.shape as CapsuleShape3D
	shape.radius = .22
	shape.height = lerpf(.88,.95,standing)
	dog_collision.rotation.z = PI/2
	dog_collision.position = Vector3(0,lerpf(.31,.47,standing),0)
	if head_bone>=0:
		head_collision.position = to_local(skeleton.to_global(skeleton.get_bone_global_pose(head_bone).origin))+Vector3(.04,.04,0)

func _process(delta: float) -> void:
	clock += delta
	fed_time = maxf(0.0,fed_time-delta)
	var desired := pose_mode
	if desired=="auto":
		if fed_time>0:desired = "stand"
		elif get_meta("free_to_roam",false):
			var phase := fmod(clock,36.0)
			desired = "stand" if phase<10.0 else "lie" if phase<25.0 else "sleep"
		else:desired = "sleep"
	set_pose(desired)
	apply_pose(delta)

func react_to_food() -> void:fed_time = 8.0
