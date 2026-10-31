extends Node3D
const World = preload("res://act4/world.gd")
const Panels = preload("res://act4/panels.gd")
const Circuit = preload("res://act4/circuit.gd")
const MouseControl = preload("res://act4/mouse_control.gd")
const GOALS := {8:["a8_food","a8_wash","a8_clock"],9:["a9_plants","a9_mole","a9_jigsaw"],10:["a10_catch","a10_note","a10_asked","a10_eat"],11:["a11_locks","a11_enter"]}
const DESTINATIONS := ["门厅","一楼书房","一楼客厅","二楼走廊","二楼电脑房","二楼主卧","一楼厨房"]
const ROUTES := [
	[Vector3(.05,.02,2.1),Vector3(1.54,.02,2.62),Vector3(1.54,.02,3.18),Vector3(3.4,.02,4.55)],
	[Vector3(1.54,.02,3.18),Vector3(1.54,.02,2.55),Vector3(.0,.02,2.3),Vector3(.0,.02,4.78),Vector3(-1.15,.02,4.78),Vector3(-3.15,.02,3.15)],
	[Vector3(-1.10,.02,4.78),Vector3(.05,.02,4.78),Vector3(.05,.02,2.2),Vector3(4.0,.02,2.05),Vector3(4.0,1.52,-1.02),Vector3(5.2,1.52,-1.02),Vector3(5.2,3.02,2.05),Vector3(.05,3.02,2.2)],
	[Vector3(1.54,3.02,2.6),Vector3(1.54,3.02,3.18),Vector3(3.40,3.02,4.65)],
	[Vector3(1.54,3.02,3.18),Vector3(1.54,3.02,2.5),Vector3(.05,3.02,2.2),Vector3(.05,3.02,-1.53),Vector3(-1.15,3.02,-1.53),Vector3(-2.30,3.02,-1.05)],
	[Vector3(-1.15,3.02,-1.53),Vector3(.05,3.02,-1.53),Vector3(.05,3.02,2.2),Vector3(5.2,3.02,2.05),Vector3(5.2,1.52,-1.02),Vector3(4.0,1.52,-1.02),Vector3(4.0,.02,2.05),Vector3(.05,.02,2.05),Vector3(.05,.02,-2.75),Vector3(1.50,.02,-3.55)]
]
var game
var day
var second
var third
var player
var world
var panel
var active_number := 0
var was_on_bed := false
var wash_time := 0.0
var bathing := false
var mole_clock := 0.0
var pounce_time := 0.0
var chase_path: Array = []
var chase_point := 0
var clock_tick := 0.0
var hud_time := 0.0
var held_mouse: Node3D
var mouse_control
const CLOCK_CLUES := {"clock_clue":"hour","clock_minute_clue":"minute","clock_second_clue":"second"}
const WARM_MIN := 48
const WARM_MAX := 56

func valve_setting() -> int:
	# Preserve the old successful detent on pre-update saves.
	return val("valve_setting",[18,55,85,30][clampi(val("valve"),0,3)])

func pressure_setting() -> int:return val("pressure_setting",82)
func water_temperature() -> float:return valve_setting()+(pressure_setting()-50)*.2
func warm_water() -> bool:return water_temperature()>=WARM_MIN and water_temperature()<=WARM_MAX
func steady_water() -> bool:return pressure_setting()>=40 and pressure_setting()<=65

func clock_clue_count() -> int:
	var count := 0
	for part in CLOCK_CLUES.values():
		if flag("a8_clue_"+part):count+=1
	return count
func _ready() -> void:
	game=get_parent();day=game.get_node("DayOne");second=game.get_node("DayTwo");third=game.get_node("ActThree");player=game.get_node("Miso")
	world=World.new();world.build(self,game)
	panel=Panels.new();panel.chapter=self;add_child(panel);panel.dismissed.connect(close_panel)
	mouse_control=MouseControl.new();mouse_control.chapter=self;add_child(mouse_control)
	call_deferred("add_entry")
func today() -> int:return day.value("current_day",1)
func active() -> bool:return day.initialized and today() in [8,9,10,11]
func flag(key: String) -> bool:return day.flag(key)
func val(key: String, fallback := 0) -> int:return day.value(key,fallback)
func set_value(key: String,value: int) -> void:day.manager.set_value(StringName(key),value)
func mark(key: String) -> void:
	if flag(key):return
	day.manager.set_flag(StringName(key),true)
	day.manager.report_event(CalicoQuestObjective.Kind.CUSTOM,StringName(key),1,"act4:"+key)
