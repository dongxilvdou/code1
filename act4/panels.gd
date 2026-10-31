extends "res://day2/puzzle_ui.gd"
const Art = preload("res://act4/puzzle_art.gd")
const Circuit = preload("res://act4/circuit.gd")
var chapter
var display: Control
var tile_buttons: Array = []
var selection := -1
var route_labels: Array = []
var coil_labels: Array = []
var run_button: Button
var challenge := false
var mouse_page := 0
var rest_fade: Tween
const MOUSE_DIALOGUE := [
	"我：阿嚼，它带着一张逃跑计划。\n\n阿嚼：……逃跑？\n\n我：你刚才说，它的味道很熟悉。你认识它吗？",
	"阿嚼：我说不清。我只是觉得……不应该吃掉它。\n\n我：可纸条让我抓住它，再吃掉它。",
	"阿嚼：你自己想这么做吗？\n\n我：……",
	"我：如果是主人留下的，为什么要让我吃掉一个想逃走的家伙？\n\n阿嚼：我不知道。\n\n阿嚼：先别急着照做。"
]
func open4(kind: String, value := "") -> void:
	if is_instance_valid(rest_fade):rest_fade.kill()
	shell.modulate=Color.WHITE
	super.open("story",value)
	title.text = "第四幕 / 第 %d 天"%chapter.today()
	if kind=="story":return
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	mode = kind
	selection = -1
	if kind=="valve":open_valve()
	elif kind=="clock":open_clock()
	elif kind=="plants":open_plants()
	elif kind=="jigsaw":open_jigsaw()
	elif kind=="circuit":open_circuit()
	elif kind.begins_with("mouse_"):open_mouse_scene(kind)

func open_mouse_scene(kind: String) -> void:
	title.text = "厨房 / 主人的命令"
	if kind=="mouse_warning":
		description.text = "老鼠嘴边的小纸条滑落到脚边。\n\n阿嚼：等等……先别吃。\n阿嚼：它的味道，我好像在哪里闻到过。\n\n我：可是，今天的纸条上写着……\n\n阿嚼：先看看它带来的东西。"
		button("查看纸条",detail,chapter.open_mouse_note).grab_focus()
	elif kind=="mouse_note":
		title.text = "老鼠带来的纸条 / 逃跑计划"
		description.text = "地下室逃跑计划。\n监控底下。沿着旧抓痕走。\n\n我：逃跑计划？它想离开这里？\n可今天留下的任务，却是让我吃掉它……"
		picture("res://act4/textures/escape_note.svg",detail,Vector2(430,220))
		button("记住纸条上的内容",detail,chapter.confirm_mouse_note).grab_focus()
	elif kind=="mouse_question":
		description.text = "逃跑计划已经记下来了。\n\n阿嚼似乎认出了它的味道。\n我得问问它，为什么要阻止我。"
		button("向阿嚼求证",detail,chapter.question_mouse).grab_focus()
		button("重看纸条",detail,chapter.open_mouse_note)
	elif kind=="mouse_dialogue":
		title.text = "向阿嚼求证 / %d · %d"%[mouse_page+1,MOUSE_DIALOGUE.size()]
		description.text = MOUSE_DIALOGUE[mouse_page]
		button("继续听阿嚼说" if mouse_page<MOUSE_DIALOGUE.size()-1 else "听完阿嚼的话",detail,advance_mouse_dialogue).grab_focus()
	elif kind=="mouse_refusal":
		description.text = "它想逃出去。\n阿嚼也在阻止我。\n\n我不想吃掉它。"
		button("我不吃，离开这里。",detail,chapter.refuse_mouse).grab_focus()
		button("重看纸条",detail,chapter.open_mouse_note)
		button("回想阿嚼的话",detail,chapter.question_mouse)
	elif kind=="mouse_rest":
		title.text = "第十天 / 猫窝"
		description.text = "我今天到底怎么了，为什么身体不受控制，为什么一定要吃了它，主人......到底是谁？"
		button("闭上眼睛",detail,chapter.finish_day_ten).grab_focus()
		shell.modulate.a = 0
		rest_fade = create_tween()
		rest_fade.tween_property(shell,"modulate:a",1.0,.8)

