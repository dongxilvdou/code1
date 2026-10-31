extends Node3D
const World = preload("res://act2/world.gd")
const Puzzles = preload("res://act2/puzzles.gd")
const CARRIED := ["","book0","book1","book2","can","fish","half_fish","bone","medicine"]
const GOALS := {"a3_books":3,"a3_photo":3,"a3_pipes":3,"a3_water":3,"a3_feed":3,"a5_letter":5,"a4_fridge":4,"a4_cook":4,"a4_share":4,"a4_toy":4,"a5_medicine":5,"a5_name":5}
var game
var day
var second
var player
var world
var puzzle
var held_visual: Node3D
var active_number := 0
var aim_progress := 0.0
var cook_clock := 0.0
var reminder_clock := 0.0
var tick_clock := 0.0
var hunger_clock := 0.0
var pending_story := ""

func _ready() -> void:
	game = get_parent()
	day = game.get_node("DayOne")
	second = game.get_node("DayTwo")
	player = game.get_node("Miso")
	world = World.new()
	world.build(self,game)
	puzzle = Puzzles.new()
	puzzle.chapter = self
	add_child(puzzle)
	puzzle.dismissed.connect(close_panel)
	puzzle.solved.connect(solved)
	set_world_enabled(false)
	call_deferred("add_chapter_entry")

func add_chapter_entry() -> void:
	var column = game.ui.welcome.get_node("MenuActions")
	var entry: Button = game.ui.button("第二幕 · 从第三天开始",column,start_chapter,true)
	column.move_child(entry,3)
	entry.tooltip_text = "保留前两天的完整流程，也可直接体验本次任务书内容。现有副本存档会先备份。"

func start_chapter() -> void:
	if game.started:return
	if not day.quests.prepare_session(true):return
	game.start_game()
	day.manager = day.quests.manager
	day.initialized = true
	day.quests.session_started = true
	seed_previous_days()
	begin_day(3)

func seed_previous_days() -> void:
	for key in ["intro_seen","walk","run","open_living","stool","table","cup_moved","note_read","light_off","papers_done","d2_unlocked","d2_cat_fed","d2_dog_fed","day_complete","d2_started","d2_note","d2_washed","ruler_found","yarn_freed","yarn_home","d2_dishes_done","d2_complete"]:set_flag(key)
	for id in second.CLOTHES:set_flag("d2_"+id)
	set_value("dish_stage",9)
	set_value("dish_flow_version",2)
	day.reconcile_progress()

func today() -> int:return day.value("current_day",1)
func active() -> bool:return day.initialized and today() in [3,4,5]
func flag(key: String) -> bool:return day.flag(key)
func val(key: String, fallback := 0) -> int:return day.value(key,fallback)
func set_value(key: String, value: int) -> void:day.manager.set_value(StringName(key),value)
func set_flag(key: String, value := true) -> void:day.manager.set_flag(StringName(key),value)
func mark(key: String) -> void:
	if flag(key):return
	set_flag(key)
	# Keep the historical catalog ID so existing saves still recognize this quest.
	day.manager.report_event(CalicoQuestObjective.Kind.CUSTOM,StringName("a4_letter" if key=="a5_letter" else key),1,"act2:"+key)

func migrate_schedule() -> void:
	if val("act2_schedule_version")>=3:return
	var data: Dictionary = day.manager.make_save_data()
	# The old fourth-day lunch letter does not count as the new care instructions.
	data.flags["a5_letter"] = false
	data.quests["a4_letter"] = {"status":CalicoQuestManager.State.ACTIVE if today()==5 else CalicoQuestManager.State.LOCKED,"progress":{"a4_letter":0}}
	data.flags["letter_dropped"] = false
	data.values["mail_shakes"] = 0
	data.values["act2_schedule_version"] = 3
	day.manager.restore_save_data(data)

func begin_day(number: int) -> void:
	if number<3 or number>5:return
	set_value("current_day",number)
	set_value("holding",0)
	set_value("d2_holding",0)
	set_value("a_holding",0)
	set_value("dog_hunger",45)
	set_value("cat_hunger",65)
	day.update_held_visual()
	second.update_held()
	day.restore_world()
	active_number = number
	player.spawn = Vector3(-4.45,.03,4.80)
	player.reset_position()
	restore()
	refresh_hud()

