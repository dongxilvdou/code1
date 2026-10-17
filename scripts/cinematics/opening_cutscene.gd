extends Node3D
## Owns the real player only while active. The host owns menu/save/start policy.
signal started
signal finished(skipped: bool)
signal shot_changed(index: int)

@export_enum("无存档时播放", "每次从菜单开始播放", "关闭") var playback_policy := 0
@export var allow_skip := true
@export var skip_action: StringName = &""
@export var use_depth_of_field := true
@export var environment_source: WorldEnvironment
@export var sun_source: DirectionalLight3D
@export_range(.05,2,.05) var skip_blend_seconds := .45
@export var restore_actor_after_preview := false
@export var shot_boundaries := PackedFloat32Array([0,6,12,20,26,28])

# AnimationPlayer property tracks: deliberately editable in the scene timeline.
@export var film_time := 0.0
@export var title_opacity := 0.0
@export var blackout := 1.0
@export var matte_amount := 1.0
@export var score_gain := 0.0

var active := false
var finishing := false
var last_shot := -1
var collision_corrections := 0
var host: Node
var player: CharacterBody3D
var model: Node3D
var interface: CanvasLayer
var snapshot := {}
var local_environment: Environment
var morning_sun: Basis
var meow_played := false
var paw_phase := 0.0
var skip_elapsed := 0.0
var skip_camera := Transform3D.IDENTITY
var skip_fov := 60.0
var finish_count := 0
var actor_distance := 0.0
var watchdog := 0.0
var previous_actor := Vector3.ZERO
@onready var camera: Camera3D = $CinemaCamera
@onready var timeline: AnimationPlayer = $AnimationPlayer
@onready var overlay: Control = $CinemaUI/Overlay
@onready var title: VBoxContainer = $CinemaUI/Overlay/Title
@onready var skip_hint: Button = $CinemaUI/Overlay/Skip
@onready var score: AudioStreamPlayer = $Score
@onready var meow: AudioStreamPlayer3D = $Meow
@onready var paw: AudioStreamPlayer3D = $Paw
@onready var actor_path: Path3D = $ActorPath
@onready var camera_paths: Array[Path3D] = [$Morning,$Wake,$Follow,$Reveal]

func _ready() -> void:
	overlay.hide()
	set_physics_process(false)
	set_process(false)
	set_process_input(false)
	timeline.animation_finished.connect(_on_animation_finished)
	skip_hint.pressed.connect(request_skip)
	get_viewport().size_changed.connect(_layout)
	_layout()

func bind_game(game: Node, actor: CharacterBody3D, ui: CanvasLayer) -> void:
	host = game
	player = actor
	model = actor.model
	interface = ui

func should_play(has_save: bool, force: bool = false) -> bool:
	if active:return false
	if force:return true
	return playback_policy!=2 and (playback_policy==1 or not has_save)

