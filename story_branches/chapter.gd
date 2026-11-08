extends Node
const StateService=preload("res://story_branches/state.gd")
const Copy=preload("res://story_branches/data.gd")
var game: Node
var day: Node
var state
var world: Node3D
var panels: CanvasLayer
var film: Node
var feedback: Node
var care_memory: Node
var recording: AudioStreamPlayer
var needs_restore := true
var previous_day := 0
var alert: Node
var memory_replay := false

func _ready() -> void:
	game=get_parent();day=game.get_node("DayOne")
	state=StateService.new()
	feedback=preload("res://story_branches/audio.gd").new();add_child(feedback)
	recording=AudioStreamPlayer.new();recording.volume_db=-14;recording.stream=load("res://story_branches/audio/transfer_log.wav");add_child(recording)
	world=preload("res://story_branches/world.gd").new();world.name="BranchWorld";add_child(world);world.build(self)
	panels=load("res://story_branches/panels.gd").new();panels.chapter=self;add_child(panels)
	alert=preload("res://story_branches/day_eleven_alert.gd").new();alert.name="DayElevenAlert";add_child(alert);alert.setup(self)
	call_deferred("ensure_bound")

func ensure_bound() -> bool:
	var system=game.get_node("QuestSystem")
	if system.manager==null:return false
	if state.manager!=system.manager:
		state.configure(system)
		system.manager.changed.connect(func():needs_restore=true)
	return true

func prepare_session(new_game: bool) -> bool:
	if not ensure_bound():return false
	state.replay=false;state.busy=false
	if new_game:
		cancel_runtime();previous_day=0;needs_restore=true
		return true
	return state.migrate_legacy(false)

func facts() -> Dictionary:return state.snapshot() if state.manager!=null else {}
func value(key: String) -> int:return int(facts().get(key,0))
func flag(key: String) -> bool:return bool(facts().get(key,false))

func _physics_process(_delta: float) -> void:
	if not day.initialized or not game.started or not ensure_bound() or not game.get_node("QuestSystem").session_started:return
	if previous_day!=day.value("current_day",1):previous_day=day.value("current_day",1);needs_restore=true
	if is_instance_valid(film) and film.running:return
	if is_instance_valid(care_memory) and care_memory.running:return
	if game.get_node("ActFour").mouse_control.running:return
	if needs_restore:restore_world()
	if not panels.opened and day.active_play():
		if value("br_phase")==2:show_final()
		elif value("br_phase")==1:start_ending_film(false)
		elif value("br_mouse_intent")!=0:start_mouse_film(true)
		elif not flag("br_legacy_flow") and value("br_memory_level")>0 and not state.busy:
			for level in range(1,value("br_memory_level")+1):
				if not value("br_memory_seen_mask")&(1<<(level-1)):play_memory(level,false);break

func restore_world() -> void:
	needs_restore=false
	state.reconcile_memory()
	state.reconcile_progress()
	world.restore(facts())
	var fourth=game.get_node("ActFour")
	if fourth.today()==10:fourth.update_held_mouse();fourth.refresh_hud()
	var ending=game.get_node("Ending")
	if ending.world:ending.world.retrofit.apply_visual_state(facts());ending.world.vent_service.apply_visual_state(facts())

func target_hint() -> String:
	var document: String=world.nearest_document()
	if not document.is_empty():return "E 查看"+preload("res://story_branches/evidence_data.gd").data(document).title
	if world.nearest_item().is_empty():return ""
	return "E 检查桌下维修盒" if day.value("current_day",1)>=7 else "维护盒 · 接口没有供电"

func try_interact() -> bool:
	var document: String=world.nearest_document()
	if not document.is_empty():day.reader.open_evidence(document);return true
	if world.nearest_item().is_empty():return false
	if day.value("current_day",1)==6:game.ui.toast("接口没有供电，等电脑恢复后再检查。",4)
	elif day.value("current_day",1)==7 and not flag("a7_login"):game.ui.toast("先登录桌上的电脑，再检查维护附件。",4)
	else:open_equipment("box")
	return true

func open_equipment(view := "k2") -> void:
	if value("br_ending")!=0:return
	var system=game.get_node("QuestSystem")
	if system.tracker.journal_visible():system.close_journal()
	if game.get_node("ActThree").computer.shell.visible:game.get_node("ActThree").computer.close_computer()
	var fourth=game.get_node("ActFour")
	if not fourth.panel.mode.is_empty():fourth.panel.close();fourth.close_panel()
	open_panel(view)

