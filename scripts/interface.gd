extends CanvasLayer
signal started
signal resumed
signal reset_requested
signal volume_changed(value: float)
var hud: Control
var welcome: Control
var pause_panel: Control
var room_label: Label
var progress_label: Label
var hint_label: Label
var toast_label: Label
var compass_label: Label
var height_label: Label
var pause_title: Label
var toast_time := 0.0
var font: SystemFont
const PAPER := Color(.89,.86,.76)
const MUTED := Color(.53,.63,.61)
const AMBER := Color(.84,.62,.34)

func _ready() -> void:
	layer = 10
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"])
	make_welcome()
	make_hud()
	make_pause()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette := ShaderMaterial.new()
	vignette.shader = load("res://shaders/vignette.gdshader")
	shade.material = vignette
	add_child(shade)
	move_child(shade,0)

func control(parent: Node = self) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

func text(value: String, size: int, color: Color = PAPER, parent: Node = self) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_override("font",font)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.add_theme_color_override("font_shadow_color",Color(.01,.03,.035,.9))
	l.add_theme_constant_override("shadow_outline_size",4)
	l.add_theme_constant_override("shadow_offset_y",1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 21
	s.content_margin_right = 21
	s.content_margin_top = 13
	s.content_margin_bottom = 13
	return s

func button(value: String, parent: Node, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size = Vector2(292,54)
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_color_override("font_color",Color(.075,.13,.13) if primary else PAPER)
	b.add_theme_color_override("font_hover_color",Color(.06,.11,.11) if primary else Color.WHITE)
	b.add_theme_stylebox_override("normal",style(AMBER if primary else Color(.055,.105,.112,.95),Color(.28,.37,.35)))
	b.add_theme_stylebox_override("hover",style(Color(.97,.78,.46) if primary else Color(.13,.23,.23),AMBER))
	b.add_theme_stylebox_override("pressed",style(Color(.70,.51,.28) if primary else Color(.08,.15,.16)))
	b.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,AMBER))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func line(parent: Node, pos: Vector2, length: float) -> void:
	var c := ColorRect.new()
	c.color = Color(.53,.60,.53,.5)
	c.position = pos
	c.size = Vector2(length,1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)

func background(parent: Node, opacity: float) -> void:
	var c := ColorRect.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.color = Color(.018,.040,.046,opacity)
	parent.add_child(c)

func make_welcome() -> void:
	welcome = control()
	background(welcome,.65)
	var left := VBoxContainer.new()
	left.position = Vector2(72,100)
	left.add_theme_constant_override("separation",18)
	welcome.add_child(left)
	text("A SMALL CAT. A BIG WORLD.",15,AMBER,left)
	text("猫屋日记",72,PAPER,left)
	text("C A L I C O",24,MUTED,left)
	text("花园别墅",31,PAPER,left)
	text("两层新家  /  先从房子开始",16,AMBER,left)
	text("以三花猫的视角，探索两层别墅和花园。\n走上楼梯，看看露台，寻找新家的每一个角落。",17,PAPER,left)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	left.add_child(spacer)
	button("开始探索   →",left,func(): welcome.hide(); hud.show(); started.emit(),true)
	text("W A S D  移动     鼠标  环顾     空格  跳跃\nShift  奔跑    Ctrl  低伏    E  互动    Q  喵叫",14,MUTED,left)
	var caption := text("01  /  THE GARDEN VILLA\nB 查看房屋全貌，家具将在后续逐步添置。",14,MUTED,welcome)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	caption.position = Vector2(72,-66)
	# A separate 3D portrait shows the complete controllable calico.
	var frame := PanelContainer.new()
	frame.anchor_left = .60
	frame.anchor_right = .94
	frame.anchor_top = .19
	frame.anchor_bottom = .79
	frame.add_theme_stylebox_override("panel",style(Color(.035,.075,.079,.55),Color(.24,.34,.31,.7)))
	welcome.add_child(frame)
	var portrait := SubViewportContainer.new()
	portrait.stretch = true
	portrait.custom_minimum_size = Vector2(380,420)
	frame.add_child(portrait)
	var vp := SubViewport.new()
	vp.size = Vector2i(480,480)
	vp.own_world_3d = true
	vp.transparent_bg = true
	portrait.add_child(vp)
	var cat: Node3D = load("res://scenes/calico.tscn").instantiate()
	cat.rotation.y = -.32
	vp.add_child(cat)
	var cam := Camera3D.new()
	cam.position = Vector3(.75,.49,-.88)
	cam.fov = 42
	cam.cull_mask = 3
	vp.add_child(cam)
	cam.look_at(Vector3(0,.30,0))
	cam.current = true
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(.035,.07,.073,0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(.74,.79,.77)
	e.ambient_light_energy = .8
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45,-35,0)
	key.light_color = Color(1,.83,.61)
	key.light_energy = 1.1
	vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-.3,.6,.6)
	rim.light_color = Color(.3,.75,.87)
	rim.light_energy = 1.4
	rim.omni_range = 2
	vp.add_child(rim)
	var name_label := text("米酥  /  MISO\n三花猫 · 眼高约 22 cm",16,PAPER,welcome)
	name_label.anchor_left = .61
	name_label.anchor_top = .81