func set_world_enabled(enabled: bool) -> void:
	visible = enabled
	update_clues_visibility()
	for body in find_children("*","StaticBody3D",true,false):body.collision_layer = 1 if enabled else 0
	# The furnished bookcase and its collisions are permanent, including on days 1–2.

func clues_unlocked() -> bool:
	return photo_collected() or flag("a3_pipes") or flag("yarn_solved")

func photo_collected() -> bool:
	return flag("a3_photo") or (day.manager!=null and day.manager.get_status(&"a3_photo")==CalicoQuestManager.State.COMPLETED)

func update_clues_visibility() -> void:
	world.items.clues.visible=clues_unlocked()
	world.items.clues.get_node("CollectedPhotograph").visible=photo_collected()
	world.items.clues.get_node("PhotoIdentifier").visible=photo_collected()

func _physics_process(delta: float) -> void:
	if not day.initialized:return
	update_clues_visibility()
	if not active():
		if active_number!=0:reset_runtime()
		return
	if active_number!=today():
		active_number = today()
		day.restore_world()
		restore()
	if not day.active_play():return
	if today()==5 and not flag("a5_bell") and day.on_surface("table",Vector2(.76,.43),.80):
		mark("a5_bell")
		puzzle.play_note(3)
		story("茶几上没有今天的清单。\n\n叮咚——门铃响了！\n打开入户门，到门外看看信箱吧。")
		return
	if not day.Notes.read(day):
		refresh_hud()
		return
	if val("cook_state")==2:
		cook_clock += delta
		set_value("cook_millis",int(cook_clock*1000))
		if cook_clock>=6:
			set_value("cook_state",3)
			mark("a4_cook")
			set_value("cat_hunger",100)
			restore()
			story("烤箱发出轻轻的一声响。\n\n我吃掉了半条热乎乎的鱼。另一半还留在厨房。\n今天的冰箱里，真的只有这一条鱼。")
	if flag("a4_cook") and not flag("a4_share") and not flag("fish_reminded"):
		reminder_clock += delta
		if reminder_clock>=12:
			set_flag("fish_reminded")
			game.ui.toast("或许，大狗嚼也会想吃鱼。",6)
	hunger_clock += delta
	if hunger_clock>=30:
		hunger_clock = 0
		set_value("cat_hunger",maxi(0,val("cat_hunger",65)-1))
		set_value("dog_hunger",maxi(0,val("dog_hunger",45)-1))
	tick_clock += delta
	if tick_clock>.15:
		tick_clock = 0
		refresh_hud()
	world.camera_led.visible = flag("cabinet_open") and fmod(Time.get_ticks_msec()/1000.0,1.3)<.65
	for n in world.items.values():
		for child in n.get_children():
			if child is Label3D:child.visible = World.Props.interactable(n,today()) and n.global_position.distance_to(player.global_position)<3.0 and not (n==world.items.fish and val("cook_state")>0)

