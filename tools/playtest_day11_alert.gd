extends "res://tools/playtest_pre11_story.gd"

func run() -> void:
	create_timer(60).timeout.connect(func():printerr("ALERT_TIMEOUT");quit(2))
	game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false;root.add_child(game);current_scene=game;game.start_game();await ticks(12)
	day=game.get_node("DayOne");branch=game.get_node("StoryBranches");fourth=game.get_node("ActFour");ending=game.get_node("Ending");dismiss()
	await setup_day(10)
	verify(game.get_node("HouseMemes").start("tv"),"Original TV clip plays before story override")
	var old_material=game.get_node("HouseMemes").screen.material_override
	game._seed_demo_day(11);await ticks(8)
	verify(branch.alert.activated and is_instance_valid(branch.alert.intro),"Normal eleven intro scheduled")
	verify(not game.get_node("HouseMemes").entries.tv.playing,"Alarm stops former clip")
	verify(branch.value("br_day11_intro_state")==1,"Intro pending persisted before presentation")
	verify(branch.alert.alarm.playing and branch.alert.alarm.bus=="Master","Alarm uses master volume")
	root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var clock: float=branch.alert.intro.clock
	await create_timer(.25).timeout
	verify(branch.alert.intro.clock==clock and branch.alert.alarm.stream_paused,"Focus loss pauses intro and alarm: before=%s after=%s paused=%s focused=%s audio=%s"%[clock,branch.alert.intro.clock,branch.alert.intro.paused,branch.alert.focused,branch.alert.alarm.stream_paused])
	root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN);branch.alert.intro.resume()
	game.set_volume(0)
	verify("实验出错" in branch.alert.intro.caption.text and "请前往地下室修复实验" in branch.alert.intro.caption.text,"Muted intro still shows full objective")
	await create_timer(3.4).timeout
	verify(branch.value("br_day11_intro_state")==2 and branch.flag("br_day11_alert_received"),"Normal-speed intro completes in about three seconds")
	verify(game.player.active and not game.cinematic_active,"Intro restores paired controls")
	await create_timer(2.2).timeout
	verify(game.get_node("HouseMemes").story_tv_active and game.get_node("HouseMemes").screen.material_override!=old_material,"Former five-second TV timeout cannot clear warning")
	verify(not game.get_node("HouseMemes").start("tv"),"TV clip cannot replace warning")
	day.manager.apply_story_patch({"a11_enter":true},{},false);await create_timer(1.3).timeout
	verify(not branch.alert.alarm.playing and game.get_node("HouseMemes").story_tv_active,"Entering lab fades sound and keeps static warning")
	dismiss();game._seed_demo_day(11);day.manager.apply_story_patch({}, {"br_day11_intro_state":1},false);await ticks(6)
	verify(not is_instance_valid(branch.alert.intro) and branch.value("br_day11_intro_state")==2,"Pending intro resumes as static goal, without waking again")
	dismiss();game._seed_demo_day(1);await ticks(5)
	verify(not branch.alert.activated and not game.get_node("HouseMemes").story_tv_active,"New session releases TV ownership")
	verify(not branch.alert.alarm.playing,"Alarm does not leak across sessions")
	print("DAY11_ALERT_TEST ",JSON.stringify({"checks":checks,"failures":failures}))
	branch.set_physics_process(false);dismiss();game.stop_audio();game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
