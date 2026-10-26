extends CanvasLayer
const PaperTheme = preload("res://quest_system/quest_theme.gd")
signal started
signal continued
signal save_requested
signal resumed
signal reset_requested
signal volume_changed(value: float)
signal demo_toggled(enabled: bool)
signal demo_day_requested(number: int)
var hud: Control
var welcome: Control
var pause_panel: Control
var settings_panel: Control
var hint_label: Label
var toast_label: Label
var navigation_label: Label
var interaction_panel: PanelContainer
var start_button: Button
var continue_button: Button
var save_button: Button
var save_summary: Label
var save_feedback: Label
var new_game_confirmation: ConfirmationDialog
var existing_save := false
var toast_time := 0.0
var font: SystemFont
var volume_value := .65
var settings_from_pause := false
var settings_return_button: Button
var resolution_options: OptionButton
var resolution_hint: Label
var fullscreen_option: CheckButton
var volume_slider: HSlider
var settings_scroll: ScrollContainer
var settings_column: VBoxContainer
var demo_mode_enabled := false
var demo_option: CheckButton
var demo_controls: VBoxContainer
var demo_day_options: OptionButton
var demo_jump_button: Button
var demo_notice: PanelContainer
var demo_caption: Label
var windowed_resolution := Vector2i(1280,800)
const WINDOW_RESOLUTIONS := [Vector2i(960,600),Vector2i(1280,720),Vector2i(1280,800),Vector2i(1366,768),Vector2i(1440,900),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]
var prompt_icon: TextureRect
var toast_panel: PanelContainer
var menu_paper: Panel
var menu_column: VBoxContainer
const PAPER := PaperTheme.TEXT
const MUTED := PaperTheme.MUTED
const AMBER := PaperTheme.ACCENT

func _ready() -> void:
	layer = 10
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"])
	make_welcome()
	make_hud()
	make_pause()
	make_settings()
	get_window().size_changed.connect(refresh_display_options,CONNECT_DEFERRED)
	start_button.grab_focus()
	call_deferred("arrange_menu")

func arrange_menu() -> void:
	for child in menu_column.get_children():
		if child is Button and child.text.begins_with("第") and "幕" in child.text:
			menu_column.remove_child(child)
			child.queue_free()
	menu_column.move_child(start_button,3)
	menu_column.move_child(continue_button,4)
	menu_column.move_child(save_summary,5)
	for child in menu_column.get_children():
		if child is Button:PaperTheme.button(child,child==start_button)

