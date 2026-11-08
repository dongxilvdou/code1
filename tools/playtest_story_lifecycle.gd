extends "res://tools/playtest_pre11_story.gd"
var samples: Array=[]

func sample(label_: String) -> Dictionary:
	var data:={"stage":label_,"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"memory":int(Performance.get_monitor(Performance.MEMORY_STATIC))}
	samples.append(data);return data

func run() -> void:
	create_timer(240).timeout.connect(func():printerr("STORY_LIFECYCLE_TIMEOUT");quit(2))
	game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false;root.add_child(game);current_scene=game;game.start_game();await ticks(12)
	day=game.get_node("DayOne");branch=game.get_node("StoryBranches");fourth=game.get_node("ActFour");ending=game.get_node("Ending");dismiss()
	await setup_day(10);await collect_evidence()
	var before=day.manager.make_save_data();var warm: Dictionary={}
	for level in range(1,4):
		for iteration in range(10):
			branch.play_memory(level,true);await ticks(2)
			if iteration%3==0:branch.film.toggle_pause();branch.film.resume()
			if iteration%3==1:branch.film.cancel();branch.state.busy=false;branch.film.queue_free()
			else:branch.film.skip()
			await process_frame;await process_frame;await ticks(2)
			var after=day.manager.make_save_data()
			if before!=after and not "memory_diff_printed" in root.get_meta_list():
				root.set_meta("memory_diff_printed",true)
				for section in ["flags","values","quests"]:
					for key_ in after[section]:
						if before[section].get(key_)!=after[section][key_]:print("MEMORY_REPLAY_DIFF ",section," ",key_," ",str(before[section].get(key_))," -> ",str(after[section][key_]))
			verify(before==after,"Memory replay never writes progress")
			var point=sample("memory_%d_%d"%[level,iteration])
			if level==1 and iteration==3:warm=point
			if level>=2:verify(point.nodes<=warm.nodes+6 and point.orphans<=warm.orphans,"Memory stages release cameras, actors, audio and orphan nodes")
	for prepared in [false,true]:
		for saved in [false,true]:
			await setup_day(10)
			if prepared:await collect_evidence()
			if saved:await equipment()
			await mouse_event(saved);await alert_check()
			var route:=3 if prepared else 2 if saved else 1
			await complete_route(route)
			before=day.manager.make_save_data();warm={}
			for iteration in range(10):
				branch.start_ending_film(true);await ticks(2)
				if iteration%2==0:branch.film.toggle_pause();branch.film.resume()
				branch.film.skip();await ticks(2);branch.film.finish_ending();await ticks(3);await process_frame
				verify(before==day.manager.make_save_data(),"Repeated ending is byte-equivalent in memory")
				var point=sample("ending_%d_%d_%d"%[route,branch.value("br_mouse"),iteration])
				if iteration==3:warm=point
				if iteration>3:verify(point.nodes<=warm.nodes+3 and point.orphans<=warm.orphans and point.resources<=warm.resources+3,"Ending repeated stages do not accumulate")
	# Restore to identical idle state ten times, checking actual world instance counts.
	dismiss();await setup_day(10);before=day.manager.make_save_data();warm=sample("restore_warm")
	for iteration in range(10):
		verify(day.manager.restore_save_data(before),"Snapshot remains loadable")
		branch.restore_world();await ticks(4)
		verify(branch.world.documents.size()==3 and branch.world.find_children("D*","Node3D",false,false).size()==3,"Reload never duplicates document actors")
		var point=sample("restore_%d"%iteration);verify(point.nodes<=warm.nodes+3,"Restoring does not grow world instances")
	# Twenty actual scene-to-menu replacements in the same process.
	for iteration in range(20):
		branch.return_menu();await ticks(12);await process_frame
		game=current_scene;day=game.get_node("DayOne");branch=game.get_node("StoryBranches");fourth=game.get_node("ActFour");ending=game.get_node("Ending")
		game.get_node("QuestSystem").save_enabled=false
		verify(not game.started and game.ui.welcome.visible and not branch.alert.activated,"Main menu contains no old alarm/film/session")
		verify(game.get_node("QuestSystem").prepare_session(true),"New session prepares after menu reload")
		game.start_game();await ticks(8);dismiss();await ticks(3)
		var point=sample("menu_%d"%iteration)
		if iteration==3:warm=point
		if iteration>3:verify(point.nodes<=warm.nodes+6 and point.orphans<=warm.orphans and point.resources<=warm.resources+6,"Repeated new/menu cycles do not grow resources")
	print("STORY_LIFECYCLE_TEST ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples}))
	branch.set_physics_process(false);dismiss();game.stop_audio();game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