func restore() -> void:
	if active():migrate_schedule()
	set_world_enabled(active())
	if not active():return
	var holding := val("a_holding")
	if holding>0 and today() not in world.items[CARRIED[holding]].get_meta("interaction_days",[3,4,5]):
		set_value("a_holding",0)
		holding = 0
	for id in world.items:world.items[id].visible = true
	for i in range(3):
		world.items["book%d"%i].visible = holding!=i+1
		world.items["book%d"%i].set_meta("interaction_complete",flag("book%d"%i))
		world.place_book(i,flag("book%d"%i))
	world.items.photo.visible = flag("photo_dropped") and not flag("a3_photo")
	world.items.pipes.visible = flag("cabinet_open")
	world.items.camera.visible = flag("cabinet_open")
	for i in range(2):world.cabinet_hinges[i].rotation.y = (1.35 if i==0 else -1.35) if today()==3 and flag("cabinet_open") else 0
	world.items.can.visible = holding!=4
	world.water_surface.position.y = .12 if flag("water_halved") else .216
	world.items.mailbox.visible = true
	world.items.mailbox.set_meta("interaction_complete",flag("a5_letter"))
	world.items.mailbox.get_node("EnvelopeTip").visible = today()==5 and not flag("letter_dropped") and not flag("a5_letter")
	world.items.letter.visible = today()==5 and flag("letter_dropped") and not flag("a5_letter")
	world.fridge_hinge.rotation.y = -1.4 if (today()==4 and flag("a4_fridge")) or (today()==3 and flag("empty_fridge_open")) else 0.0
	world.items.fish.visible = today()>=4 and flag("a4_fridge") and holding!=5 and val("cook_state") in [0,1,2]
	world.items.fish.position = world.fish_in_oven if val("cook_state") in [1,2] else world.fish_home
	world.oven_hinge.rotation.x = 1.45 if today()==4 and val("cook_state") in [0,1,3] else 0
	world.oven_glow.light_energy = .45 if today()==4 and val("cook_state")==2 else 0
	world.items.half_fish.visible = today() in [4,5] and flag("a4_cook") and not flag("a4_share") and holding!=6
	world.items.yarn.visible = today()>=4 and not flag("yarn_solved") and not flag("a4_toy")
	world.items.yarn.position = world.shared_yarn_home
	world.items.bone.visible = flag("yarn_solved") and not flag("a4_toy") and holding!=7
	world.items.medicine.visible = today()==5 and not flag("medicine_taken") and not flag("a5_medicine")
	world.medicine_selection(flag("medicine_taken"))
	update_clues_visibility()
	day.world.items.note.visible = today()<5
	day.world.items.ruler.visible = false
	World.Props.apply(world.items,today())
	# Dates retire interaction targets as well as their labels and colliders.
	player.jump_locked = holding==4 and not flag("water_halved")
	player.variable_jump = true
	cook_clock = val("cook_millis")/1000.0
	update_held()
	refresh_hud()

func update_held() -> void:
	if is_instance_valid(held_visual):
		held_visual.get_parent().remove_child(held_visual)
		held_visual.queue_free()
		held_visual = null
	var holding := val("a_holding")
	if holding==0:return
	held_visual = world.items[CARRIED[holding]].duplicate()
	for child in held_visual.get_children():
		if child is Label3D:child.hide()
	player.camera.add_child(held_visual)
	held_visual.show()
	held_visual.position = Vector3(.12,-.18,-.40)
	held_visual.scale = Vector3.ONE*.65

func can_pickup() -> bool:
	if val("a_holding")!=0 or val("d2_holding")!=0:
		game.ui.toast("嘴里已经叼着东西了，按 G 放回安全位置。",3)
		return false
	return true

func target_position(id: String) -> Vector3:
	if id=="nest":return day.world.items.nest.global_position
	if id=="note":return day.note_target()
	if id in ["feeder","dog","dog_bowl","dog_spot","cat_bowl","cat_spot"]:return second.target_position(id)
	if id=="mailbox":return world.items.mailbox.global_position+Vector3(0,.40,.20)
	if id.begins_with("shelf"):return world.book_returns[int(id.right(1))].origin+world.original_bookcase.global_basis.z*.04
	if id=="can":return world.items.can.global_position+Vector3(0,.17,0)
	if id=="plant":return world.items.plant.global_position+Vector3(0,.65,0)
	if id=="cabinet" and flag("cabinet_open"):return world.items.cabinet.global_position+Vector3(-.50,0,.12)
	if id=="oven":return world.items.oven.global_position
	return world.items[id].global_position+Vector3(0,.05,0)

func nearest_item() -> String:
	if not active() or not day.active_play():return ""
	var choices: Array = world.items.keys()
	choices.append_array(["nest","dog","feeder","dog_bowl","cat_bowl"])
	if today()<5:choices.append("note")
	if val("d2_holding")==5:choices.append("dog_spot")
	if val("d2_holding")==4:choices.append("cat_spot")
	var found := ""
	var best := 3.0
	var eye: Vector3 = player.camera.global_position
	var forward: Vector3 = -player.camera.global_basis.z
	for id in choices:
		if world.items.has(id) and not World.Props.interactable(world.items[id],today()):continue
		if id=="fish" and val("cook_state")!=0:continue
		if id=="cat_bowl" and val("d2_holding")==4:continue
		if id=="dog_bowl" and val("d2_holding")==5:continue
		var pos := target_position(id)
		var delta := pos-eye
		var alignment := forward.dot(delta.normalized())
		if delta.length()>(1.60 if id=="plant" else 1.20) or alignment<.65:continue
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,pos,1))
		if not hit.is_empty() and hit.position.distance_to(pos)>.36:continue
		var score := 1.0-alignment+delta.length()*.08
		if score<best:
			best = score
			found = id
	return found

