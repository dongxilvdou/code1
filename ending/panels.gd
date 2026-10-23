extends CanvasLayer
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

func _ready() -> void:
	layer=45
	shell=Control.new();shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shell)
	var shade:=ColorRect.new();shade.color=Color(.015,.025,.028,.78);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shell.add_child(shade)
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shell.add_child(center)
	var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(720,0);center.add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color("182c2e");style.border_color=Color("78938a");style.set_border_width_all(1);style.set_corner_radius_all(10)
	style.content_margin_left=36;style.content_margin_right=36;style.content_margin_top=30;style.content_margin_bottom=30
	panel.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",22);panel.add_child(column)
	heading=Label.new();heading.add_theme_font_size_override("font_size",29);heading.add_theme_color_override("font_color",Color("e7ddbf"));column.add_child(heading)
	body=Label.new();body.custom_minimum_size.x=648;body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_theme_font_size_override("font_size",21);body.add_theme_color_override("font_color",Color("e0e6da"));body.add_theme_constant_override("line_spacing",9);column.add_child(body)
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
	for child in actions.get_children():actions.remove_child(child);child.queue_free()
	first_button=null
	for option in options:
		var button:=Button.new();button.text=option[1];button.custom_minimum_size.y=48;button.add_theme_font_size_override("font_size",20)
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
