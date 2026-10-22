extends "res://tools/playtest_map_stairs.gd"
## Isolated save-free integration checks for the day 8–10 revisions.
var checks := 0
var day
var fourth
var capture := false

func verify(ok: bool, message: String) -> void:
	checks+=1
	expect(ok,message)
	if not ok:printerr("ACT4_CHECK_FAILED ",message)

func triangle_count(model: Node3D) -> int:
	var count := 0
	for mesh in model.find_children("*","MeshInstance3D",true,false):count+=mesh.mesh.get_faces().size()/3
	return count

func dismiss4() -> void:
	day.dialog="";day.hud.overlay.hide()
	fourth.panel.close()
	game.cinematic_active=false;game.player.set_control(true)

func read_note() -> void:
	fourth.interact_item("note")
	await key(KEY_E)
	verify(day.Notes.read(day),"Daily note did not unlock this day")

func photo(name_: String, eye: Vector3, target: Vector3) -> void:
	if not capture:return
	game.set_process(false)
	game.player.set_physics_process(false)
	game.cat_camera.global_position=eye
	game.cat_camera.look_at(target)
	game.cat_camera.fov=52
	game.cat_camera.make_current()
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/act4_polish/"+name_+".png")
	game.player.camera.make_current()
	game.player.set_physics_process(true)
	game.set_process(true)