func target_hint() -> String:
	var id := nearest_item()
	if id=="":return ""
	if id=="note":return "E 阅读第 %d 天的小纸条"%today()
	if today()==5 and id=="mailbox":return "E 摇晃信箱，让信掉下来" if flag("a5_bell") else "今天的清单不见了，先跳上客厅茶几看看"
	if today()==5 and id=="letter":return "E 拾起并阅读来信"
	if not day.Notes.read(day):return "先去门外取信" if today()==5 else "先读完今天的小纸条"
	if id=="nest":return "E 休息，进入下一天" if day_complete() else "E 查看今天还要完成的事情"
	if id=="dog":return "E 与大狗嚼互动 / 交出叼着的物品"
	if id=="dog_bowl" and val("a_holding")==8:return "E 把药混进狗粮"
	if id in ["feeder","dog_bowl","dog_spot","cat_bowl","cat_spot"]:return second.target_hint()
	return "E "+str(world.titles.get(id,id))

func try_interact() -> bool:
	var id := nearest_item()
	if id.is_empty():return false
	interact_item(id)
	return true

func interact_item(id: String) -> void:
	if id=="note":
		day.show_dialog("note")
		return
	if not day.Notes.read(day) and not (today()==5 and id in ["mailbox","letter","nest"]):
		game.ui.toast(day.Notes.guidance(today()),4)
		return
	if world.items.has(id) and not World.Props.interactable(world.items[id],today()):return
	if not active():return
	if today()==3 and id in ["cabinet","pipes","can","drain","plant"]:
		if not flag("a3_books") or not flag("a3_photo"):
			game.ui.toast("先整理书架，并看看书里掉出来的照片。",4)
			return
		if id in ["can","drain","plant"] and not flag("a3_pipes"):
			game.ui.toast("先修好厨房水槽下的水管，再去浇花。",4)
			return
	var holding := val("a_holding")
	if id.begins_with("book"):
		var i := int(id.right(1))
		if flag(id) or not can_pickup():return
		set_value("a_holding",i+1)
		if i==1:set_flag("photo_dropped")
	elif id.begins_with("shelf"):
		var i := int(id.right(1))
		if holding!=i+1:game.ui.toast("把相同颜色的书叼到这个书格。",3)
		elif absf(player.global_position.y-world.shelves[i].y)>.20 or not player.is_on_floor():game.ui.toast("先跳到对应高度的书格上，再把书放好。",3)
		else:
			set_flag("book%d"%i)
			set_value("a_holding",0)
			if flag("book0") and flag("book1") and flag("book2"):mark("a3_books")
	elif id=="photo":
		if not flag("photo_dropped"):return
		mark("a3_photo")
		open_panel("photo")
	elif id=="cabinet":set_flag("cabinet_open",not flag("cabinet_open"))
	elif id=="pipes":
		if not flag("cabinet_open"):return
		if flag("a3_pipes"):story("水管已经接好了。红点却还在闪。\n它对准的不是水槽，是刚才修水管的我。")
		else:open_panel("pipes")
	elif id=="camera":story("那不是电源灯，是一枚很小的镜头。\n\n它一直在记录我如何修理水管。\n这个家里……也许还有别的镜头。")
	elif id=="can":
		if flag("a3_water"):game.ui.toast("花已经浇好了。",3)
		elif player.global_position.y<.69:game.ui.toast("先跳上沙发，再到西窗的窗台边叼起水壶。",4)
		elif can_pickup():
			set_value("a_holding",4)
			game.ui.toast("太重了，跳不起来。可以从窗台走下去，到淋浴间倒掉一半水。",6)
	elif id=="drain":
		if holding==4 and not flag("water_halved"):
			set_flag("water_halved")
			game.ui.toast("倒掉一半，水壶轻多了。现在可以跳上客厅沙发。",5)
		else:game.ui.toast("只有装满水的水壶需要在这里减重。",3)
	elif id=="plant":
		if flag("a3_water"):return
		if holding!=4:game.ui.toast("先去客厅西侧窗台叼水壶。",3)
		elif not flag("water_halved"):game.ui.toast("壶里水太满，先去淋浴间倒掉一半。",4)
		elif player.global_position.y<.43 or player.global_position.y>.82 or not player.is_on_floor() or Vector2(player.global_position.x+5.23,player.global_position.z-2).length()>1.25:game.ui.toast("先跳上花盆旁的沙发，再瞄准花盆。",4)
		else:open_panel("aim")
	elif id=="mailbox":
		if today()!=5 or not flag("a5_bell"):return
		if flag("letter_dropped"):game.ui.toast("信已经落在信箱前面的地上。",3)
		else:
			set_value("mail_shakes",val("mail_shakes")+1)
			var tween := create_tween()
			tween.tween_property(world.items.mailbox,"rotation:z",.10,.10)
			tween.tween_property(world.items.mailbox,"rotation:z",-.10,.10)
			tween.tween_property(world.items.mailbox,"rotation:z",0,.12)
			if val("mail_shakes")>=3:set_flag("letter_dropped")
			game.ui.toast("信掉下来了！" if flag("letter_dropped") else "信松动了一点，再摇一摇。",3)
	elif id=="letter":
		if not flag("letter_dropped"):return
		mark("a5_letter")
		story("信上写着：\n\n大狗嚼今天需要吃药。\n七只药瓶无法开盖，只能摇晃听声音。药片越多，碰撞声越响、越密。\n请从药片最少的三瓶里取药，照顾它吃下去。\n\n没有署名，也没有写它为什么需要吃药。")
	elif id=="fridge_lock":
		if today()<4:
			set_flag("empty_fridge_open",not flag("empty_fridge_open"))
			story("冰箱里空空的。今天还没有食材。")
		elif player.global_position.y<.80 or not player.is_on_floor():game.ui.toast("先跳上冰箱西侧的柜子，才能碰到机关。",4)
		elif flag("a4_fridge"):story("里面只有一条鱼，没有其他食材。")
		else:open_panel("slide")
	elif id=="fish":
		if not flag("a4_fridge") or today()<4 or val("cook_state")!=0:return
		if can_pickup():set_value("a_holding",5)
	elif id=="oven":
		if holding==5 and val("cook_state")==0:
			set_value("a_holding",0)
			set_value("cook_state",1)
			game.ui.toast("鱼放好了。再按 E 关上烤箱门。",4)
		elif val("cook_state")==1:
			set_value("cook_state",2)
			set_value("cook_millis",0)
			cook_clock = 0
			game.ui.toast("关门后烤箱自动开始加热。",4)
		elif val("cook_state")==2:game.ui.toast("正在烤鱼……",3)
		else:game.ui.toast("叼着冰箱里的鱼，放进烤箱。",3)
	elif id=="half_fish":
		if flag("a4_cook") and not flag("a4_share") and can_pickup():set_value("a_holding",6)
	elif id=="yarn":
		if flag("toy_requested"):open_panel("yarn")
		else:game.ui.toast("熟悉的毛线球，里面好像有个硬东西。去问问大狗嚼。",4)
	elif id=="bone":
		if flag("yarn_solved") and not flag("a4_toy") and can_pickup():
			set_value("a_holding",7)
			story("骨头上刻着：D-017 / 阿嚼。\n旁边还有两道记号：→ 短，↘ 长。\n\n又是实验编号。和照片上的 C-031 有什么关系？")
	elif id=="medicine":
		if today()==5 and not flag("medicine_taken") and can_pickup():open_panel("medicine")
	elif id=="dog":interact_dog()
	elif id=="dog_bowl" and holding==8:
		if not flag("medicine_refused"):story("先试试直接把药交给大狗嚼吧。")
		else:
			set_flag("medicine_mixed")
			set_value("a_holding",0)
			game.ui.toast("药藏进盘子里了。叼起盘子，到给予器盛狗粮，再送给大狗嚼。",6)
	elif id in ["feeder","dog_bowl","dog_spot","cat_bowl","cat_spot"]:
		if holding!=0:
			game.ui.toast("先按 G 放下叼着的物品。",3)
			return
		var feeding: bool = id=="dog_spot" and val("d2_holding")==5 and flag("dog_portion")
		second.interact_item(id)
		if feeding:dog_fed()
	elif id=="nest":
		if day_complete() and today()<5:
			begin_day(today()+1)
			return
		elif day_complete():
			get_parent().get_node("ActThree").begin_day(6)
			return
		else:story("今天还有事情没有做完。\n\n"+guidance())

	elif id=="clues":get_parent().get_node("ActThree").show_clues()
	restore()

