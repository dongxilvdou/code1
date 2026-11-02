extends CanvasLayer
signal dismissed
const Wallpaper = preload("res://act3/desktop_art.gd")
const DesktopIcon = preload("res://act3/desktop_icon.gd")
const PaperTheme = preload("res://act3/computer_theme.gd")
var chapter
var shell: Control
var login: PanelContainer
var desktop: Control
var password: LineEdit
var hint: Label
var error: Label
var font: SystemFont
var apps
var logged_name: Label

func _ready() -> void:
	layer = 24
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","SimHei"])
	shell = Control.new()
	shell.theme=PaperTheme.resource()
	add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := Wallpaper.new()
	shell.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tint := ColorRect.new()
	tint.color = Color(0.02,.06,.10,.20)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(tint)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header := text("",18,shell)
	header.position = Vector2(34,26)
	var close := Button.new()
	close.text = "退出电脑  ·  Esc"
	close.add_theme_stylebox_override("normal",PaperTheme.box(Color(.08,.12,.19,.58)))
	close.add_theme_color_override("font_color",Color.WHITE)
	close.add_theme_font_override("font",font)
	shell.add_child(close)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -214
	close.offset_top = 18
	close.offset_right = -29
	close.offset_bottom = 58
	close.pressed.connect(close_computer)
	var center := CenterContainer.new()
	shell.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	login = PanelContainer.new()
	login.custom_minimum_size.x = 430
	var card := PaperTheme.box(Color(.96,.97,.98,.97),Color(.7,.75,.8,.5),30,10)
	login.add_theme_stylebox_override("panel",card)
	center.add_child(login)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",17)
	login.add_child(col)
	var avatar_center := CenterContainer.new()
	col.add_child(avatar_center)
	var avatar := Control.new()
	avatar.custom_minimum_size = Vector2(80,76)
	avatar_center.add_child(avatar)
	avatar.draw.connect(func():
		avatar.draw_circle(Vector2(40,38),35,Color("7faaa9"))
		avatar.draw_colored_polygon(PackedVector2Array([Vector2(18,43),Vector2(19,16),Vector2(35,27),Vector2(48,27),Vector2(61,15),Vector2(63,43)]),Color("ebe5d2"))
		avatar.draw_circle(Vector2(40,43),23,Color("ebe5d2"))
		for x in [31,49]:avatar.draw_circle(Vector2(x,41),2.5,Color("456268"))
		avatar.draw_colored_polygon(PackedVector2Array([Vector2(36,48),Vector2(44,48),Vector2(40,53)]),Color("9e7f70")))
	text("欢迎回来",29,col).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text("本地账户",14,col).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	password = LineEdit.new()
	password.secret = true
	password.max_length = 32
	password.placeholder_text = "输入密码"
	password.custom_minimum_size = Vector2(350,48)
	password.add_theme_font_override("font",font)
	password.add_theme_font_size_override("font_size",20)
	col.add_child(password)
	password.text_submitted.connect(func(_value: String):submit_password())
	password.focus_entered.connect(reveal_hint)
	hint = text("在最近的照片上。照片收在一楼客厅桌上的线索册里。",16,col)
	hint.add_theme_color_override("font_color",PaperTheme.MUTED)
	var enter := Button.new()
	enter.text = "登 录"
	enter.add_theme_stylebox_override("normal",PaperTheme.box(PaperTheme.BLUE,Color.TRANSPARENT,10))
	enter.add_theme_color_override("font_color",Color.WHITE)
	enter.custom_minimum_size.y = 46
	enter.add_theme_font_override("font",font)
	col.add_child(enter)
	enter.pressed.connect(submit_password)
	error = text("",15,col)
	error.add_theme_color_override("font_color",Color("b3261e"))
	desktop = Control.new()
	shell.add_child(desktop)
	desktop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desktop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icons=GridContainer.new();icons.columns=1;desktop.add_child(icons);icons.position=Vector2(20,28)
	icons.add_theme_constant_override("h_separation",12);icons.add_theme_constant_override("v_separation",8)
	for i in range(6):
		var id=["computer","documents","photos","recycle","browser","chat"][i]
		var item=Button.new();item.custom_minimum_size=Vector2(102,91)
		item.add_theme_stylebox_override("normal",PaperTheme.box(Color.TRANSPARENT))
		item.add_theme_stylebox_override("hover",PaperTheme.box(Color(1,1,1,.12),Color(1,1,1,.2)))
		item.add_theme_stylebox_override("focus",PaperTheme.box(Color(.35,.65,.94,.25),Color(.7,.85,1,.6)))
		icons.add_child(item)
		item.name=id.to_pascal_case()+"Icon";item.pressed.connect(func():apps.open_app(id))
		var column=VBoxContainer.new();item.add_child(column);column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);column.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var center_icon=CenterContainer.new();column.add_child(center_icon);center_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var icon=DesktopIcon.new();icon.kind=i;icon.custom_minimum_size=Vector2(52,52);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;center_icon.add_child(icon)
		var caption=text(["此电脑","文档","照片","回收站","浏览器","微信"][i],15,column);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.add_theme_color_override("font_color",Color.WHITE);caption.add_theme_color_override("font_shadow_color",Color(.0,.0,.0,.7));caption.add_theme_constant_override("shadow_offset_y",1)
	var taskbar := ColorRect.new()
	taskbar.color = Color(.94,.96,.98,.96)
	desktop.add_child(taskbar)
	taskbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	taskbar.offset_top = -54
	taskbar.offset_bottom = 0
	var launchers=HBoxContainer.new();taskbar.add_child(launchers);launchers.position=Vector2(32,8)
	for entry in [["▦", "computer"],["文件", "documents"],["浏览器", "browser"],["微信", "chat"]]:
		var launcher=Button.new();launcher.text=entry[0];launcher.custom_minimum_size=Vector2(58,38);launchers.add_child(launcher)
		launcher.pressed.connect(func():apps.open_app(entry[1]))
	logged_name = text("简  中    ◉  ♫      09:31\n                         本地账户 C-031",13,taskbar)
	logged_name.add_theme_color_override("font_color",PaperTheme.INK)
	logged_name.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	logged_name.offset_left = -260;logged_name.offset_top = 8;logged_name.offset_right = -20;logged_name.offset_bottom = 49
	apps=preload("res://act3/desktop_apps.gd").new();apps.computer=self;desktop.add_child(apps)
	shell.move_child(close,-1)
	shell.hide()

func text(value: String, size_: int, parent: Node) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size_)
	label.add_theme_color_override("font_color",PaperTheme.INK if is_instance_valid(login) and login.is_ancestor_of(parent) else Color("f0f3eb"))
	parent.add_child(label)
	return label

func open() -> void:
	chapter.reconcile_investigation()
	chapter.refresh_hud()
	shell.show()
	login.visible = not chapter.flag("a7_login")
	desktop.visible = chapter.flag("a7_login")
	password.clear()
	password.release_focus()
	hint.hide()
	error.text = ""

func reveal_hint() -> void:hint.show()

func submit_password() -> void:
	var entered := password.text.strip_edges().to_upper().replace("-","").replace(" ","").replace("－","")
	if entered!="C031":
		error.text = "密码不正确，再想想照片上的名字。"
		password.select_all()
		return
	chapter.complete_login()
	login.hide()
	desktop.show()

func close_computer() -> void:
	apps.close_all()
	shell.hide()
	dismissed.emit()

func _input(event: InputEvent) -> void:
	if not shell.visible or not chapter.day.reader.mode.is_empty():return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if not apps.back():close_computer()
		get_viewport().set_input_as_handled()
