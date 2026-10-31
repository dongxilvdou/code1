extends CanvasLayer
const QuestTheme = preload("res://quest_system/quest_theme.gd")
signal continued
var card: PanelContainer
var status: Label
var guidance: Label
var carry: Label
var overlay: Control
var heading: Label
var body: Label
var next_button: Button
var balance_panel: PanelContainer
var balance_text: Label
var cursor: ColorRect
var font: SystemFont
var day_title: Label
var dialog_panel: PanelContainer
var task_progress: ProgressBar
var body_scroll: ScrollContainer
var carry_panel: PanelContainer

func _ready() -> void:
	layer = 25
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"])
	var canvas := Control.new()
	canvas.theme=QuestTheme.resource()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	card = PanelContainer.new()
	canvas.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	card.offset_left = -344
	card.offset_right = -24
	card.offset_top = 24
	QuestTheme.glass(card,12)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	card.add_child(column)
	var day_row:=HBoxContainer.new();day_row.add_theme_constant_override("separation",9);column.add_child(day_row)
	day_row.add_child(QuestTheme.symbol("book",15))
	var task_heading:=label("今天的事情",11,day_row,QuestTheme.BRASS)
	task_heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	day_title = label("第一天  /  陌生的家",11,day_row,QuestTheme.BRASS)
	day_title.hide()
	day_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	guidance = label("",14,column)
	task_progress = QuestTheme.progress(0,4)
	column.add_child(task_progress)
	task_progress.hide()
	var footer:=HBoxContainer.new();column.add_child(footer)
	status = label("",11,footer,QuestTheme.MUTED)
	status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var journal_key:=label("J 手记",11,footer,QuestTheme.MUTED)
	journal_key.autowrap_mode=TextServer.AUTOWRAP_OFF
	carry_panel=PanelContainer.new();carry_panel.name="CarriedItemNote";canvas.add_child(carry_panel);QuestTheme.glass(carry_panel,10)
	var carry_row:=HBoxContainer.new();carry_row.add_theme_constant_override("separation",10);carry_panel.add_child(carry_row)
	carry_row.add_child(QuestTheme.symbol("hand",16))
	carry = label("",12,carry_row,QuestTheme.MUTED)
	carry.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	overlay = Control.new()
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(.10,.075,.05,.08)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := Control.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	dialog_panel = panel
	panel.custom_minimum_size = Vector2(620,0)
	panel.add_theme_stylebox_override("panel",style())
	center.add_child(panel)
	QuestTheme.decorate_dialogue(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",8)
	panel.add_child(content)
	heading = label("",12,content,QuestTheme.ACCENT)
	body_scroll=ScrollContainer.new();body_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;content.add_child(body_scroll)
	body = label("",15,body_scroll)
	body.add_theme_constant_override("line_spacing",5)
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(0,56)
	next_button = Button.new()
	next_button.text = "继续  ·  E / 空格"
	next_button.custom_minimum_size.y = 34
	next_button.add_theme_font_override("font",font)
	next_button.add_theme_font_size_override("font_size",12)
	QuestTheme.button(next_button)
	next_button.icon=QuestTheme.icon("arrow")
	next_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	next_button.custom_minimum_size.x=140
	next_button.add_theme_constant_override("icon_max_width",14)
	next_button.alignment=HORIZONTAL_ALIGNMENT_CENTER
	next_button.pressed.connect(func():continued.emit())
	content.add_child(next_button)
	overlay.hide()
	balance_panel = PanelContainer.new()
	canvas.add_child(balance_panel)
	balance_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	balance_panel.offset_left = -290
	balance_panel.offset_right = 290
	balance_panel.offset_top = -220
	balance_panel.offset_bottom = -95
	balance_panel.add_theme_stylebox_override("panel",style())
	var balance_column := VBoxContainer.new()
	balance_column.add_theme_constant_override("separation",12)
	balance_panel.add_child(balance_column)
	balance_text = label("",18,balance_column)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(530,30)
	balance_column.add_child(bar)
	var back := ColorRect.new()
	back.color = Color("59665d")
	back.size = Vector2(530,24)
	bar.add_child(back)
	var green := ColorRect.new()
	green.color = Color("9bc393")
	green.position = Vector2(530*.36,0)
	green.size = Vector2(530*.30,24)
	bar.add_child(green)
	cursor = ColorRect.new()
	cursor.color = Color("ffe0a5")
	cursor.size = Vector2(5,30)
	bar.add_child(cursor)
	label("指针进入绿色区域时按 E · Esc 放弃并回到柜子",14,balance_column)
	balance_panel.hide()
	card.hide()

func style() -> StyleBoxFlat:
	return QuestTheme.panel(20)

func _process(_delta: float) -> void:
	var viewport := get_viewport().get_visible_rect().size
	card.offset_right=-18
	card.offset_top=18
	card.offset_left = -clampf(viewport.x*.19,200,240)-18
	card.size.y=card.get_combined_minimum_size().y
	var width:=minf(1000,viewport.x*.74)
	dialog_panel.custom_minimum_size.x=width
	body.size.x=width-48
	body_scroll.custom_minimum_size.y=clampf(body.get_minimum_size().y,56,viewport.y*.28)
	dialog_panel.size=Vector2(width,0)
	dialog_panel.position=Vector2((viewport.x-width)*.5,viewport.y-dialog_panel.size.y-30)
	carry.visible=not carry.text.is_empty()
	carry_panel.visible=card.visible and carry.visible
	carry_panel.position=Vector2(24,viewport.y-144)
	carry_panel.size=Vector2(minf(300,viewport.x*.38),0)

func set_paper_progress(current: int, total: int, enabled: bool) -> void:
	task_progress.max_value = total
	task_progress.value = current
	task_progress.visible = enabled

func label(text: String, size: int, parent: Node, color := QuestTheme.PAPER) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_override("font",font)
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

func show_page(title: String, text: String, last := false) -> void:
	heading.text = title
	body.text = text
	body_scroll.scroll_vertical=0
	next_button.text = "明白了  ·  E / 空格" if last else "继续  ·  E / 空格"
	overlay.show()
	next_button.grab_focus()

func update_balance(phase: float, hits: int, misses: int) -> void:
	cursor.position.x = phase*525
	balance_text.text = "保持平衡  %d / 3     失误 %d / 3" % [hits,misses]
