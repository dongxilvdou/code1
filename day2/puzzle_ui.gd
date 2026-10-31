extends CanvasLayer
const QuestTheme = preload("res://quest_system/quest_theme.gd")
signal dismissed
signal solved(kind: String)
var mode := ""
var shell: Control
var title: Label
var description: Label
var detail: VBoxContainer
var feedback: Label
var knob: HSlider
var code: LineEdit
var picked: Array[int] = []
var font: SystemFont
var audio: AudioStreamPlayer
var memory_audio: AudioStreamPlayer
var paper_panel: PanelContainer
var paper_scroll: ScrollContainer
var paper_column: VBoxContainer
var close_button: Button
var dimmer: ColorRect
var dialogue_frame: Node2D
var story_style: StyleBoxFlat
var puzzle_style: StyleBoxFlat
const NOTES := ["低音","中音","高音"]
const MELODY := [1,3,2]
const PASSWORD := "241"

func _ready() -> void:
	layer = 30
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"])
	audio = AudioStreamPlayer.new()
	add_child(audio)
	memory_audio = AudioStreamPlayer.new()
	add_child(memory_audio)
	shell = Control.new()
	shell.theme=QuestTheme.resource()
	add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	dimmer=shade
	shade.color = Color(.10,.075,.05,.12)
	shell.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := Control.new()
	shell.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	paper_panel=panel
	panel.custom_minimum_size.x = 650
	var style := QuestTheme.panel(24)
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	dialogue_frame=QuestTheme.decorate_dialogue(panel)
	story_style=QuestTheme.panel(32)
	puzzle_style=style
	var column := VBoxContainer.new()
	paper_column=column
	column.add_theme_constant_override("separation",16)
	panel.add_child(column)
	var title_row:=HBoxContainer.new();title_row.add_theme_constant_override("separation",10);column.add_child(title_row)
	title_row.add_child(QuestTheme.symbol("book",24))
	title = label("",16,title_row)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color",QuestTheme.BRASS)
	paper_scroll=ScrollContainer.new();paper_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;paper_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;column.add_child(paper_scroll)
	var reading:=VBoxContainer.new();reading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;reading.add_theme_constant_override("separation",14);paper_scroll.add_child(reading)
	description = label("",15,reading)
	description.add_theme_constant_override("line_spacing",5)
	description.custom_minimum_size.x = 598
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation",12)
	reading.add_child(detail)
	feedback = label("",12,reading)
	feedback.add_theme_color_override("font_color",QuestTheme.MUTED)
	close_button=button("返回  ·  Esc",column,close)
	close_button.icon=QuestTheme.icon("back")
	shell.hide()

func label(text: String, size: int, parent: Node) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_override("font",font)
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",QuestTheme.PAPER)
	parent.add_child(result)
	return result

