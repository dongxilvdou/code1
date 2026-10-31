extends Node3D
## Two-step optional room event. Owns no quest state or persistent room changes.
signal begun
signal ended(cancelled: bool)
enum Phase {IDLE, WARNING, CLOSING, DIMMING, PLAYING, RECOVERY}
const ThemeArt = preload("res://quest_system/quest_theme.gd")
const KeyShader = preload("res://shaders/dog_secret_key.gdshader")
const ButtonScene = preload("res://furniture_pack/scenes/hidden_red_button.tscn")
const VIDEO_PATH := "res://assets/easter_eggs/bedroom_secret/cat_sway.ogv"
@export var desk: Node3D
@export var bed: Node3D
@export var room_door: Node3D
@export var room_bounds := Rect2(-.8,-6.0,6.8,3.6)
@export var video_seconds := 6.0
var phase := Phase.IDLE
var phase_time := 0.0
var active := false
var finish_count := 0
var world_taken := false
var snapshot := {}
var lamps: Array = []
var surfaces: Array = []
var canvases: Array = []
var game: Node
var player: CharacterBody3D
var button: Node3D
var video: VideoStreamPlayer
var projection: MeshInstance3D
var camera: Camera3D
var fill: OmniLight3D
var ui: CanvasLayer
var warning: Control
var confirm_button: Button
var cancel_button: Button
var fade: ColorRect

func _ready() -> void:
	game = get_parent();player = game.get_node("Miso")
	button = ButtonScene.instantiate()
	desk.add_child(button)
	button.position = Vector3(-.40,.715,.18)
	video = VideoStreamPlayer.new();video.name = "CatMemeDecoder"
	video.stream = load(VIDEO_PATH);video.loop = false;video.expand = true
	video.size = Vector2(768,576);video.modulate.a = 0
	# Transparent decoder must not consume first-person mouse look.
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE;video.focus_mode = Control.FOCUS_NONE
	add_child(video);video.finished.connect(_movie_end)
	projection = MeshInstance3D.new();projection.name = "CatAboveBed"
	var quad := QuadMesh.new();quad.size = Vector2(1.8,1.35);projection.mesh = quad
	var key := ShaderMaterial.new();key.shader = KeyShader;projection.material_override = key
	# This dark cat clip needs a tighter matte than the bright dog clip.
	key.set_shader_parameter("key_low",.015);key.set_shader_parameter("key_high",.12)
	projection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(projection);projection.hide()
	camera = Camera3D.new();camera.name = "BedroomSecretCamera";camera.near = .035;add_child(camera)
	fill = OmniLight3D.new();fill.name = "LowVisibilityFill";fill.light_energy = 0
	fill.light_color = Color(.38,.46,.58);fill.omni_range = 5;add_child(fill)
	_make_ui();set_process(false);set_process_input(false)

