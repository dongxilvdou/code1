extends SceneTree
var checks := 0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func ticks(n: int) -> void:
	for _i in range(n):await physics_frame
func verify(ok: bool, text_: String) -> void:
	checks+=1
	if not ok:failures.append(text_);printerr("STORY_MENU_FAILED ",text_)
func run() -> void:
	create_timer(60).timeout.connect(func():printerr("STORY_MENU_TIMEOUT");quit(2))
	var game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false;root.add_child(game);current_scene=game;game.start_game();await ticks(10)
	var day=game.get_node("DayOne");var branch=game.get_node("StoryBranches")
	day.dialog="";day.hud.overlay.hide();game.cinematic_active=false;game.player.set_control(true)
	day.manager.apply_story_patch({"a9_jigsaw":true,"intro_seen":true},{"current_day":9},false)
	branch.play_care_memory();await ticks(2)
	verify(branch.care_memory!=null and branch.care_memory.running,"Care flashback cannot replay")
	branch.care_memory.finish();verify(not branch.state.busy and game.player.active,"Care replay did not restore control")
	var flags={"a11_enter":true,"a11_memory":true}
	for key in preload("res://story_branches/legacy_rules.gd").HUMAN_FACTS:flags[key]=true
	day.manager.apply_story_patch(flags,{"current_day":11,"br_schema":1},false)
	verify(branch.state.migrate_legacy(),"Explicit old menu fixture migrates")
	verify(branch.state.commit_ending(2),"Cannot prepare ending menu check")
	branch.start_ending_film(false);branch.film.toggle_pause();await ticks(2)
	verify(branch.film.paused,"Ending pause menu did not open")
	branch.return_menu();await ticks(15)
	verify(is_instance_valid(current_scene) and current_scene!=game,"Menu reload did not replace scene")
	verify(not current_scene.started and current_scene.ui.welcome.visible,"Returned menu starts gameplay")
	verify(current_scene.get_node("StoryBranches").film==null,"Old film survived menu reload")
	print("STORY_MENU_TEST ",JSON.stringify({"checks":checks,"failures":failures}))
	current_scene.stop_audio();current_scene.queue_free()
	for _i in range(3):await process_frame
	quit(0 if failures.is_empty() else 1)