func button(text: String, parent: Node, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.add_theme_font_override("font",font)
	result.add_theme_font_size_override("font_size",14)
	result.custom_minimum_size.y = 36
	QuestTheme.button(result)
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func open(kind: String, text := "") -> void:
	mode = kind
	feedback.text = ""
	picked.clear()
	for n in detail.get_children():
		detail.remove_child(n)
		n.queue_free()
	shell.show()
	paper_scroll.scroll_vertical=0
	if kind=="wash":
		title.text = "洗衣的旋律"
		description.text = "我记得主人洗衣服时的声音……\n拖动旋钮，按 E 依次确认三个音，找到正确的洗衣程序。"
		button("重听记忆旋律  ·  R",detail,replay)
		knob = HSlider.new()
		knob.min_value = 1
		knob.max_value = 3
		knob.step = 1
		knob.value = 1
		knob.custom_minimum_size.y = 36
		var rail := StyleBoxFlat.new()
		rail.bg_color = Color("667c69")
		rail.content_margin_top = 3
		rail.content_margin_bottom = 3
		knob.add_theme_stylebox_override("slider",rail)
		detail.add_child(knob)
		knob.value_changed.connect(func(v: float):
			play_note(int(v))
			feedback.text = "旋钮："+NOTES[int(v)-1]+"  ·  已输入 %d / 3" % picked.size())
		var captions := HBoxContainer.new()
		detail.add_child(captions)
		for i in range(3):
			var caption := label(NOTES[i],16,captions)
			caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			caption.horizontal_alignment = i
		button("确认这个音  ·  E",detail,submit_note)
		button("显示音高提示",detail,func():feedback.text = "记忆中的音高：低音 → 高音 → 中音")
		knob.grab_focus()
		replay()
	elif kind=="code":
		title.text = "留下来的猫爪印"
		description.text = "面板上有别的猫留下的脚印。\n从左到右，数每一列完整的爪印，得到三位密码。"
		var clues := HBoxContainer.new()
		clues.alignment = BoxContainer.ALIGNMENT_CENTER
		clues.add_theme_constant_override("separation",70)
		detail.add_child(clues)
		for count in [2,4,1]:
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation",5)
			clues.add_child(col)
			for i in range(count):
				var paw := Control.new()
				paw.custom_minimum_size = Vector2(48,30)
				col.add_child(paw)
				paw.draw.connect(func():
					paw.draw_circle(Vector2(24,21),8,QuestTheme.ACCENT)
					for x in [12,24,36]:paw.draw_circle(Vector2(x,7),4,QuestTheme.ACCENT))
		code = LineEdit.new()
		code.max_length = 3
		code.placeholder_text = "三位数字"
		code.add_theme_font_size_override("font_size",24)
		code.add_theme_font_override("font",font)
		code.add_theme_stylebox_override("normal",QuestTheme.panel(10))
		var focused := QuestTheme.panel(10)
		focused.border_color = QuestTheme.BRASS
		code.add_theme_stylebox_override("focus",focused)
		code.add_theme_color_override("font_color",QuestTheme.PAPER)
		detail.add_child(code)
		code.text_submitted.connect(func(_t):submit_code())
		button("解锁  ·  Enter",detail,submit_code)
		code.grab_focus()
	else:
		title.text = "第二天  /  学着照顾"
		description.text = text
		button("继续  ·  E / 空格",detail,close).grab_focus()

func play_note(note: int) -> void:
	audio.stream = load("res://day2/audio/note_%d.wav" % note)
	audio.play()

func replay() -> void:
	memory_audio.stream = load("res://day2/audio/memory.wav")
	memory_audio.play()

func submit_note() -> void:
	if mode!="wash":return
	var note := int(knob.value)
	play_note(note)
	if note!=MELODY[picked.size()]:
		picked.clear()
		feedback.text = "不是这个顺序。旋钮复位，重听旋律再试试。"
		return
	picked.append(note)
	feedback.text = "听起来对了  ·  %d / 3" % picked.size()
	if picked.size()==3:solved.emit("wash")

func submit_code() -> void:
	if mode!="code":return
	if code.text==PASSWORD:solved.emit("code")
	else:
		feedback.text = "密码不对。按从左到右的顺序再数一遍。"
		code.select_all()
		code.grab_focus()

func close() -> void:
	mode = ""
	shell.hide()
	audio.stop()
	memory_audio.stop()
	dismissed.emit()

func _process(_delta: float) -> void:
	if not shell.visible:return
	feedback.visible=not feedback.text.is_empty()
	var viewport:=get_viewport().get_visible_rect().size
	var story_only:=mode=="story" or mode.begins_with("mouse_")
	for child in detail.get_children():
		if not child is Button:story_only=false
	dialogue_frame.ornaments=story_only
	var frame_style:=story_style if story_only else puzzle_style
	frame_style.bg_color=Color.TRANSPARENT
	if paper_panel.get_theme_stylebox("panel")!=frame_style:paper_panel.add_theme_stylebox_override("panel",frame_style)
	close_button.visible=not story_only
	var width:=minf(minf(1000,viewport.x*.74) if story_only else 760,viewport.x-64)
	# The live puzzle art keeps its original 598px coordinate space.
	width=maxf(minf(650,viewport.x-32),width)
	paper_panel.custom_minimum_size.x=width
	description.custom_minimum_size.x=0
	var content_width:=maxf(200,width-(64 if story_only else 48))
	description.size.x=content_width
	var reading:=paper_scroll.get_child(0) as VBoxContainer
	reading.custom_minimum_size.x=content_width
	var reading_height:=reading.get_combined_minimum_size().y
	var limit:=viewport.y*(.43 if story_only else .67)
	paper_scroll.custom_minimum_size.y=minf(reading_height,limit)
	paper_panel.size=Vector2(width,0)
	var height:=paper_panel.size.y
	paper_panel.position=Vector2((viewport.x-width)*.5,viewport.y-height-30 if story_only else maxf(20,(viewport.y-height)*.5))
	dimmer.color.a=.08 if story_only else .16

func _input(event: InputEvent) -> void:
	if mode.is_empty() or not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_ESCAPE:close()
	elif mode=="wash":
		if event.keycode==KEY_R:replay()
		elif event.keycode==KEY_E:submit_note()
		elif event.keycode==KEY_LEFT:knob.value = maxf(1,knob.value-1)
		elif event.keycode==KEY_RIGHT:knob.value = minf(3,knob.value+1)
	elif mode=="story" and event.keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:close()
	else:return
	get_viewport().set_input_as_handled()
