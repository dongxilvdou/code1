extends "res://tools/playtest_map_stairs.gd"
## Real controller + supplied skeletons + occupied half-landing regression.
var checks := 0
func verify(ok: bool, label: String) -> void:
	checks += 1
	expect(ok,label)
func run_tests() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	# Isolate locomotion from the newly added first/second-day story dialogs.
	for name in ["DayOne","DayTwo"]:game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	game.start_game()
	map_hud = game.get_node("VillaMap/MapHUD")
	await ticks(8)
	var cat: Node = game.player.model
	verify(cat.skeleton.get_bone_count()==39,"New cat skeleton not installed")
	for clip in ["idle","walk","run","crouch","jump","stretch","sit","tailwag","meow"]:verify(cat.clips.has(clip),"Missing cat clip "+clip)
	for mesh in cat.visuals.find_children("*","MeshInstance3D",true,false):
		verify(mesh.skin!=null,"Unbound new cat mesh: "+str(mesh.name))
		verify(mesh.layers==2,"Cat body leaked into first-person view")
	var nest: Node3D = game.get_node("Apartment/Staircase/DogNest")
	verify(absf(nest.position.y-1.5)<.001,"Dog nest is not on half landing")
	var dog: Node3D = nest.get_node("Dog")
	var ds: Skeleton3D = dog.find_children("*","Skeleton3D",true,false)[0]
	var cat_shoulder: float = cat.skeleton.get_bone_global_rest(cat.skeleton.find_bone("Wolf_Spine_TopSHJnt")).origin.y*game.player.cat_scale
	var dog_shoulder: float = ds.get_bone_global_rest(ds.find_bone("Dog_Spine_TopSHJnt")).origin.y*dog.scale.y
	verify(absf(dog_shoulder/cat_shoulder-2)<.01,"Dog is not twice cat's reference shoulder height")
	verify(ds.get_bone_count()==45,"Supplied dog skeleton missing")
	verify(dog.find_children("*","AnimationPlayer",true,false)[0].is_playing(),"Dog resting animation not running")
	game.player.position = Vector3(-8,.02,8)
	await ticks(30)
	var walking_start: Vector3 = game.player.position
	Input.action_press("move_forward")
	await ticks(25)
	await process_frame
	verify(cat.last_state=="walk" and game.player.position.distance_to(walking_start)>.2,"Actual walking did not drive new clip")
	Input.action_press("sprint")
	await ticks(25)
	await process_frame
	verify(cat.last_state=="run","Actual sprinting did not drive new clip")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	game.player.velocity = Vector3.ZERO
	game.player.position = Vector3(-8,.02,8)
	await ticks(30)
	var start_y: float = game.player.position.y
	Input.action_press("jump")
	var peak := start_y
	var paw_seen := false
	for i in range(70):
		await physics_frame
		if i==2:Input.action_release("jump")
		peak = maxf(peak,game.player.position.y)
		if game.player.paws[0].visible:paw_seen = true
	verify(paw_seen,"New first-person paws never appeared in flight")
	verify(peak-start_y>.80 and peak-start_y<1.02,"Jump height outside reduced range: "+str(peak-start_y))
	verify(game.player.is_on_floor(),"Jump did not land")
	verify(game.player.paws.size()==1 and game.player.paws[0].first_person,"Old static paws remain active")
	verify(not game.player.paws[0].visible,"Jump paws stayed visible after landing")
	Input.action_press("crouch")
	await ticks(20)
	verify(cat.crouching and cat.last_state=="crouch","Crouch not connected")
	Input.action_release("crouch")
	await ticks(10)
	await key(KEY_Q)
	verify(cat.meow_time>0,"Meow no longer reaches new model")
	await ticks(60)
	await key(KEY_V)
	verify(game.photo and game.cat_camera.current and game.player.active,"Third-person switch failed")
	await key(KEY_V)
	verify(not game.photo and game.player.camera.current,"First-person return failed")
	# Existing up/down route passes directly in front of the occupied bed.
	place(10,8,.02,0)
	await ticks(10)
	var crossing: float = game.get_node("Apartment/Staircase").get_meta("landing_crossing_z",4.40)
	verify(await walk_until("z",crossing-6,420),"Bed blocks ascending west flight")
	face(-PI/2)
	verify(await walk_until("x",11.20-6,180),"Bed blocks landing turn toward east flight")
	face(PI)
	verify(await walk_until("z",8.02-6,420),"Upper flight blocked")
	face(0)
	verify(await walk_until("z",crossing-6,420),"Bed blocks descending east flight")
	face(PI/2)
	verify(await walk_until("x",10.0-6,180),"Bed blocks descending landing turn")
	face(PI)
	verify(await walk_until("z",8.02-6,420),"Lower return flight blocked")
	print("IMPORTED_PETS_TEST ",JSON.stringify({"checks":checks,"jump_height_m":peak-start_y,"cat_shoulder_m":cat_shoulder,"dog_shoulder_m":dog_shoulder,"failures":failures}))
	game.stop_audio()
	game.queue_free()
	await ticks(3)
	quit(0 if failures.is_empty() else 1)
