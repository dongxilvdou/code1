extends Control
## Optional, external integration sample for the supplied code1 main scene.
## Instance villa_map.tscn under the main root. Original scripts need no edits.
const MapCanvas = preload("res://villa_maps/map_canvas.gd")
const MapTextures = preload("res://villa_maps/map_textures.gd")
const PaperTheme = preload("res://quest_system/quest_theme.gd")
const ASSET_ROOT := "res://villa_maps/"
@export var player_path := NodePath("../../Miso")
@export var minimap_position := Vector2(16, 16)
@export var minimap_size := Vector2(124, 124)
var player: CharacterBody3D
var camera: Camera3D
var game: Node
var maps: Dictionary = {}
var cache: Dictionary = {}
var current_map := ""
var current_floor := "floor_1"
var current_room := ""
var map_angle := 0.0
var big_open := false
var mini: Control
var big: Control
var mini_title: Label
var big_title: Label
var shade: ColorRect
var mini_back: Panel
var mini_day: Label
var mini_chapter: Label

func _ready() -> void:
	theme=PaperTheme.resource()
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player = get_node_or_null(player_path) as CharacterBody3D
	game = get_node_or_null("../..")
	if player == null:
		push_error("VillaMap: instance this scene below the main root containing Miso.")
		set_process(false)
		set_process_input(false)
		set_physics_process(false)
		return
	camera = player.get_node_or_null("CatEyes/FirstPersonCamera") as Camera3D
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASSET_ROOT + "layout.json"))
	if not parsed is Dictionary:
		push_error("VillaMap: missing or invalid layout.json.")
		set_process(false)
		set_process_input(false)
		set_physics_process(false)
		return
	maps = parsed.maps
	mini_back = Panel.new()
	mini_back.name = "MinimapCard"
	mini_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_back.position = minimap_position
	mini_back.size = minimap_size+Vector2(12,56)
	add_child(mini_back)
	PaperTheme.glass(mini_back,6)
	var header:=HBoxContainer.new();header.mouse_filter=Control.MOUSE_FILTER_IGNORE
	header.position=Vector2(6,4);header.size=Vector2(minimap_size.x,18);header.add_theme_constant_override("separation",4);mini_back.add_child(header)
	header.add_child(PaperTheme.symbol("paw",12))
	mini_day=Label.new();mini_day.add_theme_font_size_override("font_size",11);mini_day.mouse_filter=Control.MOUSE_FILTER_IGNORE;header.add_child(mini_day)
	mini_chapter=Label.new();mini_chapter.add_theme_font_size_override("font_size",11);mini_chapter.add_theme_color_override("font_color",PaperTheme.MUTED)
	mini_chapter.clip_text=true;mini_chapter.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;mini_chapter.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(mini_chapter)
	mini = MapCanvas.new()
	add_child(mini)
	mini.position = minimap_position+Vector2(6,26)
	mini.size = minimap_size
	mini_title = make_label(11)
	mini_title.add_theme_color_override("font_color",PaperTheme.TEXT)
	mini_title.position = minimap_position + Vector2(6, minimap_size.y + 31)
	mini_title.size=Vector2(minimap_size.x-20,19);mini_title.clip_text=true;mini_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var map_key:=Label.new();map_key.text="M";map_key.add_theme_font_size_override("font_size",11);map_key.position=Vector2(minimap_size.x-7,minimap_size.y+31);map_key.mouse_filter=Control.MOUSE_FILTER_IGNORE;mini_back.add_child(map_key)
	shade = ColorRect.new()
	shade.color = Color(0.025,0.05,0.06,0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	big = MapCanvas.new()
	big.set("large", true)
	add_child(big)
	big_title = make_label(22)
	shade.hide()
	big.hide()
	big_title.hide()
	# Supports a player initially placed on another level, without using eye height.
	current_floor = "floor_2" if player.global_position.y >= 2.6 else "floor_1"

func make_label(font_size: int) -> Label:
	var label := Label.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f0ebdb"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func available() -> bool:
	if not is_instance_valid(game) or not bool(game.get("started")):
		return false
	if bool(game.get("cinematic_active")):return false
	if bool(game.get("photo")) or bool(game.get("inspecting")):
		return false
	var ui: Variant = game.get("ui")
	return is_instance_valid(ui) and is_instance_valid(ui.pause_panel) and not ui.pause_panel.visible and not ui.settings_panel.visible

func _input(event: InputEvent) -> void:
	if not is_instance_valid(player) or not available():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M or event.keycode == KEY_M:
			set_big(not big_open)
			get_viewport().set_input_as_handled()
		elif big_open and event.keycode == KEY_ESCAPE:
			set_big(false)
			get_viewport().set_input_as_handled()
	# Existing B/V/E handlers use _unhandled_input. Do not activate them under the map.
	if big_open:
		get_viewport().set_input_as_handled()

func set_big(open: bool) -> void:
	if open and not available():return
	big_open = open
	player.call("set_control", not open and available())
	shade.visible = open
	big.visible = open
	big_title.visible = open
	mini.visible = not open
	mini_title.visible = not open
	mini_back.visible = not open

func support_floor() -> String:
	# A short ray from the CAT ROOT, not the head. Keeps a jump on the same floor.
	# Descendant names survive mesh batching and identify furniture as well as slabs.
	var p := player.global_position
	var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.10, p - Vector3.UP * 0.35, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return ""
	var node: Node = hit.collider
	while is_instance_valid(node):
		match String(node.name):
			"Basement": return "basement"
			"UpperFloor": return "floor_2"
			"GroundFloor": return "floor_1"
			"Staircase": return "stairs"
			"Garden": return "garden"
		node = node.get_parent()
	return ""

func choose_map(p: Vector3, support: String) -> String:
	var q := Vector2(p.x,p.z)
	if maps.has("basement") and (support=="basement" or p.y<-.25):
		return "basement"
	if current_map=="basement" and p.y>=-.1:current_floor = "floor_1"
	# Match the existing game's shaft region, with 6 cm exit hysteresis.
	var shaft := Rect2(3.2,-2.4,2.8,3.9)
	if current_map == "stairs":
		shaft = shaft.grow(0.06)
	if shaft.has_point(q):
		return "stairs"
	if support == "floor_1" or support == "floor_2":
		current_floor = support
	elif current_map == "stairs":
		# Resolve the stair endpoint even while jumping across the threshold.
		current_floor = "floor_2" if p.y >= 2.6 else "floor_1"
	if not Rect2(-6.14,-6.14,12.28,12.28).has_point(q):
		return "garden"
	if support == "garden":
		return "garden"
	return current_floor

func room_at(spec: Dictionary, p: Vector2) -> Dictionary:
	for item in spec.regions:
		var polygon := PackedVector2Array()
		for vertex in item.polygon_xz:
			polygon.append(Vector2(vertex[0],vertex[1]))
		if Geometry2D.is_point_in_polygon(p, polygon):
			return item
	return {}

func fetch_texture(path: String) -> Texture2D:
	if not cache.has(path):
		var texture := MapTextures.load_texture(ASSET_ROOT+path)
		if texture==null:return null
		cache[path] = texture
	return cache[path] as Texture2D

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or maps.is_empty():
		return
	var p := player.global_position
	var selected := choose_map(p, support_floor())
	if selected != current_map:
		current_map = selected
		var spec: Dictionary = maps[selected]
		for canvas in [mini,big]:
			canvas.set("spec", spec)
			canvas.set("base_texture", fetch_texture(spec.base))
			canvas.set("structure_texture", fetch_texture(spec.structure))
			canvas.set("labels_texture", fetch_texture(spec.labels))
	var position_xz := Vector2(p.x,p.z)
	var room := room_at(maps[current_map], position_xz)
	current_room = String(room.get("name", ""))
	# Outdoor paths must stay legible; only rooms and stair sections are brightened.
	mini.set("region", {} if current_map == "garden" else room)
	for canvas in [mini,big]:
		canvas.set("position_xz", position_xz)

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or maps.is_empty():
		return
	if not available():
		# Other game screens own input now; do not force re-enable the player.
		big_open = false
		hide()
		shade.hide()
		big.hide()
		big_title.hide()
		return
	show()
	mini.visible = not big_open
	mini_title.visible = not big_open
	mini_back.visible = not big_open
	if current_map.is_empty():
		return
	if is_instance_valid(camera):
		var forward := -camera.global_basis.z
		var flat := Vector2(forward.x, forward.z)
		if flat.length_squared() > 0.00001:
			map_angle = -flat.angle() - PI/2.0
	mini.set("map_angle", map_angle)
	mini.set("pixels_per_metre", 60.0 if current_map in ["stairs","basement"] else 11.0 if current_map == "garden" else 22.0)
	mini_title.text = "%s · %s" % [maps[current_map].name, current_room]
	var day:=game.get_node_or_null("DayOne")
	if day!=null and day.initialized:
		mini_day.text="第 %d 天"%day.value("current_day",1)
		mini_chapter.text=day.hud.day_title.text.get_slice("/",1).strip_edges()
	var viewport_size := get_viewport_rect().size
	var side := maxf(160.0, minf(viewport_size.x-96, viewport_size.y-180))
	big.size = Vector2(side, side)
	big.position = (viewport_size-big.size)*0.5 + Vector2(0,20)
	big_title.position = big.position + Vector2(0,-46)
	big_title.text = "%s   N ↑      M / Esc 关闭" % maps[current_map].name
	mini.queue_redraw()
	big.queue_redraw()

func _exit_tree() -> void:
	if big_open and is_instance_valid(player) and is_instance_valid(game) and not game.is_queued_for_deletion() and available():
		player.call("set_control", true)