func run_tests() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://logs/act4_polish")
	game=load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled=false
	root.add_child(game);current_scene=game
	game.start_game()
	await ticks(10)
	day=game.get_node("DayOne");fourth=game.get_node("ActFour")
	dismiss4()
	fourth.third.previous.seed_previous_days()
	fourth.begin_day(8)
	dismiss4()
	await read_note()
	var dog=fourth.third.world.dog_actor
	dog.pose_mode="lie"
	await ticks(85)
	verify(dog.kitchen_pose_active and dog.current_pose=="lie","Kitchen dog did not choose the new resting pose")
	var rig: Skeleton3D=dog.skeleton
	var reference: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/pets/kitchen_rest_pose.json")).reference_rest
	var max_rest_error:=0.0
	var source_global: Array[Transform3D] = []
	var joint_scales_ok := true
	var limb_length_error := 0.0
	for i in range(rig.get_bone_count()):
		var entry: Dictionary=reference[rig.get_bone_name(i)]
		var p: Array=entry.position
		var q: Array=entry.rotation
		var t:=Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3])),Vector3(p[0],p[1],p[2]))
		var parent:=rig.get_bone_parent(i)
		source_global.append(source_global[parent]*t if parent>=0 else t)
		max_rest_error=maxf(max_rest_error,rig.get_bone_global_rest(i).origin.distance_to(source_global[i].origin))
		joint_scales_ok = joint_scales_ok and rig.get_bone_pose_scale(i).is_equal_approx(Vector3.ONE)
		if str(rig.get_bone_name(i)).contains("Leg_"):
			limb_length_error=maxf(limb_length_error,absf(dog.kitchen_pose[i].origin.length()-dog.stand_pose[i].origin.length()))
	verify(joint_scales_ok and limb_length_error<.003,"Kitchen pose stretches a leg joint: "+str(limb_length_error))
	verify(max_rest_error<.003,"Blender/Godot retarget reference joints disagree: "+str(max_rest_error))
	await photo("01_kitchen_dog",dog.global_position+Vector3(-1.05,.75,-.95),dog.global_position+Vector3(0,.28,0))
	await photo("01b_kitchen_dog_side",dog.global_position+Vector3(.10,1.15,-1.10),dog.global_position+Vector3(0,.26,0))
	dog.pose_mode="auto"
	dog.react_to_food()
	await ticks(85)
	verify(dog.current_pose=="stand","Feeding reaction can no longer stand up")
	dog.fed_time=0
	await ticks(85)
	verify(dog.current_pose in ["lie","sleep"] and dog.kitchen_pose_active,"Feeding did not blend back into the kitchen resting pose")
	fourth.mark("a8_food")
	fourth.interact_item("valve")
	verify(fourth.panel.mode=="valve" and fourth.panel.display.kind=="valve","Continuous dial cannot open")
	await photo("02_temperature_dial",Vector3(0,3.5,0),Vector3(0,3.4,-1))
	var start: int=fourth.valve_setting()
	var art: Control=fourth.panel.display
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=art.size*.5+Vector2(0,-70)
	art._gui_input(click)
	var motion:=InputEventMouseMotion.new();motion.position=art.size*.5+Vector2(60,-40)
	art._gui_input(motion)
	verify(fourth.valve_setting()>start,"Dragging the dial clockwise did not increase the setting")
	await key(KEY_ESCAPE)
	verify(game.player.active and not fourth.panel.shell.visible,"Esc did not restore control after adjusting the dial")
	for value in [0,44,63,100]:
		fourth.set_value("valve_setting",value)
		fourth.interact_item("wash")
		verify(not fourth.bathing and not fourth.flag("a8_wash"),"Cold/hot water incorrectly passed: "+str(value))
	verify(fourth.world.items.water.running,"Trial water did not produce the new spray")
	await ticks(100)
	verify(not fourth.world.items.water.running,"Trial spray did not stop automatically")
	for value in [45,54,62]:
		fourth.set_value("valve_setting",value)
		verify(fourth.warm_water(),"Warm band boundary incorrectly rejected: "+str(value))
	game.player.global_position=fourth.world.items.wash.global_position+Vector3(0,.025,0)
	game.player.velocity=Vector3.ZERO
	await ticks(10)
	fourth.set_value("valve_setting",54)
	fourth.interact_item("wash")
	await ticks(25)
	verify(fourth.bathing and fourth.world.items.water.running,"Warm water did not begin bathing")
	var spray=fourth.world.items.water
	verify(spray.drops.multimesh.instance_count==420 and spray.ripples.multimesh.instance_count==32,"Droplets/ripples missing")
	var drops_above_tray := true
	for i in range(0,420,20):drops_above_tray=drops_above_tray and spray.drop_positions[i].y>=spray.FLOOR_Y
	verify(drops_above_tray,"Shower droplets pass through the tray")
	var shower: Node3D=fourth.world.shower
	await photo("03_shower_spray",shower.to_global(Vector3(-.60,.48,.68)),shower.to_global(Vector3(0,.65,-.10)))
	await ticks(250)
	verify(fourth.flag("a8_wash") and not spray.running,"Warm bath did not complete or clean up")
	dismiss4()
	fourth.set_value("clock_h",3);fourth.set_value("clock_m",42);fourth.set_value("clock_s",0)
	fourth.solve_clock()
	verify(not fourth.flag("a8_clock"),"Knowing the answer bypassed the three clue notes")
	for id in fourth.CLOCK_CLUES:
		var point: Vector3=fourth.target_position(id)
		game.player.global_position=point+Vector3(.20,.02,.28) if id!="clock_minute_clue" else point+Vector3(0,0,.6)
		game.player.velocity=Vector3.ZERO
		await ticks(5)
		game.player.camera.look_at(point)
		verify(fourth.nearest_item()==id,"Cannot aim at the actual time note: "+id+" got "+fourth.nearest_item())
		fourth.interact_item(id)
		verify(fourth.flag("a8_clue_"+fourth.CLOCK_CLUES[id]),"Note did not record its own hand")
		dismiss4()
	verify(fourth.clock_clue_count()==3,"Clock should require exactly three independent clues")
	var saved: Dictionary=day.manager.make_save_data().duplicate(true)
	verify(day.manager.restore_save_data(saved),"New note/dial state cannot restore")
	fourth.restore()
	verify(fourth.clock_clue_count()==3 and fourth.valve_setting()==54,"Note/dial progress lost on restore")
	fourth.set_value("clock_s",1);fourth.solve_clock()
	verify(not fourth.flag("a8_clock"),"Wrong seconds passed the clock")
	fourth.set_value("clock_s",0);fourth.solve_clock()
	verify(fourth.flag("a8_clock"),"Three clues and correct time did not pass")
	dismiss4()
	fourth.interact_item("nest");dismiss4()
	verify(fourth.today()==9,"Day-eight completion no longer advances")
	await read_note()
	fourth.mark("a9_plants");fourth.restore()
	var mole: Node3D=fourth.world.items.mole
	verify(mole.is_visible_in_tree(),"Mole not visible after arranging the plants")
	verify(fourth.world.mole_actor.visual.find_children("ContinuousFurredBody","MeshInstance3D",true,false).size()==1,"Mole has no continuous upper body")
	verify(fourth.world.mole_actor.visual.find_children("StrongCurvedClaw*","MeshInstance3D",true,false).size()==10,"Mole's digging claws are missing")
	verify(triangle_count(fourth.world.mole_actor.visual)<25000,"Mole exceeds the realtime mesh budget")
	await photo("04_mole_upper_body",mole.global_position+Vector3(.27,.22,-.36),mole.global_position+Vector3(0,.10,-.035))
	fourth.mark("a9_mole");fourth.mark("a9_jigsaw")
	fourth.interact_item("nest");dismiss4()
	verify(fourth.today()==10,"Day-nine completion no longer advances")
	await read_note()
	var mouse: Node3D=fourth.world.items.mouse
	var actor=fourth.world.mouse_actor
	actor.squeak_wait=.01
	await ticks(5)
	verify(triangle_count(actor.visual)<30000,"Mouse exceeds the realtime mesh budget")
	var paws_grounded := true
	for entry in actor.paws:
		var bottom: float=(entry[0].global_transform*entry[0].get_aabb()).position.y
		paws_grounded=paws_grounded and absf(bottom-(mouse.global_position.y-.02))<.004
	verify(paws_grounded,"Idle mouse paws float above the floor")
	verify(actor.squeak_count==1,"Mouse did not emit a spatial squeak")
	await ticks(30)
	verify(actor.squeak_count==1,"Mouse squeaks continuously rather than intermittently")
	fourth.story("Pause sound test")
	var counter: int=actor.squeak_count;actor.squeak_wait=.01
	await ticks(10)
	verify(actor.squeak_count==counter and not actor.enabled,"Mouse sound did not pause for story UI")
	dismiss4()
	await photo("05_house_mouse",mouse.global_position+Vector3(.24,.17,-.31),mouse.global_position+Vector3(0,.06,-.045))
	for stage in range(6):
		fourth.interact_item("mouse")
		var limit:=0
		while not fourth.chase_path.is_empty() and limit<250:
			fourth.advance_mouse(.25);limit+=1
		verify(limit<250 and fourth.val("mouse_stage")==stage+1,"Mouse chase route broken at stage "+str(stage))
	fourth.interact_item("mouse")
	verify(fourth.flag("a10_catch") and not mouse.visible,"Catching did not hide mouse")
	dismiss4()
	await ticks(2)
	verify(not actor.enabled and not actor.sound.playing,"Caught mouse kept squeaking")
	fourth.eat_mouse();dismiss4()
	var paper: Node3D=fourth.world.items.escape_note
	verify(paper.visible,"Escape note was not dropped")
	var floor_top: float=-INF
	for mesh in game.get_node("Apartment/GroundFloor").get_children():
		if mesh is MeshInstance3D and str(mesh.name).begins_with("KitchenFinish"):floor_top=maxf(floor_top,(mesh.global_transform*mesh.get_aabb()).end.y)
	var surface: MeshInstance3D=paper.get_node("DampFoldedPaper")
	var paper_clear := true
	for p in surface.mesh.get_faces():paper_clear=paper_clear and surface.to_global(p).y>floor_top+.003
	verify(paper_clear,"Escape note intersects the visible floor finish")
	await photo("06_escape_note_floor",paper.global_position+Vector3(.25,.22,.30),paper.global_position)
	fourth.interact_item("escape_note");dismiss4()
	verify(fourth.flag("a10_note") and fourth.day_complete(),"Dropped note/mandatory day-ten tasks cannot finish")
	fourth.interact_item("nest");dismiss4()
	verify(fourth.today()==11,"Day-ten completion cannot advance")
	verify(not day.manager.autosave,"Test must never write the user's save")
	print("ACT4_POLISH_TEST ",JSON.stringify({"checks":checks,"failures":failures}))
	game.stop_audio();game.queue_free();await ticks(3)
	quit(0 if failures.is_empty() else 1)