func play() -> bool:
	if active or not is_instance_valid(player) or not is_instance_valid(model):return false
	if actor_path.curve==null or actor_path.curve.point_count<2:return false
	if shot_boundaries.size()!=6 or not timeline.has_animation("opening"):return false
	for i in range(1,6):
		if shot_boundaries[i]<=shot_boundaries[i-1]:return false
	for path in camera_paths:
		if path.curve==null or path.curve.point_count<2:return false
	snapshot = {
		"transform":player.global_transform,"velocity":player.velocity,"active":player.active,
		"physics":player.is_physics_processing(),"input":player.is_processing_unhandled_input(),
		"yaw":player.yaw,"pitch":player.pitch,"head":player.head.transform,
		"camera_local":player.camera.transform,"camera":get_viewport().get_camera_3d(),
		"animate":model.animate,"pose":model.preview_pose,"speed":model.speed,"curious":model.curious,
		"airborne":model.airborne,"crouching":model.crouching,"hud":interface.hud.visible,
		"welcome":interface.welcome.visible,"mouse":Input.mouse_mode
	}
	if is_instance_valid(sun_source):
		snapshot.sun_basis = sun_source.basis
		snapshot.sun_color = sun_source.light_color
		snapshot.sun_energy = sun_source.light_energy
		morning_sun = Basis.from_euler(Vector3(deg_to_rad(-28),deg_to_rad(-38),0))
	if is_instance_valid(environment_source) and environment_source.environment:
		local_environment = environment_source.environment.duplicate()
		camera.environment = local_environment
	if is_instance_valid(host.rain_audio):snapshot.rain_db = host.rain_audio.volume_db
	active = true
	finishing = false
	finish_count = 0
	last_shot = -1
	collision_corrections = 0
	actor_distance = 0
	watchdog = 0
	meow_played = false
	paw_phase = 0
	player.set_control(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.velocity = Vector3.ZERO
	player.global_position = actor_path.to_global(actor_path.curve.sample_baked(0))
	_set_facing(actor_path.curve.sample_baked(.1)-actor_path.curve.sample_baked(0),1)
	_ground_actor()
	previous_actor = player.global_position
	player.pitch = -.02
	player.head.rotation = Vector3(-.02,0,0)
	player.camera.position = Vector3.ZERO
	model.preview_pose = "game"
	model.animate = true
	model.crouching = false
	model.airborne = false
	model.speed = 0
	model.curious = 0
	interface.welcome.hide()
	interface.hud.hide()
	interface.hint_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	film_time = 0
	score_gain = 0
	blackout = 1
	title_opacity = 0
	matte_amount = 1
	overlay.show()
	skip_hint.visible = allow_skip
	score.play()
	timeline.play("opening")
	timeline.advance(0)
	camera.make_current()
	_update_camera()
	_update_presentation()
	set_physics_process(true)
	set_process(true)
	set_process_input(true)
	started.emit()
	return true

func _ground_actor() -> void:
	var origin := player.global_position+Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin,origin-Vector3.UP*3,1,[player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():player.global_position.y = hit.position.y+.002

func _physics_process(delta: float) -> void:
	if not active:return
	if finishing:
		player.velocity = Vector3(0,-.2,0)
		player.move_and_slide()
		return
	var t := film_time
	var walk_start := float(shot_boundaries[2])
	var walk_end := float(shot_boundaries[3])
	var fraction := clampf((t-walk_start)/(walk_end-walk_start),0,1)
	# Smooth speed ramp: derivative stays zero at the first/last paw placement.
	var distance_fraction := fraction*fraction*(3-2*fraction)
	var destination := actor_path.to_global(actor_path.curve.sample_baked(distance_fraction*actor_path.curve.get_baked_length(),true))
	var horizontal := destination-player.global_position
	horizontal.y = 0
	player.velocity.x = clampf(horizontal.x/maxf(delta,.001),-.8,.8)
	player.velocity.z = clampf(horizontal.z/maxf(delta,.001),-.8,.8)
	player.velocity.y = maxf(player.velocity.y-12*delta,-3)
	player.move_and_slide()
	var travel := player.global_position-previous_actor
	travel.y = 0
	var actual_speed := travel.length()/maxf(delta,.001)
	actor_distance += travel.length()
	previous_actor = player.global_position
	if travel.length_squared()>.0000001:_set_facing(travel,1-exp(-delta*8))
	model.speed = actual_speed/player.cat_scale
	model.airborne = false
	model.vertical_speed = 0
	model.preview_pose = "stretch" if t>6.6 and t<9.4 else "tailwag" if t>20.2 and t<23.5 else "game"
	model.curious = smoothstep(9.5,10.7,t)*(1-smoothstep(11,12,t))*.45
	meow.global_position = player.global_position+Vector3(0,.23,-.12)
	paw.global_position = player.global_position+Vector3.UP*.03
	if t>=10.4 and not meow_played:
		meow_played = true
		model.meow()
		meow.play()
	paw_phase += travel.length()
	if paw_phase>.15 and t<walk_end:
		paw_phase = 0
		paw.pitch_scale = .94+sin(t*5)*.06
		paw.play()

func _set_facing(direction: Vector3, weight: float) -> void:
	if direction.length_squared()<.000001:return
	var yaw := atan2(-direction.x,-direction.z)
	player.rotation.y = lerp_angle(player.rotation.y,yaw,weight)
	player.yaw = player.rotation.y

func _process(delta: float) -> void:
	if not active:return
	watchdog += delta
	if not finishing and (not timeline.is_playing() or watchdog>maxf(40,shot_boundaries[5]+10)):
		_finish(true)
		return
	if finishing:
		skip_elapsed += delta
		var progress := smoothstep(0,skip_blend_seconds,skip_elapsed)
		camera.global_transform = skip_camera.interpolate_with(player.camera.global_transform,progress)
		camera.fov = lerpf(skip_fov,player.camera.fov,progress)
		_update_body_mask()
		blackout = 0
		title_opacity *= 1-progress
		matte_amount = 1-progress
		score_gain = lerpf(score_gain,0,progress)
		_apply_light(progress)
		_update_presentation()
		if progress>=1:_finish(true)
		return
	_update_camera()
	_update_presentation()

func _update_camera() -> void:
	var t := film_time
	var shot := 0
	for i in range(1,4):
		if t>=shot_boundaries[i]:shot = i
	if shot!=last_shot:
		last_shot = shot
		shot_changed.emit(shot)
	var progress := clampf((t-shot_boundaries[shot])/(shot_boundaries[shot+1]-shot_boundaries[shot]),0,1)
	if shot==3:progress = clampf((t-shot_boundaries[3])/(shot_boundaries[4]-shot_boundaries[3]),0,1)
	var curved := progress*progress*(3-2*progress)
	var path := camera_paths[shot]
	var position_target := path.to_global(path.curve.sample_baked(curved*path.curve.get_baked_length(),true))
	if shot==2:position_target += player.global_position-actor_path.to_global(actor_path.curve.sample_baked(0))
	var focus := player.global_position+Vector3.UP*(.22 if shot in [1,2] else .35)
	if shot==3:focus += Vector3(0,1.45,-3.5)*curved
	if shot==0:focus += Vector3(0,.25,-1.1)*(1-curved)
	# Keep the camera on the cat's side of any real wall/planter.
	var query := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*.22,position_target,1,[player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		collision_corrections += 1
		position_target = hit.position+(player.global_position+Vector3.UP*.22-hit.position).normalized()*.09
	camera.global_position = position_target
	if camera.global_position.distance_to(focus)>.05:camera.look_at(focus)
	camera.fov = lerpf([55.0,43.0,51.0,56.0][shot],[47.0,40.0,58.0,63.0][shot],curved)
	var handoff := smoothstep(shot_boundaries[4],shot_boundaries[5],t)
	if handoff>0:
		camera.global_transform = camera.global_transform.interpolate_with(player.camera.global_transform,handoff)
		camera.fov = lerpf(camera.fov,player.camera.fov,handoff)
	_update_body_mask()
	if camera.attributes is CameraAttributesPractical:
		var attributes: CameraAttributesPractical = camera.attributes
		attributes.dof_blur_far_enabled = use_depth_of_field and shot==1 and handoff==0 and RenderingServer.get_current_rendering_method()!="gl_compatibility"
		attributes.dof_blur_far_distance = camera.global_position.distance_to(player.global_position+Vector3.UP*.22)+.35
	_apply_light(handoff)

func _update_body_mask() -> void:
	# Match the existing first-person body filter before entering the skull.
	camera.cull_mask = player.camera.cull_mask if camera.global_position.distance_to(player.head.global_position)<.65 else 23

func _apply_light(restore: float) -> void:
	if is_instance_valid(sun_source) and snapshot.has("sun_basis"):
		sun_source.basis = morning_sun.slerp(snapshot.sun_basis,restore)
		sun_source.light_color = Color(1,.88,.71).lerp(snapshot.sun_color,restore)
		sun_source.light_energy = lerpf(1.12,snapshot.sun_energy,restore)
	if local_environment and is_instance_valid(environment_source) and environment_source.environment:
		local_environment.ambient_light_color = Color(.99,.94,.84).lerp(environment_source.environment.ambient_light_color,restore)
		local_environment.ambient_light_energy = lerpf(.28,environment_source.environment.ambient_light_energy,restore)
	if snapshot.has("rain_db") and is_instance_valid(host.rain_audio):host.rain_audio.volume_db = lerpf(-28,snapshot.rain_db,restore)

func _update_presentation() -> void:
	$CinemaUI/Overlay/Black.color.a = blackout
	title.modulate.a = title_opacity
	$CinemaUI/Overlay/Top.modulate.a = matte_amount
	$CinemaUI/Overlay/Bottom.modulate.a = matte_amount
	skip_hint.modulate.a = matte_amount*.8
	$CinemaUI/Overlay/Location.modulate.a = smoothstep(1.4,2.6,film_time)*(1-smoothstep(4,5.6,film_time))
	score.volume_db = linear_to_db(maxf(.00001,score_gain))

func _layout() -> void:
	if not is_instance_valid(overlay):return
	var size := get_viewport().get_visible_rect().size
	var font_size := clampi(int(size.x*.047),30,68)
	$CinemaUI/Overlay/Title/Name.add_theme_font_size_override("font_size",font_size)
	$CinemaUI/Overlay/Title/Chapter.add_theme_font_size_override("font_size",clampi(int(size.x*.014),12,20))
	var bar_height := clampf((size.y-size.x/2.12)*.5,0,size.y*.12)
	$CinemaUI/Overlay/Top.offset_bottom = bar_height
	$CinemaUI/Overlay/Bottom.offset_top = -bar_height

func _input(event: InputEvent) -> void:
	if not active:return
	var wants_skip: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE
	if skip_action!=&"" and InputMap.has_action(skip_action) and event.is_action_pressed(skip_action) and not event.is_echo():wants_skip = true
	if wants_skip:request_skip()
	# The cinematic layer owns all keyboard/game shortcuts while it is visible.
	if event is InputEventKey or event is InputEventMouseMotion:get_viewport().set_input_as_handled()

func request_skip() -> void:
	if not active or finishing or not allow_skip:return
	finishing = true
	timeline.pause()
	skip_elapsed = 0
	skip_camera = camera.global_transform
	skip_fov = camera.fov
	model.preview_pose = "game"
	model.speed = 0
	meow.stop()
	paw.stop()
	# Avoid flying into walls on an early skip: use a short fade during the handoff.
	# Camera movement remains outside the house on the authored courtyard route.

func _on_animation_finished(animation: StringName) -> void:
	if animation==&"opening" and active and not finishing:_finish(false)

func _restore() -> void:
	if snapshot.is_empty():return
	_apply_light(1)
	if is_instance_valid(player):
		if restore_actor_after_preview:
			player.global_transform = snapshot.transform
			player.yaw = snapshot.yaw
			player.pitch = snapshot.pitch
			player.head.transform = snapshot.head
			player.camera.transform = snapshot.camera_local
		player.velocity = snapshot.velocity if restore_actor_after_preview else Vector3.ZERO
		player.set_physics_process(snapshot.physics)
		player.set_process_unhandled_input(snapshot.input)
		player.set_control(snapshot.active)
		player.camera.make_current()
		if restore_actor_after_preview and is_instance_valid(snapshot.camera):snapshot.camera.make_current()
	if is_instance_valid(model):
		model.preview_pose = snapshot.pose
		model.animate = snapshot.animate
		model.speed = snapshot.speed if restore_actor_after_preview else 0.0
		model.curious = snapshot.curious
		model.airborne = snapshot.airborne
		model.crouching = snapshot.crouching
	if is_instance_valid(interface):
		interface.hud.visible = snapshot.hud
		interface.welcome.visible = snapshot.welcome
	Input.mouse_mode = snapshot.mouse

func _finish(skipped: bool) -> void:
	if not active:return
	active = false
	finishing = false
	finish_count += 1
	timeline.stop()
	for sound in [score,meow,paw]:sound.stop()
	_restore()
	overlay.hide()
	camera.clear_current(false)
	set_physics_process(false)
	set_process(false)
	set_process_input(false)
	finished.emit(skipped)

func _exit_tree() -> void:
	# Scene replacement/cancellation also releases the temporary sun/control ownership.
	if active:
		active = false
		_restore()