func add_entry() -> void:
	var actions := game.ui.welcome.get_node("MenuActions") as Node
	var button: Button=game.ui.button("第四幕 · 从第八天开始",actions,start_chapter,true)
	actions.move_child(button,5)
	button.tooltip_text="从第八天开始；当前存档先备份。"
func start_chapter() -> void:
	if game.started or not day.quests.prepare_session(true):return
	game.start_game();day.manager=day.quests.manager;day.initialized=true;day.quests.session_started=true
	third.previous.seed_previous_days()
	for key in ["a3_books","a3_photo","a3_pipes","a3_water","a3_feed","a4_fridge","a4_cook","a4_share","a5_letter","a5_medicine","a6_feed","a6_permission","a6_snacks","a7_power","a7_computer_power","a7_login","a7_complete"]:third.mark(key)
	for i in range(3):day.manager.set_flag(StringName("book%d"%i),true)
	for i in range(1,8):day.manager.set_flag(StringName("daily_note_ack_%d"%i),true)
	set_value("act2_schedule_version",3);set_value("cook_state",3)
	begin_day(8)
func begin_day(number: int) -> void:
	if number not in [8,9,10,11] or not day.initialized:return
	mouse_control.cancel()
	panel.close()
	third.reset_runtime()
	game.get_node("ActTwo").reset_runtime()
	set_value("current_day",number)
	for key in ["holding","d2_holding","a_holding","a3_holding"]:set_value(key,0)
	day.update_held_visual();second.update_held()
	active_number=number;wash_time=0;bathing=false;pounce_time=0;chase_path.clear()
	player.spawn=Vector3(-4.45,.03,4.8);player.reset_position()
	day.restore_world();restore()
	refresh_hud()
func plant_order() -> Array:return [val("pot0",2),val("pot1",0),val("pot2",1)]
func jigsaw_order() -> Array:
	var result: Array=[]
	for i in range(9):result.append(val("piece%d"%i,[4,0,7,2,8,1,6,3,5][i]))
	return result
func swap_plants(a: int,b: int) -> void:
	var order:=plant_order();var temp: int=order[a];order[a]=order[b];order[b]=temp
	for i in range(3):set_value("pot%d"%i,order[i])
	restore()
func swap_pieces(a: int,b: int) -> void:
	var order:=jigsaw_order();var temp: int=order[a];order[a]=order[b];order[b]=temp
	for i in range(9):set_value("piece%d"%i,order[i])
	world.update_jigsaw(order)
func circuit_routes() -> Array:
	var result: Array=[]
	for i in range(Circuit.count_(val("locks"))):result.append(clampi(val("a11_route_%d_%d"%[val("locks"),i]),0,2))
	return result
func circuit_coils() -> Array:
	var result: Array=[]
	for i in range(Circuit.count_(val("locks"))):result.append(clampi(val("a11_coil_%d_%d"%[val("locks"),i]),0,Circuit.coil_limit(val("locks"))))
	return result
func reset_circuit() -> void:
	for i in range(3):
		set_value("a11_route_%d_%d"%[val("locks"),i],0)
		set_value("a11_coil_%d_%d"%[val("locks"),i],0)
func complete_lock() -> void:
	var level:=val("locks")
	if level>=3:return
	if not Circuit.evaluate(level,circuit_routes(),circuit_coils()).ok:return
	set_value("delay_total",val("delay_total")+circuit_coils().reduce(func(a,b):return a+b,0))
	mark("a11_lock%d"%level)
	set_value("locks",level+1)
	day.manager.report_event(CalicoQuestObjective.Kind.CUSTOM,&"a11_lock",1,"act4:lock%d"%level)
	if level==2:
		mark("a11_locks")
		if val("delay_total")<=Circuit.HIGH_SCORE_COILS:mark("a11_high_score")
	restore()
