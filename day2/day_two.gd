extends Node3D
const World = preload("res://day2/world.gd")
const PuzzleUI = preload("res://day2/puzzle_ui.gd")
const CLOTHES := ["cloth_sofa","cloth_chair","cloth_entry"]
const HELD := ["","cloth_sofa","cloth_chair","cloth_entry","cat_bowl","dog_bowl"]
var day
var game
var player
var world
var puzzle
var ready_state := false
var held_visual: Node3D
var anchors := {}
var hunger_clock := 0.0
var wash_clock := 0.0
var clock := 0.0

func _ready() -> void:
	game = get_parent()
	day = game.get_node("DayOne")
	player = game.get_node("Miso")
	world = World.new()
	world.build(self,game)
	for id in world.items:anchors[id] = world.items[id].position
	puzzle = PuzzleUI.new()
	add_child(puzzle)
	puzzle.dismissed.connect(close_puzzle)
	puzzle.solved.connect(solve_puzzle)
	visible = false
	world.stream.hide()
	world.foam.hide()
	_set_collisions(false)

func flag(key: String) -> bool:return day.flag(key)
func val(key: String, fallback := 0) -> int:return day.value(key,fallback)
func active_day() -> bool:return day.initialized and val("current_day",1)==2
func feeding_available() -> bool:return day.initialized and flag("papers_done")
func runtime_available() -> bool:return active_day() or feeding_available()
func dishes_available() -> bool:return active_day() and day.yarn_available() and flag("yarn_home")
func set_value(key: String, number: int) -> void:day.manager.set_value(StringName(key),number)
func set_flag(key: String, enabled: bool) -> void:day.manager.set_flag(StringName(key),enabled)

func mark(key: String) -> void:
	if not flag(key):set_flag(key,true)
	day.manager.report_event(CalicoQuestObjective.Kind.CUSTOM,StringName(key),1,"day2:"+key)

func begin_day() -> void:
	if not day.initialized or not day.feeding_done():return
	# Old day-one completion saves migrate without changing their existing progress.
	set_value("current_day",2)
	set_value("holding",0)
	set_value("d2_holding",0)
	day.update_held_visual()
	if not flag("d2_started"):
		set_value("cat_hunger",65)
		set_value("dog_hunger",45)
		set_flag("d2_started",true)
	ready_state = true
	reconcile()
	day.restore_world()
	player.spawn = Vector3(-4.45,.03,4.80)
	player.reset_position()
	show_story("天亮了。昨天我和大狗嚼都吃饱了。\n\n先去桌上看看今天的小纸条吧。\n这一次，肚子开始有一点饿了。")

func _physics_process(delta: float) -> void:
	if not day.initialized:return
	if not ready_state:
		if active_day():
			if not flag("d2_started"):begin_day()
			else:
				ready_state = true
				reconcile()
				restore_world()
		elif flag("day_complete"):begin_day()
	if not runtime_available() or not day.active_play():return
	if active_day():advance_time(delta)
	clock += delta
	if clock>.15:
		clock = 0
		refresh_hud()
	if world.dog_tail:world.dog_tail.rotation.z = sin(Time.get_ticks_msec()*.006)*(.35 if val("dog_hunger",45)>50 else .09)

func _process(_delta: float) -> void:
	if not runtime_available():return
	for item in world.items.values():
		for child in item.get_children():
			if child is Label3D:
				var distance: float = player.camera.global_position.distance_to(child.global_position)
				child.visible = distance>.60 and distance<3.5

func advance_time(delta: float) -> void:
	# Only active play counts, never menus, puzzles or time outside the game.
	hunger_clock += delta
	if hunger_clock>=20:
		var points := int(hunger_clock/20)
		hunger_clock = fmod(hunger_clock,20)
		set_value("cat_hunger",maxi(0,val("cat_hunger",65)-points))
		set_value("dog_hunger",maxi(0,val("dog_hunger",45)-points))
	if flag("d2_washing") and not flag("d2_washed"):
		wash_clock += delta
		if world.washer_hinge:world.washer_hinge.rotation.z = sin(wash_clock*14)*.008
		if wash_clock>=4:
			mark("d2_washed")
			set_flag("d2_washing",false)
			wash_clock = 0
			reconcile()
			restore_world()
			show_story("洗好了。旋钮最后的声音，和记忆里一模一样。\n\n接下来去一楼工作书房找尺子，取回沙发底下的毛线球。")

