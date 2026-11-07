extends SceneTree
const Service=preload("res://story_branches/state.gd")
const Rules=preload("res://story_branches/rules.gd")
var game
var checks := 0
var failures: Array[String]=[]
var path_: String

func _initialize() -> void:
	path_="user://branch_regression/%d/slot.json"%OS.get_process_id();call_deferred("run")
func ticks(count: int) -> void:
	for _i in range(count):await physics_frame
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("STORY_SAVE_FAILED ",message)
func fixture(flags: Dictionary,values: Dictionary) -> void:
	var manager:=CalicoQuestManager.new();manager.configure(load("res://act2/quests/catalog.tres"));manager.save_path=path_
	var data:=manager.make_save_data();data.flags=flags;data.flags["intro_seen"]=true;data.values=values
	check(manager.restore_save_data(data,false) and manager.save_game(),"Cannot create isolated save fixture")
	manager.free()
func boot() -> Node:
	game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_file=path_;root.add_child(game);current_scene=game;await ticks(10)
	return game.get_node("QuestSystem")
func leave() -> void:
	game.get_node("StoryBranches").cancel_runtime();game.stop_audio();game.queue_free()
	for _i in range(3):await process_frame

func run() -> void:
	create_timer(120).timeout.connect(func():printerr("STORY_SAVE_TIMEOUT");quit(2))
	fixture({"a10_eat":true,"a11_memory":true},{"current_day":10,"ending_choice":1})
	var original:=FileAccess.get_file_as_string(path_)
	var system=await boot()
	check(FileAccess.get_file_as_string(path_)==original,"Menu validation changed original save")
	var notifications: Array=[]
	system.manager.changed.connect(func():notifications.append(int(system.manager.values.get("br_schema",0))))
	check(system.prepare_session(false),"Legacy session cannot prepare")
	check(notifications==[1],"Chapter notifications occurred before silent migration finished")
	check(not game.started and not game.get_node("DayOne").initialized,"Migration started gameplay")
	check(FileAccess.get_file_as_string(path_+".branches_v1.bak")==original,"Migration did not preserve one-time original backup")
	check(system.manager.values.br_mouse==1 and system.manager.values.br_ending==0 and not system.manager.flags.get("br_memory",false),"Legacy semantics changed")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path_))
	check(saved.values.br_schema==1 and saved.flags.br_mouse_resolved,"Migration was not saved before restore")
	await leave()

	fixture({"a10_catch":true,"a10_note":true,"a10_asked":true,"a10_refused":true,"br_k2_owned":true,"br_k2_ready":true,"br_k2_spent":true,"daily_note_ack_10":true,"a10_note_read":true},{"current_day":10,"br_schema":1,"br_mouse":0,"br_mouse_intent":2})
	system=await boot();check(system.prepare_session(false),"Pending rescue save cannot load")
	check(game.get_node("StoryBranches").film==null,"Rescue started before game restore")
	game.start_game();await ticks(12)
	var branch=game.get_node("StoryBranches")
	check(is_instance_valid(branch.film) and branch.film.running,"Pending rescue was not restarted")
	if is_instance_valid(branch.film):branch.film.skip()
	await ticks(3)
	saved=JSON.parse_string(FileAccess.get_file_as_string(path_))
	check(saved.values.br_mouse==2 and saved.values.br_mouse_intent==0 and saved.flags.br_k2_spent and not saved.flags.a10_eat,"Resolved rescue did not atomically reach disk")
	await leave();system=await boot();check(system.prepare_session(false),"Resolved rescue cannot reload");game.start_game();await ticks(10)
	check(not game.get_node("ActFour").mouse_control.running and game.get_node("StoryBranches").value("br_mouse")==2,"Resolved rescue resumed swallowing")
	await leave()

	var flags={"a11_enter":true,"a11_finished":true,"a11_complete":true,"br_rescue_done":true}
	for key in Rules.HUMAN_FACTS:flags[key]=true
	fixture(flags,{"current_day":11,"br_schema":1,"br_ending":2,"br_phase":2})
	system=await boot();check(system.prepare_session(false),"Completed human save cannot load");game.start_game();await ticks(10)
	branch=game.get_node("StoryBranches")
	check(branch.panels.opened and branch.panels.active_view=="final","Completed ending does not restore final panel")
	original=FileAccess.get_file_as_string(path_)
	branch.start_ending_film(true);branch.film.skip();branch.film.finish_ending();await ticks(3)
	check(original==FileAccess.get_file_as_string(path_),"Read-only replay changed disk bytes")
	await leave()

	flags={"a11_enter":true}
	for key in Rules.HUMAN_FACTS:flags[key]=true
	fixture(flags,{"current_day":11,"br_schema":1,"br_ending":2,"br_phase":1})
	system=await boot();check(system.prepare_session(false),"Interrupted human ending cannot load");game.start_game();await ticks(10)
	branch=game.get_node("StoryBranches");branch.film.skip()
	original=FileAccess.get_file_as_string(path_)
	var blocker=FileAccess.open("user://branch_save_blocker",FileAccess.WRITE);blocker.store_string("not a directory");blocker.close()
	system.manager.save_path="user://branch_save_blocker/slot.json"
	var before_end=system.manager.make_save_data();branch.film.finish_ending()
	check(branch.film.running and branch.film.waiting and branch.value("br_phase")==1,"Failed ending save released exploration")
	check(system.manager.make_save_data()==before_end and FileAccess.get_file_as_string(path_)==original,"Failed ending save partially committed")
	system.manager.save_path=path_;branch.film.finish_ending();await ticks(3)
	check(branch.value("br_phase")==2 and branch.flag("br_rescue_done"),"Ending save cannot retry")
	await leave()

	fixture({"a10_eat":true},{"current_day":10,"br_schema":1,"br_mouse":2})
	original=FileAccess.get_file_as_string(path_)
	system=await boot();check(not system.prepare_session(false),"Conflicting new save was silently repaired")
	check(FileAccess.get_file_as_string(path_)==original and not game.started,"Conflicting save was overwritten or started gameplay")
	await leave()

	path_="user://branch_regression/%d/migration_failure/slot.json"%OS.get_process_id()
	fixture({"a10_eat":true},{"current_day":10})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path_+".branches_v1.bak"))
	original=FileAccess.get_file_as_string(path_)
	system=await boot();var before=system.manager.make_save_data()
	check(not system.prepare_session(false),"Migration backup failure was ignored")
	check(system.manager.make_save_data()==before and FileAccess.get_file_as_string(path_)==original,"Failed migration polluted memory or disk")
	await leave()
	print("STORY_PERSISTENCE_TEST ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