func restore() -> void:
	if not active():return
	reconcile_mouse_progress()
	visible=true;player.variable_jump=true
	third.world.move_companion(true,second);second.restore_world()
	third.world.set_power(false,true)
	for id in world.items:
		var item_: Node3D=world.items[id]
		if item_.has_meta("quest_days"):item_.visible=today() in item_.get_meta("quest_days")
	world.items.food.visible=today()==8 and not flag("a8_food")
	for id in ["bed","tracks","valve","wash","limescale","clock_clue","clock_minute_clue","clock_second_clue"]:world.items[id].visible=today()==8 and not flag("a8_complete")
	world.valve_wheel.rotation.z = -deg_to_rad(lerpf(-140,140,valve_setting()/100.0))
	world.pressure_wheel.rotation.z=-deg_to_rad(lerpf(-120,120,pressure_setting()/100.0))
	world.items.water.flow=pressure_setting()/100.0
	if today()!=8:world.items.water.stop()
	world.arrange(plant_order(),today()==9 and not flag("a9_complete"))
	for i in range(3):world.items["plant%d"%i].visible=today()==9 and not flag("a9_complete")
	world.update_jigsaw(jigsaw_order())
	for id in ["jigsaw","burrows","painting"]:world.items[id].visible=today()==9 and not flag("a9_complete")
	world.items.mole.visible=today()==9 and flag("a9_plants") and not flag("a9_mole") and pounce_time<=0
	world.items.mole.global_position=world.holes[val("mole_hole")%9]
	world.items.mouse.visible=today()==10 and not flag("a10_catch")
	if chase_path.is_empty():world.items.mouse.position=Vector3(.05,.02,2.1) if val("mouse_stage")==0 else ROUTES[clampi(val("mouse_stage")-1,0,5)][-1]
	world.items.escape_note.visible=(today()==10 and flag("a10_catch")) or (today()==11 and not flag("a11_enter"))
	update_held_mouse()
	world.items.basement.set_meta("interaction_days",[1,2,3,4,5,6,7,8,9,10,11])
	world.door_state(val("locks")>=3,val("locks"),true)
	World.Props.apply(world.items,today())
	day.world.items.note.visible=not flag("a11_enter")
	refresh_hud()
func on_bed() -> bool:
	var p: Vector3=world.bed.to_local(player.global_position)
	return player.is_on_floor() and absf(p.x)<.78 and absf(p.z)<.97 and absf(p.y-.59)<.11
func _physics_process(delta: float) -> void:
	world.mouse_actor.set_active(active() and today()==10 and not flag("a10_catch") and day.active_play(),not chase_path.is_empty())
	world.mole_actor.set_active(active() and today()==9 and day.active_play())
	if not day.initialized:return
	if not active():
		if active_number!=0:reset_runtime()
		return
	if active_number!=today():active_number=today();restore()
	# Resume a refused command interrupted by leaving the game.
	if today()==10 and flag("a10_refused") and not flag("a10_eat") and not mouse_control.running and day.active_play():
		mouse_control.begin()
		return
	if today()==11 and flag("a11_enter"):return
	if not day.active_play():return
	if today()==8 and not flag("a8_food"):
		if Input.is_action_just_pressed("jump") and was_on_bed:
			var count:=mini(3,val("bed_jumps")+1)
			set_value("bed_jumps",count)
			player.velocity.y=[4.75,5.7,7.4][count-1]
			if count==3:
				var input_axis := Input.get_vector("move_left","move_right","move_forward","move_back")
				var direction: Vector3=(player.basis*Vector3(input_axis.x,0,input_axis.y)).normalized()
				player.velocity.x=direction.x*4.0
				player.velocity.z=direction.z*4.0
			game.ui.toast("床垫蓄力 %d / 3%s"%[count," · 这次可以跃向衣柜顶！" if count==3 else " · 落回床垫后再跳。"],3)
		elif player.is_on_floor() and not on_bed() and player.position.y<world.bed.global_position.y+.35 and val("bed_jumps")>0:set_value("bed_jumps",0)
	was_on_bed=on_bed()
	if bathing:
		if warm_water() and steady_water() and player.global_position.distance_to(world.items.wash.global_position)<.62:wash_time+=delta
		else:wash_time=0;bathing=false;world.items.water.stop()
		if wash_time>=4:
			bathing=false;mark("a8_wash");world.items.water.stop();story("水温和水流终于都稳定了。\n调小出水、试温，再缓缓加到舒适的流量。水垢下的数字仍然看不清，但我记住了两个旋钮的位置。\n\n接下来，前往二楼书房，寻找时间纸条并调整墙上的时钟。")
	if flag("a8_clock"):
		clock_tick+=delta
		if clock_tick>=1:
			set_value("clock_back_seconds",val("clock_back_seconds")+int(clock_tick))
			clock_tick=fmod(clock_tick,1)
		world.clock_pose(3*3600+42*60-val("clock_back_seconds"))
	else:world.clock_pose(val("clock_h",8)*3600+val("clock_m",11)*60+val("clock_s",25))
	if today()==9 and flag("a9_plants") and not flag("a9_mole"):
		mole_clock+=delta
		if pounce_time>0:
			pounce_time-=delta
			if pounce_time<=0:finish_pounce()
		elif mole_clock>3:
			mole_clock=0;set_value("mole_hole",(val("mole_hole")+5)%9);restore()
	if today()==10 and not chase_path.is_empty():advance_mouse(delta)
	if today()==11 and val("locks")==3 and world.items.basement.beyond_door(player.global_position) and not flag("a11_enter"):
		mark("a11_enter");restore();game.get_node("Ending").enter_laboratory()
		return
	hud_time+=delta
	if hud_time>.15:
		hud_time=0;refresh_hud()
		for item_ in world.items.values():
			for child in item_.get_children():
				if child is Label3D:child.visible=item_.is_visible_in_tree() and player.global_position.distance_to(item_.global_position)<2.6