func loaded_count() -> int:
	var count := 0
	for id in CLOTHES:
		if flag("d2_"+id):count += 1
	return count

func reconcile() -> void:
	if val("dish_stage")==9:set_flag("d2_dishes_done",true)
	day.reconcile_progress()

func _set_collisions(enabled: bool) -> void:
	for n in find_children("*","StaticBody3D",true,false):n.collision_layer = 1 if enabled else 0

func restore_world() -> void:
	visible = runtime_available()
	_set_collisions(runtime_available())
	if not runtime_available():return
	for id in world.items:world.items[id].visible = active_day() or id in ["feeder","cat_bowl","dog_bowl","dog"]
	for name in ["WashStep","SinkStep"]:
		get_node(name).visible = active_day()
	# Step colliders are siblings of their meshes; only the dog/feeder collide on day one.
	for body in get_children():
		if body is StaticBody3D:body.collision_layer = 1 if active_day() else 0
	for id in CLOTHES:world.items[id].visible = active_day() and not flag("d2_"+id) and HELD[val("d2_holding")]!=id
	if world.washer_hinge:
		world.washer_hinge.rotation.y = -1.4 if flag("washer_open") else 0.0
		world.washer_hinge.rotation.z = 0
	var stage := val("dish_stage")
	world.items.cat_bowl.visible = val("d2_holding")!=4
	world.items.dog_bowl.visible = val("d2_holding")!=5
	world.items.dog_bowl.position = Vector3(1.98,.94,-5.38) if stage in [1,2,3,4,5,6,7] else Vector3(2.85,.945,-5.34) if stage==9 else anchors.dog_bowl
	world.food.cat_bowl.visible = flag("cat_portion")
	world.food.dog_bowl.visible = flag("dog_portion")
	world.stains.visible = flag("d2_dog_fed") and stage<6 and not flag("dog_portion")
	world.stream.visible = active_day() and stage in [2,6]
	world.foam.visible = active_day() and stage in [5,6]
	world.items.sink.visible = active_day() and stage not in [1,2,3,4,5,6,7]
	for n in get_tree().get_nodes_in_group("placed_furniture"):
		if n.get_meta("asset_id","")=="decor_pet_bowls":n.hide()
	update_held()
	refresh_hud()

func update_held() -> void:
	if is_instance_valid(held_visual):
		held_visual.get_parent().remove_child(held_visual)
		held_visual.queue_free()
		held_visual = null
	var holding := val("d2_holding")
	if holding==0:return
	held_visual = world.items[HELD[holding]].duplicate()
	for child in held_visual.get_children():
		if child is Label3D:child.hide()
	player.camera.add_child(held_visual)
	held_visual.visible = true
	held_visual.position = Vector3(0,-.12,-.36)
	held_visual.rotation = Vector3.ZERO
	held_visual.scale = Vector3.ONE*.65

func open_puzzle(kind: String, text := "") -> void:
	game.cinematic_active = true
	player.set_control(false)
	puzzle.open(kind,text)
	if kind=="wash":
		puzzle.knob.value_changed.connect(func(value: float):
			world.items.washer_dial.rotation.y = (value-1)*PI*.65)

func show_story(text: String) -> void:open_puzzle("story",text)

func close_puzzle() -> void:
	game.cinematic_active = false
	player.set_control(true)
	refresh_hud()
	if not active_day():day.refresh_hud()

func solve_puzzle(kind: String) -> void:
	if kind=="wash":
		if loaded_count()!=3 or flag("washer_open") or not flag("d2_note"):return
		set_flag("d2_washing",true)
		wash_clock = 0
	elif kind=="code":mark("d2_unlocked")
	puzzle.close()
	restore_world()
	game.ui.toast("洗衣机开始转动了。" if kind=="wash" else "咔哒，解锁了。叼着对应的碗，再按 E 盛粮。",4)

