extends Node3D
## Independent catalogue; never instances or modifies the villa/game scene.
var items: Array = []
var selected := 0
var piece: Node3D
var cat: Node3D
var camera: Camera3D
var platform: Node3D
var ui: Control
var title: Label
var dimensions: Label
var description: Label
var picker: ItemList
var yaw := .66
var pitch := .28
var distance := 4.4
var focus := Vector3(0,.55,0)
var eye_view := false
var dragging := false
var grid_mode := false
var grid: Node3D

func _ready() -> void:
	items = JSON.parse_string(FileAccess.get_file_as_string("res://furniture_pack/catalog.json")).items
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("d9d6ca")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e4e7e7")
	env.ambient_light_energy = .40
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = .3
	env.ssao_intensity = 1.3
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-32,0)
	sun.light_color = Color(1,.95,.86)
	sun.light_energy = .9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 35
	sun.shadow_blur = 1.5
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,145,0)
	fill.light_color = Color(.82,.90,1)
	fill.light_energy = .25
	add_child(fill)
	camera = Camera3D.new()
	camera.near = .02
	camera.far = 100
	camera.fov = 40
	camera.current = true
	camera.cull_mask = 0xfffff
	add_child(camera)
	platform = Node3D.new()
	add_child(platform)
	make_box(platform,Vector3(0,-.035,0),Vector3(70,.06,70),Color("c5c0b0"))
	# Real 0.5 m floor marks, visible from the cat's eye height.
	for i in range(-8,9):
		make_box(platform,Vector3(i*.5,-.003,0),Vector3(.003,.002,8),Color("b4b1a5"))
		make_box(platform,Vector3(0,-.003,i*.5),Vector3(8,.002,.003),Color("b4b1a5"))
	cat = load("res://scenes/calico.tscn").instantiate()
	cat.preview_pose = "idle"
	add_child(cat)
	cat.scale = Vector3.ONE*.8
	make_ui()
	select(0)
	get_window().title = "猫屋日记 · 独立家具资产预览"

func make_box(parent: Node3D, p: Vector3, size: Vector3, color: Color) -> void:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = p
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .9
	n.material_override = m
	parent.add_child(n)

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","SimHei"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	ui.theme = theme
	var panel := Panel.new()
	panel.position = Vector2(24,24)
	panel.size = Vector2(268,710)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.12,.16,.14,.95)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel",style)
	ui.add_child(panel)
	var heading := Label.new()
	heading.text = "CALICO  /  家具系列"
	heading.position = Vector2(44,43)
	heading.add_theme_font_size_override("font_size",23)
	ui.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "20 件独立资产 · 暖木与鼠尾草绿"
	subtitle.position = Vector2(44,82)
	subtitle.add_theme_font_size_override("font_size",13)
	ui.add_child(subtitle)
	picker = ItemList.new()
	picker.position = Vector2(38,120)
	picker.size = Vector2(240,596)
	picker.add_theme_constant_override("line_separation",8)
	picker.add_theme_font_size_override("font_size",16)
	var clear := StyleBoxEmpty.new()
	picker.add_theme_stylebox_override("panel",clear)
	for record in items:picker.add_item(record.name)
	picker.item_selected.connect(select)
	ui.add_child(picker)
	title = Label.new()
	title.position = Vector2(334,38)
	title.add_theme_font_size_override("font_size",30)
	title.add_theme_color_override("font_color",Color("293a32"))
	ui.add_child(title)
	dimensions = Label.new()
	dimensions.position = Vector2(336,84)
	dimensions.add_theme_color_override("font_color",Color("415346"))
	ui.add_child(dimensions)
	description = Label.new()
	description.position = Vector2(336,120)
	description.size.x = 1020
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size",15)
	description.add_theme_color_override("font_color",Color("48594b"))
	ui.add_child(description)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 320
	bottom.offset_right = -24
	bottom.offset_top = -90
	bottom.offset_bottom = -24
	var bottom_style := StyleBoxFlat.new()
	bottom_style.bg_color = Color(.12,.16,.14,.93)
	bottom_style.set_corner_radius_all(10)
	bottom_style.content_margin_left = 18
	bottom_style.content_margin_top = 10
	bottom_style.content_margin_bottom = 10
	bottom.add_theme_stylebox_override("panel",bottom_style)
	ui.add_child(bottom)
	var help := Label.new()
	help.text = "拖动鼠标旋转 · 滚轮缩放 · ← / → 切换家具 · R 复位\nC 猫眼高度 / 全景  ·  G 总览  ·  H 隐藏界面  ·  地面每格 0.5 m"
	help.add_theme_font_size_override("font_size",14)
	bottom.add_child(help)