func solve_clock() -> void:
	if flag("a8_clock"):return
	if not flag("a8_wash") or clock_clue_count()<3:return
	if val("clock_h")!=3 or val("clock_m")!=42 or val("clock_s")!=0:return
	mark("a8_clock");set_value("clock_back_seconds",0);restore()
	story("指针终于开始运行。\n\n03:42:00。还剩下三天。\n\n可秒针……是在倒着走。")
func pounce() -> void:
	if pounce_time>0 or flag("a9_mole"):return
	set_value("mole_attempts",val("mole_attempts")+1)
	var direction: Vector3=world.items.mole.global_position-player.global_position
	direction.y=0
	player.velocity=direction.normalized()*2.6+Vector3.UP*3.3
	pounce_time=.42;mole_clock=0
	world.items.mole.hide()
func finish_pounce() -> void:
	var attempt:=val("mole_attempts")
	var separation: Vector3=world.items.mole.global_position-player.global_position
	separation.y=0
	if attempt<=3 or separation.length()>.38:game.ui.toast("它又缩回洞里了。身体还没记起怎么扑，靠近洞口再试试。",4)
	else:
		set_value("mole_catches",mini(2,val("mole_catches")+1))
		if val("mole_catches")==1:game.ui.toast("抓到了！它从爪缝里挣脱了。再抓住一次。",4)
		else:mark("a9_mole");story("第二次，爪子终于稳稳扣住了它。\n扑出去的那一刻，身体比思考更快。\n\n原来，我还记得如何捕猎。")
	set_value("mole_hole",(val("mole_hole")+5)%9);restore()
func chase_mouse() -> void:
	if flag("a10_catch"):
		open_mouse_story()
		return
	if not chase_path.is_empty():game.ui.toast("它还在跑，跟上去。",2);return
	var stage:=val("mouse_stage")
	if stage>=6:
		game.ui.toast_time=0
		mark("a10_catch");restore();open_mouse_story();return
	chase_path=ROUTES[stage].duplicate();chase_point=0
	set_value("mouse_stage",stage+1)
	for d in get_tree().get_nodes_in_group("villa_doors"):
		if not d.locked:d.set_open(true)
	game.ui.toast("差一点就抓住了！老鼠跑向%s。"%DESTINATIONS[stage+1],4)
func advance_mouse(delta: float) -> void:
	var mouse: Node3D=world.items.mouse
	var remaining:=maxf(delta,0)
	while remaining>0 and not chase_path.is_empty():
		var destination: Vector3=chase_path[chase_point]
		var source: Vector3=chase_path[maxi(0,chase_point-1)]
		var stair_leg:=absf(source.x-destination.x)<.01 and absf(source.y-destination.y)>1.0 and (absf(source.x-4.0)<.01 or absf(source.x-5.2)<.01)
		var motion:=destination-mouse.global_position
		if stair_leg:motion.y=0
		var distance_:=motion.length()
		var speed:=1.05 if stair_leg else 2.5
		var travel:=minf(remaining*speed,distance_)
		if distance_>.0001:
			mouse.global_position+=motion/distance_*travel
			if Vector2(motion.x,motion.z).length()>.001:mouse.rotation.y=atan2(-motion.x,-motion.z)
		if stair_leg:mouse.global_position.y=mouse_stair_height(mouse.global_position,destination.y>source.y)
		remaining=maxf(0,remaining-travel/speed)
		if distance_-travel>.0001:break
		chase_point+=1
		if chase_point>=chase_path.size():chase_path.clear();restore()