func nearest_item() -> String:
	if not runtime_available() or not day.active_play():return ""
	var eye: Vector3 = player.camera.global_position
	var forward: Vector3 = -player.camera.global_basis.z
	var choices: Dictionary = world.items.duplicate()
	if active_day():
		choices["note"] = day.world.items.note
		choices["nest"] = day.world.items.nest
		for id in ["mess_cup","mess_pot"]:choices[id] = day.world.items[id]
		var yarn_target: String = day.nearest_item()
		if yarn_target in ["ruler","yarn","sofa_gap"]:return yarn_target
	if val("d2_holding")==4:choices["cat_spot"] = world.items.cat_bowl
	var best := 2.0
	var found := ""
	for id in choices:
		var n: Node3D = choices[id]
		if not n.visible and id!="cat_spot":continue
		var pos: Vector3 = target_position(id)
		var delta := pos-eye
		var alignment := forward.dot(delta.normalized())
		var score := 1.0-alignment+delta.length()*.005
		if delta.length()>1.15 or alignment<.77 or score>=best:continue
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,pos,1))
		if not hit.is_empty() and hit.position.distance_to(pos)>.12:continue
		best = score
		found = id
	return found

func target_position(id: String) -> Vector3:
	if id=="sofa_gap":return Vector3(-4.64,.13,2.15)
	var n: Node3D = day.world.items[id] if id in ["note","nest","mess_cup","mess_pot","ruler","yarn"] else world.items["cat_bowl" if id=="cat_spot" else id]
	var pos := n.global_position+Vector3(0,.05,0)
	if id=="feeder":return n.to_global(Vector3(0,.50,.28))
	if id=="dog":pos += Vector3(0,.40,.35)
	return pos

func target_hint() -> String:
	var id := nearest_item()
	var holding := val("d2_holding")
	if id in CLOTHES:return "E 叼起待洗衣服" if flag("d2_note") else "先看今天的小纸条"
	match id:
		"ruler":return "E 叼起尺子 · R 切换横叼 / 竖叼"
		"sofa_gap":return "E 用竖叼的尺子够出毛线球"
		"yarn":return "E 叼起毛线球"
		"note":return "E 阅读第二天的小纸条"
		"washer_door":return "E 放入衣服  %d / 3" % loaded_count() if holding in [1,2,3] and flag("washer_open") else "E 关闭洗衣机门" if flag("washer_open") else "E 打开洗衣机门"
		"washer_dial":return "E 回忆洗衣旋律 · 需要站到洗衣机顶上"
		"feeder":return "E 研究脚印密码" if not flag("d2_unlocked") else "E 给叼着的碗盛粮（猫粮 / 狗粮自动区分）"
		"cat_bowl":return "E 叼起自己的碗"
		"cat_spot":return "E 放下猫碗吃饭" if flag("cat_portion") else "先叼碗去给予器盛猫粮"
		"dog_bowl":return dish_hint() if val("dish_stage") in [1,2,3,4,5,6,7] else "E 叼起大狗嚼的盘子"
		"dog":return "E 把盛好的狗粮送给大狗嚼" if holding==5 and flag("dog_portion") else "大狗嚼 · 饱腹 %d / 100" % val("dog_hunger",45)
		"sink":return "E 把脏盘子放进水槽"
		"tap":return "E 关水" if val("dish_stage") in [2,6] else "E 开水"
		"soap":return "E 按压洗洁精，沾到爪子上"
		"drying":return "E 把干净盘子放到水槽旁"
		"nest":return "E 放下毛线球" if val("holding")==3 else "E 休息，结束第二天" if flag("d2_dishes_done") else "先做完今天的三件事吧"
		"mess_cup","mess_pot":return "已经倒了" if flag(id) else "E 推倒 · 会降低整洁度"
	return ""

func dish_hint() -> String:
	match val("dish_stage"):
		1:return "先开水龙头，把盘子润湿"
		2:return "盘子湿了 · 再按水龙头关水"
		3:return "先按压旁边的洗洁精"
		4:return "E 用爪子把洗洁精涂抹在盘子上"
		5:return "泡沫覆盖了盘子 · 再开水冲洗"
		6:return "冲干净了 · 关水后叼起"
		7:return "E 叼起干净盘子，放到沥水垫"
	return ""

func try_interact() -> bool:
	var id := nearest_item()
	if id.is_empty():return false
	interact_item(id)
	return true

