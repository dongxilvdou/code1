extends CanvasLayer
const PaperTheme = preload("res://quest_system/quest_theme.gd")
signal action(id: String)
var shell: Control
var heading: Label
var body: Label
var actions: VBoxContainer
var mode := ""
var first_button: Button
var caption: Label
var blackout: ColorRect
var eyelids: Array[ColorRect] = []
var film_root: Control
var paper_panel: PanelContainer
var reading: ScrollContainer
var dimmer: ColorRect

func _ready() -> void:
	layer=45
	shell=Control.new();shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shell)
	shell.theme=PaperTheme.resource()
	var shade:=ColorRect.new();dimmer=shade;shade.color=Color(.10,.075,.05,.43);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shell.add_child(shade)
	var center:=Control.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shell.add_child(center)
	var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(720,0);center.add_child(panel)
	paper_panel=panel
	var style:=PaperTheme.panel(28)
	panel.add_theme_stylebox_override("panel",style)
	PaperTheme.decorate_dialogue(panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);panel.add_child(column)
	var title_row:=HBoxContainer.new();title_row.add_theme_constant_override("separation",10);column.add_child(title_row)
	title_row.add_child(PaperTheme.symbol("chat",16))
	heading=Label.new();heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;heading.add_theme_font_size_override("font_size",14);heading.add_theme_color_override("font_color",PaperTheme.ACCENT);title_row.add_child(heading)
	reading=ScrollContainer.new();reading.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;reading.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;column.add_child(reading)
	body=Label.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_theme_font_size_override("font_size",15);body.add_theme_color_override("font_color",PaperTheme.TEXT);body.add_theme_constant_override("line_spacing",5);reading.add_child(body)
	actions=VBoxContainer.new();actions.add_theme_constant_override("separation",10);column.add_child(actions)
	film_root=Control.new();film_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;film_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(film_root)
	for i in range(2):
		var lid:=ColorRect.new();lid.color=Color("03080a");lid.mouse_filter=Control.MOUSE_FILTER_IGNORE;film_root.add_child(lid);eyelids.append(lid)
	blackout=ColorRect.new();blackout.color=Color(0,0,0,0);blackout.mouse_filter=Control.MOUSE_FILTER_IGNORE;blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);film_root.add_child(blackout)
	caption=Label.new();caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_top=-148;caption.offset_bottom=-55
	caption.add_theme_font_size_override("font_size",24);caption.add_theme_color_override("font_color",Color("f0ecda"));caption.add_theme_color_override("font_shadow_color",Color.BLACK);caption.add_theme_constant_override("shadow_offset_y",2)
	film_root.add_child(caption)
	move_child(film_root,0)
	close();film_root.hide()

func show_panel(kind: String, title: String, text_: String, options: Array) -> void:
	mode=kind;heading.text=title;body.text=text_
	reading.scroll_vertical=0
	for child in actions.get_children():actions.remove_child(child);child.queue_free()
	first_button=null
	for option in options:
		var button:=Button.new();button.text=option[1];button.custom_minimum_size.y=36;button.add_theme_font_size_override("font_size",13)
		PaperTheme.button(button)
		button.add_theme_constant_override("icon_max_width",14)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		if options.size()>1:button.icon=PaperTheme.icon("arrow")
		var id: String=option[0]
		button.pressed.connect(func():action.emit(id));actions.add_child(button)
		if first_button==null:first_button=button
	shell.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if first_button:first_button.grab_focus()

func close() -> void:
	mode="";shell.hide()

func shade_lids(amount: float) -> void:
	var viewport:=get_viewport().get_visible_rect().size
	var height:=viewport.y*clampf(amount,0,.47)
	eyelids[0].position=Vector2.ZERO;eyelids[0].size=Vector2(viewport.x,height)
	eyelids[1].position=Vector2(0,viewport.y-height);eyelids[1].size=Vector2(viewport.x,height)

func _process(_delta: float) -> void:
	if not shell.visible:return
	var viewport:=get_viewport().get_visible_rect().size
	var narrative:=mode in ["story","cage","camera","locked_vent","memory"]
	var width:=minf(minf(1000,viewport.x*.74) if narrative else 650,viewport.x-64)
	paper_panel.custom_minimum_size.x=width
	body.size.x=width-48
	reading.custom_minimum_size.y=clampf(body.get_minimum_size().y,60,viewport.y*(.40 if narrative else .43))
	paper_panel.size=Vector2(width,0)
	paper_panel.position=Vector2((viewport.x-width)*.5,viewport.y-paper_panel.size.y-30 if narrative else maxf(20,(viewport.y-paper_panel.size.y)*.5))
	dimmer.color.a=.08 if narrative else .16

func _input(event: InputEvent) -> void:
	if not shell.visible:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			# A recollection and the unlocked escape both have exactly one answer.
			if mode in ["story","cage","camera","locked_vent"]:action.emit("close")
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_1,KEY_2,KEY_3] and mode=="device":
			action.emit("choice%d"%(event.keycode-KEY_0));get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_E,KEY_SPACE] and actions.get_child_count()==1:
			first_button.pressed.emit();get_viewport().set_input_as_handled()