func mouse_stair_height(position_: Vector3, ascending: bool) -> float:
	# Nine 1/6 m risers on each 2 m flight, matching the existing tread colliders.
	# Lift before the nose reaches a riser; descend only after the long tail clears it.
	var lower:=absf(position_.x-4.0)<.01
	var along:=1.5-position_.z if lower else position_.z+.5
	var support:=along+(.17 if ascending else .31)
	var height:=.02 if lower else 1.52
	for i in range(9):
		var edge:=i*2.0/9.0
		var t:=clampf((support-edge+.14)/.14,0,1)
		height+=smoothstep(0,1,t)/6.0
		if ascending:height+=sin(t*PI)*.018
	return height
func reconcile_mouse_progress() -> void:
	# Older saves have already eaten; preserve that action without replaying control.
	if flag("a10_eat") and not flag("a10_asked"):mark("a10_asked")
	# Reconcile newly added/reordered quests only when their conditions are active.
	for key in ["a10_catch","a10_note","a10_asked","a10_eat"]:
		if flag(key) and day.manager.get_status(StringName(key))==CalicoQuestManager.State.ACTIVE:
			day.manager.report_event(CalicoQuestObjective.Kind.CUSTOM,StringName(key),1,"act4:mouse_restore:"+key)

func update_held_mouse() -> void:
	var holding := today()==10 and flag("a10_catch") and not flag("a10_eat")
	player.set_meta("holding_mouse",holding)
	if holding and not is_instance_valid(held_mouse):
		held_mouse=Node3D.new();held_mouse.name="CaughtMouse"
		player.camera.add_child(held_mouse)
		var animal: Node3D=load("res://furniture_pack/quest_props/house_mouse.glb").instantiate()
		animal.name="MouseVisual";held_mouse.add_child(animal)
		for mesh in animal.find_children("*","MeshInstance3D",true,false):
			mesh.layers=8
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if is_instance_valid(held_mouse):
		held_mouse.visible=holding
		if not mouse_control.running:
			held_mouse.position=Vector3(.07,-.14,-.30)
			held_mouse.rotation=Vector3(.15,-PI*.5,.08)
			held_mouse.scale=Vector3.ONE*.65

func open_mouse_story() -> void:
	if today()!=10 or not flag("a10_catch") or mouse_control.running:return
	if flag("a10_eat"):
		story("我：我明明想走。可刚才……我停不下来。\n\n阿嚼：我看见了。\n阿嚼：你刚才已经转身了。")
	elif not flag("a10_note"):open_panel("mouse_warning")
	elif not flag("a10_asked"):open_panel("mouse_question")
	else:open_panel("mouse_refusal")

func open_mouse_note() -> void:
	if today()!=10 or not flag("a10_catch") or mouse_control.running:return
	open_panel("mouse_note")

func confirm_mouse_note() -> void:
	if panel.mode!="mouse_note" or today()!=10 or not flag("a10_catch") or mouse_control.running:return
	mark("a10_note");restore()
	if flag("a10_eat"):story("逃跑计划已经记在了线索册里。\n身体终于停下来了。先回猫窝。")
	else:open_mouse_story()

func question_mouse() -> void:
	if today()!=10 or not flag("a10_catch") or mouse_control.running:return
	if not flag("a10_note"):open_mouse_story();return
	panel.mouse_page=0
	open_panel("mouse_dialogue")

func confirm_mouse_question() -> void:
	if panel.mode!="mouse_dialogue" or panel.mouse_page!=panel.MOUSE_DIALOGUE.size()-1:return
	if today()!=10 or not flag("a10_note") or mouse_control.running:return
	mark("a10_asked");restore();open_mouse_story()

func refuse_mouse() -> void:
	if today()!=10 or panel.mode!="mouse_refusal" or not flag("a10_note") or not flag("a10_asked") or flag("a10_eat") or mouse_control.running:return
	panel.close()
	mark("a10_refused")
	mouse_control.begin()

