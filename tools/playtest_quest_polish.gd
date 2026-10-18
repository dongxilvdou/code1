extends "res://tools/playtest_map_stairs.gd"
var checks := 0
func verify(ok: bool, label: String) -> void:
	checks += 1
	expect(ok,label)

func migration_tests() -> void:
	var m := CalicoQuestManager.new()
	root.add_child(m)
	verify(m.configure(load("res://day2/quests/catalog.tres")),"catalog validation")
	m.start_new_game()
	var old := m.make_save_data()
	old.erase("paper_layout")
	old.quests.day1_papers = {"status":2,"progress":{"collect_paper":8}}
	old.flags = {"paper_living":true,"paper_kitchen":true,"paper_master":true}
	var before := old.duplicate(true)
	verify(m.restore_save_data(old),"old partial save rejected")
	verify(m.get_progress(&"day1_papers",&"collect_paper")==2,"removed room scraps counted")
	verify(old==before,"migration mutated caller data")
	old.quests.day1_papers.status = 3
	old.quests.day1_papers.progress.collect_paper = 17
	old.flags.d2_started = true
	verify(m.restore_save_data(old),"old completed save rejected")
	verify(m.get_progress(&"day1_papers",&"collect_paper")==4 and m.flags.get("papers_done",false),"completion not preserved")
	verify(m.flags.get("d2_started",false),"later story state lost")
	for spot in ["living","dining","kitchen","study1"]:verify(m.flags.get("paper_"+spot,false),"completed scrap missing "+spot)
	var valid := m.make_save_data()
	old.quests.day1_papers.progress.collect_paper = 18
	verify(not m.restore_save_data(old) and m.make_save_data()==valid,"bad old save accepted or polluted state")
	var bad := valid.duplicate(true)
	bad.quests.day1_papers.progress.collect_paper = 5
	verify(not m.restore_save_data(bad),"new save count > 4 accepted")
	m.queue_free()

func run_tests() -> void:
	migration_tests()
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game)
	current_scene = game
	map_hud = game.get_node("VillaMap/MapHUD")
	await ticks(8)
	game.start_game()
	await ticks(10)
	var day = game.get_node("DayOne")
	if not day.dialog.is_empty():await key(KEY_ESCAPE)
	verify(game.player.active,"story did not restore controls")
	verify(day.world.PAPER_SPOTS.size()==4,"paper world not reduced to 4")
	var count := 0
	for id in day.world.items:
		if str(id).begins_with("paper_"):
			count += 1
			verify(day.world.items[id].position.y<.1,"scrap not on first floor")
	verify(count==4,"extra scrap props remain")
	for gate in day.world.gates:
		verify(gate.has_node("StripedPartition"),"stripe material missing")
		var label = gate.find_children("*","Label3D",true,false)[0]
		verify(label.font_size==130,"barrier label not 5x")
		verify(gate.visible,"barrier initially hidden")
	for flag in ["walk","run","open_living","stool","table","cup_moved","note_read","light_off"]:day.manager.set_flag(StringName(flag),true)
	day.reconcile_progress()
	day.restore_world()
	for gate in day.world.gates:
		verify(not gate.visible,"barrier not removed on light task completion")
		for child in gate.get_children():
			if child is StaticBody3D:verify(child.collision_layer==0,"unlocked barrier still blocks")
	verify(day.manager.get_status(&"day1_papers")==CalicoQuestManager.State.ACTIVE,"paper task not active")
	day.perform_interaction("paper_master")
	verify(day.paper_count()==0,"removed scrap can advance mission")
	for spot in day.world.PAPER_SPOTS:
		day.perform_interaction("paper_"+spot[0])
		day.perform_interaction("paper_"+spot[0])
	verify(day.paper_count()==4 and day.flag("papers_done"),"4 scraps did not finish task")
	verify(day.manager.get_progress(&"day1_papers",&"collect_paper")==4,"duplicate pickups counted")
	verify(day.second_day().feeding_available(),"feeding did not unlock")
	var second = day.second_day()
	second.open_puzzle("code")
	verify(second.puzzle.shell.visible and not game.player.active,"task puzzle did not show")
	second.puzzle.code.text = "241"
	second.puzzle.submit_code()
	verify(day.flag("d2_unlocked") and game.player.active,"styled puzzle did not solve or restore input")
	await key(KEY_J)
	verify(day.quests.tracker.journal_visible() and not game.player.active,"journal open/pause")
	await key(KEY_ESCAPE)
	verify(not day.quests.tracker.journal_visible() and game.player.active,"journal close/control restoration")
	var nest: Node3D = game.get_node("Apartment/Staircase/DogNest")
	var landing: StaticBody3D = game.get_node("Apartment/Staircase/HalfLanding")
	verify(Vector2(nest.position.x,nest.position.z).distance_to(Vector2(landing.position.x,landing.position.z))<.001,"round bed not centered")
	verify(nest.get_node("Collision/Bed").shape is CylinderShape3D,"bed collision is rectangular")
	var dog_player: AnimationPlayer = nest.player
	var skeleton: Skeleton3D = nest.skeleton
	nest.set_process(false)
	var max_joint_error := 0.0
	for sample in range(17):
		dog_player.seek(sample*.25,true)
		skeleton.force_update_all_bone_transforms()
		for bone in range(skeleton.get_bone_count()):
			var posed := skeleton.get_bone_global_pose(bone)
			verify(posed.is_finite(),"invalid dog pose")
			var parent := skeleton.get_bone_parent(bone)
			# ROOT translates the whole torso into its resting height; it is an
			# animation control offset, not an anatomical limb segment.
			if parent < 0 or "ROOT" in skeleton.get_bone_name(bone):continue
			var actual := posed.origin.distance_to(skeleton.get_bone_global_pose(parent).origin)
			var rest := skeleton.get_bone_global_rest(bone).origin.distance_to(skeleton.get_bone_global_rest(parent).origin)
			max_joint_error = maxf(max_joint_error,absf(actual-rest))
	verify(max_joint_error<.001,"dog bones stretched "+str(max_joint_error))
	dog_player.seek(0,true)
	nest.set_process(true)
	var moved := false
	for plant in game.get_node("Apartment").find_children("*","Node3D",true,false):
		if str(plant.get_meta("asset_id",""))=="decor_plant":
			verify(Vector2(plant.global_position.x,plant.global_position.z).distance_to(Vector2(.30,2.06))>.10,"hall plant remains")
			if plant.global_position.distance_to(Vector3(-4.65,0,-1.10))<.1:moved = true
	verify(moved,"living room relocated plant missing")
	for name in ["DayOne","DayTwo"]:game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	place(6.30,7.40,.02,PI)
	await ticks(8)
	verify(await walk_until("z",2.70,160),"former hall plant position still blocks walking")
	for rate in [30,60,120]:await stair_route("round bed route",10.0,11.2,rate)
	verify(not day.manager.autosave,"tests enabled player saves")
	print("QUEST_POLISH_TEST ",JSON.stringify({"checks":checks,"max_dog_joint_error_m":max_joint_error,"stairs":stair_trials,"failures":failures}))
	game.stop_audio()
	game.queue_free()
	await ticks(3)
	quit(0 if failures.is_empty() else 1)
