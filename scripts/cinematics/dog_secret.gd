extends Node3D
## Optional companion gag. No quest flags, inventory or map transforms are changed.
signal begun
signal ended(cancelled: bool)
signal phase_changed(value: int)
enum Phase {IDLE, DIALOGUE, DIMMING, VIDEO, WHITEOUT, RECOVERY}
const VIDEO_PATH := "res://assets/easter_eggs/dog_secret/dog_power.ogv"
const KeyShader = preload("res://shaders/dog_secret_key.gdshader")
const QuestTheme = preload("res://quest_system/quest_theme.gd")
const LINES := [
	["阿嚼","曾经的我有一个能力，威能巨大，我不敢轻易尝试"],
	["我","是什么能力？让我看看，好不好？"],
	["阿嚼","不行。我已经很久没试过了……怕你承受不住。"],
	["我","就一次！我站远一点，保证不捣乱。"],
	["阿嚼","你真的这么想看？"],
	["我","想！拜托了，阿嚼！我会准备好的。"],
	["阿嚼","……好吧。那你看好了。"]
]
@export_range(0,1,.01) var trigger_chance := .5
@export var dog_actor: Node3D
@export var white_hold_seconds := 3.0
@export var recovery_seconds := 3.0
@export var video_seconds := 6.0
@export var video_volume_db := 0.0
var phase := Phase.IDLE
var active := false
var phase_time := 0.0
var line_index := 0
var finish_count := 0
var last_cancelled := false
var rng := RandomNumberGenerator.new()
var game: Node
var day: Node
var player: CharacterBody3D
var pending_panel: Node
var snapshot := {}
var lights: Array = []
var emissive_surfaces: Array = []
var canvases: Array = []
var dark_environment: Environment
var video: VideoStreamPlayer
var projection: MeshInstance3D
var key_material: ShaderMaterial
var camera: Camera3D
var ui: CanvasLayer
var dialogue: Control
var heading: Label
var words: Label
var next_button: Button
var white: ColorRect

func _ready() -> void:
	game = get_parent();day = game.get_node("DayOne");player = game.get_node("Miso")
	rng.randomize()
	video = VideoStreamPlayer.new()
	video.name = "DogMemeVideo"
	video.expand = true
	video.size = Vector2(960,540)
	video.loop = false
	video.volume_db = video_volume_db
	video.stream = load(VIDEO_PATH)
	# Decode without drawing a green rectangle in the 2D canvas.
	# Alpha-zero Controls still hit-test: this media source must never eat mouse look.
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video.focus_mode = Control.FOCUS_NONE
	video.modulate.a = 0
	add_child(video)
	video.finished.connect(_on_video_finished)
	projection = MeshInstance3D.new()
	projection.name = "FloatingDog"
	var quad := QuadMesh.new();quad.size = Vector2(1.6,.9)
	projection.mesh = quad
	projection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	projection.extra_cull_margin = 2
	key_material = ShaderMaterial.new();key_material.shader = KeyShader
	projection.material_override = key_material
	add_child(projection);projection.hide()
	camera = Camera3D.new();camera.name = "SecretCamera";camera.near = .04
	add_child(camera)
	_make_ui()
	set_process(false);set_process_input(false)

func eligible() -> bool:
	return not active and game.started and day.initialized and day.value("current_day",1)>=6 \
		and is_instance_valid(dog_actor) and bool(dog_actor.get_meta("free_to_roam",false)) \
		and not game.cinematic_active and player.active and not game.photo and not game.inspecting

func queue_after_chat(panel: Node) -> void:
	# Called only by the ordinary companion-chat branches, after their story opens.
	if active or is_instance_valid(pending_panel) or not is_instance_valid(panel):return
	if not bool(dog_actor.get_meta("free_to_roam",false)):return
	pending_panel = panel
	panel.dismissed.connect(_after_chat,CONNECT_ONE_SHOT)

func _after_chat() -> void:
	pending_panel = null
	# The chapter first releases its panel/control; don't reuse the closing E press.
	call_deferred("_roll_after_chat")

func _roll_after_chat() -> void:
	if eligible() and rng.randf()<trigger_chance:begin()

