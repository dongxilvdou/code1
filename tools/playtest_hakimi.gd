extends "res://tools/playtest_map_stairs.gd"
var checks := 0
var max_cat_joint_error := 0.0
func verify(ok: bool, label: String) -> void:
	checks += 1
	expect(ok,label)

func cat_tests() -> void:
	var cat = load("res://scenes/calico.tscn").instantiate()
	root.add_child(cat)
	cat.animate = false
	var skeleton: Skeleton3D = cat.skeleton
	for clip in cat.clips:
		cat.animation_player.play(cat.clips[clip],0)
		for frame in range(41):
			cat.animation_player.seek(cat.animation_player.current_animation_length*frame/40.0,true)
			skeleton.force_update_all_bone_transforms()
			for bone in range(skeleton.get_bone_count()):
				var posed := skeleton.get_bone_global_pose(bone)
				verify(posed.is_finite(),"non-finite cat skeleton "+clip)
				var parent := skeleton.get_bone_parent(bone)
				if parent<0 or "ROOT" in skeleton.get_bone_name(bone):continue
				var actual := posed.origin.distance_to(skeleton.get_bone_global_pose(parent).origin)
				var rest := skeleton.get_bone_global_rest(bone).origin.distance_to(skeleton.get_bone_global_rest(parent).origin)
				max_cat_joint_error = maxf(max_cat_joint_error,absf(actual-rest))
	verify(max_cat_joint_error<.0001,"cat limb length changes "+str(max_cat_joint_error))
	cat.preview_pose = "idle"
	cat.animate = true
	cat.curious = 1
	for frame in range(600):cat._process(1.0/60)
	verify(cat.skeleton.get_bone_pose_rotation(cat.head_bone).angle_to(cat.head_base)<.112,"look additive accumulated")
	var base: Quaternion = cat.head_base
	cat.curious = 0
	cat._process(0)
	verify(cat.skeleton.get_bone_pose_rotation(cat.head_bone).angle_to(base)<.001,"look offset did not restore")
	cat.free()

func aim_at(target: Vector3) -> void:
	game.player.camera.look_at(target)
	await ticks(3)

func run_tests() -> void:
	cat_tests()
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game)
	current_scene = game
	map_hud = game.get_node("VillaMap/MapHUD")
	await ticks(8)
	verify(ProjectSettings.get_setting("application/config/name")=="哈基米模拟器","game name")
	game.request_start_game(true)
	await ticks(1740)
	var day = game.get_node("DayOne")
	var second = game.get_node("DayTwo")
	verify(not game.opening.active and game.opening.finish_count==1,"intro did not end once")
	verify(day.dialog=="intro","intro did not enter story")
	await key(KEY_ESCAPE)
	verify(game.player.active,"intro did not restore input")
	for flag in ["walk","run","open_living","stool","table","cup_moved","note_read","light_off","papers_done","d2_started","d2_unlocked","d2_cat_fed","d2_dog_fed","d2_note","d2_washed","d2_cloth_sofa","d2_cloth_chair","d2_cloth_entry","ruler_found","yarn_freed","yarn_home"]:day.manager.set_flag(StringName(flag),true)
	day.manager.set_value(&"current_day",2)
	day.manager.set_value(&"dish_stage",0)
	second.reconcile()
	day.restore_world()
	await ticks(8)
	verify(second.dishes_available(),"dish quest prerequisite lost")
	verify(not second.world.items.has("soap") and not second.world.items.has("drying") and not second.world.items.has("sink"),"old dish steps still present")
	verify(second.world.items.tap.find_children("*","MeshInstance3D",true,false).is_empty(),"separate tap button remains")
	verify(second.world.items.dog_bowl.position.distance_to(second.world.dog_home)<.001,"bowl not beside dog")
	var saved: Dictionary = day.manager.make_save_data()
	saved.values.cleanliness = 47
	verify(day.manager.restore_save_data(saved) and not day.manager.values.has("cleanliness"),"old cleanliness persists")
	day.perform_interaction("mess_cup")
	verify(not day.manager.values.has("cleanliness"),"pushing prop still scores cleanliness")
	day.refresh_hud()
	verify(not day.hud.status.text.contains("整洁"),"cleanliness UI remains")
	# Pick up the real bowl at its new home, using the existing E input routing.
	game.player.position = Vector3(3.85,1.51,-.90)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = 0
	game.player.rotation.y = 0
	await ticks(8)
	await aim_at(second.target_position("dog_bowl"))
	verify(second.nearest_item()=="dog_bowl","cannot target plate by dog: "+second.nearest_item())
	await key(KEY_E)
	verify(second.val("d2_holding")==5,"E did not pick up plate")
	# Reach the actual faucet from the existing countertop, with no proxy button.
	game.player.position = Vector3(1.64,.92,-5.10)
	game.player.velocity = Vector3.ZERO
	await ticks(8)
	await aim_at(second.target_position("tap"))
	verify(second.nearest_item()=="tap","real faucet not accessible: "+second.nearest_item())
	await key(KEY_E)
	verify(second.val("dish_stage")==1 and second.val("d2_holding")==0,"faucet did not begin washing")
	verify(second.world.stream.visible and second.world.stream.droplets.emitting,"water effects did not start")
	var basin: Vector3 = second.world.basin_position
	var clear: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(basin+Vector3.UP*.35,basin+Vector3.UP*.074,1))
	verify(clear.is_empty(),"cabinet shelf covers the bowl")
	await ticks(70)
	var before_pause: float = second.dish_clock
	await key(KEY_ESCAPE)
	await ticks(70)
	verify(absf(second.dish_clock-before_pause)<.05,"washing progressed while paused")
	await key(KEY_ESCAPE)
	await ticks(240)
	verify(second.val("dish_stage")==8 and not second.world.stream.visible,"wash did not finish / tap did not close")
	verify(not second.world.stains.visible,"clean plate still stained")
	await aim_at(second.target_position("dog_bowl"))
	verify(second.nearest_item()=="dog_bowl","clean plate not reachable in basin: "+second.nearest_item())
	await key(KEY_E)
	verify(second.val("d2_holding")==5,"could not pick up clean plate")
	game.player.position = Vector3(3.85,1.51,-.90)
	game.player.velocity = Vector3.ZERO
	await ticks(8)
	await aim_at(second.target_position("dog_spot"))
	verify(second.nearest_item()=="dog_spot","cannot target fixed plate home: "+second.nearest_item())
	await key(KEY_E)
	verify(second.val("dish_stage")==9 and second.flag("d2_dishes_done"),"returning bowl did not complete task")
	verify(second.world.items.dog_bowl.position.distance_to(second.world.dog_home)<.001,"finished bowl not at dog")
	if not second.puzzle.mode.is_empty():await key(KEY_ESCAPE)
	verify(game.player.active,"completion dialog trapped controls")
	# Old saves resume their interrupted wash and preserve completed dishes.
	for stage in [1,3,6,7,8,9]:
		day.manager.values["dish_flow_version"] = 1
		day.manager.values["dish_stage"] = stage
		second.reconcile()
		verify(second.val("dish_stage")== (1 if stage<7 else 8 if stage<9 else 9),"dish save migration "+str(stage))
	verify(not day.manager.autosave,"tests touched user save")
	print("HAKIMI_TEST ",JSON.stringify({"checks":checks,"max_cat_joint_error_m":max_cat_joint_error,"full_intro_and_real_dish_inputs":true,"failures":failures}))
	game.stop_audio()
	game.queue_free()
	await ticks(3)
	quit(0 if failures.is_empty() else 1)
