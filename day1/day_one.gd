extends Node3D
## The quest manager is the only persistent state. World props are derived from it.
const World = preload("res://day1/world.gd")
const Hud = preload("res://day1/hud.gd")
const SPAWN := Vector3(-.04,.03,5.45)
const INTRO := [
	"……这是哪里？我怎么会在一扇陌生的门前？",
	"这双爪子……还有尾巴？原来，我是一只猫。\n先看看四周吧。这里安静得有些奇怪。",
	"我想起来了，我有一个主人。\n她会轻轻摸我的头，也会给我留一块暖和的地方。",
	"我最喜欢她了。只要听到她回家的声音，我就会跑过去。",
	"可是主人生病了。现在，应该换我照顾她。\n我记得……这里能让我学会照顾主人。",
	"总之，先看看房间里有什么。\n试着走一走、跑一跑，再打开客厅的门吧。"
]
var game
var player
var quests
var manager: CalicoQuestManager
var world
var hud
var initialized := false
var dialog := ""
var page := 0
var target := ""
var held_visual: Node3D
var anchor_positions := {}
var walk_distance := 0.0
var run_distance := 0.0
var previous_position := Vector3.ZERO
var balancing := false
var balance_phase := 0.0
var balance_hits := 0
var balance_misses := 0
var balance_pressed := false
var tv_stable := false
var balance_cooldown := 0.0
var tv_rotation := Vector3.ZERO
var room_light: OmniLight3D
var light_diffuser: MeshInstance3D
var diffuser_material: Material
var update_clock := 0.0

func _ready() -> void:
	game = get_parent()
	player = game.get_node("Miso")
	quests = game.get_node("QuestSystem")
	world = World.new()
	world.build(self,game)
	for id in world.items:anchor_positions[id] = world.items[id].position
	hud = Hud.new()
	add_child(hud)
	hud.continued.connect(advance_dialog)
	for light in game.get_node("Apartment/Lighting").get_children():
		if light is OmniLight3D and light.position.distance_to(Vector3(-3.4,2.54,1.8))<.15:room_light = light
	for child in game.get_node("Apartment/GroundFloor").get_children():
		if child is MeshInstance3D and child.position.distance_to(Vector3(-3.4,2.605,1.8))<.02:
			light_diffuser = child
			diffuser_material = child.material_override
	if world.items.has("television"):tv_rotation = world.items.television.rotation
	player.spawn = SPAWN

func flag(key: String) -> bool:
	return manager!=null and bool(manager.flags.get(key,false))

func value(key: String, fallback := 0) -> int:
	return int(manager.values.get(key,fallback)) if manager else fallback

func mark(key: String) -> void:
	if flag(key):return
	manager.set_flag(StringName(key),true)
	manager.report_event(CalicoQuestObjective.Kind.CUSTOM,StringName(key),1,"day1:"+key)

func active_play() -> bool:
	return initialized and game.started and player.active and not game.photo and not game.inspecting and not game.cinematic_active and quests.exploration_active()

func second_day():
	return get_parent().get_node_or_null("DayTwo")

func feeding_done() -> bool:
	return flag("d2_cat_fed") and flag("d2_dog_fed")

func yarn_available() -> bool:
	return is_second_day() and flag("d2_washed") and flag("d2_note") and feeding_done()

func is_second_day() -> bool:
	return value("current_day",1)>=2