func interact_dog() -> void:
	match val("a_holding"):
		6:
			set_value("a_holding",0)
			mark("a4_share")
			set_value("dog_hunger",100)
			dog_react()
			if not flag("a4_toy"):set_flag("toy_requested")
			story("大狗嚼：这鱼……是给我的？\n\n谢谢。"+toy_dialogue())
		7:
			set_value("a_holding",0)
			mark("a4_toy")
			dog_react()
			story("大狗嚼把骨头抱在爪子里。\n\n“是它！我一直在找它。”\n\nD-017。这个编号也属于它吗？")
		8:
			set_flag("medicine_refused")
			story("大狗嚼把头扭开了。\n\n“这味道太苦了，我不吃。”\n\n它不肯直接吃药。试着把药藏进它的狗粮盘里。")
		_:
			if val("d2_holding")==5:
				var fed := flag("dog_portion")
				second.interact_item("dog")
				if fed:dog_fed()
			elif today()==3:story("大狗嚼：我不喜欢洗过的碗，有一股消毒水味。\n\n以后不用每顿都洗了。你今天……还记得给我带饭吧？")
			elif today()==4:
				if not flag("a4_toy"):set_flag("toy_requested")
				story("大狗嚼："+toy_dialogue())
			elif flag("a5_medicine"):
				if flag("a5_name"):story("阿嚼：原来我叫阿嚼。\n\n我想起来了……你以前也这样叫过我。\n谢谢你没有忘记。")
				else:
					if not flag("a4_toy"):set_flag("toy_requested")
					open_panel("voice")
			else:story("大狗嚼：今天有点没精神。\n桌上的药，闻起来很苦。")