func available() -> bool:
	if active or not game.started or game.cinematic_active or not player.active or game.photo or game.inspecting:return false
	if not room_bounds.has_point(Vector2(player.global_position.x,player.global_position.z)) or absf(player.global_position.y-desk.global_position.y)>.8:return false
	var eye: Vector3 = player.camera.global_position
	var delta: Vector3 = button.to_global(Vector3(0,-.04,0))-eye
	if delta.length()>1.1 or (-player.camera.global_basis.z).dot(delta.normalized())<.65:return false
	var query := PhysicsRayQueryParameters3D.create(eye,eye+delta,1,[player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func target_hint() -> String:
	return "[ E ]  按下桌底的红色按钮" if available() else ""

func try_interact() -> bool:
	if not available():return false
	return open_warning()

func open_warning() -> bool:
	if active or game.cinematic_active or not player.active or video.stream==null:return false
	snapshot = {"control":player.active,"physics":player.is_physics_processing(),
		"input":player.is_processing_unhandled_input(),"mouse":Input.mouse_mode,
		"camera":get_viewport().get_camera_3d(),"velocity":player.velocity,"cinematic":game.cinematic_active}
	active = true;finish_count = 0;world_taken = false
	game.cinematic_active = true
	player.set_control(false);player.set_physics_process(false);player.set_process_unhandled_input(false)
	ui.show();warning.show();fade.color.a = 0;cancel_button.grab_focus()
	_set_phase(Phase.WARNING);set_process(true);set_process_input(true)
	return true

func confirm() -> void:
	if not active or phase!=Phase.WARNING:return
	if video.stream==null:finish(true);return
	warning.hide()
	snapshot.door = {"open":room_door.is_open,"angle":room_door.target_angle,
		"leaf":room_door.leaf.transform,"moving":room_door.moving,
		"blocked":room_door.blocked,"locked":room_door.locked}
	lamps.clear();surfaces.clear();canvases.clear()
	for lamp in game.find_children("*","Light3D",true,false):
		if lamp!=fill:lamps.append([lamp,lamp.light_energy])
	for mesh in game.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or mesh==projection:continue
		var point: Vector3 = mesh.global_position
		if point.y<2.9 or point.y>6.1 or not room_bounds.grow(.2).has_point(Vector2(point.x,point.z)):continue
		if mesh.material_override!=null:_remember_surface(mesh,-1,mesh.material_override)
		else:
			for i in range(mesh.mesh.get_surface_count()):_remember_surface(mesh,i,mesh.get_active_material(i))
	for canvas in game.find_children("*","CanvasLayer",true,false):
		if canvas!=ui:canvases.append([canvas,canvas.visible]);canvas.hide()
	world_taken = true
	room_door.locked = true;room_door.set_open(false)
	_set_phase(Phase.CLOSING)
	begun.emit()

func _remember_surface(mesh: MeshInstance3D, surface: int, material_: Material) -> void:
	if not material_ is BaseMaterial3D:return
	if not material_.emission_enabled and material_.shading_mode!=BaseMaterial3D.SHADING_MODE_UNSHADED:return
	var dim := material_.duplicate() as BaseMaterial3D
	dim.emission_enabled = false;dim.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	dim.albedo_color = Color(.025,.025,.03);dim.albedo_texture = null
	var original: Material = mesh.material_override if surface<0 else mesh.get_surface_override_material(surface)
	surfaces.append({"mesh":mesh,"surface":surface,"original":original,"dim":dim})

func _start_dimming() -> void:
	for entry in surfaces:
		if entry.surface<0:entry.mesh.material_override = entry.dim
		else:entry.mesh.set_surface_override_material(entry.surface,entry.dim)
	var original: Camera3D = snapshot.camera
	camera.global_transform = original.global_transform;camera.fov = original.fov;camera.cull_mask = original.cull_mask
	var environment := original.environment if original.environment!=null else get_viewport().world_3d.environment
	if environment:
		camera.environment = environment.duplicate()
		camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		camera.environment.ambient_light_energy = .025
		camera.environment.ambient_light_color = Color(.35,.40,.48)
		camera.environment.ambient_light_sky_contribution = 0
		camera.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		camera.environment.background_energy_multiplier = .04
		camera.environment.glow_enabled = false
	projection.global_position = bed.global_position+Vector3(0,1.30,0)
	if not _place_clear_camera():
		finish(true);return
	camera.look_at(projection.global_position)
	fill.global_position = bed.global_position+Vector3(0,1.4,0)
	camera.make_current();_set_phase(Phase.DIMMING)

func _place_clear_camera() -> bool:
	# The button is under a desk/chair. Keep the actor there, but cut to a clear
	# bedside shot rather than aiming the film through furniture.
	var sphere := SphereShape3D.new();sphere.radius = .06
	for offset in [Vector3(-1.25,.82,.35),Vector3(-1.35,.85,-.35),Vector3(0,.90,1.30),Vector3(1.3,.85,.25)]:
		var point: Vector3 = bed.global_position+offset
		var shape := PhysicsShapeQueryParameters3D.new();shape.shape = sphere
		shape.transform = Transform3D(Basis.IDENTITY,point);shape.collision_mask = 1
		if not get_world_3d().direct_space_state.intersect_shape(shape,1).is_empty():continue
		var clear := true
		for margin in [Vector3.ZERO,Vector3(0,.38,0),Vector3(0,-.38,0)]:
			var ray := PhysicsRayQueryParameters3D.create(point,projection.global_position+margin,1)
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():clear = false;break
		if clear:
			camera.global_position = point
			return true
	return false

func _set_phase(value: int) -> void:
	phase = value;phase_time = 0

func _process(delta: float) -> void:
	if not active:return
	phase_time += delta
	if phase==Phase.CLOSING:
		if not room_door.moving and not room_door.is_open:_start_dimming()
		elif phase_time>2.5:finish(true)
	elif phase==Phase.DIMMING:
		var amount := smoothstep(0,.45,phase_time)
		for entry in lamps:entry[0].light_energy = lerpf(entry[1],0,amount)
		fill.light_energy = .11*amount
		if phase_time>=.45:
			video.play()
			projection.material_override.set_shader_parameter("video_frame",video.get_video_texture())
			_set_phase(Phase.PLAYING)
	elif phase==Phase.PLAYING:
		projection.look_at(camera.global_position,Vector3.UP,true)
		projection.visible = phase_time>.08
		if phase_time>=video_seconds:_movie_end()
		elif phase_time>2 and not video.is_playing():finish(true)
	elif phase==Phase.RECOVERY:
		fade.color.a = .30*(1-smoothstep(0,.3,phase_time))
		if phase_time>=.3:finish(false)

func _movie_end() -> void:
	if not active or phase!=Phase.PLAYING:return
	video.stop();projection.hide();_restore_world()
	fade.color.a = .30;_set_phase(Phase.RECOVERY)

func _restore_world() -> void:
	if not world_taken:return
	for entry in lamps:
		if is_instance_valid(entry[0]):entry[0].light_energy = entry[1]
	for entry in surfaces:
		if not is_instance_valid(entry.mesh):continue
		if entry.surface<0:entry.mesh.material_override = entry.original
		else:entry.mesh.set_surface_override_material(entry.surface,entry.original)
	for entry in canvases:
		if is_instance_valid(entry[0]):entry[0].visible = entry[1]
	var state: Dictionary = snapshot.door
	room_door.is_open = state.open;room_door.target_angle = state.angle;room_door.leaf.transform = state.leaf
	room_door.moving = state.moving;room_door.blocked = state.blocked;room_door.locked = state.locked
	fill.light_energy = 0;camera.environment = null
	if is_instance_valid(snapshot.camera):snapshot.camera.make_current()
	world_taken = false

func finish(cancelled := true) -> void:
	if not active:return
	active = false;finish_count += 1;video.stop();projection.hide();ui.hide()
	_restore_world()
	player.velocity = snapshot.velocity
	player.set_physics_process(snapshot.physics);player.set_process_unhandled_input(snapshot.input);player.set_control(snapshot.control)
	Input.mouse_mode = snapshot.mouse;game.cinematic_active = snapshot.cinematic
	_set_phase(Phase.IDLE);set_process(false);set_process_input(false)
	ended.emit(cancelled)

func _make_ui() -> void:
	ui = CanvasLayer.new();ui.layer = 111;add_child(ui)
	var root := Control.new();ui.add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning = Control.new();root.add_child(warning);warning.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warning.theme=ThemeArt.resource()
	var shade := ColorRect.new();shade.color = Color(0,0,0,.45);shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new();warning.add_child(center);center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new();card.add_theme_stylebox_override("panel",ThemeArt.panel(24));center.add_child(card)
	ThemeArt.decorate_dialogue(card)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",20);card.add_child(column)
	var font := SystemFont.new();font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"])
	var label := Label.new();label.text = "可能有精神污染，请勿随意触摸";column.add_child(label)
	label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",15)
	label.add_theme_color_override("font_color",ThemeArt.BRASS)
	confirm_button = Button.new();confirm_button.text = "再次按下  ·  E";confirm_button.pressed.connect(confirm)
	cancel_button = Button.new();cancel_button.text = "不碰了  ·  Esc";cancel_button.pressed.connect(func():finish(true))
	for action in [confirm_button,cancel_button]:
		action.custom_minimum_size.y = 44;action.add_theme_font_override("font",font);ThemeArt.button(action);column.add_child(action)
	fade = ColorRect.new();fade.color = Color(0,0,0,0);fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade);fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.hide()

func _input(event: InputEvent) -> void:
	if not active:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:finish(true)
		elif phase==Phase.WARNING and event.keycode==KEY_E:confirm()
		elif phase==Phase.WARNING and event.keycode in [KEY_SPACE,KEY_ENTER]:return
	if event is InputEventKey or event is InputEventMouseMotion:get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if active:finish(true)
