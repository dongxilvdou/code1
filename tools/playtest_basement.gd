extends "res://tools/playtest_map_stairs.gd"
## Save-free real CharacterBody traversal, cage interaction and environment checks.
var checks := 0
var capture := false
var lab: Node3D

func verify(ok: bool, message: String) -> void:
	checks += 1
	expect(ok,message)
	if not ok:printerr("BASEMENT_CHECK_FAILED ",message)

func dismiss() -> void:
	var day = game.get_node("DayOne")
	day.dialog = "";day.hud.overlay.hide()
	game.get_node("ActFour").panel.close()
	game.cinematic_active = false;game.player.set_control(true)

func go(pos: Vector3, yaw: float = 0) -> void:
	game.player.position = pos;game.player.velocity = Vector3.ZERO
	game.player.yaw = yaw;game.player.rotation.y = yaw
	game.player.pitch = 0;game.player.head.rotation.x = 0

func photo(name_: String, eye: Vector3, target: Vector3, fov: float = 67) -> void:
	if not capture:return
	game.set_process(false);game.player.set_physics_process(false)
	game.cat_camera.global_position = eye;game.cat_camera.look_at(target)
	game.cat_camera.fov = fov;game.cat_camera.make_current()
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/basement/"+name_+".png")
	game.player.camera.make_current();game.player.set_physics_process(true);game.set_process(true)