func eat_mouse() -> void:
	# Only the completed involuntary action can commit eating, never a dialogue button.
	if today()!=10 or not mouse_control.running or mouse_control.elapsed<mouse_control.DURATION:return
	if not flag("a10_catch") or not flag("a10_note") or not flag("a10_asked") or not flag("a10_refused") or flag("a10_eat"):return
	mark("a10_eat")
	mouse_control.finish()
	restore()
	open_mouse_story()

func finish_day_ten() -> void:
	if today()!=10 or panel.mode!="mouse_rest" or not day_complete():return
	mark("a10_complete")
	begin_day(11)
func target_position(id: String) -> Vector3:
	if id=="note":return day.note_target()
	if id=="nest":return day.world.items.nest.global_position+Vector3(0,.12,0)
	if id=="clues":return third.world.items.clues.global_position+Vector3(0,.012,0)
	if id=="computer":return third.world.items.computer.global_position
	if id in ["dog","feeder","dog_bowl","dog_spot","cat_bowl","cat_spot"]:return second.target_position(id)
	if id=="basement":return world.items.basement.interaction_position()
	return world.items[id].global_position+Vector3(0,.035,0)
func nearest_item() -> String:
	if not active() or not day.active_play():return ""
	var choices: Array=world.items.keys()+["note","nest","clues","dog","computer"]
	var best:=3.0;var found:=""
	var eye: Vector3=player.camera.global_position
	var forward: Vector3=-player.camera.global_basis.z
	for id in choices:
		if id in ["water","burrows"]:continue
		if world.items.has(id) and not World.Props.interactable(world.items[id],today()):continue
		if id=="note" and not day.world.items.note.visible:continue
		var pos:=target_position(id);var delta:=pos-eye
		var limit:=1.45 if id not in ["clock","limescale","painting","tracks"] else 2.25
		if delta.length()>limit or forward.dot(delta.normalized())<.68:continue
		var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,pos,1))
		if not hit.is_empty() and hit.position.distance_to(pos)>(.16 if id=="mouse" else .28):continue
		var score:=1-forward.dot(delta.normalized())+delta.length()*.08
		if score<best:best=score;found=id
	return found
func target_hint() -> String:
	var id:=nearest_item()
	if id.is_empty():return ""
	if id=="escape_note" and today()==10:return "E "+("重看老鼠带来的纸条" if flag("a10_note") else "查看老鼠带来的纸条")
	if id=="basement":
		if val("locks")<3:return "E 检查实验室密码门 · 三组电流锁"
		if world.items.basement.blocked:return "让开一点，门会继续移动 · E 改变方向"
		return "E "+("关闭" if world.items.basement.is_open else "打开")+"实验室密码门"
	return {"note":"E 阅读今天的小纸条","nest":"E 回窝休息" if day_complete() else "E 查看未完成的事情","mouse":"E 伸爪抓取老鼠","mole":"E 扑向地鼠","clues":"E 翻阅客厅线索册","computer":"E 查看电脑桌面","dog":"E 与阿嚼说话"}.get(id,"E "+str(world.items[id].get_meta("title",id)) if world.items.has(id) else "E 查看")
func try_interact() -> bool:
	var id:=nearest_item()
	if id.is_empty():return false
	interact_item(id);return true