func _physics_process(delta: float) -> void:
	if not initialized:
		if quests.session_started:
			manager = quests.manager
			initialized = true
			reconcile_progress()
			restore_world()
			reset_spawn()
			if not flag("intro_seen"):show_dialog("intro")
		return
	if not active_play():
		previous_position = player.global_position
		return
	if is_second_day():return
	balance_cooldown = maxf(0,balance_cooldown-delta)
	var p: Vector3 = player.global_position
	var travel := Vector2(p.x-previous_position.x,p.z-previous_position.z).length()
	previous_position = p
	if travel<.15 and player.is_on_floor():
		walk_distance += travel
		if Input.is_action_pressed("sprint"):run_distance += travel
	if walk_distance>.65:mark("walk")
	if run_distance>.65:mark("run")
	if world.door.is_open and not world.door.moving:mark("open_living")
	if flag("open_living") and player.is_on_floor():
		if on_surface("stool",Vector2(.35,.32),.34):mark("stool")
		if flag("stool") and on_surface("table",Vector2(.76,.43),.80):mark("table")
	if flag("note_read") and not flag("light_off"):
		if p.y>1.23 and p.y<1.48 and absf(p.x+1.28)<.28 and absf(p.z-2.57)<.66 and player.is_on_floor():
			if not tv_stable and balance_cooldown<=0:start_balance()
		if tv_stable and p.y<1.05:tv_stable = false
		var body_center := p+Vector3(0,.15,0)
		if tv_stable and not player.is_on_floor() and body_center.distance_to(world.items.switch.global_position)<.36:
			mark("light_off")
			tv_stable = false
			restore_world()
			game.ui.toast("灯熄灭了。其他房间的门也能打开了。",4)
	update_clock += delta
	if update_clock>.12:
		update_clock = 0
		refresh_hud()

func on_surface(id: String, half_size: Vector2, top: float) -> bool:
	var p: Vector3 = player.global_position-world.items[id].global_position
	return absf(p.x)<half_size.x and absf(p.z)<half_size.y and absf(p.y-top)<.10

func _process(delta: float) -> void:
	if not initialized:return
	hud.card.visible = active_play()
	if balancing:
		balance_phase += delta/.95
		if balance_phase>=1:
			if not balance_pressed:balance_misses += 1
			balance_phase = fmod(balance_phase,1.0)
			balance_pressed = false
		if world.items.has("television"):
			world.items.television.rotation.z = tv_rotation.z+sin(Time.get_ticks_msec()*.012)*.035
		hud.update_balance(balance_phase,balance_hits,balance_misses)
		if balance_misses>=3:finish_balance(false)

func reset_spawn() -> void:
	player.spawn = SPAWN
	player.reset_position()
	player.yaw = PI/2
	player.rotation.y = player.yaw
	previous_position = player.global_position

func restore_world() -> void:
	var unlocked := flag("light_off")
	for door in get_tree().get_nodes_in_group("villa_doors"):
		if door==world.door:continue
		door.locked = not unlocked
		if not unlocked:door.set_open(false,true)
	for gate in world.gates:
		gate.visible = not unlocked
		for child in gate.get_children():
			if child is StaticBody3D:child.collision_layer = 0 if unlocked else 1
	world.door.set_open(flag("open_living"),true)
	if room_light:room_light.light_energy = 0.0 if flag("light_off") else .48
	if light_diffuser:
		light_diffuser.material_override = world.mat(Color("a9aa98")) if flag("light_off") else diffuser_material
	world.items.switch.get_node("Rocker").rotation.z = -.25 if flag("light_off") else .25
	for data in World.PAPER_SPOTS:world.items["paper_"+data[0]].visible = not flag("paper_"+data[0])
	world.items.cup.visible = value("holding")!=1
	world.items.cup.position = Vector3(-3.48,.82,4.65) if flag("cup_moved") else anchor_positions.cup
	world.items.ruler.visible = is_second_day() and value("holding")!=2
	world.items.yarn.visible = is_second_day() and value("holding")!=3
	world.items.yarn.position = Vector3(-5,.27,4.85) if flag("yarn_home") else Vector3(-4.56,.10,2.15) if flag("yarn_freed") else anchor_positions.yarn
	for id in ["mess_cup","mess_pot"]:
		world.items[id].position = anchor_positions[id]+Vector3(.20,-.38 if id=="mess_cup" else .14,.12) if flag(id) else anchor_positions[id]
		world.items[id].rotation.z = PI/2 if flag(id) else 0.0
	update_held_visual()
	if second_day() and second_day().world:second_day().restore_world()
	refresh_hud()

