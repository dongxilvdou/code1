extends Node3D
## Optional world props. No quest, input-map, player or camera state is modified.
const KeyShader = preload("res://shaders/house_meme_key.gdshader")
const BananaScene = preload("res://furniture_pack/scenes/easter_banana.tscn")
const SwitchScene = preload("res://furniture_pack/scenes/tv_power_switch.tscn")
const CurtainStandee = preload("res://scripts/cinematics/curtain_standee.gd")
@export var television: Node3D
@export var kitchen_counter: Node3D
@export var play_seconds := 5.0
var game: Node
var player: CharacterBody3D
var tv_switch: Node3D
var banana: Node3D
var entries := {}
var screen: MeshInstance3D
var original_screen: Material
var original_art: Array = []
var indicator: StandardMaterial3D
var curtain_secret: Node3D

func _ready() -> void:
	game = get_parent();player = game.get_node("Miso")
	tv_switch = SwitchScene.instantiate();television.add_child(tv_switch)
	tv_switch.position = Vector3(0,-.12,.30)
	indicator = StandardMaterial3D.new();indicator.albedo_color = Color("819285")
	indicator.emission_enabled = true;indicator.emission = Color("72ce9b");indicator.emission_energy_multiplier = 0
	for name_ in ["PowerRing","PowerStroke"]:tv_switch.get_node(name_).material_override = indicator
	screen = television.get_node("Print_field");original_screen = screen.material_override
	var black := StandardMaterial3D.new();black.albedo_color = Color("080c0b");black.roughness = .32
	screen.material_override = black
	for name_ in ["Sun","Layered_hills","Layered_hills2","Layered_hills3"]:
		var art: Node3D = television.get_node(name_)
		original_art.append([art,art.visible]);art.hide()
	banana = BananaScene.instantiate();kitchen_counter.add_child(banana)
	banana.position = Vector3(0,.900,.25);banana.rotation.y = -.24
	_create_clip("tv","fresh_cat.ogv",television,Vector3(0,.43,.055),Vector2(1.07,.602),tv_switch)
	_create_clip("banana","banana_cat.ogv",kitchen_counter,Vector3(0,1.00,.25),Vector2(.42,.252),banana)
	curtain_secret=CurtainStandee.new();curtain_secret.name="CurtainStandee"
	add_child(curtain_secret);curtain_secret.setup(game)
	set_process(false)

func _create_clip(id: String, file: String, parent_: Node3D, position_: Vector3, size_: Vector2, target: Node3D) -> void:
	var decoder := VideoStreamPlayer.new();decoder.name = id.to_pascal_case()+"MemeDecoder"
	decoder.stream = load("res://assets/easter_eggs/house_memes/"+file)
	decoder.loop = false;decoder.expand = true;decoder.size = Vector2(960,540);decoder.modulate.a = 0
	decoder.mouse_filter = Control.MOUSE_FILTER_IGNORE;decoder.focus_mode = Control.FOCUS_NONE
	add_child(decoder);decoder.finished.connect(finish.bind(id))
	var plane := MeshInstance3D.new();plane.name = id.to_pascal_case()+"MemeProjection"
	var quad := QuadMesh.new();quad.size = size_;plane.mesh = quad
	var key := ShaderMaterial.new();key.shader = KeyShader
	plane.material_override = key;plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent_.add_child(plane);plane.position = position_;plane.hide()
	entries[id] = {"video":decoder,"plane":plane,"target":target,"elapsed":0.0,"playing":false}

func _gameplay_available() -> bool:
	return game.started and player.active and not game.cinematic_active and not game.photo and not game.inspecting

func target_id() -> String:
	if not _gameplay_available():return ""
	var view := get_viewport().get_camera_3d()
	if view==null:return ""
	var eye := view.global_position
	for id in entries:
		var entry: Dictionary = entries[id]
		if not entry.target.is_visible_in_tree():continue
		var point: Vector3 = entry.target.global_position+Vector3(0,.035,0)
		var delta := point-eye
		if delta.length()>1.25 or (-view.global_basis.z).dot(delta.normalized())<.72:continue
		var query := PhysicsRayQueryParameters3D.create(eye,point,1,[player.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
		return id
	return ""

func target_hint() -> String:
	var curtain_hint: String=curtain_secret.target_hint()
	if not curtain_hint.is_empty():return curtain_hint
	match target_id():
		"tv":return "[ E ]  "+("关闭电视" if entries.tv.playing else "打开电视")
		"banana":return "[ E ]  看看这根香蕉"
	return ""

func try_interact() -> bool:
	if curtain_secret.try_interact():return true
	var id := target_id()
	if id.is_empty():return false
	if entries[id].playing:finish(id)
	else:start(id)
	return true

func start(id: String) -> bool:
	if not entries.has(id) or not _gameplay_available():return false
	var entry: Dictionary = entries[id]
	if entry.playing or entry.video.stream==null:return false
	for other in entries:finish(other)
	entry.playing = true;entry.elapsed = 0.0
	if id=="banana":banana.hide()
	else:indicator.emission_energy_multiplier = .65
	entry.video.play();entry.plane.material_override.set_shader_parameter("video_frame",entry.video.get_video_texture())
	set_process(true)
	return true

func finish(id: String) -> void:
	if not entries.has(id):return
	var entry: Dictionary = entries[id]
	if not entry.playing:return
	entry.playing = false;entry.video.stop();entry.plane.hide()
	if id=="banana" and is_instance_valid(banana):banana.show()
	elif id=="tv" and is_instance_valid(indicator):indicator.emission_energy_multiplier = 0
	var any_playing := false
	for other in entries:
		if entries[other].playing:any_playing = true
	set_process(any_playing)

func _process(delta: float) -> void:
	if not _gameplay_available():
		for id in entries:finish(id)
		return
	var view := get_viewport().get_camera_3d()
	for id in entries:
		var entry: Dictionary = entries[id]
		if not entry.playing:continue
		entry.elapsed += delta
		if entry.elapsed>=play_seconds or (entry.elapsed>1.0 and not entry.video.is_playing()):finish(id);continue
		entry.plane.visible = entry.elapsed>.08
		if id=="banana" and view and entry.plane.global_position.distance_to(view.global_position)>.01:
			entry.plane.look_at(view.global_position,Vector3.UP,true)
		var distance_: float = entry.plane.global_position.distance_to(player.camera.global_position)
		entry.video.volume_db = -8.0+linear_to_db(clampf(1.5/maxf(1.5,distance_),.03,1))

func _exit_tree() -> void:
	for id in entries:finish(id)
	if is_instance_valid(screen):screen.material_override = original_screen
	for entry in original_art:
		if is_instance_valid(entry[0]):entry[0].visible = entry[1]