func control(parent: Node = self) -> Control:
	var c := Control.new()
	c.theme=PaperTheme.resource()
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
	label.add_theme_constant_override("shadow_offset_y",0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var result := PaperTheme.panel(12)
	if border!=Color.TRANSPARENT:result.border_color=border
	return result

func button(value: String, parent: Node, callback: Callable, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size = Vector2(280,40)
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.add_theme_font_override("font",font)
	result.add_theme_font_size_override("font_size",15)
	PaperTheme.button(result,primary)
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func background(parent: Node, opacity: float) -> void:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(.13,.10,.075,opacity*.62)
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
	menu_paper=Panel.new();menu_paper.name="PaperMenu"
	menu_paper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	PaperTheme.glass(menu_paper,18)
	welcome.add_child(menu_paper)
	var column := VBoxContainer.new()
	menu_column=column
	column.name = "MenuActions"
	column.anchor_left = .065
	column.anchor_right = .065
	column.anchor_top = 0
	column.anchor_bottom = 0
	column.offset_right = 348
	column.add_theme_constant_override("separation",9)
	welcome.add_child(column)
	text("哈基米模拟器",34,PAPER,column)
	text("暖纸手记  /  一只猫的日常",12,MUTED,column)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	column.add_child(spacer)
	start_button = button("新游戏",column,request_new_game,true)
	start_button.name = "StartGame"
	continue_button = button("继续游戏",column,func(): continued.emit())
	continue_button.name = "ContinueGame"
	continue_button.disabled = true
	save_summary = text("正在检查存档……",15,MUTED,column)
	save_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button("设置",column,open_settings).name = "Settings"
	button("退出游戏",column,func(): get_tree().quit()).name = "QuitGame"
	new_game_confirmation = ConfirmationDialog.new()
	new_game_confirmation.title = "开始新游戏"
	new_game_confirmation.dialog_text = "将从第一天重新开始。\n当前进度会被新进度覆盖。\n原存档会先保留一份备份。"
	new_game_confirmation.ok_button_text = "开始新游戏"
	new_game_confirmation.cancel_button_text = "取消"
	new_game_confirmation.theme=PaperTheme.resource()
	new_game_confirmation.add_theme_font_override("font",font)
	var prompt_paper:=PaperTheme.panel(24)
	prompt_paper.bg_color=Color("fff8e8")
	new_game_confirmation.add_theme_stylebox_override("panel",prompt_paper)
	var prompt_border:=PaperTheme.panel(18)
	prompt_border.bg_color=prompt_paper.bg_color
	prompt_border.expand_margin_top=32
	new_game_confirmation.add_theme_stylebox_override("embedded_border",prompt_border)
	new_game_confirmation.add_theme_stylebox_override("embedded_unfocused_border",prompt_border)
	new_game_confirmation.add_theme_font_override("title_font",font)
	new_game_confirmation.add_theme_color_override("title_color",PAPER)
	new_game_confirmation.add_theme_color_override("title_unfocused_color",PAPER)
	new_game_confirmation.add_theme_font_size_override("title_font_size",18)
	var close_image:=Image.new()
	close_image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" stroke="#302b25" stroke-width="2" stroke-linecap="round"><path d="m4 4 8 8m0-8-8 8"/></svg>')
	var close_icon:=ImageTexture.create_from_image(close_image)
	new_game_confirmation.add_theme_icon_override("close",close_icon)
	new_game_confirmation.add_theme_icon_override("close_pressed",close_icon)
	var prompt_label:=new_game_confirmation.get_label()
	prompt_label.add_theme_color_override("font_color",PAPER)
	prompt_label.add_theme_font_size_override("font_size",18)
	prompt_label.add_theme_constant_override("line_spacing",8)
	prompt_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for action_button in [new_game_confirmation.get_ok_button(),new_game_confirmation.get_cancel_button()]:
		PaperTheme.button(action_button,action_button==new_game_confirmation.get_ok_button())
		action_button.add_theme_font_size_override("font_size",16)
	new_game_confirmation.confirmed.connect(func():started.emit())
	new_game_confirmation.canceled.connect(func():start_button.grab_focus())
	add_child(new_game_confirmation)

func request_new_game() -> void:
	if existing_save:
		var popup_width:=mini(560,int(get_viewport().get_visible_rect().size.x)-48)
		new_game_confirmation.popup_centered(Vector2i(popup_width,240))
		for action_button in [new_game_confirmation.get_ok_button(),new_game_confirmation.get_cancel_button()]:
			action_button.custom_minimum_size=Vector2(128,40)
		new_game_confirmation.get_cancel_button().grab_focus()
	else:started.emit()

func update_save_menu(exists: bool, valid: bool, summary: String) -> void:
	existing_save = exists
	continue_button.disabled = not valid
	save_summary.text = summary

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
	PaperTheme.glass(interaction_panel,10)
	hud.add_child(interaction_panel)
	var prompt_row:=HBoxContainer.new();prompt_row.add_theme_constant_override("separation",12)
	interaction_panel.add_child(prompt_row)
	prompt_icon=PaperTheme.symbol("eye",16);prompt_row.add_child(prompt_icon)
	hint_label = text("",14,PAPER,prompt_row)
	hint_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel=PanelContainer.new();toast_panel.name="PaperNotice";toast_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(toast_panel);PaperTheme.glass(toast_panel,10)
	var toast_row:=HBoxContainer.new();toast_row.add_theme_constant_override("separation",10);toast_panel.add_child(toast_row)
	toast_row.add_child(PaperTheme.symbol("check",16))
	toast_label = text("",13,AMBER,toast_row)
	toast_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
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
	navigation_label = text("M  地图     J  任务     Esc  暂停",13,MUTED,navigation)
	demo_notice=PanelContainer.new();demo_notice.name="DemoModeNotice"
	demo_notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	demo_notice.offset_left=24;demo_notice.offset_right=338;demo_notice.offset_top=-96;demo_notice.offset_bottom=-68
	demo_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	PaperTheme.glass(demo_notice,7);hud.add_child(demo_notice)
	demo_caption=text("",12,AMBER,demo_notice);demo_notice.hide()

func center_box(parent: Node, scrollable := false) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var paper:=PanelContainer.new();center.add_child(paper);PaperTheme.glass(paper,20)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	column.custom_minimum_size.x = 400
	if scrollable:
		settings_scroll=ScrollContainer.new()
		settings_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		settings_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
		paper.add_child(settings_scroll);settings_scroll.add_child(column)
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation",10)
		settings_column=column
	else:paper.add_child(column)
	return column

func make_pause() -> void:
	pause_panel = control()
	pause_panel.name = "PauseMenu"
	background(pause_panel,.85)
	var column := center_box(pause_panel)
	text("暂停",26,PAPER,column)
	button("继续游戏",column,func(): pause_panel.hide(); resumed.emit(),true)
	save_button = button("保存游戏",column,func():save_requested.emit())
	save_button.name = "SaveGame"
	save_button.tooltip_text = "保存当前任务、道具和状态；继续游戏时从一楼入口恢复。"
	save_feedback = text("进度会自动保存，也可在这里手动保存。",14,MUTED,column)
	save_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_feedback.custom_minimum_size.x = 400
	button("设置",column,open_settings)
	button("返回客厅",column,func(): reset_requested.emit(); pause_panel.hide(); resumed.emit())
	button("退出游戏",column,func(): get_tree().quit())
	text("WASD 移动   鼠标 环顾   空格 跳跃\nShift 奔跑   Ctrl 低伏   E 开关门\nQ 喵叫   V 看猫   M 地图   B 总览",14,MUTED,column)
	pause_panel.hide()

func make_settings() -> void:
	settings_panel = control()
	settings_panel.name = "SettingsMenu"
	background(settings_panel,.94)
	var column := center_box(settings_panel,true)
	text("设置",26,PAPER,column)
	text("音量",16,MUTED,column)
	var volume := HSlider.new()
	volume_slider=volume
	volume.min_value = 0
	volume.max_value = 1
	volume.step = .05
	volume.value = volume_value
	volume.custom_minimum_size = Vector2(320,40)
	volume.value_changed.connect(func(value: float): volume_value = value; volume_changed.emit(value))
	column.add_child(volume)
	text("窗口分辨率",16,MUTED,column)
	resolution_options=OptionButton.new()
	resolution_options.name="Resolution"
	resolution_options.custom_minimum_size=Vector2(320,40)
	resolution_options.add_theme_font_size_override("font_size",16)
	style_selector(resolution_options)
	resolution_options.item_selected.connect(apply_resolution)
	column.add_child(resolution_options)
	resolution_hint=text("",13,MUTED,column)
	resolution_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	fullscreen_option=CheckButton.new()
	fullscreen_option.text="全屏显示"
	fullscreen_option.add_theme_font_override("font",font)
	fullscreen_option.add_theme_font_size_override("font_size",17)
	fullscreen_option.toggled.connect(set_fullscreen)
	column.add_child(fullscreen_option)
	demo_option=CheckButton.new();demo_option.name="DemoMode"
	demo_option.text="演示模式"
	demo_option.add_theme_font_override("font",font);demo_option.add_theme_font_size_override("font_size",17)
	demo_option.toggled.connect(func(enabled: bool):demo_toggled.emit(enabled))
	column.add_child(demo_option)
	demo_controls=VBoxContainer.new();demo_controls.name="DemoDayControls"
	demo_controls.add_theme_constant_override("separation",8);column.add_child(demo_controls)
	var day_row:=HBoxContainer.new();day_row.add_theme_constant_override("separation",12);demo_controls.add_child(day_row)
	text("演示天数",15,MUTED,day_row)
	demo_day_options=OptionButton.new();demo_day_options.name="DemoDay"
	demo_day_options.custom_minimum_size=Vector2(180,36);demo_day_options.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	style_selector(demo_day_options)
	for number in range(1,12):demo_day_options.add_item("第 %d 天"%number,number)
	day_row.add_child(demo_day_options)
	demo_jump_button=button("进入所选天数",demo_controls,func():demo_day_requested.emit(demo_day_options.get_selected_id()),true)
	var demo_help:=text("演示进度不保存；关闭演示模式后，恢复进入前的正常进度。",13,MUTED,demo_controls)
	demo_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	demo_controls.hide()
	settings_return_button = button("返回",column,close_settings)
	windowed_resolution=get_window().size
	refresh_display_options()
	settings_panel.hide()

func style_selector(selector: OptionButton) -> void:
	PaperTheme.button(selector)
	var popup:=selector.get_popup()
	popup.max_size=Vector2i(0,360)
	popup.add_theme_font_override("font",font);popup.add_theme_font_size_override("font_size",15)
	popup.add_theme_color_override("font_color",PAPER);popup.add_theme_color_override("font_hover_color",PAPER)
	popup.add_theme_color_override("font_disabled_color",MUTED)
	popup.add_theme_stylebox_override("panel",PaperTheme.panel(10))
	popup.add_theme_stylebox_override("hover",PaperTheme.button_style(PaperTheme.SOFT))
	popup.add_theme_constant_override("v_separation",10)

func set_demo_state(enabled: bool, number := 1) -> void:
	demo_mode_enabled=enabled
	demo_option.set_pressed_no_signal(enabled)
	demo_controls.visible=enabled
	demo_day_options.select(clampi(number-1,0,10))

func is_fullscreen() -> bool:
	return get_window().mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]

func refresh_display_options() -> void:
	var fullscreen:=is_fullscreen()
	fullscreen_option.set_pressed_no_signal(fullscreen)
	resolution_options.disabled=fullscreen
	resolution_hint.text="全屏使用显示器原生分辨率，退出后恢复所选窗口尺寸。" if fullscreen else "选择后立即应用；超出可用桌面的尺寸不可选。"
	if not fullscreen:windowed_resolution=get_window().size
	var usable:=DisplayServer.screen_get_usable_rect(get_window().current_screen)
	var available:=usable.size-Vector2i(16,48)
	resolution_options.clear()
	var selected_index:=-1
	for resolution in WINDOW_RESOLUTIONS:
		var index:=resolution_options.item_count
		resolution_options.add_item("%d × %d" % [resolution.x,resolution.y])
		resolution_options.set_item_metadata(index,resolution)
		resolution_options.set_item_disabled(index,resolution.x>available.x or resolution.y>available.y)
		if resolution==windowed_resolution:selected_index=index
	if selected_index<0:
		selected_index=resolution_options.item_count
		resolution_options.add_item("%d × %d（当前）" % [windowed_resolution.x,windowed_resolution.y])
		resolution_options.set_item_metadata(selected_index,windowed_resolution)
	resolution_options.select(selected_index)

func apply_resolution(index: int) -> void:
	if is_fullscreen() or index<0 or index>=resolution_options.item_count or resolution_options.is_item_disabled(index):return
	windowed_resolution=resolution_options.get_item_metadata(index)
	var window:=get_window()
	window.mode=Window.MODE_WINDOWED
	window.size=windowed_resolution
	var usable:=DisplayServer.screen_get_usable_rect(window.current_screen)
	window.position=usable.position+(usable.size-windowed_resolution)/2
	call_deferred("refresh_display_options")

func set_fullscreen(enabled: bool) -> void:
	var window:=get_window()
	if enabled:
		if not is_fullscreen():windowed_resolution=window.size
		window.mode=Window.MODE_FULLSCREEN
	else:
		window.mode=Window.MODE_WINDOWED
		window.size=windowed_resolution
		var usable:=DisplayServer.screen_get_usable_rect(window.current_screen)
		window.position=usable.position+(usable.size-windowed_resolution)/2
	call_deferred("refresh_display_options")

func open_settings() -> void:
	if settings_panel.visible:return
	refresh_display_options()
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
	if interaction_panel.visible:prompt_icon.texture=PaperTheme.icon(PaperTheme.action_icon(hint_label.text))
	toast_panel.visible=toast_time>0 and not toast_label.text.is_empty() and not bool(get_parent().get("cinematic_active"))
	toast_panel.modulate.a=clampf(toast_time,0,1)
	var viewport:=get_viewport().get_visible_rect().size
	var settings_width:=minf(400,viewport.x-88)
	settings_column.custom_minimum_size.x=settings_width-16
	settings_scroll.custom_minimum_size=Vector2(settings_width,minf(settings_column.get_combined_minimum_size().y,viewport.y-88))
	demo_notice.visible=demo_mode_enabled and bool(get_parent().get("started"))
	if demo_notice.visible:
		var day=get_parent().get_node_or_null("DayOne")
		demo_caption.text="演示模式 · 第 %d 天 · 进度不保存"%(day.value("current_day",1) if day else 1)
	var toast_width:=minf(600,viewport.x-80)
	toast_panel.position=Vector2((viewport.x-toast_width)*.5,28)
	toast_panel.size=Vector2(toast_width,0)
	var compact:=viewport.y<700
	menu_column.position=Vector2(44,28 if compact else 48)
	menu_column.size.x=minf(344,viewport.x-88)
	menu_column.add_theme_constant_override("separation",7 if compact else 9)
	for child in menu_column.get_children():
		if child is Button:child.custom_minimum_size.y=36 if compact else 40;child.add_theme_font_size_override("font_size",14 if compact else 15)
	menu_paper.position=Vector2(24,16 if compact else 28)
	menu_paper.size=Vector2(minf(388,viewport.x-48),minf(viewport.y-32,menu_column.get_combined_minimum_size().y+40))
	navigation_label.get_parent().size.x = navigation_label.get_minimum_size().x+26