func reconcile_progress() -> void:
	if flag("papers_done"):
		for spot in World.PAPER_SPOTS:manager.flags["paper_"+spot[0]] = true
	if paper_count()==World.PAPER_SPOTS.size():manager.flags["papers_done"] = true
	# A carried old first-day ruler/yarn is returned safely; its progress is preserved.
	if not is_second_day() and value("holding") in [2,3]:manager.values["holding"] = 0
	var data: Dictionary = manager.make_save_data()
	var order := ["day1_arrival","day1_lights","day1_papers","day2_feed","day2_note","day2_laundry","day1_yarn","day2_dishes"]
	var previous_done := true
	for id in order:
		var definition = manager.definitions[id]
		var progress := {}
		var done := true
		for goal in definition.objectives:
			var count := paper_count() if str(goal.id)=="collect_paper" else (1 if flag(str(goal.id)) else 0)
			progress[str(goal.id)] = count
			if count<goal.target_count:done = false
		if id=="day2_note":previous_done = previous_done and flag("d2_started")
		data.quests[id] = {"status": (CalicoQuestManager.State.COMPLETED if done else CalicoQuestManager.State.ACTIVE) if previous_done else CalicoQuestManager.State.LOCKED, "progress": progress}
		previous_done = previous_done and done
	if data.quests!=manager.states:
		manager.restore_save_data(data)
		if manager.autosave:manager.save_game()

func update_held_visual() -> void:
	if is_instance_valid(held_visual):
		held_visual.get_parent().remove_child(held_visual)
		held_visual.queue_free()
		held_visual = null
	var holding := value("holding")
	if holding==0:return
	var id: String = ["","cup","ruler","yarn"][holding]
	held_visual = world.items[id].duplicate()
	for child in held_visual.get_children():
		if child is Label3D:child.hide()
	player.camera.add_child(held_visual)
	held_visual.visible = true
	held_visual.position = Vector3(.0,-.12,-.37)
	held_visual.rotation = Vector3.ZERO
	if holding==2:
		held_visual.position = Vector3(0,-.11,-.47)
		held_visual.rotation.y = PI/2 if value("ruler_vertical")==1 else 0.0
	else:held_visual.scale = Vector3.ONE*.7

func show_dialog(kind: String) -> void:
	dialog = kind
	page = 0
	game.cinematic_active = true
	player.set_control(false)
	render_page()

func render_page() -> void:
	match dialog:
		"intro":hud.show_page("醒来  ·  %d / %d" % [page+1,INTRO.size()],INTRO[page],page==INTRO.size()-1)
		"note":hud.show_page("第一天的小纸条","① 关掉客厅的灯。\n② 收集一楼的 %d 张纸片：客厅、餐厅、厨房和书房各一张。\n③ 解开厨房食物给予器，给自己和大狗嚼喂食。\n\n今天不用担心肚子饿。慢慢来。" % World.PAPER_SPOTS.size(),true)
		"ending":hud.show_page("不是我的毛……","毛线球上缠着几根灰白色的猫毛。\n可我的毛不是这样的。\n\n在我来之前，还有别的猫住过这里吗？\n毛线球已经送回窝了。接下来，把大狗嚼的盘子洗干净吧。",true)
		"rest":hud.show_page("第一天结束","今天，我学会了关灯、整理房间，也喂饱了自己和大狗嚼。给予器上的猫爪印……是谁留下的？\n\n蜷进窝里，好好睡一觉吧。\n醒来就是第二天，桌上会有新的小纸条。",true)

func advance_dialog() -> void:
	if dialog.is_empty():return
	if dialog=="intro" and page<INTRO.size()-1:
		page += 1
		render_page()
		return
	if dialog=="intro":mark("intro_seen")
	var start_next := dialog=="rest"
	if start_next:mark("day_complete")
	dialog = ""
	hud.overlay.hide()
	game.cinematic_active = false
	player.set_control(true)
	refresh_hud()
	if start_next and second_day():second_day().begin_day()