func make_hud() -> void:
	hud = control()
	hud.hide()
	var tag := text("C A L I C O    /    花园别墅",14,AMBER,hud)
	tag.position = Vector2(32,25)
	room_label = text("客厅",28,PAPER,hud)
	room_label.position = Vector2(32,48)
	var chapter := text("01  /  两层新家",13,MUTED,hud)
	chapter.position = Vector2(33,87)
	line(hud,Vector2(32,115),160)
	progress_label = text("两层别墅 + 花园\n自由探索 / B 查看房屋",15,PAPER,hud)
	progress_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	progress_label.offset_left = -220
	progress_label.offset_top = 32
	progress_label.offset_right = -24
	progress_label.offset_bottom = 96
	compass_label = text("N  /  北",13,MUTED,hud)
	compass_label.anchor_left = .5
	compass_label.anchor_right = .5
	compass_label.position = Vector2(-42,27)
	var dot := ColorRect.new()
	dot.color = Color(.95,.91,.78,.64)
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot.offset_left = -2
	dot.offset_right = 2
	dot.offset_top = -2
	dot.offset_bottom = 2
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dot)
	hint_label = text("",19,PAPER,hud)
	hint_label.anchor_left = .5
	hint_label.anchor_right = .5
	hint_label.anchor_top = .73
	hint_label.anchor_bottom = .73
	hint_label.offset_left = -330
	hint_label.offset_right = 330
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = text("",18,AMBER,hud)
	toast_label.anchor_left = .5
	toast_label.anchor_right = .5
	toast_label.anchor_top = .82
	toast_label.offset_left = -470
	toast_label.offset_right = 470
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var keys := text("E 开关门   ·   空格 跳跃   ·   Q 喵叫   ·   V 看猫   ·   B 看房屋   ·   Esc 暂停",13,MUTED,hud)
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	keys.offset_left = 32
	keys.offset_top = -40
	height_label = text("米酥  /  眼高约 22 cm",13,AMBER,hud)
	height_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	height_label.offset_left = -210
	height_label.offset_top = -40
	height_label.offset_right = -32

func center_box(parent: Node) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	column.custom_minimum_size.x = 440
	center.add_child(column)
	return column

func make_pause() -> void:
	pause_panel = control()
	background(pause_panel,.91)
	var c := center_box(pause_panel)
	text("P A U S E",14,AMBER,c)
	pause_title = text("在雨声中停一会儿",30,PAPER,c)
	text("W A S D 移动  /  鼠标 环顾  /  空格 跳跃\nShift 奔跑  /  Ctrl 低伏  /  Q 喵叫\nE 开关门  /  V 查看猫  /  B 查看房屋",15,MUTED,c)
	button("继续探索",c,func(): pause_panel.hide(); resumed.emit(),true)
	button("回到客厅入口",c,func(): reset_requested.emit(); pause_panel.hide(); resumed.emit())
	var volume_row := HBoxContainer.new()
	c.add_child(volume_row)
	text("雨声与音效",14,MUTED,volume_row)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = .05
	volume.value = .65
	volume.custom_minimum_size.x = 230
	volume.value_changed.connect(func(value: float): volume_changed.emit(value))
	volume_row.add_child(volume)
	button("离开游戏",c,func(): get_tree().quit())
	pause_panel.hide()

func toast(value: String, duration: float = 4.0) -> void:
	toast_label.text = value
	toast_time = duration

func _process(delta: float) -> void:
	toast_time -= delta
	toast_label.modulate.a = clampf(toast_time,0,1)
	if toast_time<=0:toast_label.text = ""