func advance_mouse_dialogue() -> void:
	if mode!="mouse_dialogue":return
	if mouse_page<MOUSE_DIALOGUE.size()-1:
		mouse_page+=1
		open4("mouse_dialogue")
	else:chapter.confirm_mouse_question()

func _input(event: InputEvent) -> void:
	if mode.begins_with("mouse_") and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			close()
		elif event.keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:
			if detail.get_child_count()>0 and detail.get_child(0) is Button:
				(detail.get_child(0) as Button).pressed.emit()
			elif mode=="mouse_note":chapter.confirm_mouse_note()
		else:return
		get_viewport().set_input_as_handled()
		return
	super._input(event)
func _process(delta: float) -> void:
	super._process(delta)
	if mode=="mouse_rest":dimmer.color.a=.72

func picture(path: String, parent: Node, dims := Vector2(550,280)) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = dims
	parent.add_child(image)
	return image
func art(kind: String, height: int) -> Control:
	display = Art.new()
	display.chapter = chapter
	display.kind = kind
	display.custom_minimum_size = Vector2(598,height)
	detail.add_child(display)
	return display
func open_valve() -> void:
	title.text = "水垢下的温度"
	description.text = "水温数字被水垢遮住了。温度和出水量会一起影响体感。\n先观察两个旋钮的磨痕，用小水试温，再逐步增加出水。回到底盘按 E 检查。"
	art("valve",245)
	var row := HBoxContainer.new()
	detail.add_child(row)
	for direction in [-1,1]:
		var b := button("← 往冷水转一点" if direction<0 else "往热水转一点 →",row,adjust_valve.bind(direction*4))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var flow_row:=HBoxContainer.new();detail.add_child(flow_row)
	for direction in [-1,1]:
		var b:=button("− 收小出水量" if direction<0 else "＋ 增大出水量",flow_row,adjust_pressure.bind(direction*6))
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	feedback.text = "数字看不清。左侧小旋钮管出水，右侧旋钮调冷热；浅色磨痕是常用位置。"

func adjust_pressure(amount: int) -> void:
	chapter.set_value("pressure_setting",clampi(chapter.pressure_setting()+amount,0,100))
	chapter.world.pressure_wheel.rotation.z=-deg_to_rad(lerpf(-120,120,chapter.pressure_setting()/100.0))
	chapter.world.items.water.flow=chapter.pressure_setting()/100.0
	chapter.bathing=false;chapter.wash_time=0;chapter.world.items.water.stop()
	feedback.text="出水旋钮已调整。回到底盘试水，注意水流是否稳定、是否冲得太急。"
func adjust_valve(amount: int) -> void:
	chapter.bathing=false;chapter.wash_time=0;chapter.world.items.water.stop()
	chapter.set_value("valve_setting",clampi(chapter.valve_setting()+amount,0,100))
	chapter.world.valve_wheel.rotation.z = -deg_to_rad(lerpf(-140,140,chapter.valve_setting()/100.0))
	feedback.text = "已转动旋钮。回到底盘按 E 试水；太冷往热转，太热往冷退。"
func open_clock() -> void:
	title.text = "三根指针 / 沉默的时钟"
	description.text = "地点：二楼书房。\n书桌、书柜脚边和阅读小桌各有一张纸条，分别记录时、分、秒。按找到的线索调整三根指针。"
	art("clock",220)
	var row := HBoxContainer.new()
	detail.add_child(row)
	for i in range(3):
		var col := VBoxContainer.new()
		row.add_child(col)
		label(["时针","分针","秒针"][i],16,col)
		var spin := SpinBox.new()
		spin.max_value = 11 if i==0 else 59
		spin.step = 1
		spin.value = chapter.val(["clock_h","clock_m","clock_s"][i],[8,11,25][i])
		spin.custom_minimum_size = Vector2(170,44)
		col.add_child(spin)
		spin.value_changed.connect(func(v: float):chapter.set_value(["clock_h","clock_m","clock_s"][i],int(v)))
	button("确认这个时间",detail,func():
		if chapter.clock_clue_count()<3:feedback.text="先找到三张纸条：小时、分钟、秒各一张。"
		elif chapter.val("clock_h")==3 and chapter.val("clock_m")==42 and chapter.val("clock_s")==0:
			close();chapter.solve_clock()
		else:feedback.text="指针仍然停着。再核对三张纸条上的小时、分钟和秒。")