func begin() -> bool:
	if not eligible() or video.stream == null:return false
	snapshot = {"control":player.active,"physics":player.is_physics_processing(),
		"input":player.is_processing_unhandled_input(),"mouse":Input.mouse_mode,
		"velocity":player.velocity,"camera":get_viewport().get_camera_3d(),
		"cinematic":game.cinematic_active,"dog_process":dog_actor.is_processing()}
	if is_instance_valid(game.rain_audio):snapshot.rain_db = game.rain_audio.volume_db
	canvases.clear()
	for canvas in game.find_children("*","CanvasLayer",true,false):
		if canvas!=ui:
			canvases.append([canvas,canvas.visible]);canvas.hide()
	lights.clear()
	for lamp in game.find_children("*","Light3D",true,false):lights.append([lamp,lamp.light_energy])
	emissive_surfaces.clear()
	for mesh in game.find_children("*","MeshInstance3D",true,false):
		if mesh==projection or mesh.mesh==null:continue
		if mesh.material_override!=null:
			_remember_emission(mesh,-1,mesh.material_override)
		else:
			for surface in range(mesh.mesh.get_surface_count()):
				_remember_emission(mesh,surface,mesh.get_active_material(surface))
	active = true;finish_count = 0;last_cancelled = false;line_index = 0
	game.cinematic_active = true
	player.set_control(false);player.set_physics_process(false);player.set_process_unhandled_input(false)
	dog_actor.set_process(false)
	white.color.a = 0;ui.show();dialogue.show()
	_set_phase(Phase.DIALOGUE)
	_render_line()
	set_process(true);set_process_input(true)
	begun.emit()
	return true

func _make_ui() -> void:
	ui = CanvasLayer.new();ui.name = "SecretUI";ui.layer = 110;add_child(ui)
	var root := Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE;ui.add_child(root)
	dialogue = CenterContainer.new();root.add_child(dialogue)
	dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new();card.custom_minimum_size.x = 580
	card.add_theme_stylebox_override("panel",QuestTheme.panel(24));dialogue.add_child(card)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",20);card.add_child(column)
	var font := SystemFont.new();font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"])
	heading = Label.new();column.add_child(heading)
	heading.add_theme_font_override("font",font);heading.add_theme_font_size_override("font_size",24)
	heading.add_theme_color_override("font_color",QuestTheme.BRASS)
	words = Label.new();words.custom_minimum_size = Vector2(500,95);words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_theme_font_override("font",font);words.add_theme_font_size_override("font_size",21);column.add_child(words)
	next_button = Button.new();next_button.text = "继续  ·  E / 空格";next_button.custom_minimum_size.y = 46
	next_button.add_theme_font_override("font",font);QuestTheme.button(next_button)
	next_button.pressed.connect(advance);column.add_child(next_button)
	var hint := Label.new();hint.text = "Esc 结束这段彩蛋";hint.add_theme_font_override("font",font)
	hint.add_theme_font_size_override("font_size",13);hint.add_theme_color_override("font_color",QuestTheme.MUTED);column.add_child(hint)
	white = ColorRect.new();white.color = Color(1,1,1,0);white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(white);white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.hide()

func _render_line() -> void:
	heading.text = str(LINES[line_index][0]);words.text = str(LINES[line_index][1])

func advance() -> void:
	if not active or phase!=Phase.DIALOGUE:return
	line_index += 1
	if line_index<LINES.size():_render_line()
	else:_prepare_video()

func _head_position() -> Vector3:
	if dog_actor.get("skeleton") is Skeleton3D and dog_actor.head_bone>=0:
		return dog_actor.skeleton.to_global(dog_actor.skeleton.get_bone_global_pose(dog_actor.head_bone).origin)
	return dog_actor.global_position+Vector3.UP*.45

func _prepare_video() -> void:
	dialogue.hide()
	for entry in emissive_surfaces:
		if entry.surface<0:entry.mesh.material_override = entry.dark
		else:entry.mesh.set_surface_override_material(entry.surface,entry.dark)
	var previous: Camera3D = snapshot.camera
	camera.global_transform = previous.global_transform
	camera.fov = previous.fov;camera.cull_mask = previous.cull_mask
	var source := previous.environment
	if source == null:source = get_viewport().world_3d.environment
	if source:
		dark_environment = source.duplicate()
		camera.environment = dark_environment
		# Only this temporary camera receives the darker ambient/sky environment.
		dark_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		dark_environment.ambient_light_color = Color(.25,.27,.30)
		dark_environment.ambient_light_sky_contribution = 0
		dark_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		dark_environment.glow_enabled = false
		dark_environment.fog_enabled = false
	projection.global_position = _head_position()+Vector3.UP*.95
	camera.look_at(projection.global_position)
	camera.make_current()
	_set_phase(Phase.DIMMING)

