extends Node3D
const World = preload("res://act3/world.gd")
const Panels = preload("res://act3/panels.gd")
const Computer = preload("res://act3/computer_ui.gd")
const Circuit = preload("res://act3/lights_out.gd")
const CAT_KG := 3.0
const REQUIRED_KG := 8.0
var game
var day
var second
var previous
var player
var world
var panel
var computer
var held_visual: Node3D
var active_number := 0
var weight_time := 0.0
var hunger_time := 0.0
var hud_time := 0.0
var meter: PanelContainer
var meter_label: Label
var meter_bar: ProgressBar
var _restoring := false

func _ready() -> void:
	game = get_parent()
	day = game.get_node("DayOne")
	second = game.get_node("DayTwo")
	previous = game.get_node("ActTwo")
	player = game.get_node("Miso")
	world = World.new()
	world.build(self,game)
	panel = Panels.new()
	panel.chapter = self
	add_child(panel)
	panel.dismissed.connect(close_panel)
	computer = Computer.new()
	computer.chapter = self
	add_child(computer)
	computer.dismissed.connect(close_panel)
	build_meter()
	call_deferred("add_entry")

func today() -> int:return day.value("current_day",1)
func active() -> bool:return day.initialized and today() in [6,7]
func flag(key: String) -> bool:return day.flag(key)
func val(key: String, fallback := 0) -> int:return day.value(key,fallback)
func set_value(key: String, value: int) -> void:day.manager.set_value(StringName(key),value)
func set_flag(key: String, value := true) -> void:day.manager.set_flag(StringName(key),value)
func mark(key: String) -> void:
	if flag(key):return
	set_flag(key)
	day.manager.report_event(CalicoQuestObjective.Kind.CUSTOM,StringName(key),1,"act3:"+key)

func add_entry() -> void:
	var actions: Node = game.ui.welcome.get_node("MenuActions")
	var entry: Button = game.ui.button("第三幕 · 从第六天开始",actions,start_chapter,true)
	actions.move_child(entry,4)
	entry.tooltip_text = "从第六天的早晨开始。原有存档会先备份。"

func start_chapter() -> void:
	if game.started or not day.quests.prepare_session(true):return
	game.start_game()
	day.manager = day.quests.manager
	day.initialized = true
	day.quests.session_started = true
	previous.seed_previous_days()
	for key in ["a3_books","a3_photo","a3_pipes","a3_water","a3_feed","a4_fridge","a4_cook","a4_share","a5_letter","a5_medicine"]:previous.mark(key)
	for i in range(3):set_flag("book%d"%i)
	set_value("act2_schedule_version",3)
	set_value("cook_state",3)
	set_flag("a5_bell")
	set_flag("photo_dropped")
	for i in range(1,6):set_flag("daily_note_ack_%d"%i)
	begin_day(6)

func begin_day(number: int) -> void:
	if number not in [6,7] or not day.initialized:return
	if computer.shell.visible:computer.shell.hide()
	panel.mode = ""
	panel.shell.hide()
	game.cinematic_active = false
	set_value("current_day",number)
	for key in ["holding","d2_holding","a_holding","a3_holding"]:set_value(key,0)
	set_value("cat_hunger",65)
	set_value("dog_hunger",45)
	day.update_held_visual()
	second.update_held()
	previous.reset_runtime()
	active_number = number
	weight_time = 0
	player.spawn = Vector3(-4.45,.03,4.80)
	player.reset_position()
	day.restore_world()
	restore()
	story("第六天 / 守在楼梯上的朋友\n\n先给阿嚼带一份饭，再和它聊聊。\n茶几上也留下了今天的小纸条。" if number==6 else "第七天 / 断开的电路\n\n整栋楼都断电了，厨房的给予器也不工作。\n去二楼走廊看看配电板。")

