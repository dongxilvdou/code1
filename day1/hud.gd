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

func _ready() -> void:
	layer = 25
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"])
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	card = PanelContainer.new()
	canvas.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	card.offset_left = -344
	card.offset_right = -24
	card.offset_top = 24
	card.add_theme_stylebox_override("panel",style())
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	card.add_child(column)
	day_title = label("第一天  /  陌生的家",18,column,QuestTheme.BRASS)
	guidance = label("",16,column)
	task_progress = QuestTheme.progress(0,4)
	column.add_child(task_progress)
	task_progress.hide()
	status = label("",14,column,QuestTheme.MUTED)
	carry = label("",12,column,QuestTheme.SAGE)
	overlay = Control.new()
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(.035,.028,.020,.73)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	dialog_panel = panel
	panel.custom_minimum_size = Vector2(620,0)
	panel.add_theme_stylebox_override("panel",style())
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",24)
	panel.add_child(content)
	heading = label("",25,content,Color("e5bc7c"))
	body = label("",19,content)
	body.custom_minimum_size = Vector2(0,150)
	next_button = Button.new()
	next_button.text = "继续  ·  E / 空格"
	next_button.custom_minimum_size.y = 48
	next_button.add_theme_font_override("font",font)
	next_button.add_theme_font_size_override("font_size",18)
	QuestTheme.button(next_button)
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
	card.offset_left = -minf(320,viewport.x*.34)-24
	carry.visible = not carry.text.is_empty()
	card.size.y = card.get_combined_minimum_size().y
	dialog_panel.custom_minimum_size.x = minf(640,viewport.x-64)

func set_paper_progress(current: int, total: int, enabled: bool) -> void:
	task_progress.max_value = total
	task_progress.value = current
	task_progress.visible = enabled

func label(text: String, size: int, parent: Node, color := Color("eee7d9")) -> Label:
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
	next_button.text = "明白了  ·  E / 空格" if last else "继续  ·  E / 空格"
	overlay.show()
	next_button.grab_focus()

func update_balance(phase: float, hits: int, misses: int) -> void:
	cursor.position.x = phase*525
	balance_text.text = "保持平衡  %d / 3     失误 %d / 3" % [hits,misses]