func toy_dialogue() -> String:
	# The handoff flag takes precedence over the earlier request and puzzle flags.
	if flag("a4_toy"):return "玩具已经找回来了，谢谢你。\n\n这上面的编号……我好像记得。"
	if flag("yarn_solved"):return "那根刻着 D-017 的骨头，好像就是我的玩具。\n\n叼过来让我看看吧。"
	return "我的玩具丢了。最后是在客厅沙发旁边。\n\n那边不是有个毛线球吗？帮我看看里面。"

func dog_fed() -> void:
	if today()==3:mark("a3_feed")
	if today()==5 and flag("medicine_mixed"):
		mark("a5_medicine")
		set_value("dog_affection",val("dog_affection")+1)
		set_flag("medicine_mixed",false)
		story("药混在狗粮里，它终于吃下去了。\n\n大狗嚼轻轻碰了碰你的额头。\n好感度上升。再和它聊聊吧。")

func dog_react() -> void:
	var actor = second.world.items.dog.get_meta("actor")
	actor.react_to_food()

func open_panel(kind: String, text := "") -> void:
	game.cinematic_active = true
	player.set_control(false)
	puzzle.open(kind,text)

func story(text: String) -> void:open_panel("story",text)

func close_panel() -> void:
	game.cinematic_active = false
	player.set_control(true)
	refresh_hud()

func solved(kind: String) -> void:
	if not day.Notes.read(day):return
	puzzle.close()
	match kind:
		"pipes":
			mark("a3_pipes")
			story("水顺着管道流向出口。修好了。\n\n门内那个闪烁的红点，是监控镜头。\n它在观察我解开水管，而不是观察漏水。")
		"slide":
			mark("a4_fridge")
			story("咔哒。冰箱门打开了。\n\n里面只有一条鱼。叼出来，放进灶台下方的烤箱，再关门。")
		"yarn":
			set_flag("yarn_solved")
			story("最后一根毛线松开，一根玩具骨头掉了出来。\n\n叼起来，看看上面的刻字。")
		"medicine":
			set_flag("medicine_taken")
			set_value("a_holding",8)
			game.ui.toast("拿到了三瓶少量的药。先去找大狗嚼。",4)
		"voice":
			mark("a5_name")
			dog_react()
			story("“喵——喵。”\n\n大狗的尾巴摇了起来。\n“阿嚼……对，我叫阿嚼。我想起来了。”\n\n它靠近你，像认出了一个很久以前的朋友。\n\n第二幕完。回猫窝可以再次查看结语。")
		"aim":
			mark("a3_water")
			set_value("a_holding",0)
			game.ui.toast("水落进花盆，叶子慢慢舒展开了。",4)
	restore()