func _physics_process(delta: float) -> void:
	if not day.initialized:return
	if not active():
		if active_number!=0:reset_runtime()
		world.stair_guard.collision_layer = 0 if flag("a6_permission") else 1
		return
	if active_number!=today():
		active_number = today()
		restore()
	if not day.active_play():
		meter.hide()
		return
	if today()==7 and flag("a7_power") and not flag("a7_computer_power"):
		weight_time = weight_time+delta if current_weight()>=REQUIRED_KG else 0.0
		if weight_time>=.65:
			mark("a7_computer_power")
			world.set_power(false,true)
			game.ui.toast("感应垫达到供电重量，电脑已启动。现在可以离开座椅，电脑会保持开启。",5)
	hunger_time += delta
	if hunger_time>=30:
		hunger_time = 0
		set_value("cat_hunger",maxi(0,val("cat_hunger",65)-1))
		set_value("dog_hunger",maxi(0,val("dog_hunger",45)-1))
	hud_time += delta
	if hud_time>.12:
		hud_time = 0
		refresh_hud()
	update_meter()
	for item in world.items.values():
		for child in item.get_children():
			if child is Label3D and child.billboard==BaseMaterial3D.BILLBOARD_ENABLED:
				child.visible = World.Props.interactable(item,today()) and player.global_position.distance_to(child.global_position)<3

func restore() -> void:
	if _restoring or not active():return
	_restoring = true
	visible = true
	player.variable_jump = true
	player.jump_locked = false
	world.move_companion(flag("a6_permission"),second)
	second.restore_world()
	day.world.items.note.visible = not (today()==7 and flag("a7_complete"))
	for i in range(world.SNACKS.size()):world.items["snack%d"%i].visible = today()==6 and not (val("snack_mask") & (1<<i))
	world.items.clues.visible = true
	for id in ["circuit","seat","computer","computer_note","weight_book","weight_plant"]:
		world.items[id].visible = today()==7
	if today()==7:
		world.place_weights(flag("weight_book_placed"),flag("weight_plant_placed"),val("a3_holding"),flag("a7_complete"))
		for id in ["seat","computer_note"]:world.items[id].visible = not flag("a7_complete")
	else:
		world.source_book.show()
		if world.source_band:world.source_band.show()
		world.house_plant.global_transform = world.plant_home
		world.house_plant.show()
	world.set_power(today()==7 and not flag("a7_power"),flag("a7_computer_power"))
	world.refresh_circuit(val("circuit_bits"))
	World.Props.apply(world.items,today())
	update_held()
	refresh_hud()
	_restoring = false

func snack_count() -> int:
	var count := 0
	for i in range(world.SNACKS.size()):
		if val("snack_mask") & (1<<i):count += 1
	return count

func on_pad() -> bool:
	var p: Vector3 = world.chair.to_local(player.global_position)
	return player.is_on_floor() and absf(p.x)<.27 and absf(p.z)<.25 and absf(p.y-.515)<.12

func current_weight() -> float:
	return (2.0 if flag("weight_book_placed") else 0.0)+(3.2 if flag("weight_plant_placed") else 0.0)+(CAT_KG if on_pad() else 0.0)

func build_meter() -> void:
	var layer_ := CanvasLayer.new()
	layer_.layer = 12
	add_child(layer_)
	meter = PanelContainer.new()
	meter.custom_minimum_size = Vector2(240,80)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("panel",panel.QuestTheme.panel(10))
	layer_.add_child(meter)
	var col := VBoxContainer.new()
	meter.add_child(col)
	meter_label = panel.label("",16,col)
	meter_bar = ProgressBar.new()
	meter_bar.max_value = REQUIRED_KG
	meter_bar.show_percentage = false
	meter_bar.custom_minimum_size.y = 14
	col.add_child(meter_bar)
	meter.hide()

func update_meter() -> void:
	var pos: Vector3 = world.pad.global_position+Vector3(.30,.40,0)
	meter.visible = today()==7 and not flag("a7_complete") and player.camera.global_position.distance_to(pos)<3.3 and not player.camera.is_position_behind(pos) and day.active_play()
	if not meter.visible:return
	var screen: Vector2 = player.camera.unproject_position(pos)
	var bounds := get_viewport().get_visible_rect().size
	meter.position = Vector2(clampf(screen.x+14,12,bounds.x-260),clampf(screen.y-45,12,bounds.y-110))
	meter_label.text = "座椅重量  %.1f / %.1f kg\n%s"%[current_weight(),REQUIRED_KG,"电脑已启动" if flag("a7_computer_power") else "猫 3.0 · 厚书 2.0 · 花盆 3.2"]
	meter_bar.value = current_weight()

func target_position(id: String) -> Vector3:
	if id=="note":return day.note_target()
	if id=="nest":return day.world.items.nest.global_position+Vector3(0,.12,0)
	if id in ["feeder","dog","dog_bowl","dog_spot","cat_bowl","cat_spot"]:return second.target_position(id)
	var n: Node3D = world.items[id]
	if id=="clues":return n.global_position+Vector3(0,.012,0)
	if id=="weight_plant":return n.global_position+Vector3(0,.13,0)
	return n.global_position+Vector3(0,.045,0)