func interact_item(id: String) -> void:
	if not runtime_available():return
	if not active_day() and id not in ["feeder","cat_bowl","cat_spot","dog_bowl","dog"]:return
	if active_day() and (id in ["ruler","yarn","sofa_gap"] or (id=="nest" and val("holding")==3)):
		day.perform_interaction(id)
		return
	var holding := val("d2_holding")
	if id in ["mess_cup","mess_pot"]:day.perform_interaction(id)
	elif id=="note":
		mark("d2_note")
		show_story("今天的小纸条\n\n① 收集三件衣服，放进洗衣机。按记忆里的旋律找到洗衣程序。\n② 用工作书房的尺子，取回沙发底下的毛线球，送回猫窝。\n③ 洗净大狗嚼的盘子，放到水槽旁。")
	elif id in CLOTHES:
		if not flag("d2_note") or not day.feeding_done() or val("holding")!=0 or holding!=0 or flag("d2_"+id):return
		set_value("d2_holding",CLOTHES.find(id)+1)
		if not flag("d2_no_smell"):
			set_flag("d2_no_smell",true)
			show_story("这些衣服明明被放在了待洗的位置……\n可叼起来时，一点臭味也没有。\n连主人身上熟悉的气味，都很淡。")
	elif id=="washer_door":
		if not flag("d2_note") or not day.feeding_done() or flag("d2_washing") or flag("d2_washed"):return
		if flag("washer_open") and holding in [1,2,3]:
			mark("d2_"+HELD[holding])
			set_value("d2_holding",0)
		else:set_flag("washer_open",not flag("washer_open"))
	elif id=="washer_dial":
		if not flag("d2_note") or not day.feeding_done() or flag("d2_washed") or flag("d2_washing"):return
		if loaded_count()!=3 or flag("washer_open"):
			game.ui.toast("先放入三件衣服，再关好洗衣机门。",3)
			return
		if player.global_position.y<.80 or player.global_position.y>1.05 or not player.is_on_floor():
			game.ui.toast("跳上洗衣机，再碰一碰顶部的旋钮。",3)
			return
		open_puzzle("wash")
	elif id=="feeder":
		if not feeding_available():
			game.ui.toast("先收齐第一天的纸片，再来研究给予器。",3)
			return
		if not flag("d2_unlocked"):open_puzzle("code")
		elif holding==4:set_flag("cat_portion",true)
		elif holding==5 and (not flag("d2_dog_fed") or val("dish_stage") in [8,9]):set_flag("dog_portion",true)
		else:game.ui.toast("先叼起空碗；脏的狗盘需要洗净才能再盛粮。",3)
	elif id=="cat_bowl":
		if not feeding_available() or holding!=0 or val("holding")!=0:return
		set_value("d2_holding",4)
	elif id=="cat_spot":
		if holding!=4 or not flag("cat_portion"):return
		set_flag("cat_portion",false)
		set_value("d2_holding",0)
		set_value("cat_hunger",100)
		mark("d2_cat_fed")
		game.ui.toast("吃饱了。也别忘了大狗嚼。",3)
	elif id=="dog":
		if holding!=5 or not flag("dog_portion"):return
		set_flag("dog_portion",false)
		set_value("d2_holding",0)
		set_value("dog_hunger",100)
		set_value("dish_stage",0)
		mark("d2_dog_fed")
		game.ui.toast("大狗嚼吃光了狗粮，尾巴摇了起来。",3)
	elif id=="dog_bowl":
		if not feeding_available() or holding!=0 or val("holding")!=0:return
		if val("dish_stage")==4:set_value("dish_stage",5)
		elif val("dish_stage")==7:
			set_value("dish_stage",8)
			set_value("d2_holding",5)
		elif val("dish_stage") in [0,8,9]:set_value("d2_holding",5)
	elif id=="sink":
		if not dishes_available() or holding!=5 or not flag("d2_dog_fed") or not flag("d2_cat_fed") or flag("dog_portion"):return
		set_value("dish_stage",1)
		set_value("d2_holding",0)
		if not flag("d2_no_dishes"):
			set_flag("d2_no_dishes",true)
			show_story("大狗嚼的盘子确实需要好好洗洗。\n\n可这里怎么找不到人用的盘子和碗筷？\n这个厨房，好像没有谁真正用它吃过饭。")
	elif id=="tap":
		if not dishes_available():return
		var stages := {1:2,2:3,5:6,6:7}
		if stages.has(val("dish_stage")):set_value("dish_stage",stages[val("dish_stage")])
	elif id=="soap":
		if not dishes_available():return
		if val("dish_stage")==3:set_value("dish_stage",4)
	elif id=="drying":
		if not dishes_available() or holding!=5 or val("dish_stage")!=8:return
		set_value("d2_holding",0)
		set_value("dish_stage",9)
		mark("d2_dishes_done")
		show_story("洗干净的盘子，已经放到水槽旁。\n\n今天的三件事都完成了。\n没有气味的衣服、毛线球上的陌生猫毛，还有这个没有人用餐的厨房……\n这里到底是什么地方？")
	elif id=="nest" and flag("d2_dishes_done"):
		mark("d2_complete")
		show_story("第二天结束\n\n衣服洗好了，毛线球找回来了，狗盘也洗干净了。\n明天，也要继续学着照顾主人。\n\n第三天尚未开放，关闭后仍可探索、补粮和清洗。")
	reconcile()
	restore_world()
	if not active_day():day.refresh_hud()

