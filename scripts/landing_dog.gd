extends Node3D
## One resting companion; its baked skeleton is twice the cat's reference scale.
var breathing: Array = []
var clock := 0.0
var player: AnimationPlayer
var skeleton: Skeleton3D
var fed_time := 0.0
var awake_time := 0.0
var awake_blink: Array = []
func _ready() -> void:
	player = find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	skeleton = find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var sleep_clip := ""
	for name in player.get_animation_list():
		if String(name).ends_with("sleep"):sleep_clip = name
	if sleep_clip.is_empty():
		push_error("Landing dog: missing sleep clip")
		return
	player.get_animation(sleep_clip).loop_mode = Animation.LOOP_LINEAR
	player.play(sleep_clip,0)
	player.advance(0)
	for mesh in find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_blend_shape_count()):
			var label: StringName = mesh.mesh.get_blend_shape_name(i)
			if label==&"blink":
				mesh.set_blend_shape_value(i,.96)
				awake_blink.append([mesh,i])
			if label==&"breath":breathing.append([mesh,i])
	set_meta("reference_shoulder_m",.512)

func _process(delta: float) -> void:
	clock += delta
	if is_instance_valid(player):player.advance(delta)
	fed_time = maxf(0,fed_time-delta)
	if fed_time>0:
		var tail := skeleton.find_bone("Dog_Tail_01_02SHJnt")
		if tail>=0:skeleton.set_bone_pose_rotation(tail,skeleton.get_bone_pose_rotation(tail)*Quaternion(Vector3.UP,sin(clock*6)*.20*minf(1,fed_time)))
	for entry in breathing:entry[0].set_blend_shape_value(entry[1],.25+.15*sin(clock*TAU/4))
	# Keep the authored rest animation, adding brief alert/listening and tail reactions.
	if get_meta("free_to_roam",false):
		awake_time += delta
		var attentive := fmod(awake_time,14.0)<5.0 or fed_time>0
		for entry in awake_blink:entry[0].set_blend_shape_value(entry[1],.15 if attentive else .96)
		if attentive:
			for i in range(skeleton.get_bone_count()):
				if "Head" in skeleton.get_bone_name(i):
					skeleton.set_bone_pose_rotation(i,skeleton.get_bone_pose_rotation(i)*Quaternion(Vector3.UP,sin(clock*.8)*.12))
					break

func react_to_food() -> void:fed_time = 8.0
