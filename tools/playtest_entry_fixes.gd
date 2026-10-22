extends "res://tools/playtest_basement.gd"
## Actual input/physics, floor coverage and day-eleven puzzle regression.
func mesh_bounds(n: MeshInstance3D) -> AABB:return n.global_transform*n.get_aabb()

func rendered_floor_count(p: Vector3) -> int:
	var count := 0
	for mesh in game.get_node("Apartment/Basement").find_children("*","MeshInstance3D",true,false):
		if not ("TiledFloor" in mesh.name or "LandingConnection" in mesh.name or "TreadsAndLanding" in mesh.name):continue
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var a: Vector3 = mesh.to_global(faces[i])
			var b: Vector3 = mesh.to_global(faces[i+1])
			var c: Vector3 = mesh.to_global(faces[i+2])
			if absf(a.y-p.y)>.0001 or absf(b.y-p.y)>.0001 or absf(c.y-p.y)>.0001:continue
			if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])):
				count += 1;break
	return count

func run_tests() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game);current_scene = game
	game.start_game();await ticks(12);dismiss()
	var day = game.get_node("DayOne")
	var fourth = game.get_node("ActFour")
	verify(fourth.world.door_body.collision_layer==0,"An invisible fourth-act door blocks early-day exploration")
	var third_day = game.get_node("ActTwo")
	var nest: MeshInstance3D = day.world.items.nest.find_children("*","MeshInstance3D",true,false)[0]
	var nest_box := mesh_bounds(nest)
	var sofa: Node3D = day.World.Props.furniture(game,"sofa","Living")
	var plant_count := 0
	for n in get_nodes_in_group("placed_furniture"):
		if n.get_meta("asset_id","")!="decor_plant" or n.get_meta("placement_room","")!="Living":continue
		plant_count += 1
		var clips_bed := false;var clips_sofa := false;var clips_wall := false
		for mesh in n.find_children("*","MeshInstance3D",true,false):
			var bounds := mesh_bounds(mesh)
			clips_bed = clips_bed or bounds.intersects(nest_box)
			clips_wall = clips_wall or bounds.position.x< -5.86 or bounds.end.z>5.86
			for sofa_mesh in sofa.find_children("*","MeshInstance3D",true,false):clips_sofa = clips_sofa or bounds.intersects(mesh_bounds(sofa_mesh))
		verify(not clips_bed,"Plant clips cat bed: "+str(n.name))
		verify(not clips_sofa,"Plant clips sofa: "+str(n.name))
		verify(not clips_wall,"Plant clips living-room walls: "+str(n.name))
	verify(plant_count==2,"Living plants were deleted instead of repositioned")
	verify(third_day.world.items.plant.get_meta("bound_furniture").position.distance_to(Vector3(-5.4,0,3.65))<.01,"Day-three plant binding moved away from its pot")
	fourth.third.previous.seed_previous_days()
	fourth.mark("a6_permission");fourth.begin_day(11);dismiss();fourth.mark("daily_note_ack_11")
	await ticks(4)
	go(Vector3(-4.40,.02,4.87),PI/2);await ticks(8)
	game.update_target()
	verify(day.target_hint().contains("休息") or fourth.nearest_item()=="nest","Cat bed can no longer be approached/interacted with")
	await photo("05_cat_bed_clearance",Vector3(-4.05,.49,4.36),Vector3(-5.12,.27,4.72),76)
	for x in [3.20,3.29,3.335,3.38,3.43]:
		for z in [-3.39,-2.81,-2.21]:verify(rendered_floor_count(Vector3(x,-2.7,z))==1,"Duplicate/missing rendered floor at "+str(Vector2(x,z)))
	var door = fourth.world.items.basement
	verify(absf(door.global_position.x-3.34)<.01 and absf(door.global_position.y+2.7)<.01,"Puzzle door was not moved to the lower laboratory portal")
	verify(door.locked and not door.is_open,"New door starts unlocked before three relay puzzles")
	go(Vector3(5.20,.02,2.20));await ticks(8)
	verify(await walk_until("z",-2.80,450),"Old upstairs door location still blocks basement stairs")
	verify(not fourth.flag("a11_enter"),"Reaching landing completed the moved entrance objective")
	face(PI/2)
	verify(not await walk_until("x",2.9,190),"Locked relocated door lets cat enter")
	go(Vector3(4.35,-2.68,-2.80),PI/2);await ticks(8)
	verify(fourth.nearest_item()=="basement","Moved relay controls cannot be targeted at cat height")
	await key(KEY_E)
	verify(fourth.panel.mode=="circuit","E did not open the original circuit puzzle")
	for level in range(3):
		var solution: Dictionary = fourth.Circuit.solution(level)
		for i in range(fourth.Circuit.count_(level)):
			fourth.set_value("a11_route_%d_%d"%[level,i],solution.routes[i])
			fourth.set_value("a11_coil_%d_%d"%[level,i],solution.coils[i])
		var result: Dictionary = fourth.Circuit.evaluate(level,fourth.circuit_routes(),fourth.circuit_coils())
		verify(result.ok,"Original circuit solution broke at level "+str(level))
		fourth.panel.mode = "circuit";fourth.panel.finish_circuit(result)
		verify(fourth.val("locks")==level+1,"Circuit progression did not unlock one relay")
		dismiss()
	await ticks(90)
	verify(not door.locked and door.is_open and not door.moving,"Three puzzles did not open the laboratory door")
	verify(not fourth.flag("a11_enter"),"Unlocking alone completed entering the laboratory")
	# Close the door from the landing, proving it remains a usable physical door.
	await key(KEY_E);await ticks(90)
	verify(not door.is_open and not door.moving,"Unlocked lab door cannot be closed from landing")
	fourth.restore();await ticks(4)
	verify(not door.is_open,"Quest refresh forced a manually closed door open")
	await photo("06_relocated_locked_door",Vector3(4.73,-1.66,-2.85),Vector3(3.34,-1.70,-2.80),72)
	await key(KEY_E);await ticks(90)
	verify(door.is_open,"Unlocked lab door cannot reopen from landing")
	# Crossing the portal deliberately opens the completion story and pauses
	# input. Wait for that transition rather than treating it as a collision.
	Input.action_press("move_forward")
	for i in range(180):
		await physics_frame
		if fourth.flag("a11_enter"):break
	Input.action_release("move_forward")
	await ticks(4)
	verify(fourth.flag("a11_enter") and fourth.flag("a11_complete"),"Entering laboratory did not finish the original day-eleven goals")
	dismiss()
	verify(await walk_until("x",2.78,120),"New threshold/door blocked walking into lab after completion story")
	await photo("07_threshold_clear",Vector3(4.5,-2.22,-2.80),Vector3(2.45,-2.30,-2.80),76)
	# Both sides can operate the door, and returning across the seam needs no jump.
	go(Vector3(1.85,-2.68,-2.80),-PI/2);await ticks(8)
	verify(fourth.nearest_item()=="basement","Door cannot be targeted from laboratory side")
	await key(KEY_E);await ticks(90)
	verify(not door.is_open,"E did not close door from inside")
	await key(KEY_E);await ticks(90)
	verify(door.is_open,"E did not reopen door from inside")
	verify(await walk_until("x",4.5,190),"Threshold blocks return to landing")
	verify(absf(game.player.position.y+2.7)<.06,"Doorway floor height changed")
	verify(not day.manager.autosave,"Test wrote a real save")
	print("ENTRY_FIX_PLAYTEST ",JSON.stringify({"checks":checks,"failures":failures}))
	game.stop_audio();game.queue_free();await ticks(3)
	quit(0 if failures.is_empty() else 1)