func nearest_item() -> String:
	if not active() or not day.active_play():return ""
	var choices: Array = world.items.keys()
	choices.append_array(["nest","dog","feeder","dog_bowl","cat_bowl"])
	if day.world.items.note.visible:choices.append("note")
	if val("d2_holding")==4:choices.append("cat_spot")
	if val("d2_holding")==5:choices.append("dog_spot")
	var best := 3.0
	var found := ""
	var eye: Vector3 = player.camera.global_position
	var forward: Vector3 = -player.camera.global_basis.z
	for id in choices:
		if world.items.has(id) and not World.Props.interactable(world.items[id],today()):continue
		if id=="weight_book" and val("a3_holding")==1:continue
		if id=="weight_plant" and val("a3_holding")==2:continue
		if id=="cat_bowl" and val("d2_holding")==4:continue
		if id=="dog_bowl" and val("d2_holding")==5:continue
		var pos := target_position(id)
		var delta := pos-eye
		var alignment := forward.dot(delta.normalized())
		if delta.length()>1.35 or alignment<.67:continue
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,pos,1))
		if not hit.is_empty() and hit.position.distance_to(pos)>.20:continue
		var score := 1.0-alignment+delta.length()*.08
		if score<best:
			best = score
			found = id
	return found

func target_hint() -> String:
	var id := nearest_item()
	if id.is_empty():return ""
	if id=="note":return "E 阅读今天的小纸条"
	if id=="dog":return "E 与阿嚼说话 / 交出狗盘"
	if id=="nest":return "E 回窝休息，进入第七天" if today()==6 and day_complete() else "E 回窝休息" if day_complete() else "E 查看未完成的事情"
	if id in ["feeder","dog_bowl","dog_spot","cat_bowl","cat_spot"]:
		if id=="feeder" and today()==7 and not flag("a7_power"):return "给予器断电了 · 先检查二楼走廊的电路"
		return second.target_hint()
	if id.begins_with("snack"):return "E 吃掉小鱼干"
	if id=="seat":return "E 把叼着的物品放到感应垫上" if val("a3_holding")>0 else "感应垫 %.1f / %.1f kg · E 查看"%[current_weight(),REQUIRED_KG]
	if id=="computer":return "E 进入电脑 · 鼠标左键也可点击屏幕" if flag("a7_computer_power") else "电脑没有启动，先检查供电和座椅感应垫"
	return "E "+str(world.items[id].get_meta("title",id))

func try_interact() -> bool:
	var id := nearest_item()
	if id.is_empty():return false
	interact_item(id)
	return true