func _set_phase(value: int) -> void:
	phase = value;phase_time = 0;phase_changed.emit(value)

func _process(delta: float) -> void:
	if not active:return
	phase_time += delta
	if not is_instance_valid(player) or not is_instance_valid(dog_actor):
		finish(true);return
	if phase==Phase.DIMMING:
		_apply_darkness(smoothstep(0,.8,phase_time))
		if phase_time>=.8:
			video.play()
			key_material.set_shader_parameter("video_frame",video.get_video_texture())
			_set_phase(Phase.VIDEO)
	elif phase==Phase.VIDEO:
		projection.global_position = _head_position()+Vector3.UP*.95
		if projection.global_position.distance_to(camera.global_position)>.01:
			projection.look_at(camera.global_position,Vector3.UP,true)
		projection.visible = phase_time>.1 and video.get_video_texture()!=null
		if phase_time>2 and not video.is_playing():
			finish(true);return
		if phase_time>=video_seconds:_on_video_finished()
	elif phase==Phase.WHITEOUT:
		if phase_time>=white_hold_seconds:
			_restore_lighting()
			_set_phase(Phase.RECOVERY)
	elif phase==Phase.RECOVERY:
		white.color.a = 1-smoothstep(0,maxf(.1,recovery_seconds),phase_time)
		if phase_time>=recovery_seconds:finish(false)

func _apply_darkness(amount: float) -> void:
	for entry in lights:
		if is_instance_valid(entry[0]):entry[0].light_energy = lerpf(entry[1],0.0,amount)
	if dark_environment:
		dark_environment.ambient_light_energy = lerpf(.22,.001,amount)
		dark_environment.background_energy_multiplier = lerpf(1,.01,amount)
	if snapshot.has("rain_db"):game.rain_audio.volume_db = lerpf(snapshot.rain_db,-38,amount)

func _on_video_finished() -> void:
	if not active or phase!=Phase.VIDEO:return
	projection.hide();video.stop()
	white.color.a = 1
	_set_phase(Phase.WHITEOUT)

func _restore_lighting() -> void:
	for entry in lights:
		if is_instance_valid(entry[0]):entry[0].light_energy = entry[1]
	for entry in emissive_surfaces:
		if not is_instance_valid(entry.mesh):continue
		if entry.surface<0:entry.mesh.material_override = entry.original
		else:entry.mesh.set_surface_override_material(entry.surface,entry.original)
	if snapshot.has("rain_db") and is_instance_valid(game.rain_audio):game.rain_audio.volume_db = snapshot.rain_db
	if is_instance_valid(snapshot.get("camera")):snapshot.camera.make_current()
	camera.environment = null;dark_environment = null

func _remember_emission(mesh: MeshInstance3D, surface: int, material_: Material) -> void:
	if not material_ is BaseMaterial3D:return
	if not material_.emission_enabled and material_.shading_mode!=BaseMaterial3D.SHADING_MODE_UNSHADED:return
	var dim := material_.duplicate() as BaseMaterial3D
	dim.emission_enabled = false
	dim.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	dim.albedo_color = Color(.025,.025,.027)
	dim.albedo_texture = null
	# Keep the exact old override (including null), not just the effective material.
	var original: Material = mesh.material_override if surface<0 else mesh.get_surface_override_material(surface)
	emissive_surfaces.append({"mesh":mesh,"surface":surface,"original":original,"dark":dim})

func finish(cancelled := true) -> void:
	if not active:return
	active = false;last_cancelled = cancelled;finish_count += 1
	video.stop();projection.hide();ui.hide();white.color.a = 0
	_restore_lighting()
	for entry in canvases:
		if is_instance_valid(entry[0]):entry[0].visible = entry[1]
	if is_instance_valid(player):
		player.velocity = snapshot.velocity
		player.set_physics_process(snapshot.physics);player.set_process_unhandled_input(snapshot.input)
		player.set_control(snapshot.control)
	if is_instance_valid(dog_actor):dog_actor.set_process(snapshot.dog_process)
	Input.mouse_mode = snapshot.mouse
	game.cinematic_active = snapshot.cinematic
	set_process(false);set_process_input(false)
	_set_phase(Phase.IDLE)
	ended.emit(cancelled)

func _input(event: InputEvent) -> void:
	if not active:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:finish(true)
		elif event.keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:advance()
	if event is InputEventKey or event is InputEventMouseMotion:get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if active:finish(true)