func select(index: int) -> void:
	selected = wrapi(index,0,items.size())
	grid_mode = false
	if grid: grid.hide()
	if piece: piece.free()
	var record: Dictionary = items[selected]
	piece = load(record.scene).instantiate()
	add_child(piece)
	cat.show()
	cat.position = Vector3(-record.dimensions_m[0]*.5-.40,0,.45)
	cat.rotation.y = PI*.80
	title.text = "%02d   %s" % [selected+1,record.name]
	dimensions.text = "宽 %.2f × 深 %.2f × 高 %.2f m     /     %s" % [record.dimensions_m[0],record.dimensions_m[2],record.dimensions_m[1],record.room]
	description.text = record.note
	picker.select(selected)
	eye_view = false
	yaw = .66
	pitch = .28
	distance = maxf(record.dimensions_m[0]+.85,record.dimensions_m[1]+.6)*2.15
	focus = Vector3(-.22,record.dimensions_m[1]*.44,0)
	update_camera()

func update_camera() -> void:
	if eye_view:
		camera.position = Vector3(sin(yaw)*distance,.224,cos(yaw)*distance)
		camera.look_at(Vector3(0,.224,0))
	else:
		camera.position = focus + Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
		camera.look_at(focus)
	# Offset optical centre to leave space for the catalogue sidebar.
	camera.h_offset = -.38 if ui.visible and not grid_mode else 0

func overview() -> void:
	grid_mode = not grid_mode
	if not grid_mode:
		select(selected)
		return
	piece.hide()
	cat.hide()
	if grid == null:
		grid = Node3D.new()
		add_child(grid)
		for i in range(items.size()):
			var n: Node3D = load(items[i].scene).instantiate()
			n.position = Vector3((i%5-2)*3.1,0,(i/5-1.5)*3.5)
			grid.add_child(n)
			var label := Label3D.new()
			label.text = "%02d  %s" % [i+1,items[i].name]
			label.position = n.position+Vector3(0,.025,1.5)
			label.rotation.x = -PI*.5
			label.font_size = 36
			label.pixel_size = .008
			label.modulate = Color("293a32")
			label.outline_size = 0
			label.no_depth_test = false
			var font := SystemFont.new()
			font.font_names = PackedStringArray(["Microsoft YaHei"])
			label.font = font
			grid.add_child(label)
	grid.show()
	title.text = "CALICO   /   20 件家具总览"
	dimensions.text = "全部保持真实尺寸 · 单独场景 · 原点位于地面"
	description.text = "点击左侧名称返回单件预览。"
	eye_view = false
	yaw = .17
	pitch = .91
	distance = 28
	focus = Vector3(0,0,0)
	update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance*(.90 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.11),.5,45)
			update_camera()
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x*.008
		pitch = clampf(pitch+event.relative.y*.006,.05,1.45)
		update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT:select(selected+1)
			KEY_LEFT:select(selected-1)
			KEY_R:select(selected)
			KEY_C:
				if not grid_mode:
					eye_view = not eye_view
					distance = 3.2 if eye_view else 4.5
					update_camera()
			KEY_G:overview()
			KEY_H:
				ui.visible = not ui.visible
				update_camera()
			KEY_ESCAPE:get_tree().quit()