func interact_item(id: String) -> void:
	if not active():return
	if id=="note":
		day.show_dialog("note")
		return
	if world.items.has(id) and not World.Props.interactable(world.items[id],today()):return
	if id in ["feeder","dog_bowl","dog_spot","cat_bowl","cat_spot"]:
		if val("a3_holding")!=0:
			game.ui.toast("嘴里已经叼着东西，先按 G 放回书桌。",3)
			return
		var fed: bool = id=="dog_spot" and val("d2_holding")==5 and flag("dog_portion")
		second.interact_item(id)
		if fed and today()==6:mark("a6_feed")
	elif id=="dog":
		if val("d2_holding")==5:
			var fed := flag("dog_portion")
			second.interact_item("dog")
			if fed and today()==6:mark("a6_feed")
		elif today()==6 and not flag("a6_feed"):story("阿嚼：有一点饿了。\n先帮我带一份饭吧。")
		elif today()==6 and not flag("a6_permission"):
			mark("a6_permission")
			world.dog_actor.react_to_food()
			restore()
			story("阿嚼：谢谢你这几天的帮助。\n\n其实我不知道为什么不让你上去，那好像一道程序一样留在我的意识里。\n现在，我又觉得可以放你上去了……虽然我也不知道为什么。\n\n接下来，我和窝都待在厨房的给予器旁边。你有问题，可以来那里找我。")
		else:
			story("阿嚼：我就在这里。\n"+("二楼每个房间都去看看吧，小鱼干不会自己跑掉。" if today()==6 else "今天连给予器也停了。电路修好后，看看电脑桌旁的东西吧。"))
			game.get_node("DogSecret").queue_after_chat(panel)
	elif id=="nest":
		if not day_complete():story(guidance())
		elif today()==7 and flag("a7_complete") and get_parent().has_node("ActFour"):
			get_parent().get_node("ActFour").begin_day(8)
			return
		elif today()==6:
			begin_day(7)
			return
		else:
			mark("a7_complete")
			set_value("a3_holding",0)
			set_flag("weight_book_placed",false)
			set_flag("weight_plant_placed",false)
			restore()
			story("第三幕当前任务完成\n\n电路恢复了，电脑也认出了照片上的 C-031。\n阿嚼留在厨房等你。\n\n再次回窝休息，将进入第八天。也可以继续探索或查看电脑桌面。")
	elif not day.Notes.read(day):game.ui.toast(day.Notes.guidance(today()),4)
	elif id.begins_with("snack"):
		if not flag("a6_permission"):return
		var i := int(id.trim_prefix("snack"))
		if val("snack_mask") & (1<<i):return
		set_value("snack_mask",val("snack_mask") | (1<<i))
		day.manager.report_event(CalicoQuestObjective.Kind.CUSTOM,&"a6_snack",1,"act3:snack%d"%i)
		set_value("cat_hunger",mini(100,val("cat_hunger",65)+8))
		game.ui.toast("吃掉了%s的小鱼干。 %d / 8"%[world.SNACKS[i][1],snack_count()],4)
		if snack_count()==8:mark("a6_snacks")
	elif id=="circuit":
		if flag("a7_power"):story("十六盏灯都亮着，家里的供电已经恢复。")
		else:
			open_panel()
			panel.open_circuit()
	elif id in ["weight_book","weight_plant"]:
		if not flag("a7_power"):
			game.ui.toast("先恢复整栋楼的供电。",3)
			return
		if val("a3_holding")!=0 or val("d2_holding")!=0:
			game.ui.toast("嘴里已经叼着东西。按 G 放回安全位置。",3)
			return
		set_flag(id+"_placed",false)
		set_value("a3_holding",1 if id=="weight_book" else 2)
	elif id=="seat":
		var held := val("a3_holding")
		if held>0:
			set_flag("weight_book_placed" if held==1 else "weight_plant_placed")
			set_value("a3_holding",0)
		else:story("感应垫需要至少 %.1f kg。\n\n猫重 %.1f kg，桌上的厚书重 2.0 kg，花盆重 3.2 kg。\n把物品叼到垫子上，再自己站上去。\n\n电脑启动后会保持开启。"%[REQUIRED_KG,CAT_KG])
	elif id=="computer_note":story("电脑桌上的便签\n\n“密码是你的名字呀。”")
	elif id=="clues":show_clues()
	elif id=="computer":
		if not flag("a7_power"):game.ui.toast("房子还没有恢复供电。",3)
		elif not flag("a7_computer_power"):game.ui.toast("电脑接着座椅感应垫，先凑够重量再站上去。",4)
		else:
			open_panel()
			computer.open()
	restore()

func show_clues() -> void:
	story("客厅线索册 / 收好的照片\n\n白大褂实验人员，身旁蹲着我。右下角印着一个编号。\n照片背面：C-031 / 阶段 II。\n"+("柜门镜头：红点正对修水管的位置。\n" if flag("a3_pipes") else "")+("骨头：D-017 / 阿嚼。→ 短，↘ 长。" if flag("yarn_solved") else ""))
	var image := TextureRect.new()
	image.texture = load("res://act2/memory_photo.svg")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(540,270)
	panel.detail.add_child(image)
	var serial: Label = panel.label("C-031",20,panel.detail)
	serial.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func restore_power() -> void:
	mark("a7_power")
	set_value("circuit_bits",Circuit.FULL)
	restore()
	story("全部灯同时亮起，楼下也传来了给予器重新通电的声音。\n\n接下来，去二楼电脑房看看吧。")

func complete_login() -> void:
	if not flag("a7_power") or not flag("a7_computer_power"):return
	mark("a7_login")
	refresh_hud()

