extends "res://day2/puzzle_ui.gd"
const Circuit = preload("res://act3/lights_out.gd")
var chapter
var switches: Array[Button] = []
var hint_cell := -1

func open_circuit() -> void:
	super.open("story")
	mode = "circuit"
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	title.text = "二楼配电板 / 恢复供电"
	description.text = "按下一只开关，会切换它自己和上下左右四盏灯。\n让十六盏灯同时点亮。提示会根据当前灯态重新计算。"
	var center := CenterContainer.new()
	detail.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	center.add_child(grid)
	switches.clear()
	for i in range(16):
		var lamp := button("",grid,press_switch.bind(i))
		lamp.custom_minimum_size = Vector2(96,66)
		switches.append(lamp)
	var actions := HBoxContainer.new()
	detail.add_child(actions)
	button("提示 · 从现在的灯态出发",actions,show_hint)
	button("重置 · 全部熄灭",actions,reset_circuit)
	refresh_switches()

func refresh_switches() -> void:
	for i in range(switches.size()):
		var on: bool = chapter.val("circuit_bits") & (1<<i)!=0
		var style := QuestTheme.panel(10)
		style.bg_color = Color("d5c19a") if on else QuestTheme.SOFT
		style.border_color = QuestTheme.ACCENT if i==hint_cell else QuestTheme.BORDER
		style.set_border_width_all(3 if i==hint_cell else 1)
		switches[i].add_theme_stylebox_override("normal",style)
		switches[i].text = "%02d\n%s"%[i+1,"● 亮" if on else "○ 灭"]
		switches[i].add_theme_color_override("font_color",QuestTheme.TEXT if on else QuestTheme.MUTED)
	feedback.text = "已点亮 %d / 16"%lit_count(chapter.val("circuit_bits"))

func lit_count(state: int) -> int:
	var count := 0
	for i in range(16):
		if state & (1<<i):count += 1
	return count

func press_switch(i: int) -> void:
	if mode!="circuit" or chapter.flag("a7_power") or i not in range(16):return
	chapter.set_value("circuit_bits",chapter.val("circuit_bits")^Circuit.toggle_mask(i))
	hint_cell = -1
	refresh_switches()
	chapter.world.refresh_circuit(chapter.val("circuit_bits"))
	if chapter.val("circuit_bits")==Circuit.FULL:
		close()
		chapter.restore_power()

func show_hint() -> void:
	var path := Circuit.solution(chapter.val("circuit_bits"))
	if path.is_empty():
		feedback.text = "灯已全部点亮。" if chapter.val("circuit_bits")==Circuit.FULL else "这个状态无法接通，请重置后再试。"
		return
	hint_cell = path[0]
	refresh_switches()
	var sequence := PackedStringArray()
	for i in path:sequence.append(str(i+1))
	feedback.text = "从当前状态，依次按："+" → ".join(sequence)+"。下一只开关已描边。"

func reset_circuit() -> void:
	if chapter.flag("a7_power"):return
	chapter.set_value("circuit_bits",0)
	hint_cell = -1
	refresh_switches()
	chapter.world.refresh_circuit(0)
