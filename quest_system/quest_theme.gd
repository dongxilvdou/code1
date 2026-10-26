@static_unload
extends RefCounted
const Surface = preload("res://ui/paper/paper_surface.gd")
const SURFACE := Color("f5efdf")
const TEXT := Color("302b25")
const MUTED := Color("5c5142")
const ACCENT := Color("85553e")
const SOFT := Color("e8dfcb")
const BORDER := Color("c9baa0")
const SUCCESS := Color("4c654d")
const PAPER := TEXT
const BRASS := ACCENT
const SAGE := SUCCESS
const INK := SURFACE
static var shared_theme: Theme
static var shared_font: SystemFont
const MARKS := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"240\" height=\"24\" fill=\"none\" stroke=\"#85553e\" stroke-width=\"1.7\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><g transform=\"translate(0)\"><path d=\"M7.2 16.8c0-2.7 2.1-5.8 4.8-5.8s4.8 3.1 4.8 5.8c0 2-1.4 2.8-2.9 2.3a5.9 5.9 0 0 0-3.8 0c-1.5.5-2.9-.3-2.9-2.3Z\"/><ellipse cx=\"5.2\" cy=\"10.3\" rx=\"1.6\" ry=\"2.1\"/><ellipse cx=\"9.1\" cy=\"5.9\" rx=\"1.6\" ry=\"2.3\"/><ellipse cx=\"14.9\" cy=\"5.9\" rx=\"1.6\" ry=\"2.3\"/><ellipse cx=\"18.8\" cy=\"10.3\" rx=\"1.6\" ry=\"2.1\"/></g><g transform=\"translate(24)\"><path d=\"M8 12V5a1.5 1.5 0 0 1 3 0v6-7a1.5 1.5 0 0 1 3 0v7-5a1.5 1.5 0 0 1 3 0v6-3a1.5 1.5 0 0 1 3 0v7c0 3.5-2 5-5 5h-3c-2 0-3-1-4-2l-4-5a1.6 1.6 0 0 1 2.3-2.2L8 14\"/></g><g transform=\"translate(48)\"><path d=\"M21 11.5c0 5-4.1 8.5-9 8.5-1.6 0-3-.3-4.2-.9L3 21l1.7-4.6A7.7 7.7 0 0 1 3 11.5C3 6.5 7.1 3 12 3s9 3.5 9 8.5Z\"/><path d=\"M8 10h8M8 14h5\"/></g><g transform=\"translate(72)\"><path d=\"M3 4h6c2 0 3 1 3 2v15c0-2-1-3-3-3H3V4ZM21 4h-6c-2 0-3 1-3 2v15c0-2 1-3 3-3h6V4Z\"/><path d=\"M6 8h3M6 11h3M15 8h3M15 11h3\"/></g><g transform=\"translate(96)\"><path d=\"M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z\"/><circle cx=\"12\" cy=\"12\" r=\"2.6\"/></g><g transform=\"translate(120)\"><path d=\"M4 21h16M6 21V4l11-2v19M17 4h3v17\"/><circle cx=\"13.5\" cy=\"12\" r=\".7\"/></g><g transform=\"translate(144)\"><path d=\"M5 12h14m-6-6 6 6-6 6\"/></g><g transform=\"translate(168)\"><path d=\"m5 12 4 4L19 6\"/></g><g transform=\"translate(192)\"><path d=\"M19 12H5m6-6-6 6 6 6\"/></g><g transform=\"translate(216)\"><circle cx=\"12\" cy=\"12\" r=\"6\" fill=\"#85553e\" stroke=\"none\"/></g></svg>"
static var icons := {}
static var shared_marks: Texture2D
const MARK_NAMES := ["paw","hand","chat","book","eye","door","arrow","check","back","dot"]

static func font() -> SystemFont:
	if shared_font==null:
		shared_font=SystemFont.new()
		shared_font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","PingFang SC","Noto Sans CJK SC","SimHei"])
	return shared_font