func _input(event: InputEvent) -> void:
	if not initialized or not event is InputEventKey or not event.pressed or event.echo:return
	if not dialog.is_empty():
		if event.keycode in [KEY_E,KEY_SPACE,KEY_ENTER,KEY_ESCAPE]:
			if event.keycode==KEY_ESCAPE and dialog=="intro":page = INTRO.size()-1
			advance_dialog()
		get_viewport().set_input_as_handled()
		return
	if balancing:
		if event.keycode==KEY_ESCAPE:finish_balance(false)
		elif event.keycode==KEY_E:balance_press()
		get_viewport().set_input_as_handled()
		return
	if not active_play():return
	if event.keycode==KEY_R and value("holding")==2:
		manager.set_value(&"ruler_vertical",1-value("ruler_vertical"))
		update_held_visual()
		refresh_hud()
		get_viewport().set_input_as_handled()
	elif event.keycode==KEY_G and value("holding")!=0:
		# Return to a known accessible anchor. Quest tools cannot be lost in walls/void.
		manager.set_value(&"holding",0)
		restore_world()
		game.ui.toast("松口了，道具已放回原处。",2)
		get_viewport().set_input_as_handled()

func nearest_item() -> String:
	if not active_play():return ""
	var eye: Vector3 = player.camera.global_position
	var forward: Vector3 = -player.camera.global_basis.z
	var best := 2.0
	var found := ""
	for id in world.items:
		if id in ["table","stool","television","switch"]:continue
		var node: Node3D = world.items[id]
		if not node.visible:continue
		if id in ["ruler","yarn"] and not yarn_available():continue
		if id=="yarn" and not flag("yarn_freed"):continue
		if id=="note" and not flag("cup_moved"):continue
		if id=="tray" and value("holding")!=1:continue
		var point := node.global_position+Vector3(0,.05,0)
		var delta := point-eye
		var alignment := forward.dot(delta.normalized())
		var score := 1.0-alignment+delta.length()*.03
		if delta.length()>1.10 or alignment<.78 or score>=best:continue
		var ray := PhysicsRayQueryParameters3D.create(eye,point,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.position.distance_to(point)>.10:continue
		best = score
		found = id
	# The ball is inside the sofa; interact with the reachable front opening, not through its seat.
	if not flag("yarn_freed") and yarn_available():
		var mouth := Vector3(-4.64,.13,2.15)
		var delta := mouth-eye
		if delta.length()<.85 and forward.dot(delta.normalized())>.5 and player.global_position.y<.25:
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,mouth,1))
			if hit.is_empty():found = "sofa_gap"
	return found

func target_hint() -> String:
	if value("current_day",1)>=3:return get_parent().get_node("ActTwo").target_hint()
	if not initialized:return ""
	if is_second_day() and second_day():return second_day().target_hint()
	target = nearest_item()
	if target.is_empty() and second_day():return second_day().target_hint()
	match target:
		"cup":return "E 叼起装水的纸杯" if flag("table") else "先跳上凳子，再跳上桌子"
		"tray":return "E 把纸杯放在杯垫上" if value("holding")==1 else "杯垫 · 用来放纸杯"
		"note":return "E 阅读今天的小纸条" if flag("cup_moved") else "纸杯压住了纸条 · 先叼到旁边的杯垫"
		"ruler":return "E 叼起尺子 · R 切换横叼 / 竖叼" if yarn_available() else "一楼工作书房的尺子 · 先完成前面的任务"
		"sofa_gap":return "E 用竖叼的尺子够出毛线球" if value("holding")==2 and value("ruler_vertical")==1 else "毛线球卡在里面 · 需要尺子，按 R 竖着叼"
		"yarn":return "E 叼起毛线球（尺子会放回书桌）"
		"nest":return "E 放下毛线球" if value("holding")==3 else "E 回窝休息" if feeding_done() else "这是我的窝"
		"mess_cup","mess_pot":return "已经倒了" if flag(target) else "E 推倒"+("杯子" if target=="mess_cup" else "盆栽")
	if target.begins_with("paper_"):return "E 收集纸片" if flag("light_off") else "先关掉客厅的灯，再整理纸片"
	return ""

