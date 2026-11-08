extends "res://tools/playtest_basement.gd"
## Updated fixtures for the current note gate and ending dialogue; original tests kept.
func clear_modals() -> void:
	dismiss()
	game.get_node("Ending").ui.close()
	game.player.set_control(true);game.cinematic_active=false

func run_tests() -> void:
	game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false
	root.add_child(game);current_scene=game;await ticks(12);game.start_game();await ticks(12)
	var day=game.get_node("DayOne");var fourth=game.get_node("ActFour");var ending=game.get_node("Ending")
	game._seed_demo_day(11);fourth.mark("daily_note_ack_11")
	day.manager.apply_story_patch({"br_day11_alert_received":true},{"br_day11_intro_state":2},false)
	clear_modals();await ticks(4)
	go(Vector3(5.20,.02,2.20));await ticks(8)
	verify(await walk_until("z",-2.80,450),"Descent blocked with current daily note acknowledged")
	verify(absf(game.player.position.y+2.7)<.06,"Basement floor height changed")
	face(PI/2)
	verify(not await walk_until("x",2.9,190),"Locked door can be crossed")
	go(Vector3(4.35,-2.68,-2.80),PI/2);await ticks(8)
	verify(fourth.nearest_item()=="basement","Original relay door target lost")
	for level in range(3):
		var solution: Dictionary=fourth.Circuit.solution(level)
		for i in range(fourth.Circuit.count_(level)):
			fourth.set_value("a11_route_%d_%d"%[level,i],solution.routes[i]);fourth.set_value("a11_coil_%d_%d"%[level,i],solution.coils[i])
		fourth.complete_lock()
		verify(fourth.val("locks")==level+1,"Original lock progression failed")
	clear_modals();await ticks(100)
	verify(fourth.world.items.basement.is_open,"Three relays failed to open door")
	Input.action_press("move_forward")
	for i in range(180):
		await physics_frame
		if fourth.flag("a11_enter"):break
	Input.action_release("move_forward");await ticks(4)
	verify(fourth.flag("a11_enter"),"Crossing threshold failed to enter ending")
	ending.mark("a11_memory");clear_modals();await ticks(5)
	# The ending's first-frame resume position must settle before traversal.
	clear_modals()
	for cage in get_nodes_in_group("lab_cages"):
		var center: Vector3=cage.global_position
		cage.set_open(false,true);go(center+Vector3(0,.01,-1.35),PI);await ticks(8)
		verify(not await walk_until("z",center.z-.2,65),"Closed cage is passable")
		go(center+Vector3(0,.01,-2.2),PI);await ticks(5);game.update_target()
		verify(game.nearest_door==cage,"Cage not targetable from outside")
		await key(KEY_E);await ticks(100)
		verify(cage.is_open and not cage.moving,"Cage cannot open by E")
		verify(await walk_until("z",center.z+.25,170),"Open cage tray inaccessible")
		verify(absf(game.player.position.y-(center.y+.05))<.045,"Tray height changed")
		face(0);await ticks(6);await key(KEY_E);await ticks(100)
		verify(not cage.is_open and not cage.moving,"Cannot close from inside: "+str(cage.name))
		go(center+Vector3(0,.06,-.25));await ticks(5);await key(KEY_E);await ticks(100)
		verify(cage.is_open,"Cannot reopen cage from inside")
		verify(await walk_until("z",center.z-1.4,180),"Cannot leave cage")
		go(center+Vector3(.13,.01,-1.19));await ticks(5);cage.set_open(false);await ticks(100)
		verify(cage.blocked and cage.moving,"Anti-crush pause failed")
		go(center+Vector3(0,.01,-2.05));await ticks(100)
		verify(not cage.moving and not cage.is_open,"Door does not resume after cat clears")
	go(Vector3(1.5,-2.68,-2.8),-PI/2);await ticks(8)
	verify(await walk_until("x",5.2,300),"Return to landing blocked")
	face(PI);verify(await walk_until("z",2.15,480),"Return up stairs blocked")
	verify(absf(game.player.position.y)<.08,"Failed to return upstairs")
	verify(game.player.active and not game.cinematic_active,"Input not restored")
	verify(not day.manager.autosave,"Normal save enabled")
	print("BRANCH_ROUTES_TEST ",JSON.stringify({"checks":checks,"failures":failures}))
	game.stop_audio();game.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