static func panel(padding := 18.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=SURFACE;s.border_color=BORDER;s.set_border_width_all(1);s.set_corner_radius_all(9)
	s.set_content_margin_all(padding);s.shadow_color=Color(0.12,0.09,0.06,.12);s.shadow_size=6
	return s

static func button_style(fill: Color, border := BORDER, padding := 8.0) -> StyleBoxFlat:
	var s:=panel(padding)
	s.bg_color=fill;s.border_color=border;s.shadow_size=0;s.set_corner_radius_all(6)
	return s

static func glass(box: Control, padding := 12.0, ornaments := false) -> Node2D:
	var style:=panel(padding);style.bg_color=Color.TRANSPARENT
	box.add_theme_stylebox_override("panel",style)
	var surface:=Surface.new();surface.name="PaperSurface";surface.ornaments=ornaments
	box.add_child(surface);box.move_child(surface,0)
	return surface

static func decorate_dialogue(box: PanelContainer, padding := 24.0) -> Node2D:
	return glass(box,padding,true)

static func resource() -> Theme:
	if shared_theme!=null:return shared_theme
	shared_theme=Theme.new();shared_theme.default_font=font();shared_theme.default_font_size=15
	for type_ in ["Label","RichTextLabel","LineEdit","SpinBox","CheckButton","CheckBox","OptionButton"]:
		shared_theme.set_color("font_color",type_,TEXT)
		shared_theme.set_color("font_focus_color",type_,TEXT)
		shared_theme.set_color("font_hover_color",type_,TEXT)
	shared_theme.set_color("font_placeholder_color","LineEdit",MUTED)
	shared_theme.set_color("caret_color","LineEdit",ACCENT)
	shared_theme.set_color("selection_color","LineEdit",Color("dbc5ab"))
	shared_theme.set_stylebox("normal","LineEdit",button_style(Color("fffbf1")))
	shared_theme.set_stylebox("focus","LineEdit",button_style(Color("fffbf1"),ACCENT))
	for state in ["normal","hover","pressed","focus","disabled"]:
		var s:=button_style(SOFT if state in ["hover","pressed"] else SURFACE,ACCENT if state=="focus" else BORDER)
		if state=="focus":s.bg_color=Color.TRANSPARENT;s.set_border_width_all(2)
		if state=="disabled":s.bg_color=Color("e8e2d7")
		shared_theme.set_stylebox(state,"Button",s)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:shared_theme.set_color(state,"Button",TEXT)
	shared_theme.set_color("font_disabled_color","Button",Color("857a6b"))
	shared_theme.set_color("font_color","TooltipLabel",TEXT)
	shared_theme.set_stylebox("panel","TooltipPanel",panel(12))
	shared_theme.set_stylebox("panel","PopupPanel",panel(18))
	shared_theme.set_stylebox("embedded_border","Window",panel(18))
	shared_theme.set_color("title_color","Window",TEXT)
	for type_ in ["HSlider","VSlider"]:
		var track:=button_style(SOFT,BORDER,3)
		shared_theme.set_stylebox("slider",type_,track)
		shared_theme.set_stylebox("grabber_area",type_,button_style(ACCENT,ACCENT,3))
		shared_theme.set_stylebox("grabber_area_highlight",type_,button_style(ACCENT,ACCENT,3))
		shared_theme.set_icon("grabber",type_,icon("dot"));shared_theme.set_icon("grabber_highlight",type_,icon("dot"))
	for type_ in ["VScrollBar","HScrollBar"]:
		shared_theme.set_stylebox("scroll",type_,button_style(SOFT,SOFT,3))
		for state in ["grabber","grabber_highlight","grabber_pressed"]:shared_theme.set_stylebox(state,type_,button_style(BORDER,BORDER,3))
	return shared_theme

static func button(b: Button, primary := false) -> void:
	b.theme=resource();b.add_theme_font_override("font",font())
	for state in ["normal","hover","pressed","focus","disabled"]:
		var fill:=ACCENT if primary else Color(.96,.94,.87,.45)
		if state in ["hover","pressed"]:fill=Color("71452f") if primary else SOFT
		if state=="disabled":fill=SOFT
		var s:=button_style(fill,ACCENT if state=="focus" else BORDER)
		if state=="focus":s.bg_color=Color.TRANSPARENT;s.set_border_width_all(2)
		b.add_theme_stylebox_override(state,s)
	for color_ in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(color_,Color("fff9ed") if primary else TEXT)
	b.add_theme_color_override("font_disabled_color",MUTED)
	b.add_theme_color_override("icon_normal_color",Color("fff9ed") if primary else ACCENT)
	b.add_theme_color_override("icon_hover_color",Color("fff9ed") if primary else ACCENT)
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND

static func icon(id: String) -> Texture2D:
	if not icons.has(id):
		if shared_marks==null:
			var image:=Image.new();image.load_svg_from_string(MARKS)
			shared_marks=ImageTexture.create_from_image(image)
		var item:=AtlasTexture.new();item.atlas=shared_marks
		item.region=Rect2(maxi(0,MARK_NAMES.find(id))*24,0,24,24)
		icons[id]=item
	return icons[id]

static func symbol(id: String, pixels := 16.0) -> TextureRect:
	var n:=TextureRect.new();n.texture=icon(id);n.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	n.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;n.custom_minimum_size=Vector2.ONE*pixels
	n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return n

static func action_icon(text: String) -> String:
	if "对话" in text or "说话" in text or "阿嚼" in text:return "chat"
	if "叼" in text or "拾" in text or "拿" in text:return "hand"
	if "门" in text:return "door"
	if "纸条" in text or "手记" in text or "册" in text:return "book"
	return "eye"

static func progress(current: int, total: int) -> ProgressBar:
	var bar:=ProgressBar.new();bar.min_value=0;bar.max_value=maxi(1,total);bar.value=current
	bar.show_percentage=false;bar.custom_minimum_size.y=5;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var track:=StyleBoxFlat.new();track.bg_color=SOFT;track.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background",track)
	var fill:=track.duplicate() as StyleBoxFlat;fill.bg_color=SUCCESS if current>=total else ACCENT
	bar.add_theme_stylebox_override("fill",fill)
	return bar
