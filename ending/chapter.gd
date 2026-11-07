extends Node3D
const World = preload("res://ending/world.gd")
const Panels = preload("res://ending/panels.gd")
const Film = preload("res://ending/film.gd")
const BranchCopy=preload("res://story_branches/data.gd")
var game
var day
var player
var fourth
var world
var ui
var film
var initialized := false
var needs_restore := true
var hud_clock := 0.0
var model_inspection: CanvasLayer

func _ready() -> void:
	game=get_parent();day=game.get_node("DayOne");player=game.get_node("Miso");fourth=game.get_node("ActFour")
	world=World.new();world.name="LaboratoryStory";add_child(world);world.build(game)
	ui=Panels.new();add_child(ui);ui.action.connect(on_action)
	# Heavy cinematic props are instantiated when the escape starts, not at startup.
	call_deferred("connect_manager")

func connect_manager() -> void:
	day.quests.manager.changed.connect(func():needs_restore=true)

func active() -> bool:
	return day.initialized and day.value("current_day",1)==11 and day.flag("a11_enter")

func flag(key: String) -> bool:return day.flag(key)
func mark(key: String) -> void:
	if flag(key):return
	day.manager.set_flag(StringName(key),true)
	day.manager.report_event(CalicoQuestObjective.Kind.CUSTOM,StringName(key),1,"ending:"+key)

func enter_laboratory() -> void:
	if not active():return
	initialized=true;needs_restore=true
	# Older saves used a11_complete for crossing the threshold. The ending has its own flag.
	world.restore(true,flag("a11_vent"))
	day.world.items.note.hide()
	show_panel("arrival","地下室 / 留观区","一排排观察笼。空的。\n\n笼门上留下了编号。更里面，那张检查台连着一组弧形玻璃和电缆。\n\n昨天的纸条上写着：监控底下，沿着旧抓痕走。\n我得先找到能出去的路。",[["recall","回想昨天的纸条"]])

func restore() -> void:
	needs_restore=false
	world.restore(active(),flag("a11_vent"))
	if not active():return
	day.world.items.note.hide()
	World.Props.activate(fourth.world.items.escape_note,false)
	if day.value("br_phase",0)>0:return
	if not flag("a11_memory") and ui.mode.is_empty():
		memory()
	refresh_hud()

func _physics_process(delta: float) -> void:
	if not day.initialized:return
	if not active():
		if initialized:reset_runtime()
		world.hide()
		return
	if not initialized:
		initialized=true
		# Saves store quest state rather than player coordinates; resume inside the lab.
		player.spawn=Vector3(1.80,-2.67,-2.77);player.reset_position()
		player.yaw=PI/2;player.rotation.y=player.yaw
		needs_restore=true
	if needs_restore:restore()
	if not day.active_play():return
	hud_clock+=delta
	if hud_clock>.15:hud_clock=0;refresh_hud()

func target_position(id: String) -> Vector3:
	if id=="camera":return world.items.camera.global_position+Vector3(.18,-.08,0)
	return world.items[id].global_position

func nearest_item() -> String:
	if not active() or not day.active_play() or flag("a11_escape"):return ""
	var eye: Vector3=player.camera.global_position
	var forward: Vector3=-player.camera.global_basis.z
	var found:="";var best:=3.0
	for id in world.items:
		if not World.Props.interactable(world.items[id],11):continue
		var pos:=target_position(id);var delta:=pos-eye
		var limit:=2.10 if id=="camera" else 1.55
		if delta.length()>limit or forward.dot(delta.normalized())<.64:continue
		var ray:=PhysicsRayQueryParameters3D.create(eye,pos,1)
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.position.distance_to(pos)>.20:continue
		var score:=1-forward.dot(delta.normalized())+delta.length()*.08
		if score<best:best=score;found=id
	# Horizontal aiming at the cage latch should operate its door. Looking down
	# at the tray selects the evidence, so the optional clue cannot trap the cat.
	if found=="cage":
		var latch_delta: Vector3=world.cage.interaction_position()-eye
		var clue_delta: Vector3=target_position("cage")-eye
		if latch_delta.length()<1.4 and forward.dot(latch_delta.normalized())>forward.dot(clue_delta.normalized())+.015:return ""
	return found

