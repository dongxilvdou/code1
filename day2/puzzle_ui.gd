extends CanvasLayer
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
	add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(.02,.035,.03,.80)
	shell.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	shell.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 650
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14221b")
	style.border_color = Color("8fa88d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	panel.add_child(column)
	title = label("",25,column)
	title.add_theme_color_override("font_color",Color("e8c184"))
	description = label("",19,column)
	description.custom_minimum_size.x = 598
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation",12)
	column.add_child(detail)
	feedback = label("",17,column)
	button("返回  ·  Esc",column,close)
	shell.hide()

func label(text: String, size: int, parent: Node) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_override("font",font)
	result.add_theme_font_size_override("font_size",size)
	parent.add_child(result)
	return result

func button(text: String, parent: Node, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.add_theme_font_override("font",font)
	result.add_theme_font_size_override("font_size",17)
	result.custom_minimum_size.y = 42
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
					paw.draw_circle(Vector2(24,21),8,Color("d3bd87"))
					for x in [12,24,36]:paw.draw_circle(Vector2(x,7),4,Color("d3bd87")))
		code = LineEdit.new()
		code.max_length = 3
		code.placeholder_text = "三位数字"
		code.add_theme_font_size_override("font_size",24)
		code.add_theme_font_override("font",font)
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