func open_plants() -> void:
	title.text = "让盆栽回到画里的位置"
	description.text = "观察墙画中叶片与花朵的特征，选择两盆交换位置。"
	picture("res://act4/textures/botanical_order.png",detail,Vector2(550,230))
	var row := HBoxContainer.new()
	detail.add_child(row)
	var order: Array = chapter.plant_order()
	for slot in range(3):
		var i: int = order[slot]
		var b := button("%s  ·  %s"%[["左","中","右"][slot],chapter.world.PLANT_NAMES[i]],row,choose_plant.bind(slot))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button("检查排列",detail,func():
		if chapter.plant_order()==[0,1,2]:close();chapter.mark("a9_plants");chapter.restore();chapter.story("三盆植物和画中的顺序一致了。花盆边沿有浅浅的旧擦痕，像是有人摆过很多次。")
		else:feedback.text="顺序还不相同。注意蕨叶的羽片、白菊的花心、迷迭香的细针叶。")
func choose_plant(slot: int) -> void:
	if selection<0:selection=slot;feedback.text="再选另一盆，与它交换。";return
	chapter.swap_plants(selection,slot)
	open4("plants")
func open_jigsaw() -> void:
	title.text = "照片拼图"
	description.text = "选择两块纸板交换位置，还原被打乱的照片。"
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",3)
	grid.add_theme_constant_override("v_separation",3)
	detail.add_child(grid)
	tile_buttons.clear()
	var order: Array = chapter.jigsaw_order()
	var texture := load("res://act4/textures/laboratory_cats.png") as Texture2D
	var dims := Vector2(texture.get_width()/3.0,texture.get_height()/3.0)
	for i in range(9):
		var b := TextureButton.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(order[i]%3,order[i]/3)*dims,dims)
		b.texture_normal = atlas
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.custom_minimum_size = Vector2(185,123)
		grid.add_child(b)
		b.pressed.connect(choose_piece.bind(i))
		tile_buttons.append(b)
func choose_piece(index: int) -> void:
	if selection<0:
		selection=index
		tile_buttons[index].modulate = Color("c8d9b9")
		return
	chapter.swap_pieces(selection,index)
	if chapter.jigsaw_order()==range(9):
		close();chapter.mark("a9_jigsaw");chapter.restore();chapter.story("照片终于拼好了。\n\n三只猫，三扇实验室的笼门。中间那只灰猫的眼神，为什么如此熟悉？")
		picture("res://act4/textures/laboratory_cats.png",detail)
	else:open4("jigsaw")
func open_circuit() -> void:
	var level: int = chapter.val("locks")
	if level>=3:close();return
	title.text = "电流锁 %d / 3 · %s"%[level+1,Circuit.NAMES[level]]
	description.text = Circuit.rules(level)
	var board := art("circuit",[220,255,360][level])
	board.level = level
	board.routes = chapter.circuit_routes()
	board.coils = chapter.circuit_coils()
	route_labels.clear();coil_labels.clear()
	for i in range(Circuit.count_(level)):
		var row := HBoxContainer.new()
		detail.add_child(row)
		label(["红","蓝","绿"][i]+"球",16,row).custom_minimum_size.x=44
		var route := button("",row,adjust_circuit.bind(i,true,1))
		route.custom_minimum_size.x=256
		route_labels.append(route)
		button("− 线圈",row,adjust_circuit.bind(i,false,-1))
		var count_label := label("",17,row)
		count_label.custom_minimum_size.x=28
		coil_labels.append(count_label)
		button("+ 线圈",row,adjust_circuit.bind(i,false,1))
	var controls := HBoxContainer.new()
	detail.add_child(controls)
	run_button = button("接通电流 / 运行",controls,start_circuit)
	button("从当前摆法给提示",controls,circuit_hint)
	button("复位",controls,func():chapter.reset_circuit();open4("circuit"))
	refresh_circuit()
