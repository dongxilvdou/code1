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
func open4(kind: String, value := "") -> void:
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
	elif kind=="eat":
		title.text = "厨房 / 阿嚼闻到了熟悉的味道"
		description.text = "阿嚼：我不想你吃了它，它的味道好熟悉。\n\n我：但是，这是主人的命令。\n\n老鼠嘴边，还夹着一张折起来的纸条。"
		button("遵从命令，吞下老鼠",detail,func():close();chapter.eat_mouse())
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
	description.text = "水垢挡住了水温数字，只能看见刻线和一段旧磨痕。\n按住旋钮拖动，或点按钮微调；回到底盘按 E，用试水判断冷热。"
	art("valve",245)
	var row := HBoxContainer.new()
	detail.add_child(row)
	for direction in [-1,1]:
		var b := button("← 往冷水转一点" if direction<0 else "往热水转一点 →",row,adjust_valve.bind(direction*4))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback.text = "温度数字看不清。浅色磨痕附近，似乎是平时常用的位置。"
func adjust_valve(amount: int) -> void:
	chapter.set_value("valve_setting",clampi(chapter.valve_setting()+amount,0,100))
	chapter.world.valve_wheel.rotation.z = -deg_to_rad(lerpf(-140,140,chapter.valve_setting()/100.0))
	feedback.text = "已转动旋钮。回到底盘按 E 试水；太冷往热转，太热往冷退。"
func open_clock() -> void:
	title.text = "三根指针 / 沉默的时钟"
	description.text = "三张纸条分别记录时、分、秒。按找到的线索调整三根指针。"
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
	description.text = ["两球每拍走一格。让终点灯同时点亮。短路可放四枚线圈，每枚停一拍。", "两路必须同一拍到达汇流门，随后共同走两格。早到会卡死，晚到也打不开门。", "红、绿球每拍一格；蓝球每拍两格，经过齿形变速带后每拍四格。红→蓝→绿，每灯间隔两拍。全关最多三枚线圈。 "][level]
	var board := art("circuit",350 if level==2 else 205)
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
	var routes: Array = chapter.circuit_routes()
	var coils: Array = chapter.circuit_coils()
	for i in range(route_labels.size()):
		route_labels[i].text = "转向器：%s / %d 格"%[["直行","短绕路","长绕路"][routes[i]],Circuit.length_(chapter.val("locks"),i,routes[i])]
		coil_labels[i].text = str(coils[i])
	display.routes=routes;display.coils=coils
	feedback.text="本关线圈 %d / %d · 高分挑战：三关累计不超过 3 枚，已用 %d。"%[coils.reduce(func(a,b):return a+b,0),Circuit.budget(chapter.val("locks")),chapter.val("delay_total")]
func adjust_circuit(lane: int, route: bool, delta: int) -> void:
	if display.running:return
	var key := "a11_%s_%d_%d"%["route" if route else "coil",chapter.val("locks"),lane]
	var value: int = chapter.val(key)
	value = (value+1)%3 if route else clampi(value+delta,0,4)
	chapter.set_value(key,value)
	refresh_circuit()
func start_circuit() -> void:
	if display.running:return
	var result := Circuit.evaluate(chapter.val("locks"),chapter.circuit_routes(),chapter.circuit_coils())
	if result.used>Circuit.budget(chapter.val("locks")):feedback.text=result.message;return
	display.result=result;display.elapsed=0;display.running=true
	run_button.disabled=true
	feedback.text="电流已出发，观察小球每一拍的位置。"
func finish_circuit(result: Dictionary) -> void:
	if mode!="circuit":return
	feedback.text=result.message+" 到达拍数："+str(result.times)
	run_button.disabled=false
	if result.ok:
		chapter.complete_lock()
		close()
		chapter.story("第 %d 组电流锁已解开。\n%s"%[chapter.val("locks"),("三道锁都亮了，门已经打开。沿楼梯下去吧。\n全程使用 %d 枚线圈。%s"%[chapter.val("delay_total"),"高分挑战达成。" if chapter.flag("a11_high_score") else "高分目标为累计不超过 3 枚。"] ) if chapter.val("locks")==3 else "锁扣松开了。继续检查门上的下一组导线。"])
func circuit_hint() -> void:
	var solution := Circuit.solution(chapter.val("locks"))
	for i in range(Circuit.count_(chapter.val("locks"))):
		if chapter.circuit_routes()[i]!=solution.routes[i]:feedback.text="观察%s球：转向器试试%s，让空间换取时间。"%[["红","蓝","绿"][i],["直行","短绕路","长绕路"][solution.routes[i]]];return
		if chapter.circuit_coils()[i]!=solution.coils[i]:feedback.text="%s球这条路试试 %d 枚线圈。"%[["红","蓝","绿"][i],solution.coils[i]];return
	feedback.text="当前摆法已满足要求，接通电流验证。"
func close() -> void:
	if is_instance_valid(display) and display.get("running")!=null:display.running=false
	super.close()