func run_tests() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://logs/basement")
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game);current_scene = game
	game.start_game();await ticks(12)
	dismiss()
	lab = game.get_node("Apartment/Basement/MedicalLaboratory")
	map_hud = game.get_node("VillaMap/MapHUD")
	verify(is_instance_valid(lab),"Laboratory scene failed to load")
	verify(game.player.cat_scale==.8 and game.player.collision_layer==2,"Existing cat/controller was modified")
	for cage in get_nodes_in_group("lab_cages"):
		verify(not cage.is_in_group("villa_doors"),"Cage participates in whole-house quest door changes")
		verify(not cage.locked and cage.is_open==cage.starts_open,"Tutorial changed cage's configured state")
	var env: Environment = game.get_node("Apartment/Lighting/VillaEnvironment").environment
	var energy := env.ambient_light_energy
	var original_camera_env: Environment = game.player.camera.environment
	var fourth = game.get_node("ActFour")
	fourth.third.previous.seed_previous_days();fourth.begin_day(11);dismiss()
	fourth.set_value("locks",3);fourth.restore();fourth.mark("a11_enter");fourth.mark("a11_complete")
	await ticks(4)
	# Walk every original stair, then turn through the new 1.3m west opening.
	go(Vector3(5.20,.02,2.20))
	await ticks(10)
	verify(await walk_until("z",-2.80,450),"Basement stair descent blocked: "+str(game.player.position))
	verify(absf(game.player.position.y+2.7)<.06,"Basement floor height changed")
	face(PI/2)
	verify(await walk_until("x",1.5,300),"Landing-to-laboratory doorway obstructed")
	verify(map_hud.current_map=="basement","Minimap not selected underground")
	verify(map_hud.maps.basement.regions.size()==5,"Laboratory map regions missing")
	verify(game.player.camera.environment==lab.basement_environment,"Local basement environment not applied")
	verify(is_equal_approx(env.ambient_light_energy,energy),"Upstairs environment was changed")
	verify(not lab.basement_environment.fog_enabled,"Basement gained unwanted haze")
	await photo("01_laboratory_entrance",Vector3(2.9,-1.35,-2.7),Vector3(-2.25,-1.65,-2.48))
	await photo("02_examination_area",Vector3(2.5,-1.15,-2.25),Vector3(-2.0,-1.7,-4.05),72)
	var cages := get_nodes_in_group("lab_cages")
	verify(cages.size()==3,"Missing observation cages")
	for cage in cages:
		var center: Vector3 = cage.global_position
		var size_: Vector3 = cage.get_meta("dimensions_m")
		verify(size_.is_equal_approx(Vector3(1.14,1.05,1.62)),"Cage not metre-scale")
		cage.set_open(false,true)
		go(center+Vector3(0,.01,-1.35),PI)
		await ticks(8)
		game.update_target()
		verify(game.nearest_door==cage,"Cage E prompt unavailable outside: "+str(cage.name))
		verify(game.ui.hint_label.text.contains("观察笼门"),"Cage has no interaction hint")
		verify(not await walk_until("z",center.z-.2,70),"Closed cage door let cat pass")
		# Opening outward needs a clear door sweep; stand back one cat length.
		go(center+Vector3(0,.01,-2.20),PI);await ticks(5)
		await key(KEY_E);await ticks(90)
		if not cage.is_open or cage.moving:print("CAGE_STATE ",cage.name," open=",cage.is_open," moving=",cage.moving," blocked=",cage.blocked," angle=",cage.leaf.rotation.y)
		verify(cage.is_open and not cage.moving,"E failed to open cage")
		verify(await walk_until("z",center.z+.30,160),"Cat could not enter open cage: "+str(game.player.position))
		verify(absf(game.player.position.y-(center.y+.05))<.045,"Cage tray not walkable")
		# Close from inside, including the same UI/input path as regular room doors.
		face(0);await ticks(4);game.update_target()
		verify(game.nearest_door==cage,"Open cage not interactable from inside")
		await key(KEY_E);await ticks(90)
		verify(not cage.is_open and not cage.moving,"Cage cannot close from inside")
		verify(not await walk_until("z",center.z-1.25,75),"Cat escaped through closed door")
		go(center+Vector3(0,.06,-.25));await ticks(6)
		await key(KEY_E);await ticks(90)
		verify(cage.is_open,"Cage cannot reopen from inside")
		verify(await walk_until("z",center.z-1.4,180),"Cat could not leave cage")
		# Test anti-crush: the closing door must wait for the occupied sweep.
		go(center+Vector3(.13,.01,-1.19),0);await ticks(4)
		cage.set_open(false);await ticks(90)
		verify(cage.blocked and cage.moving,"Cage door did not stop for the cat")
		go(center+Vector3(0,.01,-2.05));await ticks(100)
		verify(not cage.moving and not cage.is_open,"Cage did not resume after obstruction cleared")
	await photo("03_observation_cages",Vector3(-4.45,-1.55,-2.4),Vector3(-1.92,-2.04,.18),70)
	cages[0].set_open(true,true)
	go(cages[0].global_position+Vector3(0,.06,.15),0);await ticks(8)
	await photo("04_cat_in_cage",Vector3(-3.14,-1.97,-1.48),cages[0].global_position+Vector3(0,.22,.1),62)
	# Neither the ceiling nor the three solid cage sides may be crossed.
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for cage in cages:
		var c: Vector3 = cage.global_position+Vector3(0,.35,0)
		for offset in [Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1.1),Vector3(0,1,0)]:
			verify(not space.intersect_ray(PhysicsRayQueryParameters3D.create(c,c+offset,1)).is_empty(),"Missing cage wall/roof collision")
	go(Vector3(1.5,-2.68,-2.8),-PI/2);await ticks(8)
	verify(await walk_until("x",5.2,300),"Laboratory-to-stair return blocked")
	face(PI)
	verify(await walk_until("z",2.15,480),"Return up original basement stairs blocked")
	verify(absf(game.player.position.y)<.08,"Player failed to return to ground floor")
	await ticks(8)
	verify(game.player.camera.environment==original_camera_env,"Player camera environment was not restored")
	verify(game.player.active and not game.cinematic_active,"Basement left player controls disabled")
	verify(not game.get_node("DayOne").manager.autosave,"Test touched player save")
	print("BASEMENT_PLAYTEST ",JSON.stringify({"checks":checks,"failures":failures}))
	game.stop_audio();game.queue_free();await ticks(3)
	quit(0 if failures.is_empty() else 1)
