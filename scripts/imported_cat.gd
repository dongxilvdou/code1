extends Node3D
## Adapter for the supplied, Blender-animated cat. Keeps the existing game API.
@export var visual_scene: PackedScene
@export var first_person := false
@export var animate := true
@export_enum("game","idle","walk","run","crouch","jump","stretch","sit","tailwag") var preview_pose := "game"
var speed := 0.0
var crouching := false
var airborne := false
var vertical_speed := 0.0
var jump_takeoff_speed := 4.75
var curious := 0.0
var clock := 0.0
var last_state := ""
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var rig_data: Dictionary = {"stats":{"triangles":8646}}
var clips := {}
var meow_time := 0.0
var visuals: Node3D
var blink_meshes: Array = []
var head_bone := -1
var head_base := Quaternion.IDENTITY
var head_offset_applied := false

func _ready() -> void:
	visuals = visual_scene.instantiate()
	add_child(visuals)
	skeleton = visuals.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	head_bone = skeleton.find_bone("Wolf_Neck_TopSHJnt")
	skeleton.reset_bone_poses()
	animation_player = visuals.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for animation_name in animation_player.get_animation_list():
		var text := String(animation_name)
		var name_only := text.get_slice("/",text.get_slice_count("/")-1)
		clips[name_only] = animation_name
		var clip := animation_player.get_animation(animation_name)
		# Jump is scrubbed by velocity and must remain available on long falls.
		clip.loop_mode = Animation.LOOP_NONE if name_only=="meow" else Animation.LOOP_LINEAR
	for mesh in visuals.find_children("*","MeshInstance3D",true,false):
		mesh.layers = 8 if first_person else 2
		if first_person:mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in range(mesh.mesh.get_blend_shape_count()):
			if mesh.mesh.get_blend_shape_name(i)==&"eye blink":blink_meshes.append([mesh,i])
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/pets/pet_assets.json"))
	rig_data = {"stats":meta.cat}
	set_meta("source_model","C:/zGoDot/3D/cat/bicolor-cat/source/bicolor Cat.glb")
	_process(0)

func meow() -> void:meow_time = .65

func set_clay(value: bool) -> void:
	var clay: StandardMaterial3D
	if value:
		clay = StandardMaterial3D.new()
		clay.albedo_color = Color(.46,.52,.53)
		clay.roughness = .8
	for mesh in visuals.find_children("*","MeshInstance3D",true,false):mesh.material_override = clay

func _process(delta: float) -> void:
	# Remove last frame's additive look before sampling the animation. Constant
	# tracks may be cached by AnimationMixer, so multiplying again would accumulate.
	if head_offset_applied and is_instance_valid(skeleton):
		skeleton.set_bone_pose_rotation(head_bone,head_base)
		head_offset_applied = false
	if not animate or not is_instance_valid(animation_player):return
	clock += delta
	meow_time = maxf(0,meow_time-delta)
	var state := preview_pose
	if state=="game":state = "jump" if airborne else "crouch" if crouching else "run" if speed>2 else "walk" if speed>.12 else "meow" if meow_time>0 else "idle"
	if not clips.has(state):state = "idle"
	var rate := 1.0
	if preview_pose=="game":
		if state=="walk":rate = clampf(speed/.651,.4,3.5)
		elif state=="run":rate = clampf(speed/1.95,.6,2.5)
		elif state=="crouch":rate = clampf(speed/.266,0,3)
	if state!=last_state or animation_player.current_animation!=clips[state]:
		animation_player.play(clips[state],0 if last_state.is_empty() else .16)
		last_state = state
	animation_player.speed_scale = rate
	animation_player.advance(delta)
	var blink := pow(maxf(0,1-absf(fposmod(clock,4.8)-4.55)/.11),2)
	for entry in blink_meshes:entry[0].set_blend_shape_value(entry[1],blink)
	if state=="jump" and preview_pose=="game":
		var phase := clampf((jump_takeoff_speed-vertical_speed)/maxf(.1,2*jump_takeoff_speed),0,.99)
		animation_player.seek(phase*animation_player.current_animation_length,true)
	if curious!=0 and not first_person:
		if head_bone>=0:
			head_base = skeleton.get_bone_pose_rotation(head_bone)
			skeleton.set_bone_pose_rotation(head_bone,head_base*Quaternion(Vector3.UP,clampf(curious,-1,1)*.11))
			head_offset_applied = true