func day_complete() -> bool:
	if not day.Notes.read(day):return false
	for key in GOALS:
		if key in ["a4_share","a4_toy","a5_name"]:continue
		if GOALS[key]==today() and not flag(key):return false
	return true

func guidance() -> String:
	if today()==5 and not flag("a5_letter"):
		return "01 没有清单的一天\n打开入户门，摇晃门外偏西的高信箱三次，再拾起掉落的信。" if flag("a5_bell") else day.Notes.guidance(5)
	if not day.Notes.read(day):return day.Notes.guidance(today())
	if today()==3:
		if not flag("a3_books"):return "01 整理书架\n把地上的三本书放回对应书列。"
		if not flag("a3_photo"):return "书里掉出了一张照片。回书架旁的地上看看。"
		if not flag("a3_pipes"):return "02 修理水管\n到厨房水槽下面，打开柜门，接通水管。"
		if not flag("a3_water"):return "03 浇花\n取来窗台上的水壶，照顾沙发旁的花。"
		if not flag("a3_feed"):return "今天还没喂大狗嚼。叼狗盘到厨房给予器盛粮，再送回楼梯平台。"
	elif today()==4:
		if not flag("a4_fridge"):return "01 猫用冰箱\n跳上冰箱西侧柜台，解开侧面的八数码机关。"
		if not flag("a4_cook"):return "02 做午饭\n叼鱼放进灶台下方的烤箱，再按 E 关门，等它烤熟。"
		if not flag("a4_share"):return "厨房还有半条鱼。大狗嚼也许会想尝一尝。"
		if not flag("a4_toy"):return "和大狗嚼聊聊。它的玩具可能藏在客厅沙发旁的毛线球里。"
	else:
		if not flag("a5_medicine"):return "02 照顾阿嚼\n按信上的要求听一听药瓶，再去找它。"
		if not flag("a5_name"):return "今天的照护任务完成了，可以回窝。\n也可以再和大狗嚼聊聊，它似乎还有心事。"
	return "今天的事情都完成了。回南窗边的猫窝休息。"

func refresh_hud() -> void:
	if not active():return
	day.hud.day_title.text = {3:"第三天 / 被观察的日常",4:"第四天 / 只剩一条鱼",5:"第五天 / 记得你的名字"}[today()]
	day.hud.guidance.text = guidance()
	day.hud.status.text = "饱食度：%d/100"%val("cat_hunger",65)
	day.hud.set_paper_progress(0,4,false)
	var holding := val("a_holding")
	day.hud.carry.text = "叼着："+str(world.titles[CARRIED[holding]])+"\nG 放回安全位置" if holding!=0 else second.carry_text()
	if player.jump_locked:day.hud.carry.text += "\n水太满，无法跳跃"

func _input(event: InputEvent) -> void:
	if not active() or not day.active_play():return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_G and val("a_holding")!=0:
		if val("a_holding")==8:set_flag("medicine_taken",false)
		set_value("a_holding",0)
		restore()
		get_viewport().set_input_as_handled()

func reset_runtime() -> void:
	active_number = 0
	aim_progress = 0
	cook_clock = 0
	reminder_clock = 0
	hunger_clock = 0
	player.jump_locked = false
	player.variable_jump = false
	day.world.items.note.show()
	set_world_enabled(false)
	puzzle.mode = ""
	puzzle.shell.hide()
	for hinge in world.cabinet_hinges:hinge.rotation.y = 0
	world.fridge_hinge.rotation.y = 0
	world.oven_hinge.rotation.x = 0
	world.oven_glow.light_energy = 0
	if is_instance_valid(held_visual):
		held_visual.queue_free()
		held_visual = null