func interact_item(id: String) -> void:
	if not active():return
	if mouse_control.running:return
	if id=="note":day.show_dialog("note");return
	if id=="nest":
		if not day_complete():story(guidance());return
		if today()==10:open_panel("mouse_rest");return
		mark("a%d_complete"%today())
		if today()<11:begin_day(today()+1)
		else:story("第四幕当前任务已完成。地下室门已打开，可以继续探索。")
		return
	if not day.Notes.read(day):game.ui.toast(day.Notes.guidance(today()),3);return
	if id=="clues":
		story("客厅线索册\n\nC-031 / 阶段 II。\n"+("地下室逃跑计划。\n监控底下。沿着旧抓痕走。" if flag("a10_note") else "照片上，主人穿着白大褂。"))
		panel.picture("res://act2/memory_photo.png",panel.detail);return
	if id=="computer":open_panel("story");panel.close();game.cinematic_active=true;player.set_control(false);third.computer.open();return
	if id=="dog":
		if today()==10 and flag("a10_catch") and not flag("a10_eat"):
			if flag("a10_note") and not flag("a10_asked"):question_mouse()
			else:open_mouse_story()
		elif today()==10 and flag("a10_eat"):story("阿嚼：先休息吧。我在这里。")
		else:
			story("阿嚼："+("它的味道……我好像认识它。" if today()>=10 else "我在这里。你今天的任务，还是写在那张纸条上吗？"))
			game.get_node("DogSecret").queue_after_chat(panel)
		return
	if not world.items.has(id) or not World.Props.interactable(world.items[id],today()):return
	if id=="food":
		if val("bed_jumps")<3:game.ui.toast("衣柜太高了。先在原来的床垫上连续跳三次。",3);return
		mark("a8_food");set_value("cat_hunger",100);restore();story("封口完好的新猫粮。\n\n柜顶的灰尘积了很久，但灰里有猫的脚印。猫粮却是新放上去的。")
	elif id=="tracks":story("浮灰被一串猫爪印踩开了。\n边缘的灰很旧，封口猫粮袋却没有落灰。谁在这之前上来过？")
	elif id=="bed":story("这张床的床垫有弹性。\n落在床上后连续跳三次，第三次朝衣柜顶跳。离开床垫落回地面，蓄力会消失。")
	elif id in ["valve","wash","limescale"]:
		if not flag("a8_food"):game.ui.toast("先拿到并吃掉柜顶的猫粮。",3);return
		if id=="valve":open_panel("valve")
		elif id=="limescale":story("水温数字被水垢遮住了。旁边还有一个出水旋钮。\n底座上，两段常用位置都磨得发亮。\n\n旧贴纸写着：先用小水试温，再慢慢加水。水开大时，热水也会来得更快；别一下拧到底。")
		elif flag("a8_wash"):story("毛已经洗干净了。关好水，去二楼书房看看墙上的时钟吧。")
		elif not steady_water():
			world.items.water.flow=pressure_setting()/100.0
			world.items.water.start(1.6)
			game.ui.toast("水流断断续续，先把出水旋钮开大一些，再检查水温。" if pressure_setting()<40 else "水冲得太急了！先收小出水旋钮，再重新试温。",4)
		elif not warm_water():
			world.items.water.start(1.6)
			var away: Vector3=Vector3(-1,0,-.3).normalized()
			player.velocity=away*1.7+Vector3.UP*2.2
			game.ui.toast("好冷……把温度旋钮往热水方向转一点，再试试。" if water_temperature()<WARM_MIN else "太烫了！把温度旋钮往冷水方向退一点，再试试。",4)
		else:bathing=true;wash_time=0;world.items.water.start();game.ui.toast("温温的，正合适。留在淋浴底盘里，洗澡中……",4)
	elif CLOCK_CLUES.has(id):
		var part: String = CLOCK_CLUES[id]
		mark("a8_clue_"+part)
		story({"hour":"时针纸条\n\n时针：03。\n这张只写了小时，另外两张在哪里？","minute":"分针纸条\n\n分针：42。\n把这个数字记在分针的位置。","second":"秒针纸条\n\n秒针：00。\n它要对准最上面的刻线。"}[part]+"\n\n三张纸条都在二楼书房。已经找到 %d / 3。"%clock_clue_count())
	elif id=="clock":
		if flag("a8_clock"):story("时钟还在走。\n可是它在倒着走。还剩下三天。")
		elif not flag("a8_wash"):game.ui.toast("先去淋浴间洗澡，再调整时钟。",3)
		elif clock_clue_count()<3:game.ui.toast("还缺时间纸条：已找到 %d / 3。二楼书房的书桌、书柜脚边和阅读小桌各有一张。"%clock_clue_count(),4)
		else:open_panel("clock")
	elif id=="painting" or id.begins_with("plant"):
		if flag("a9_plants"):story("三盆植物已经按照墙画排列好了。")
		else:open_panel("plants")
	elif id=="mole":
		if not flag("a9_plants"):game.ui.toast("先整理露台上的花盆。",3)
		else:pounce()
	elif id=="jigsaw":
		if not flag("a9_mole"):game.ui.toast("先去花园的九个洞口练习捕猎。",3)
		elif flag("a9_jigsaw"):story("三只猫，被关在实验室的笼子里。");panel.picture("res://act4/textures/laboratory_cats.png",panel.detail)
		else:open_panel("jigsaw")
	elif id=="mouse":chase_mouse()
	elif id=="escape_note":
		if today()==10:open_mouse_note()
		else:story("潮湿的小纸条\n\n地下室逃跑计划。\n\n监控底下。\n沿着旧抓痕走。")
	elif id=="basement":
		if val("locks")<3:open_panel("circuit")
		else:world.items.basement.toggle()
	refresh_hud()