func target_hint() -> String:
	var id:=nearest_item()
	if id.is_empty():return ""
	return "E "+str(world.items[id].get_meta("title"))

func try_interact() -> bool:
	var id:=nearest_item()
	if id.is_empty():return false
	interact_item(id);return true

func interact_item(id: String) -> void:
	if not active() or flag("a11_escape"):return
	if id=="device":game.get_node("StoryBranches").open_terminal()
	elif id=="report":
		show_panel("report",World.Copy.REPORT_TITLE,World.Copy.REPORT,[["close","放回原处"]])
	elif id=="cage":
		if not flag("a11_memory"):memory();return
		mark("a11_cage")
		show_panel("cage","前代实验猫","这里有一道旧抓痕。有猫……来过这里。\n\n笼角卡着几根灰白色的猫毛，托盘上是反复抓挠留下的凹痕。\n一串沾灰的爪印从笼门边延伸出去，朝着西侧墙角。\n\n纸条上说：监控底下。",[["close","沿着爪印寻找"]])
	elif id=="camera":show_panel("camera","监控底下","黑色镜头朝着观察笼。镜头下方靠近地面的位置，有一道松动的金属格栅。",[["close","检查下方的通风口"]])
	elif id=="vent":game.get_node("StoryBranches").open_panel("vent")

func show_panel(kind: String, title: String, text_: String, options: Array) -> void:
	game.cinematic_active=true;player.set_control(false)
	ui.show_panel(kind,title,text_,options)

func memory() -> void:
	show_panel("memory","昨天的纸条",BranchCopy.paper_memory(day.value("br_mouse",0)),[["look","我应该到处看看"]])

func on_action(id: String) -> void:
	if not active():return
	if id=="inspect":open_model_inspection()
	elif id=="recall" and ui.mode=="arrival":memory()
	elif id.begins_with("choice"):game.get_node("StoryBranches").open_terminal()
	elif id=="look":
		if ui.mode!="memory":return
		mark("a11_memory");close_panel()
	elif id=="escape":game.get_node("StoryBranches").open_panel("cat_confirm")
	elif id=="replay":game.get_node("StoryBranches").start_ending_film(true)
	elif id=="menu":
		if ui.mode!="final":return
		game.get_tree().reload_current_scene()
	elif id=="close" and ui.mode in ["story","cage","camera","locked_vent","report"]:close_panel()

func open_model_inspection() -> void:
	ui.close()
	if not is_instance_valid(model_inspection):
		model_inspection=preload("res://story_branches/inspection.gd").new();add_child(model_inspection)
		model_inspection.closed.connect(close_panel)
	model_inspection.open(game,world)

func close_panel() -> void:
	ui.close();game.cinematic_active=false;player.set_control(true);refresh_hud()

func make_film() -> void:
	if film!=null:return
	film=Film.new();add_child(film);film.build(self)

func finish_ending() -> void:
	game.get_node("StoryBranches").show_final()

func guidance() -> String:
	if flag("a11_finished"):return "这一段经历已经结束。"
	if flag("a11_escape"):return "沿着旧抓痕，穿过通风管道。"
	if not flag("a11_memory"):return "03 昨天的逃跑计划\n回想纸条，寻找观察笼与监控下方的痕迹。"
	if not flag("a11_cage"):return "04 前代实验猫\n检查敞开的 01 号观察笼，寻找猫毛、旧抓痕与离开的路径。"
	return "05 决定如何离开\n可以沿监控下方的通风口寻找出口，也可以核对转化装置与原身体。"

func refresh_hud() -> void:
	if not active():return
	day.hud.day_title.text="结局篇 / 地下室逃跑计划"
	day.hud.guidance.text=guidance();day.hud.status.text="循着前代实验猫的痕迹，寻找出口。"
	day.hud.carry.text=""

func reset_runtime() -> void:
	if is_instance_valid(model_inspection) and model_inspection.opened:model_inspection.close()
	initialized=false;needs_restore=true
	ui.close();world.restore(false,false)
	if film!=null:film.reset();film.queue_free();film=null
