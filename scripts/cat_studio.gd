extends Node3D
var cat: Node3D
var camera: Camera3D
var overlay: MeshInstance3D
var lines := ImmediateMesh.new()
var joints: Array[MeshInstance3D] = []
var show_bones := false
var clay := false
var yaw := .64
var elevation := .24
var distance := 1.25
var pose := "idle"
var text_label: Label
const POSES := ["idle","walk","run","crouch","jump","stretch","sit","tailwag"]
const LABELS := ["站立","行走","奔跑","低伏","跳跃","伸展","坐下","摆尾"]

func _ready() -> void:
	cat = $Calico
	cat.preview_pose = "idle"
	camera = $Camera3D
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.055,.070,.077)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.70,.76,.79)
	environment.ambient_light_energy = .62
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.15
	environment.ssao_radius = .12
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45,-35,0)
	key.light_color = Color(1,.90,.76)
	key.light_energy = 1.3
	key.shadow_enabled = true
	key.shadow_blur = 1.3
	add_child(key)
	for info in [[Vector3(-.7,.7,.5),Color(.48,.68,.92),1.4],[Vector3(.5,.25,-1.0),Color(.9,.85,.72),.5]]:
		var lamp := OmniLight3D.new()
		lamp.position = info[0]
		lamp.light_color = info[1]
		lamp.light_energy = info[2]
		lamp.omni_range = 3
		add_child(lamp)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = .53
	floor_mesh.bottom_radius = .53
	floor_mesh.height = .012
	floor_mesh.radial_segments = 128
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position.y = -.008
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(.105,.130,.139)
	floor_mat.roughness = .8
	floor_node.material_override = floor_mat
	add_child(floor_node)
	var bone_mat := StandardMaterial3D.new()
	bone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bone_mat.albedo_color = Color(.98,.65,.22)
	bone_mat.no_depth_test = true
	bone_mat.render_priority = 100
	overlay = MeshInstance3D.new()
	overlay.mesh = lines
	overlay.material_override = bone_mat
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(overlay)
	for i in range(cat.skeleton.get_bone_count()):
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = .0026
		sphere.height = .0052
		sphere.radial_segments = 10
		sphere.rings = 6
		dot.mesh = sphere
		dot.material_override = bone_mat
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dot)
		joints.append(dot)
	make_ui()
	update_camera()

func make_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","SimHei"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = theme
	canvas.add_child(ui)
	var title := Label.new()
	title.text = "三花  /  模型与骨骼"
	title.add_theme_font_size_override("font_size",30)
	title.position = Vector2(36,30)
	ui.add_child(title)
	text_label = Label.new()
	text_label.position = Vector2(38,80)
	text_label.add_theme_color_override("font_color",Color(.72,.77,.76))
	ui.add_child(text_label)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	row.offset_left = 36
	row.offset_top = -105
	row.offset_bottom = -58
	row.add_theme_constant_override("separation",9)
	ui.add_child(row)
	for i in range(POSES.size()):
		var b := Button.new()
		b.text = "%d  %s" % [i+1,LABELS[i]]
		b.custom_minimum_size = Vector2(98,43)
		var s := StyleBoxFlat.new()
		s.bg_color = Color(.12,.18,.20)
		s.border_color = Color(.38,.47,.45)
		s.set_border_width_all(1)
		s.set_corner_radius_all(3)
		s.content_margin_left = 13
		s.content_margin_right = 13
		s.content_margin_top = 10
		s.content_margin_bottom = 10
		b.add_theme_stylebox_override("normal",s)
		b.pressed.connect(set_pose.bind(POSES[i]))
		row.add_child(b)
	var toggles := HBoxContainer.new()
	toggles.position = Vector2(36,134)
	ui.add_child(toggles)
	for label in ["B  显示骨骼","C  灰模"]:
		var b := CheckButton.new()
		b.text = label
		toggles.add_child(b)
		if label.begins_with("B"):b.toggled.connect(func(value: bool):show_bones = value)
		else:b.toggled.connect(set_clay)
	var help := Label.new()
	help.text = "鼠标拖动旋转  ·  滚轮缩放  ·  空格冻结姿态  ·  1—8 切换动作"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 38
	help.offset_top = -35
	help.offset_bottom = -14
	help.add_theme_font_size_override("font_size",13)
	help.add_theme_color_override("font_color",Color(.67,.74,.74))
	ui.add_child(help)

func set_pose(value: String) -> void:
	pose = value
	cat.preview_pose = value
	cat.animate = true
	cat.clock = 0

func set_clay(value: bool) -> void:
	clay = value
	var material: StandardMaterial3D
	if clay:
		material = StandardMaterial3D.new()
		material.albedo_color = Color(.46,.52,.53)
		material.roughness = .72
	cat.get_node("AnatomicalMesh").material_override = material

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x*.008
		elevation = clampf(elevation+event.relative.y*.006,-.1,.75)
		update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:distance = maxf(.70,distance-.08)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:distance = minf(2.1,distance+.08)
		update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode>=KEY_1 and event.keycode<=KEY_8:set_pose(POSES[event.keycode-KEY_1])
		if event.keycode==KEY_B:show_bones = not show_bones
		if event.keycode==KEY_C:set_clay(not clay)
		if event.keycode==KEY_SPACE:cat.animate = not cat.animate

func update_camera() -> void:
	var center := Vector3(0,.24,-.01)
	camera.position = center+Vector3(sin(yaw)*cos(elevation),sin(elevation),-cos(yaw)*cos(elevation))*distance
	camera.look_at(center)

func _process(_delta: float) -> void:
	text_label.text = "%s 三角面  /  47 骨骼  /  8 组动作\n独立 UV 毛色 · 短毛细节 · 足爪逆运动学 · 13 节尾骨" % cat.rig_data.stats.triangles
	if not show_bones:
		overlay.hide()
		for dot in joints:dot.hide()
		return
	overlay.show()
	lines.clear_surfaces()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(cat.skeleton.get_bone_count()):
		var p: Vector3 = cat.skeleton.get_bone_global_pose(i).origin
		joints[i].position = p
		joints[i].show()
		var parent: int = cat.skeleton.get_bone_parent(i)
		if parent>=0:
			lines.surface_add_vertex(p)
			lines.surface_add_vertex(cat.skeleton.get_bone_global_pose(parent).origin)
	lines.surface_end()