func open_panel(kind: String,value := "") -> void:
	game.cinematic_active=true;player.set_control(false);panel.open4(kind,value)
func story(value: String) -> void:open_panel("story",value)
func close_panel() -> void:
	if mouse_control.running:return
	game.cinematic_active=false;player.set_control(true)
	refresh_hud()
func day_complete() -> bool:
	if not day.Notes.read(day):return false
	for key in GOALS[today()]:
		if not flag(key):return false
	return true
func guidance() -> String:
	if today()==11 and flag("a11_enter"):return game.get_node("Ending").guidance()
	if not day.Notes.read(day):return day.Notes.guidance(today())
	if today()==8:
		if not flag("a8_food"):return "01 柜顶的猫粮\n留意主卧的床垫，想办法够到柜顶。蓄力 %d / 3。"%val("bed_jumps")
		if not flag("a8_wash"):return "02 洗个澡\n观察淋浴间的旧贴纸，调整温度和出水旋钮，再到底盘试水。"
		if not flag("a8_clock"):return "03 沉默的时钟\n前往二楼书房，在书桌、书柜脚边和阅读小桌找齐纸条，再调整墙上时钟。已找到 %d / 3。"%clock_clue_count()
	elif today()==9:
		if not flag("a9_plants"):return "01 露台花盆\n按照旁边墙画中三种植物的顺序交换现有盆栽。"
		if not flag("a9_mole"):return "02 花园捕猎\n北花园九个地鼠洞。看准露头的地鼠，靠近按 E 猫扑。已抓住 %d / 2。"%val("mole_catches")
		if not flag("a9_jigsaw"):return "03 书桌拼图\n跳上二楼书房原书桌，交换纸板拼成完整照片。"
	elif today()==10:
		if not flag("a10_catch"):return "01 追逐老鼠\n老鼠在%s。靠近按 E 抓取，跟上它跑过的房间。"%DESTINATIONS[clampi(val("mouse_stage"),0,6)]
		if not flag("a10_note"):return "02 查看纸条\n老鼠带来了一张纸条。先看看上面写着什么。纸条落在厨房地面，也可以找阿嚼继续这段对话。"
		if not flag("a10_asked"):return "03 向阿嚼求证\n阿嚼似乎认出了它的味道。问问阿嚼。"
		if not flag("a10_eat"):return "04 尝试拒绝命令\n我不想吃掉它。我想离开这里。找阿嚼继续，或者重看纸条后做出决定。"
		return "身体终于停下来了。\n先回客厅猫窝休息。"
	else:
		if val("locks")<3:return "01 实验室密码门\n沿一楼楼梯下到地下平台，左转检查门上的三组电流锁。%d / 3\n依次解开同步灯、分时窄桥、变速时钟窗口。规则写在每关面板上。"%val("locks")
		if not flag("a11_enter"):return "02 进入实验室\n门锁已解开，穿过平台旁的密码门进入实验室。"
	return "今天的任务都完成了。\n回客厅猫窝按 E 休息。" if today()<11 else "进入实验室，检查里面的转化装置。"
func refresh_hud() -> void:
	if not active():return
	day.hud.day_title.text="第 %d 天 / %s"%[today(),{8:"倒走的时间",9:"身体的记忆",10:"主人的命令",11:"来地下室"}[today()]]
	day.hud.guidance.text=guidance()
	day.hud.status.text="饱食度：%d/100"%val("cat_hunger",65)
	day.hud.carry.text="抓着老鼠" if today()==10 and flag("a10_catch") and not flag("a10_eat") else ""
	day.hud.set_paper_progress(0,4,false)
func reset_runtime() -> void:
	mouse_control.cancel()
	player.set_meta("holding_mouse",false)
	if is_instance_valid(held_mouse):held_mouse.hide()
	active_number=0;bathing=false;wash_time=0;chase_path.clear();pounce_time=0
	world.items.water.stop()
	world.mouse_actor.set_active(false)
	world.mole_actor.set_active(false)
	world.arrange([0,1,2],false)
	world.door_state(val("locks")>=3,val("locks"),true)
	visible=false
	panel.mode="";panel.shell.hide()
	if is_instance_valid(panel.display):panel.display.running=false