func try_interact() -> bool:
	if value("current_day",1)>=3:return get_parent().get_node("ActTwo").try_interact()
	if not active_play():return false
	if is_second_day() and second_day():return second_day().try_interact()
	target = nearest_item()
	if target.is_empty():return second_day().try_interact() if second_day() else false
	perform_interaction(target)
	return true

func perform_interaction(id: String) -> void:
	# Callers must resolve a visible, nearby target. Preconditions also protect out-of-order actions.
	match id:
		"cup":
			if not flag("table") or value("holding")!=0:return
			manager.set_value(&"holding",1)
		"tray":
			if value("holding")!=1:return
			manager.set_value(&"holding",0)
			mark("cup_moved")
		"note":
			if not flag("cup_moved"):return
			if not flag("walk") or not flag("run"):
				game.ui.toast("先试试 WASD 移动，再按住 Shift 跑一小段。",3)
				return
			mark("note_read")
			show_dialog("note")
		"ruler":
			if not yarn_available() or value("holding")!=0 or second_day().val("d2_holding")!=0:return
			manager.set_value(&"holding",2)
			mark("ruler_found")
		"sofa_gap":
			if not yarn_available() or value("holding")!=2 or value("ruler_vertical")!=1:return
			mark("yarn_freed")
			game.ui.toast("够到了！毛线球滚出了沙发。",3)
		"yarn":
			if not yarn_available() or not flag("yarn_freed") or flag("yarn_home") or value("holding") not in [0,2]:return
			manager.set_value(&"holding",3)
		"nest":
			if yarn_available() and value("holding")==3:
				manager.set_value(&"holding",0)
				mark("yarn_home")
				show_dialog("ending")
			elif not is_second_day() and feeding_done():show_dialog("rest")
		"mess_cup","mess_pot":
			if flag(id):return
			mark(id)
			game.ui.toast("哗啦……房间变乱了一点。",2)
		_:
			if not id.begins_with("paper_") or not world.items.has(id) or not flag("light_off") or flag(id):return
			mark(id)
			manager.report_event(CalicoQuestObjective.Kind.CUSTOM,&"collect_paper",1,id)
			if paper_count()==World.PAPER_SPOTS.size():mark("papers_done")
	restore_world()

func paper_count() -> int:
	var count := 0
	for data in World.PAPER_SPOTS:
		if flag("paper_"+data[0]):count += 1
	return count

func start_balance() -> void:
	balancing = true
	balance_phase = 0
	balance_hits = 0
	balance_misses = 0
	balance_pressed = false
	game.cinematic_active = true
	player.set_control(false)
	player.velocity = Vector3.ZERO
	var toward: Vector3 = world.items.switch.global_position-player.global_position
	player.yaw = atan2(-toward.x,-toward.z)
	player.rotation.y = player.yaw
	toward = world.items.switch.global_position-player.camera.global_position
	player.pitch = atan2(toward.y,Vector2(toward.x,toward.z).length())
	player.head.rotation.x = player.pitch
	hud.balance_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func balance_press() -> void:
	if balance_pressed:return
	balance_pressed = true
	if balance_phase>=.36 and balance_phase<=.66:balance_hits += 1
	else:balance_misses += 1
	if balance_hits>=3:finish_balance(true)
	elif balance_misses>=3:finish_balance(false)