func refresh_circuit() -> void:
	var level: int=chapter.val("locks")
	var routes: Array=chapter.circuit_routes()
	var coils: Array=chapter.circuit_coils()
	for i in range(route_labels.size()):
		var length_: int=Circuit.approach_length(i,routes[i]) if level==1 else Circuit.length_(level,i,routes[i])
		route_labels[i].text="%s / %d节点%s"%[["直行","短绕路","长绕路"][routes[i]],length_,"到桥" if level==1 else ""]
		coil_labels[i].text=str(coils[i])
	display.routes=routes;display.coils=coils;display.result={};display.elapsed=0
	feedback.text="本关线圈 %d / %d · 每路上限 %d · 高分：三关累计≤%d枚，已用%d枚。"%[coils.reduce(func(a,b):return a+b,0),Circuit.budget(level),Circuit.coil_limit(level),Circuit.HIGH_SCORE_COILS,chapter.val("delay_total")]

func adjust_circuit(lane: int, route: bool, delta: int) -> void:
	if mode!="circuit" or display.running:return
	var level: int=chapter.val("locks")
	var key:="a11_%s_%d_%d"%["route" if route else "coil",level,lane]
	var value: int=clampi(chapter.val(key),0,2 if route else Circuit.coil_limit(level))
	value=(value+1)%3 if route else clampi(value+delta,0,Circuit.coil_limit(level))
	chapter.set_value(key,value)
	refresh_circuit()

func start_circuit() -> void:
	if mode!="circuit" or display.running:return
	var result:=Circuit.evaluate(chapter.val("locks"),chapter.circuit_routes(),chapter.circuit_coils())
	if not result.valid_input or result.used>Circuit.budget(chapter.val("locks")):
		show_circuit_feedback(result.message);return
	display.result=result;display.elapsed=0;display.running=true
	run_button.disabled=true
	feedback.text="电流已出发，观察小球每一拍的位置。"
	paper_scroll.set_deferred("scroll_vertical",0)

func finish_circuit(result: Dictionary) -> void:
	if mode!="circuit":return
	show_circuit_feedback(result.message+" 终点拍数："+str(result.times))
	run_button.disabled=false
	if result.ok:
		var previous: int=chapter.val("locks")
		chapter.complete_lock()
		if chapter.val("locks")==previous:
			show_circuit_feedback("线路已变化，请重新运行当前配置。");return
		close()
		var summary:="锁扣松开了。继续检查门上的下一组导线。"
		if chapter.val("locks")==3:
			summary="三道锁都亮了，推门进入实验室吧。\n全程使用 %d 枚线圈。%s"%[chapter.val("delay_total"),"高分挑战达成。" if chapter.flag("a11_high_score") else "高分目标为累计不超过 %d 枚。"%Circuit.HIGH_SCORE_COILS]
		chapter.story("第 %d 组电流锁已解开。\n%s"%[chapter.val("locks"),summary])

func show_circuit_feedback(message: String) -> void:
	feedback.text=message
	paper_scroll.call_deferred("ensure_control_visible",feedback)

func circuit_hint() -> void:
	var solution := Circuit.solution(chapter.val("locks"))
	for i in range(Circuit.count_(chapter.val("locks"))):
		if chapter.circuit_routes()[i]!=solution.routes[i]:show_circuit_feedback("观察%s球：转向器试试%s，让空间换取时间。"%[["红","蓝","绿"][i],["直行","短绕路","长绕路"][solution.routes[i]]]);return
		if chapter.circuit_coils()[i]!=solution.coils[i]:show_circuit_feedback("%s球这条路试试 %d 枚线圈。"%[["红","蓝","绿"][i],solution.coils[i]]);return
	show_circuit_feedback("当前摆法已满足要求，接通电流验证。")
func close() -> void:
	if is_instance_valid(display) and display.get("running")!=null:display.running=false
	super.close()