func open_panel(view: String) -> void:
	if not ensure_bound() or (is_instance_valid(film) and film.running):return
	if not panels.opened:panels.open(game,game.get_node("Ending").world)
	panels.show_view(view)
	feedback.play_feedback("open")

func open_terminal() -> void:
	if not flag("a11_enter") or value("br_ending")!=0:return
	open_panel("overview")

func step(action: String, input: Dictionary={}) -> bool:
	var ok: bool=state.commit_step(action,input)
	if ok:restore_world()
	feedback.play_feedback("error" if not ok else "relay" if action=="power_safe" else "pulse" if action=="k2_ready" else "record" if action in ["records","index","body_seen"] else "confirm")
	return ok

func choose_mouse(rescue: bool) -> bool:
	if not state.commit_mouse_intent(rescue):return false
	panels.close()
	game.get_node("ActFour").panel.close();game.get_node("ActFour").close_panel()
	start_mouse_film(false)
	return true

func start_mouse_film(recovering: bool) -> void:
	if value("br_mouse_intent")==0 or value("br_mouse")!=0:return
	var fourth=game.get_node("ActFour")
	if recovering:
		game.player.global_position=Vector3(1.38,.025,-3.42);game.player.velocity=Vector3.ZERO
		game.player.yaw=PI*.5;game.player.rotation.y=game.player.yaw;game.player.pitch=0;game.player.head.rotation.x=0
	state.busy=true
	if value("br_mouse_intent")==1:
		if not fourth.mouse_control.begin():state.busy=false
	else:
		film=load("res://story_branches/resist_film.gd").new();film.chapter=self;add_child(film);film.play()

func mouse_finished() -> void:
	state.busy=false;needs_restore=true
	game.get_node("ActFour").restore()
	game.get_node("ActFour").open_mouse_story()

func confirm_ending(kind: int) -> bool:
	if not state.commit_ending(kind):return false
	panels.close();start_ending_film(false);return true

func start_ending_film(replay: bool) -> void:
	if is_instance_valid(film) and film.running:return
	if panels.opened:panels.close()
	state.replay=replay;state.busy=true
	film=load("res://story_branches/recovery_film.gd" if value("br_ending")==2 else "res://story_branches/rescue_film.gd").new()
	film.chapter=self;add_child(film);film.play()

func ending_finished() -> bool:
	if not state.replay and not state.finish_ending():return false
	state.busy=false;state.replay=false;needs_restore=true
	return true

func show_final() -> void:
	state.replay=false;state.busy=false
	open_panel("final")

func play_memory(level := 0, readonly := true) -> void:
	if is_instance_valid(film) and film.running:return
	if level==0:level=maxi(1,value("br_memory_level"))
	var system=game.get_node("QuestSystem")
	if system.tracker.journal_visible():system.close_journal()
	var return_view:="repair" if flag("br_legacy_flow") else "records" if panels.opened else ""
	if panels.opened:panels.close()
	state.busy=true;memory_replay=readonly;state.replay=readonly
	film=load("res://story_branches/memory_film.gd").new();film.chapter=self;film.level=level;film.readonly=readonly;film.return_view=return_view;add_child(film);film.play()

func play_care_memory() -> void:
	if is_instance_valid(care_memory) or (is_instance_valid(film) and film.running):return
	var system=game.get_node("QuestSystem")
	if system.tracker.journal_visible():system.close_journal()
	state.busy=true
	care_memory=preload("res://story_branches/memory_player.gd").new();add_child(care_memory)
	care_memory.finished.connect(func():state.busy=false;care_memory=null)
	care_memory.play(game)

func play_recording() -> void:recording.play()

func cancel_runtime() -> void:
	if is_instance_valid(world):world.reset_session()
	if is_instance_valid(alert):alert.reset()
	recording.stop()
	if is_instance_valid(care_memory):care_memory.finish();care_memory=null
	if is_instance_valid(film):film.cancel();film.queue_free();film=null
	if panels.opened:panels.close()
	state.busy=false;state.replay=false;needs_restore=true

func return_menu() -> void:
	cancel_runtime();set_physics_process(false);game.get_tree().reload_current_scene()