func finish_balance(success: bool) -> void:
	balancing = false
	tv_stable = success
	balance_cooldown = 1.5
	if world.items.has("television"):world.items.television.rotation = tv_rotation
	hud.balance_panel.hide()
	game.cinematic_active = false
	player.set_control(true)
	if success:
		game.ui.toast("稳住了！朝电视右侧的开关跳过去，用身体碰到它。",4)
	else:
		# Return to the detached stool, safely clear of the cabinet and panel.
		player.global_position = World.TV_RETRY_POSITION
		player.yaw = 0
		player.rotation.y = 0
		player.pitch = 0
		player.head.rotation.x = 0
		player.velocity = Vector3.ZERO
		game.ui.toast("滑回小凳子了。再跳上电视就能重试。",3)

func refresh_hud() -> void:
	if value("current_day",1)>=3:
		get_parent().get_node("ActTwo").refresh_hud()
		return
	if is_second_day():
		hud.set_paper_progress(0,4,false)
		if second_day():second_day().refresh_hud()
		return
	hud.day_title.text = "第一天  /  陌生的家"
	hud.status.text = "饱腹 100 / 100  ·  今日不消耗"
	if flag("papers_done"):hud.status.text = "我 %d / 100  ·  大狗嚼 %d / 100\n今日不消耗" % [value("cat_hunger",100),value("dog_hunger",100)]
	var text := ""
	if not flag("walk"):text = "WASD 走一走，鼠标环顾四周。"
	elif not flag("run"):text = "按住 Shift + WASD，试着跑一小段。"
	elif not flag("open_living"):text = "靠近左侧客厅门，看向把手，按 E 打开。"
	elif not flag("stool"):text = "客厅南窗边有一张桌子。按空格先跳上旁边的小凳子。"
	elif not flag("table"):text = "从凳子起跳，跳到放着纸条的桌上。"
	elif not flag("cup_moved"):text = "看向纸杯按 E 叼起，再看向左侧杯垫按 E 放下。"
	elif not flag("note_read"):text = "现在能看清纸条了。看向纸条按 E。"
	elif not flag("light_off"):text = "01  关灯\n先跳上电视柜，再跳到电视顶端。绿色区按 E，成功三次后起跳碰开关。"
	elif not flag("papers_done"):
		var missing := PackedStringArray()
		for data in World.PAPER_SPOTS:
			if not flag("paper_"+data[0]):missing.append(data[1])
		text = "整理纸片   %d / %d\n一楼 · 靠近纸片按 E\n待寻找：%s" % [paper_count(),World.PAPER_SPOTS.size(),"、".join(missing)]
	elif not feeding_done():text = "两份晚饭\n去厨房东侧，数三列猫爪印解锁给予器。叼猫碗盛粮回原位吃，再叼狗盘盛粮送到楼梯平台的大狗嚼身边。"
	else:text = "今日三件事都做完了。\n可以自由探索，也可以回猫窝按 E 休息。\n给予器上的猫爪印……是谁留下的？"
	hud.guidance.text = text
	hud.set_paper_progress(paper_count(),World.PAPER_SPOTS.size(),flag("light_off") and not flag("papers_done"))
	var holding := value("holding")
	hud.carry.text = "J 任务日志  ·  M 地图" if holding==0 else "叼着：%s\n%sG 松口并放回原处" % [["","水杯","尺子","毛线球"][holding],("竖叼" if value("ruler_vertical")==1 else "横叼")+" · R 切换\n" if holding==2 else ""]

	if second_day() and second_day().val("d2_holding")!=0:hud.carry.text = second_day().carry_text()

func restart_day() -> void:
	initialized = true
	manager = quests.manager
	dialog = ""
	balancing = false
	tv_stable = false
	walk_distance = 0
	run_distance = 0
	hud.overlay.hide()
	hud.balance_panel.hide()
	game.cinematic_active = false
	if second_day():second_day().reset_runtime()
	if get_parent().has_node("ActTwo"):get_parent().get_node("ActTwo").reset_runtime()
	restore_world()
	reset_spawn()
	# The caller is still inside the journal; do not steal pause/input ownership.
