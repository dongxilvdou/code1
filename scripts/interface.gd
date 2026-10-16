extends CanvasLayer
signal started
signal resumed
signal reset_requested
signal volume_changed(value: float)
var hud: Control
var welcome: Control
var pause_panel: Control
var settings_panel: Control
var hint_label: Label
var toast_label: Label
var navigation_label: Label
var interaction_panel: PanelContainer
var start_button: Button
var toast_time := 0.0
var font: SystemFont
var volume_value := .65
var settings_from_pause := false
var settings_return_button: Button
const PAPER := Color("e9e7dc")
const MUTED := Color("b2b9af")
const AMBER := Color("caa36a")

func _ready() -> void:
	layer = 10
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"])
	make_welcome()
	make_hud()
	make_pause()
	make_settings()
	start_button.grab_focus()

func control(parent: Node = self) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

func text(value: String, size: int, color: Color = PAPER, parent: Node = self) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,.45))
	label.add_theme_constant_override("shadow_offset_y",1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(6)
	result.content_margin_left = 22
	result.content_margin_right = 22
	result.content_margin_top = 12
	result.content_margin_bottom = 12
	return result

func button(value: String, parent: Node, callback: Callable, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size = Vector2(300,52)
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.add_theme_font_override("font",font)
	result.add_theme_font_size_override("font_size",18)
	result.add_theme_color_override("font_color",Color("252c27") if primary else PAPER)
	result.add_theme_color_override("font_focus_color",Color("252c27") if primary else PAPER)
	result.add_theme_color_override("font_hover_color",Color("202820") if primary else Color.WHITE)
	result.add_theme_stylebox_override("normal",style(AMBER if primary else Color(.06,.085,.073,.46)))
	result.add_theme_stylebox_override("hover",style(Color("dfbd87") if primary else Color(.18,.23,.20,.85)))
	result.add_theme_stylebox_override("pressed",style(Color("b78c52") if primary else Color(.10,.15,.12,.9)))
	result.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,Color(.83,.74,.57,.65)))
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func background(parent: Node, opacity: float) -> void:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(.025,.038,.032,opacity)
	parent.add_child(rect)

func make_welcome() -> void:
	welcome = control()
	welcome.name = "MainMenu"
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/menu_backdrop.gdshader")
	shade.material = material
	welcome.add_child(shade)
	var column := VBoxContainer.new()
	column.name = "MenuActions"
	column.anchor_left = .065
	column.anchor_right = .065
	column.anchor_top = .27
	column.anchor_bottom = .27
	column.offset_right = 348
	column.add_theme_constant_override("separation",12)
	welcome.add_child(column)
	text("猫屋日记",64,PAPER,column)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	column.add_child(spacer)
	start_button = button("开始游戏",column,func(): started.emit(),true)
	start_button.name = "StartGame"
	button("设置",column,open_settings).name = "Settings"
	button("退出游戏",column,func(): get_tree().quit()).name = "QuitGame"

func make_hud() -> void:
	hud = control()
	hud.name = "HUD"
	hud.hide()
	var dot := ColorRect.new()
	dot.color = Color(.94,.94,.88,.6)
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot.offset_left = -1
	dot.offset_right = 1
	dot.offset_top = -1
	dot.offset_bottom = 1
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dot)
	interaction_panel = PanelContainer.new()
	interaction_panel.name = "InteractionPrompt"
	interaction_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_panel.offset_left = -210
	interaction_panel.offset_right = 210
	interaction_panel.offset_top = -116
	interaction_panel.offset_bottom = -70
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_panel.add_theme_stylebox_override("panel",style(Color(.025,.04,.032,.76)))
	hud.add_child(interaction_panel)
	hint_label = text("",17,PAPER,interaction_panel)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label = text("",16,AMBER,hud)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_left = -320
	toast_label.offset_right = 320
	toast_label.offset_top = -166
	toast_label.offset_bottom = -126
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var navigation := PanelContainer.new()
	navigation.name = "NavigationHints"
	navigation.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	navigation.offset_left = 24
	navigation.offset_top = -58
	navigation.offset_right = 324
	navigation.offset_bottom = -24
	navigation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := style(Color(.025,.04,.032,.70))
	panel.content_margin_left = 13
	panel.content_margin_right = 13
	panel.content_margin_top = 7
	panel.content_margin_bottom = 7
	navigation.add_theme_stylebox_override("panel",panel)
	hud.add_child(navigation)
	navigation_label = text("M  地图     B  总览     Esc  暂停",13,MUTED,navigation)

func center_box(parent: Node) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	column.custom_minimum_size.x = 400
	center.add_child(column)
	return column

func make_pause() -> void:
	pause_panel = control()
	pause_panel.name = "PauseMenu"
	background(pause_panel,.85)
	var column := center_box(pause_panel)
	text("暂停",34,PAPER,column)
	button("继续游戏",column,func(): pause_panel.hide(); resumed.emit(),true)
	button("设置",column,open_settings)
	button("返回客厅",column,func(): reset_requested.emit(); pause_panel.hide(); resumed.emit())
	button("退出游戏",column,func(): get_tree().quit())
	text("WASD 移动   鼠标 环顾   空格 跳跃\nShift 奔跑   Ctrl 低伏   E 开关门\nQ 喵叫   V 看猫   M 地图   B 总览",14,MUTED,column)
	pause_panel.hide()

func make_settings() -> void:
	settings_panel = control()
	settings_panel.name = "SettingsMenu"
	background(settings_panel,.94)
	var column := center_box(settings_panel)
	text("设置",34,PAPER,column)
	text("音量",16,MUTED,column)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = .05
	volume.value = volume_value
	volume.custom_minimum_size = Vector2(320,40)
	volume.value_changed.connect(func(value: float): volume_value = value; volume_changed.emit(value))
	column.add_child(volume)
	var fullscreen := CheckButton.new()
	fullscreen.text = "全屏显示"
	fullscreen.add_theme_font_override("font",font)
	fullscreen.add_theme_font_size_override("font_size",17)
	fullscreen.button_pressed = DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(value: bool): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED))
	column.add_child(fullscreen)
	settings_return_button = button("返回",column,close_settings)
	settings_panel.hide()

func open_settings() -> void:
	if settings_panel.visible:return
	settings_from_pause = pause_panel.visible
	welcome.hide()
	pause_panel.hide()
	hud.hide()
	settings_panel.show()
	settings_return_button.grab_focus()

func close_settings() -> void:
	settings_panel.hide()
	pause_panel.visible = settings_from_pause
	welcome.visible = not settings_from_pause
	if welcome.visible:start_button.grab_focus()

func _input(event: InputEvent) -> void:
	if settings_panel.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		close_settings()
		get_viewport().set_input_as_handled()

func toast(value: String, duration: float = 4.0) -> void:
	toast_label.text = value
	toast_time = duration

func _process(delta: float) -> void:
	toast_time -= delta
	toast_label.modulate.a = clampf(toast_time,0,1)
	if toast_time<=0:toast_label.text = ""
	interaction_panel.visible = not hint_label.text.is_empty()
	navigation_label.get_parent().size.x = navigation_label.get_minimum_size().x+26