func _input(event: InputEvent) -> void:
	if not runtime_available() or not day.active_play() or not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_G and val("d2_holding")!=0:
		set_value("d2_holding",0)
		if val("dish_stage")==8:set_value("dish_stage",7)
		restore_world()
		day.refresh_hud()
		game.ui.toast("道具已放回安全位置。",2)
		get_viewport().set_input_as_handled()

func refresh_hud() -> void:
	if not active_day():return
	day.hud.day_title.text = "第二天  /  学着照顾"
	day.hud.status.text = "我  %d / 100    大狗嚼  %d / 100\n整洁 %d / 100" % [val("cat_hunger",65),val("dog_hunger",45),val("cleanliness",100)]
	var text := ""
	if not day.feeding_done():text = "旧进度已保留。先补完已移到第一天的喂食：到厨房解锁给予器，叼猫碗和狗盘盛粮，分别吃饭、送给大狗嚼。"
	elif not flag("d2_note"):text = "先去客厅南窗边的桌子，阅读今天的小纸条。"
	elif not flag("d2_washed"):
		text = "01  洗衣服  %d / 3\n衣服在沙发、客厅小凳子、玄关地上。叼到洗衣间，开机门、放入、关门，再跳上洗衣机调旋钮。" % loaded_count()
		if flag("d2_washing"):text = "洗衣机正在运转……\n洗好后去工作书房找尺子。"
	elif not flag("ruler_found"):text = "02  沙发底下的秘密\n到一楼东南角工作书房，跳上书桌叼起尺子。"
	elif not flag("yarn_freed"):text = "02  取回毛线球\n叼尺子回客厅沙发前，R 改为竖叼，低头按 E 够出毛线球。"
	elif not flag("yarn_home"):text = "02  取回毛线球\n叼起滚出来的毛线球，送到客厅南窗边的猫窝。"
	elif not flag("d2_dishes_done"):
		text = "03  洗狗盘\n叼脏盘到厨房水槽。\n润湿 → 关水 → 洗洁精 → 涂抹 → 冲洗 → 关水 → 叼到沥水垫。\n"+dish_hint()
	else:text = "今天的事情完成了。\n回窝可以休息。饱腹仍会下降，给予器已永久解锁，可以随时补粮；狗盘脏了要洗净再用。"
	day.hud.guidance.text = text
	day.hud.carry.text = carry_text()
	if val("holding") in [2,3]:day.hud.carry.text = "叼着：%s\n%sG 松口并放回原处" % ["尺子" if val("holding")==2 else "毛线球", ("竖叼" if val("ruler_vertical")==1 else "横叼")+" · R 切换\n" if val("holding")==2 else ""]

func carry_text() -> String:
	var holding := val("d2_holding")
	return "J 任务日志  ·  M 地图" if holding==0 else "叼着：%s\nG 松口并放回安全位置" % (["","沙发上的衣服","凳子上的衣服","玄关的衣服","自己的猫碗","大狗嚼的盘子"][holding])

func reset_runtime() -> void:
	ready_state = false
	hunger_clock = 0
	wash_clock = 0
	visible = false
	_set_collisions(false)
	puzzle.mode = ""
	puzzle.shell.hide()
	puzzle.audio.stop()
	puzzle.memory_audio.stop()
	if is_instance_valid(held_visual):
		held_visual.queue_free()
		held_visual = null
	if world.washer_hinge:world.washer_hinge.rotation = Vector3.ZERO
	world.stream.hide()
	world.foam.hide()
	for n in get_tree().get_nodes_in_group("placed_furniture"):
		if n.get_meta("asset_id","")=="decor_pet_bowls":n.show()
