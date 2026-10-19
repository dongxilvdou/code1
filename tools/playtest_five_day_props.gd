extends "res://tools/playtest_map_stairs.gd"
## Real scenes + quest handlers + physics contacts. Never reads/writes the player's save.
var checks := 0
var day
var second
var chapter
var capture := false

func verify(ok: bool, message: String) -> void:
	checks += 1
	expect(ok,message)
	if not ok:printerr("CHECK_FAILED ",message)

func dismiss() -> void:
	day.dialog = ""
	day.hud.overlay.hide()
	second.puzzle.close()
	chapter.puzzle.close()
	game.cinematic_active = false
	game.player.set_control(true)

func settle(pos: Vector3) -> void:
	game.player.position = pos
	game.player.velocity = Vector3.ZERO
	await ticks(10)

func restored() -> void:
	day.restore_world()
	if chapter.active():chapter.restore()
	await ticks(2)

func read_daily_note() -> void:
	var number: int = day.value("current_day",1)
	if number<=2:
		day.manager.set_flag(StringName(day.Notes.FLAGS[number]),true) # Old versions marked these on opening.
		day.reconcile_progress()
	verify(not day.Notes.read(day),"Day "+str(number)+" unlocked before reading")
	var flags: Dictionary = day.manager.flags.duplicate(true)
	var values: Dictionary = day.manager.values.duplicate(true)
	if number==1:day.perform_interaction("mess_pot")
	elif number==2:second.interact_item("dog_bowl")
	else:chapter.interact_item({3:"book0",4:"dog",5:"medicine"}[number])
	verify(day.manager.flags==flags and day.manager.values==values,"Task mutated before day "+str(number)+" note acknowledgement")
	var reading_position: Vector3 = day.world.items.table.position+Vector3(0,.02,.75)
	if number==1:reading_position = day.SPAWN
	elif number==5:reading_position = Vector3(-4.45,.03,4.80)
	await settle(reading_position)
	game.player.camera.look_at(day.note_target())
	var selected: String = chapter.nearest_item() if number>=3 else second.nearest_item() if number==2 else day.nearest_item()
	if selected!="note":
		var point: Vector3 = day.note_target()
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(game.player.camera.global_position,point,1))
		print("NOTE_DIAGNOSTIC ",number," player=",game.player.active," active=",day.active_play()," cine=",game.cinematic_active," dialog=",day.dialog," pause=",game.ui.pause_panel.visible," puzzle=",second.puzzle.mode," chapter_panel=",chapter.puzzle.mode," pos=",game.player.position," eye=",game.player.camera.global_position," target=",point," hit=",hit.get("position")," collider=",hit.get("collider"))
	verify(selected=="note","Day "+str(number)+" paper cannot be selected at its real location: "+selected)
	await key(KEY_E)
	verify(day.dialog=="note" and not day.Notes.read(day),"Opening paper incorrectly unlocked day "+str(number))
	await key(KEY_ESCAPE)
	verify(not day.Notes.read(day) and game.player.active,"Esc should close paper without unlocking")
	await key(KEY_E)
	await key(KEY_E)
	await ticks(2)
	verify(day.Notes.read(day) and game.player.active,"Acknowledging paper did not unlock day "+str(number))

func aim_check(id: String, position_: Vector3) -> void:
	await settle(position_)
	game.player.camera.look_at(chapter.target_position(id))
	verify(chapter.nearest_item()==id,"Real camera/ray cannot select "+id+"; selected "+chapter.nearest_item())