func update_held() -> void:
	if is_instance_valid(held_visual):
		held_visual.get_parent().remove_child(held_visual)
		held_visual.queue_free()
		held_visual = null
	if val("a3_holding")==0:return
	held_visual = (world.items.weight_book if val("a3_holding")==1 else world.house_plant).duplicate()
	player.camera.add_child(held_visual)
	held_visual.remove_from_group("placed_furniture")
	held_visual.show()
	held_visual.position = Vector3(.10,-.22,-.47)
	held_visual.rotation = Vector3.ZERO
	held_visual.scale = Vector3.ONE*(.52 if val("a3_holding")==2 else .70)
	for label in held_visual.find_children("*","Label3D",true,false):label.hide()
	for body in held_visual.find_children("*","CollisionObject3D",true,false):body.collision_layer = 0

func open_panel() -> void:
	game.cinematic_active = true
	player.set_control(false)
	meter.hide()

func story(value: String) -> void:
	open_panel()
	panel.open("story",value)
	panel.title.text = "第三幕 / "+("楼梯之上" if today()==6 else "我的名字")

func close_panel() -> void:
	game.cinematic_active = false
	player.set_control(true)
	refresh_hud()

func day_complete() -> bool:
	return day.Notes.read(day) and ((flag("a6_feed") and flag("a6_permission") and flag("a6_snacks")) if today()==6 else flag("a7_power") and flag("a7_computer_power") and flag("a7_login"))

func guidance() -> String:
	if today()==6:
		if not flag("a6_feed"):return "先给阿嚼喂饭\n叼狗盘到厨房给予器盛粮，再送到楼梯平台。"
		if not flag("a6_permission"):return "和楼梯上的阿嚼聊聊。它似乎愿意告诉你一些事情。"
		if not day.Notes.read(day):return day.Notes.guidance(6)
		if snack_count()<8:
			var remaining := PackedStringArray()
			for i in range(8):
				if not val("snack_mask") & (1<<i):remaining.append(world.SNACKS[i][1])
			return "寻找二楼的小鱼干  %d / 8\n待寻找：%s\n靠近小鱼干，按 E 吃掉。"%[snack_count(),"、".join(remaining)]
		return "二楼的小鱼干都吃完了。\n阿嚼和窝留在厨房。回客厅猫窝休息，进入第七天。"
	if not day.Notes.read(day):return day.Notes.guidance(7)
	if not flag("a7_power"):return "01 恢复供电\n二楼走廊、电脑房门外的配电板：按开关切换自己和上下左右的灯，让十六盏同时点亮。"
	if not flag("a7_computer_power"):return "02 启动电脑\n把现有书桌上的厚书、花盆叼到办公椅感应垫上，再跳上座椅。重量达到 8.0 kg 后，电脑会保持开启。"
	if not flag("a7_login"):return "03 输入密码\n电脑桌上的便签写着：密码是你的名字呀。\n照片收在一楼客厅桌上的线索册里。回到电脑屏幕，按 E 或鼠标左键输入。"
	return "电脑已登录。\n桌面目前只能查看。按 Esc 离开电脑，回猫窝可结束今天。"

func refresh_hud() -> void:
	if not active():return
	day.hud.day_title.text = "第六天 / 楼梯之上" if today()==6 else "第七天 / 我的名字"
	day.hud.guidance.text = guidance()
	day.hud.status.text = "我 %d / 100 · 阿嚼 %d / 100\n%s"%[val("cat_hunger",65),val("dog_hunger",45),"阿嚼在厨房" if flag("a6_permission") else "阿嚼守着楼梯"]
	day.hud.set_paper_progress(0,4,false)
	day.hud.carry.text = second.carry_text() if val("a3_holding")==0 else "叼着：%s\n对感应垫按 E 放下 · G 放回书桌"%("厚书 · 2.0 kg" if val("a3_holding")==1 else "花盆 · 3.2 kg")

func _input(event: InputEvent) -> void:
	if not active() or not day.active_play():return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_G and val("a3_holding")>0:
		set_value("a3_holding",0)
		restore()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and nearest_item()=="computer":
		interact_item("computer")
		get_viewport().set_input_as_handled()

func reset_runtime() -> void:
	active_number = 0
	weight_time = 0
	meter.hide()
	panel.mode = ""
	panel.shell.hide()
	computer.shell.hide()
	world.reset_power()
	world.move_companion(false,second)
	world.source_book.show()
	if world.source_band:world.source_band.show()
	world.house_plant.global_transform = world.plant_home
	world.house_plant.show()
	visible = false
	if is_instance_valid(held_visual):
		held_visual.queue_free()
		held_visual = null
