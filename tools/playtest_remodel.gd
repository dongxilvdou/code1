extends "res://tools/playtest_map_stairs.gd"
var checks := 0
func verify(value: bool, message: String) -> void:
	checks += 1
	expect(value,message)
func run_tests() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game)
	current_scene = game
	game.start_game()
	map_hud = game.get_node("VillaMap/MapHUD")
	await ticks(8)
	# This geometry test predates the story/tutorial gates. Enter a disposable,
	# unlocked day-eleven state instead of leaving the arrival dialog in control.
	var day = game.get_node("DayOne")
	var fourth = game.get_node("ActFour")
	fourth.third.previous.seed_previous_days()
	fourth.mark("a6_permission")
	fourth.begin_day(11)
	fourth.set_value("locks",3)
	fourth.mark("a11_enter");fourth.mark("a11_complete")
	fourth.restore()
	day.dialog = "";day.hud.overlay.hide();fourth.panel.close()
	game.cinematic_active = false;game.player.set_control(true)
	var house: Node3D = game.get_node("Apartment")
	verify(house.has_node("GroundFloor/Furnishings/Workshop"),"Downstairs study missing")
	verify(house.has_node("UpperFloor/Furnishings/ComputerRoom"),"Upstairs computer room missing")
	for path in ["GroundFloor/Furnishings/Workshop","UpperFloor/Furnishings/ComputerRoom"]:
		for asset in house.get_node(path).get_children():verify(asset.get_meta("asset_id","")!="bed","Old bed remains in converted room")
	var ids: Array[String] = []
	for asset in house.get_node("UpperFloor/Furnishings/ComputerRoom").get_children():ids.append(asset.get_meta("asset_id",""))
	for wanted in ["work_desk","dual_monitor","keyboard_mouse","computer_tower","audio_accessories","router_power"]:verify(wanted in ids,"Missing computer asset "+wanted)
	for asset in get_nodes_in_group("placed_furniture"):
		if asset.get_meta("placement_room","") in ["Living","Dining"]:verify(asset.get_meta("asset_id","")!="decor_place_setting","Plates/chopsticks remain in shared living/dining area")
	verify(game.player.void_reset_height<-3,"Basement still triggers the old void reset")
	verify(map_hud.maps.has("basement"),"Basement navigation missing")
	for door in get_nodes_in_group("villa_doors"):door.set_open(true,true)
	await ticks(4)
	# Enter through each converted room's actual doorway and approach its desk.
	for floor_y in [0.02,3.02]:
		place(7.55,8.35,floor_y,PI)
		await ticks(8)
		verify(await walk_until("z",10.25-6,240),"Room doorway blocked on floor "+str(floor_y))
		verify(game.room_at(game.player.position).contains("书房" if floor_y<1 else "电脑房"),"Room identity not updated")
		face(-PI/2)
		verify(await walk_until("x",9.65-6,240),"Route toward work desk obstructed")
	# Real descending/ascending staircase, 18 x 15cm rises, no teleport or ramp.
	place(11.20,8.20,.02,0)
	await ticks(12)
	var descend := await walk_until("z",3.25-6,480)
	var bottom: float = game.player.position.y
	verify(descend,"Basement descent blocked at "+str(game.player.position))
	verify(absf(bottom+2.70)<.06,"Wrong basement landing height: "+str(bottom))
	verify(map_hud.current_map=="basement","Minimap did not select basement")
	face(PI/2)
	verify(await walk_until("x",9.85-6,180),"Lower landing turn blocked")
	face(-PI/2)
	verify(await walk_until("x",11.20-6,180),"Lower landing return blocked")
	face(PI)
	verify(await walk_until("z",8.10-6,480),"Basement ascent blocked at "+str(game.player.position))
	verify(absf(game.player.position.y)<.06,"Did not exit basement at ground level")
	verify(map_hud.current_map=="floor_1","Map did not return to first floor")
	face(PI/2)
	verify(await walk_until("x",10.00-6,180),"Basement exit did not leave enough space to turn")
	# Upstairs circulation must remain available beside the new mouth.
	place(10,8.0,.02,0)
	await ticks(8)
	verify(await walk_until("z",4.40-6,420),"Original lower upstairs flight obstructed")
	face(-PI/2)
	verify(await walk_until("x",11.2-6,180),"Original stair turn obstructed")
	face(PI)
	verify(await walk_until("z",8.02-6,420),"Original upper flight obstructed")
	verify(absf(game.player.position.y-3)<.06,"Upstairs floor height changed")
	for trial in [[30,"sprint",11.2],[60,"crouch",10.83],[120,"",11.57]]:
		Engine.physics_ticks_per_second = trial[0]
		place(trial[2],8.2,.02,0)
		await ticks(12)
		if not trial[1].is_empty():Input.action_press(trial[1])
		verify(await walk_until("z",3.25-6,trial[0]*10),"Basement descent at "+str(trial))
		verify(absf(game.player.position.y+2.7)<.06,"Basement floor at "+str(trial))
		face(PI)
		verify(await walk_until("z",8.10-6,trial[0]*10),"Basement return at "+str(trial))
		verify(absf(game.player.position.y)<.06,"Basement exit at "+str(trial))
		if not trial[1].is_empty():Input.action_release(trial[1])
	Engine.physics_ticks_per_second = 60
	print("REMODEL_PLAYTEST ",JSON.stringify({"checks":checks,"basement_y":bottom,"failures":failures}))
	game.stop_audio()
	game.queue_free()
	await ticks(3)
	quit(0 if failures.is_empty() else 1)