func jump_to(destination: Vector3) -> bool:
	if "--trace" in OS.get_cmdline_user_args():print("JUMP_FROM ",game.player.position," TO ",destination," radius ",game.player.collider.shape.radius)
	var direction: Vector3 = destination-game.player.global_position
	direction.y = 0
	face(atan2(-direction.x,-direction.z))
	Input.action_press("jump")
	Input.action_press("move_forward")
	for frame in range(95):
		await physics_frame
		if "--trace" in OS.get_cmdline_user_args() and frame%8==0:print("TRACE ",frame," ",game.player.position," velocity ",game.player.velocity," floor ",game.player.is_on_floor())
		if "--trace" in OS.get_cmdline_user_args() and not game.player.is_on_floor():
			for j in range(game.player.get_slide_collision_count()):print("HIT ",game.player.get_slide_collision(j).get_collider().get_path()," ",game.player.get_slide_collision(j).get_normal())
		var delta: Vector3 = destination-game.player.global_position
		delta.y = 0
		if delta.dot(direction.normalized())<.19:Input.action_release("move_forward")
		if frame==30:Input.action_release("jump")
		if frame>6 and game.player.is_on_floor():
			Input.action_release("jump")
			Input.action_release("move_forward")
			await ticks(8)
			return absf(game.player.position.y-destination.y)<.07
	Input.action_release("jump")
	Input.action_release("move_forward")
	return false

func photograph(name_: String, eye: Vector3, at: Vector3) -> void:
	if not capture:return
	game.player.set_physics_process(false)
	game.set_process(false)
	day.hud.hide()
	game.ui.hud.hide()
	game.get_node("QuestSystem").tracker.hide()
	game.get_node("VillaMap/MapHUD").hide()
	game.cat_camera.make_current()
	game.cat_camera.fov = 55
	game.cat_camera.global_position = eye
	game.cat_camera.look_at(at)
	for i in range(10):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/five_day_props/"+name_+".png")
	game.player.set_physics_process(true)
	game.set_process(true)
	game.player.camera.make_current()

func feed_dog() -> void:
	if chapter.active():
		chapter.interact_item("dog_bowl")
		chapter.interact_item("feeder")
		chapter.interact_item("dog_spot")
	else:
		second.interact_item("dog_bowl")
		second.interact_item("feeder")
		second.interact_item("dog_spot")
	dismiss()

func verify_yarn_contact(label_: String) -> void:
	var yarn: Node3D = day.world.items.yarn
	var ball: MeshInstance3D = yarn.find_children("*","MeshInstance3D",true,false)[0]
	var bed: MeshInstance3D = day.world.items.nest.find_children("*","MeshInstance3D",true,false)[0]
	var bottom: float = (ball.global_transform*ball.get_aabb()).position.y
	var origin: Vector3 = yarn.global_position+Vector3.UP*.4
	var support := -INF
	var faces := bed.mesh.get_faces()
	for i in range(0,faces.size(),3):
		var hit = Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,bed.to_global(faces[i]),bed.to_global(faces[i+1]),bed.to_global(faces[i+2]))
		if hit!=null:support = maxf(support,hit.y)
	# Allow a soft cushion to cradle the ball, but no visible air gap above it.
	verify(support>-INF and bottom-support<=.002 and bottom-support>=-.012,label_+": yarn must touch the real cushion mesh; bottom="+str(bottom)+", cushion="+str(support))

