extends SceneTree
## Formal controller persistence; the previous q01 sample catalog is tested separately.
var save_path: String
var checks := 0
var failures: Array[String]=[]
var game: Node
func _initialize() -> void:
	save_path="user://quest_controller/%d/slot.json"%OS.get_process_id();call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("QUEST_SAVE_FAILED ",message)
func ticks(count := 8) -> void:
	for _i in range(count):await physics_frame
	await process_frame
func boot() -> Node:
	game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_file=save_path;root.add_child(game);current_scene=game;await ticks()
	return game.get_node("QuestSystem")
func leave() -> void:
	game.get_node("StoryBranches").cancel_runtime();game.stop_audio();game.queue_free();await process_frame;await process_frame;await process_frame
func run() -> void:
	create_timer(90).timeout.connect(func():printerr("QUEST_SAVE_TIMEOUT");quit(2))
	var system=await boot()
	expect(system.prepare_session(true),"Formal new session prepares")
	expect(system.manager.autosave,"Controller enables autosave in isolated profile")
	game.start_game();await ticks()
	var day=game.get_node("DayOne");day.dialog="";day.hud.overlay.hide();game.cinematic_active=false;game.player.set_control(true)
	day.reader.open_daily(1);await process_frame;await process_frame;await process_frame;day.reader.cancel();await ticks(2)
	expect(day.flag("note_read") and FileAccess.file_exists(save_path),"Presented note reaches physical save")
	var original=FileAccess.get_file_as_bytes(save_path);await leave()
	system=await boot();expect(system.inspect_save().valid and FileAccess.get_file_as_bytes(save_path)==original,"Menu validates without modifying bytes")
	expect(system.prepare_session(false),"Controller continues saved progress")
	expect(system.manager.flags.get("daily_note_ack_1",false),"New scene restores actual read flag")
	var event_history=system.manager.make_save_data().seen_events.duplicate()
	game.start_game();await ticks()
	expect(system.manager.make_save_data().seen_events==event_history,"Reload does not repeat read reward/event")
	system.restart_quests();await ticks()
	expect(not system.manager.flags.get("note_read",false) and int(system.manager.values.get("br_schema",0))==2,"Explicit reset clears progress and keeps schema2")
	await leave();system=await boot();expect(system.prepare_session(false) and not system.manager.flags.get("note_read",false),"Reset persists to next session")
	await leave()
	var file=FileAccess.open(save_path,FileAccess.WRITE);file.store_string("{\"version\":999}");file.close()
	system=await boot();expect(not system.prepare_session(false),"Invalid save refuses continuation")
	expect(not system.manager.autosave and not system.menu_error.is_empty(),"Invalid save disables automatic overwrite and explains failure")
	expect(FileAccess.get_file_as_string(save_path)=="{\"version\":999}","Invalid original file is preserved")
	system.restart_quests();expect(system.manager.autosave and system.manager.last_save_error.is_empty(),"Explicit reset recovers persistence")
	await leave()
	print("QUEST_PERSISTENCE_TESTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
