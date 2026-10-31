extends Node3D
const World = preload("res://ending/world.gd")
const Panels = preload("res://ending/panels.gd")
const Film = preload("res://ending/film.gd")
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
	if flag("a11_escape"):
		if film==null:make_film();film.play(flag("a11_finished"))
		return
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
	if id=="device":
		if not flag("a11_choice"):
			show_panel("device","转化装置","透明的器皿安在那张检查台上。\n\n进去，就能变成人吗？装置外面还有一颗红色按钮。",[["choice1","1  进去，变成人"],["choice2","2  拒绝，按下装置外面的红色按钮"],["choice3","3  给我一点时间想想"]])
		elif not flag("a11_memory"):memory()
		else:show_panel("story","我应该到处看看","昨天老鼠叼着的纸条……写着地下室逃跑计划。\n\n先看看笼子和监控底下。",[["close","继续寻找"]])
	elif id=="cage":
		if not flag("a11_memory"):memory();return
		mark("a11_cage")
		show_panel("cage","前代实验猫","这里有一道旧抓痕。有猫……来过这里。\n\n笼角卡着几根灰白色的猫毛，托盘上是反复抓挠留下的凹痕。\n一串沾灰的爪印从笼门边延伸出去，朝着西侧墙角。\n\n纸条上说：监控底下。",[["close","沿着爪印寻找"]])
	elif id=="camera":show_panel("camera","监控底下","黑色镜头朝着观察笼。镜头下方靠近地面的位置，有一道松动的金属格栅。",[["close","检查下方的通风口"]])
	elif id=="vent":
		if not flag("a11_memory"):
			memory();return
		if not flag("a11_cage"):
			show_panel("locked_vent","监控底下的通风口","边框上有猫毛和旧抓痕。\n这些痕迹是从哪里来的？先检查那只敞开的观察笼。",[["close","回头检查笼舍"]]);return
		mark("a11_vent");world.restore(true,true)
		show_panel("escape","通往外面的路","格栅松开了。边框上的猫毛，与观察笼里的颜色一样。\n旧抓痕一直延伸进黑暗的通风管道。\n\n前面的猫从这里离开了。现在，我也只能沿着它的路走。",[["escape","逃跑"]])

func show_panel(kind: String, title: String, text_: String, options: Array) -> void:
	game.cinematic_active=true;player.set_control(false)
	ui.show_panel(kind,title,text_,options)

func memory() -> void:
	show_panel("memory","昨天的纸条","昨天，我明明想离开，身体却还是执行了命令。\n但那张纸条上的内容，我记住了。\n\n「地下室逃跑计划」\n「监控底下。沿着旧抓痕走。」\n\n这里也许有答案，也许有能出去的路。",[["look","我应该到处看看"]])

func on_action(id: String) -> void:
	if not active():return
	if id=="recall" and ui.mode=="arrival":memory()
	elif id.begins_with("choice"):
		if ui.mode!="device" or flag("a11_choice"):return
		day.manager.set_value(&"ending_choice",int(id.right(1)))
		mark("a11_choice")
		if not flag("a11_memory"):memory()
		else:show_panel("story","我应该继续寻找","装置仍然在这里。\n但我还记得昨天的纸条：监控底下，沿着旧抓痕走。",[["close","继续寻找出口"]])
	elif id=="look":
		if ui.mode!="memory":return
		mark("a11_memory");close_panel()
	elif id=="escape":
		if ui.mode!="escape" or not flag("a11_memory") or not flag("a11_cage") or not flag("a11_vent"):return
		mark("a11_escape");make_film();film.play()
	elif id=="replay":
		if ui.mode=="final":film.play()
	elif id=="menu":
		if ui.mode!="final":return
		game.get_tree().reload_current_scene()
	elif id=="close" and ui.mode in ["story","cage","camera","locked_vent"]:close_panel()

func close_panel() -> void:
	ui.close();game.cinematic_active=false;player.set_control(true);refresh_hud()

func make_film() -> void:
	if film!=null:return
	film=Film.new();add_child(film);film.build(self)

func finish_ending() -> void:
	mark("a11_finished");mark("a11_complete")
	show_panel("final","实验失败。","回到了原来的家。\n另一只猫向我跑来，大狗还守在熟悉的位置。\n\n全剧终",[["replay","重看逃脱与归家"],["menu","返回主菜单"]])

func guidance() -> String:
	if flag("a11_finished"):return "实验失败。全剧终。"
	if flag("a11_escape"):return "沿着旧抓痕，穿过通风管道。"
	if not flag("a11_memory"):return "03 昨天的逃跑计划\n回想纸条，寻找观察笼与监控下方的痕迹。"
	if not flag("a11_cage"):return "04 前代实验猫\n检查敞开的 01 号观察笼，寻找猫毛、旧抓痕与离开的路径。"
	return "05 监控底下\n沿着地上的旧爪印，检查西侧监控下方的通风格栅。"

func refresh_hud() -> void:
	if not active():return
	day.hud.day_title.text="结局篇 / 地下室逃跑计划"
	day.hud.guidance.text=guidance();day.hud.status.text="循着前代实验猫的痕迹，寻找出口。"
	day.hud.carry.text=""

func reset_runtime() -> void:
	initialized=false;needs_restore=true
	ui.close();world.hide()
	if film!=null:film.reset();film.queue_free();film=null