func verify_returned_toy_dialogue() -> void:
	# Exercise the optional fourth-day route, then restore it so the existing
	# unfinished-toy route across the day boundary is still tested below.
	var before: Dictionary = day.manager.make_save_data().duplicate(true)
	chapter.interact_item("dog")
	dismiss()
	chapter.interact_item("yarn")
	verify(chapter.puzzle.mode=="yarn","Day-four toy puzzle cannot open after the dog's request")
	chapter.solved("yarn")
	dismiss()
	chapter.interact_item("dog")
	verify(chapter.puzzle.description.text.contains("D-017") and not chapter.puzzle.description.text.contains("毛线球"),"Solved yarn should direct the player to the exposed bone")
	dismiss()
	chapter.interact_item("bone")
	dismiss()
	chapter.interact_item("dog")
	verify(chapter.flag("a4_toy") and chapter.val("a_holding")==0,"Bone handoff did not finish the toy quest")
	dismiss()
	chapter.interact_item("dog")
	verify(chapter.puzzle.description.text.contains("已经找回") and not chapter.puzzle.description.text.contains("玩具丢了"),"Dog still asks for its toy after receiving the bone")
	dismiss()
	var completed: Dictionary = day.manager.make_save_data().duplicate(true)
	verify(day.manager.restore_save_data(completed),"Completed toy save cannot restore")
	await restored()
	chapter.interact_item("dog")
	verify(chapter.puzzle.description.text.contains("已经找回"),"Reloaded completed toy quest repeats the missing-toy dialogue")
	dismiss()
	chapter.interact_item("half_fish")
	chapter.interact_item("dog")
	verify(chapter.flag("a4_share") and chapter.flag("a4_toy"),"Sharing fish after the toy handoff lost quest progress")
	verify(chapter.puzzle.description.text.contains("已经找回") and not chapter.puzzle.description.text.contains("玩具不见了"),"Sharing fish after returning the bone asks for the missing toy again")
	dismiss()
	verify(day.manager.restore_save_data(before),"Optional route checkpoint cannot restore")
	await restored()
	verify(not chapter.flag("a4_toy") and not chapter.flag("yarn_solved"),"Optional cross-day route checkpoint was not restored")

func run_tests() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://logs/five_day_props")
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game)
	current_scene = game
	await ticks(8)
	game.start_game()
	await ticks(8)
	day = game.get_node("DayOne")
	second = game.get_node("DayTwo")
	chapter = game.get_node("ActTwo")
	dismiss()
	await read_daily_note()
	verify(day.manager.definitions.size()==20,"Existing quest catalog must retain all twenty quests")
	verify(day.world.items.table.get_meta("bound_furniture").get_meta("asset_id")=="coffee_table","Day-one table is not the existing coffee table")
	verify(day.world.items.stool.get_meta("bound_furniture").get_meta("asset_id")=="armchair","Day-one jump target is not the existing armchair")
	verify(not day.world.items.table.has_node("Tabletop"),"Duplicate tutorial table survived")
	await photograph("01_day1_coffee_table",Vector3(-2.8,.97,3.35),Vector3(-3.43,.51,2.0))
	for key_ in ["walk","run","open_living"]:day.mark(key_)
	await restored()
	await settle(day.world.items.stool.position+Vector3(0,.52,0))
	verify(day.flag("stool"),"Actual armchair seat fails the day-one jump objective: "+str(game.player.position))
	await settle(day.world.items.table.position+Vector3(0,.49,0))
	verify(day.flag("table"),"Actual coffee table fails the day-one jump objective")
	day.perform_interaction("cup")
	verify(day.value("holding")==1,"Ceramic mug cannot be picked up")
	day.perform_interaction("tray")
	verify(day.flag("cup_moved"),"Coaster placement cannot complete")
	day.perform_interaction("note")
	dismiss()
	verify(day.flag("note_read"),"Paper interaction regressed")
	day.mark("light_off") # Existing physical TV/balance jump is independently regression tested.
	await restored()
	for data in day.world.PAPER_SPOTS:day.perform_interaction("paper_"+data[0])
	verify(day.paper_count()==4 and day.flag("papers_done"),"Four first-floor scraps cannot complete")
	second.solve_puzzle("code")
	dismiss()
	second.interact_item("cat_bowl")
	second.interact_item("feeder")
	second.interact_item("cat_spot")
	feed_dog()
	verify(day.feeding_done(),"Existing dual-bowl feeding cannot finish")
	second.begin_day()
	dismiss()
	await restored()
	verify(day.value("current_day")==2,"Cannot begin day two")
	await read_daily_note()
	await settle(Vector3(-4.20,.03,1.9))
	game.player.camera.look_at(second.target_position("cloth_sofa"))
	verify(second.nearest_item()=="cloth_sofa","Sofa garment cannot be selected from floor level")
	await photograph("01b_day2_visible_clothing",Vector3(-3.98,.43,2.33),second.target_position("cloth_sofa"))
	for id in ["cup","tray","paper_living","paper_dining","paper_kitchen","paper_study1"]:verify(not day.world.items[id].visible,"Retired day-one prop remains: "+id)
	second.interact_item("note")
	day.advance_dialog()
	dismiss()
	second.interact_item("washer_door")
	for id in second.CLOTHES:
		second.interact_item(id)
		dismiss()
		second.interact_item("washer_door")
	second.interact_item("washer_door")
	verify(second.loaded_count()==3,"Detailed shirts cannot be loaded")
	var washer: Node3D = second.world.washer_selector.get_parent()
	await settle(washer.global_position+Vector3(0,.88,0))
	second.interact_item("washer_dial")
	verify(second.puzzle.mode=="wash","Existing washing-machine selector cannot open its puzzle")
	second.solve_puzzle("wash")
	second.advance_time(4.1)
	dismiss()
	verify(day.flag("d2_washed"),"Laundry cannot complete")
	day.perform_interaction("ruler")
	day.manager.set_value(&"ruler_vertical",1)
	day.perform_interaction("sofa_gap")
	day.perform_interaction("yarn")
	day.perform_interaction("nest")
	dismiss()
	verify(day.flag("yarn_home"),"Original drafting-kit ruler cannot retrieve the ball")
	verify_yarn_contact("After returning the yarn")
	var yarn_save: Dictionary = day.manager.make_save_data().duplicate(true)
	verify(day.manager.restore_save_data(yarn_save),"Returned yarn save cannot restore")
	await restored()
	verify_yarn_contact("After restoring the returned yarn")
	await photograph("01c_day2_yarn_in_bed",Vector3(-4.40,.55,5.48),day.world.items.nest.global_position+Vector3(0,.12,0))
	second.interact_item("dog_bowl")
	second.interact_item("tap")
	verify(second.val("dish_stage")==1 and second.world.stream.visible,"Actual faucet did not start rinsing")
	second.advance_time(4.1)
	second.interact_item("dog_bowl")
	second.interact_item("dog_spot")
	dismiss()
	verify(day.flag("d2_dishes_done") and second.val("dish_stage")==9,"Simplified dog-plate wash cannot complete")
	second.interact_item("nest")
	dismiss()
	await restored()
	verify(chapter.today()==3,"Cannot advance from day two to day three")
	await read_daily_note()
	for book in chapter.world.original_bookcase.get_children():
		var color_index: int = book.get_meta("shelf_color",-1)
		if color_index>=0:verify(book.get_meta("quest_model")==["book_red","book_blue","book_gold"][color_index],"Book row colour is incorrect")
	verify(not day.world.items.ruler.visible,"Day-two ruler was not put away")
	for id in second.CLOTHES:verify(not second.world.items[id].visible,"Old laundry remains in room")
	verify(not second.get_node("WashStep").visible,"Temporary laundry step was not put away")
	for body in second.get_node("WashStep").find_children("*","StaticBody3D",true,false):verify(body.collision_layer==0,"Hidden day-two stool still blocks")
	verify(chapter.world.original_bookcase.visible,"Original bookcase disappears on day three")
	verify(chapter.world.items.oven.get_meta("bound_furniture").get_meta("asset_id")=="cooker","Oven task is not bound to the real kitchen range")
	verify(chapter.world.items.plant.get_meta("bound_furniture").get_meta("asset_id")=="decor_plant","Watering task does not reuse the real plant")
	verify(not chapter.world.items.medicine.visible and not chapter.world.items.fish.visible,"Future props leak into day three")
	await photograph("02_day3_bookcase",Vector3(-3.6,1.37,.45),Vector3(-1.22,.88,-1.1))
	await settle(chapter.world.shelves[0]+Vector3(-.55,-chapter.world.shelves[0].y+.03,0))
	for i in range(3):
		verify(await jump_to(chapter.world.shelves[i]),"Bookcase cannot be climbed using real jump input at level "+str(i)+" / "+str(game.player.position))
		if absf(game.player.position.y-chapter.world.shelves[i].y)>.07:await settle(chapter.world.shelves[i]+Vector3(0,.025,0))
	for i in range(3):
		chapter.interact_item("book%d"%i)
		verify(chapter.val("a_holding")==i+1,"Detailed book cannot be carried")
		if i==1:
			var mid: Dictionary = day.manager.make_save_data().duplicate(true)
			chapter.set_value("a_holding",0)
			verify(day.manager.restore_save_data(mid),"Partial day-three save cannot reload")
			chapter.restore()
			verify(chapter.val("a_holding")==2 and is_instance_valid(chapter.held_visual),"Carried book lost after partial save reload")
		await settle(chapter.world.shelves[i]+Vector3(0,.025,0))
		verify(game.player.is_on_floor() and absf(game.player.position.y-chapter.world.shelves[i].y)<.10,"Actual bookcase ledge cannot support the cat: "+str(i)+" at "+str(game.player.position))
		game.player.camera.look_at(chapter.target_position("shelf%d"%i))
		verify(chapter.nearest_item()=="shelf%d"%i,"Looking at coloured book row does not select its return slot")
		await key(KEY_E)
		verify(chapter.flag("book%d"%i),"Return to actual bookcase failed: "+str(i))
	verify(chapter.flag("a3_books"),"Day-three bookcase task cannot complete")
	chapter.interact_item("photo")
	dismiss()
	await aim_check("cabinet",Vector3(1.98,.02,-4.65))
	chapter.interact_item("cabinet")
	verify(chapter.flag("cabinet_open"),"Existing sink cabinet doors cannot open")
	await aim_check("pipes",Vector3(1.98,.02,-4.72))
	chapter.interact_item("pipes")
	verify(chapter.puzzle.mode=="pipes","Plumbing puzzle cannot open")
	chapter.solved("pipes")
	dismiss()
	await photograph("03_day3_sink",Vector3(1.42,.59,-4.32),Vector3(1.98,.42,-5.25))
	await settle(chapter.world.items.can.position+Vector3(.60,-chapter.world.items.can.position.y+.02,0))
	verify(await jump_to(chapter.world.items.can.position),"Existing cat-tree perch cannot be reached for watering-can pickup")
	chapter.interact_item("can")
	verify(chapter.val("a_holding")==4 and game.player.jump_locked,"Full watering can must temporarily lock jumping")
	chapter.interact_item("drain")
	verify(chapter.flag("water_halved") and not game.player.jump_locked,"Real shower drain did not lighten the can")
	await aim_check("plant",Vector3(-5.22,.57,2.60))
	chapter.interact_item("plant")
	verify(chapter.puzzle.mode=="aim","Existing plant cannot open the watering task")
	await ticks(3)
	var watering = chapter.puzzle.watering
	verify(is_instance_valid(watering) and watering.viewport.own_world_3d,"Watering preview is not a live 3D scene")
	verify(watering.stage.has_node("RealHousePlant"),"Watering preview does not reuse the house plant")
	var target: Vector2 = watering.soil_screen_position()
	# parse_input_event expects native window pixels, including stretch/letterbox.
	var mouse_position: Vector2 = root.get_final_transform()*(watering.get_global_transform_with_canvas()*target)
	var motion := InputEventMouseMotion.new()
	motion.position = mouse_position
	motion.global_position = mouse_position
	Input.parse_input_event(motion)
	# Native windows poll the OS cursor; event injection alone only moves the dummy
	# headless cursor. Keep the interaction check at the actual projected pot opening.
	var previous_mouse: Vector2 = root.get_mouse_position()
	if DisplayServer.get_name()!="headless":
		root.warp_mouse(watering.get_global_transform_with_canvas()*target)
		await ticks(2)
	var click := InputEventMouseButton.new()
	click.position = mouse_position
	click.global_position = mouse_position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await ticks(6)
	if chapter.aim_progress<=0 or not watering.pouring:print("WATER_INPUT_DIAGNOSTIC expected=",target," local=",watering.get_local_mouse_position()," injected=",mouse_position," pressed=",Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)," hit=",watering.on_target," size=",watering.size)
	verify(chapter.aim_progress>0 and watering.pouring,"Real mouse hold over the 3D pot did not start watering")
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	if DisplayServer.get_name()!="headless":root.warp_mouse(previous_mouse)
	chapter.puzzle.set_process(false) # Deterministic held-input samples while the 3D water keeps animating.
	chapter.puzzle.pour_at(target,true,.2)
	await ticks(3)
	verify(watering.jets.size()==5 and watering.drops.multimesh.instance_count==120,"Water spray/droplets missing")
	verify(day.value("a_holding")==4 and watering.pouring,"Pouring did not retain the water can")
	await photograph("03b_day3_real_water",Vector3(-5.22,.8,2.6),Vector3(-5.35,.4,3.12))
	chapter.puzzle.pour_at(target,true,2.5)
	chapter.puzzle.set_process(true)
	dismiss()
	feed_dog()
	verify(chapter.day_complete(),"Day-three required tasks cannot all complete")
	await photograph("04_day3_completed_bookcase",Vector3(-2.72,1.14,-.2),Vector3(-1.22,.94,-1.14))
	chapter.interact_item("nest")
	dismiss()
	await restored()
	verify(chapter.today()==4,"Cannot advance to day four")
	await read_daily_note()
	for id in ["can","drain","pipes","camera","photo","plant","shelf0","shelf1","shelf2"]:verify(not chapter.world.items[id].visible,"Retired day-three prop/target remains: "+id)
	verify(chapter.world.items.plant.get_meta("bound_furniture").visible,"Retiring the watering target hid the real plant")
	verify(chapter.world.items.book0.visible,"Returned books must stay on the real bookcase")
	verify(not chapter.world.Props.interactable(chapter.world.items.book0,4),"Returned books remain incorrectly pickable on day four")
	await settle(day.world.items.table.position+Vector3(0,.49,0))
	verify(chapter.flag("a4_bell"),"Actual coffee table cannot trigger the day-four doorbell")
	dismiss()
	for i in range(3):chapter.interact_item("mailbox")
	chapter.interact_item("letter")
	dismiss()
	verify(chapter.flag("a4_letter"),"New mailbox and letter cannot complete")
	await settle(Vector3(4.12,.95,-5.40))
	game.player.camera.look_at(chapter.target_position("fridge_lock"))
	verify(chapter.nearest_item()=="fridge_lock","Real counter view cannot select refrigerator lock")
	chapter.interact_item("fridge_lock")
	verify(chapter.puzzle.mode=="slide","Existing refrigerator puzzle cannot open")
	chapter.solved("slide")
	dismiss()
	await photograph("05a_day4_pixel_fish",Vector3(5.13,.99,-4.64),chapter.world.fish_home)
	await aim_check("fish",Vector3(5.13,.02,-4.55))
	chapter.interact_item("fish")
	verify(chapter.val("a_holding")==5,"Detailed fish cannot be removed from refrigerator")
	await aim_check("oven",Vector3(.63,.02,-4.45))
	chapter.interact_item("oven")
	verify(chapter.val("cook_state")==1 and chapter.val("a_holding")==0,"Actual range oven cannot accept fish")
	chapter.interact_item("oven")
	verify(chapter.val("cook_state")==2 and chapter.world.oven_glow.light_energy>0,"Actual range oven cannot start cooking")
	await photograph("05_day4_real_oven",Vector3(1.25,.74,-4.49),Vector3(.63,.47,-5.30))
	chapter._physics_process(6.1)
	dismiss()
	verify(chapter.flag("a4_cook"),"Real oven cooking cannot complete")
	await photograph("05b_day4_pixel_half_fish",Vector3(3.12,1.25,-4.91),chapter.world.items.half_fish.position)
	await verify_returned_toy_dialogue()
	chapter.interact_item("half_fish")
	chapter.interact_item("dog")
	dismiss()
	verify(chapter.flag("a4_share"),"Cooked fish cannot be shared")
	verify(chapter.world.items.yarn==day.world.items.yarn,"Day-four yarn ball must reuse the exact day-two object")
	# Keep the optional toy unfinished across the day boundary, an important existing story route.
	verify(chapter.day_complete(),"Day-four mandatory tasks cannot complete")
	chapter.interact_item("nest")
	dismiss()
	await restored()
	verify(chapter.today()==5,"Cannot advance to day five")
	verify(day.world.items.note.visible and day.world.items.note.position.distance_to(Vector3(-4.30,.018,4.32))<.01,"Day-five paper is not beside the cat bed")
	await photograph("07_day5_paper_by_bed",Vector3(-3.85,.63,4.84),day.world.items.note.position)
	await read_daily_note()
	for id in ["letter","fish","oven","fridge_lock"]:verify(not chapter.world.items[id].visible,"Retired day-four target remains: "+id)
	verify(chapter.world.items.yarn.visible,"Optional toy route was removed at day change")
	verify(chapter.world.items.medicine.visible,"Day-five medication not spawned")
	await photograph("06_day5_medicines",Vector3(-3.08,.92,2.89),Vector3(-3.40,.55,2.02))
	chapter.interact_item("medicine")
	chapter.puzzle.selected = [1,3,5]
	chapter.puzzle.check_medicine()
	verify(chapter.val("a_holding")==8,"Seven labeled bottles cannot supply the selected three")
	verify(chapter.held_visual.find_children("Visual_medicine*","Node3D",true,false).filter(func(n):return n.visible).size()==3,"Carried medication does not show exactly the three selected bottles")
	chapter.interact_item("dog")
	dismiss()
	chapter.interact_item("dog_bowl")
	verify(chapter.flag("medicine_mixed"),"Selected medication cannot be mixed into the existing dog bowl")
	feed_dog()
	verify(chapter.flag("a5_medicine"),"Day-five feeding/medication cannot complete")
	chapter.interact_item("yarn")
	verify(chapter.puzzle.mode=="yarn","Optional toy puzzle lost across day four/five")
	chapter.solved("yarn")
	dismiss()
	chapter.interact_item("bone")
	dismiss()
	chapter.interact_item("dog")
	dismiss()
	verify(chapter.flag("a4_toy"),"Engraved chew toy cannot be returned on day five")
	chapter.interact_item("dog")
	chapter.puzzle.sequence = [0]
	chapter.puzzle.add_voice(3,true)
	dismiss()
	verify(chapter.flag("a5_name") and chapter.day_complete(),"Name story/day-five completion regressed")
	# Restore an in-progress snapshot without touching user://. Supports earlier-day saves too.
	var snapshot: Dictionary = day.manager.make_save_data()
	verify(day.manager.restore_save_data(snapshot),"Save data cannot round-trip after prop replacement")
	await restored()
	verify(not game.player.jump_locked and game.player.active,"Prop lifecycle left movement disabled")
	verify(not day.manager.autosave,"Regression test must not enable player's autosave")
	print("FIVE_DAY_PROPS_TEST ",JSON.stringify({"checks":checks,"failures":failures,"day":chapter.today(),"catalog":day.manager.definitions.size()}))
	game.stop_audio()
	game.queue_free()
	await ticks(3)
	quit(0 if failures.is_empty() else 1)

