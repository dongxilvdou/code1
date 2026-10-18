extends SceneTree
var game: Node
var output := "res://logs/quest_polish/"
func _initialize() -> void:call_deferred("run")
func shot(label: String) -> void:
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game)
	current_scene = game
	for i in range(8):await physics_frame
	game.start_game()
	for i in range(8):await physics_frame
	var day = game.get_node("DayOne")
	if not day.dialog.is_empty():
		day.dialog = ""
		day.hud.overlay.hide()
		game.cinematic_active = false
	game.player.set_control(true)
	game.player.position = Vector3(-3.4,.025,-.55)
	game.player.yaw = 0
	game.player.rotation.y = 0
	await shot("01_striped_barrier")
	for flag in ["walk","run","open_living","stool","table","cup_moved","note_read","light_off"]:day.manager.set_flag(StringName(flag),true)
	day.reconcile_progress()
	day.restore_world()
	game.player.position = Vector3(-3.5,.025,2.2)
	game.player.yaw = PI
	game.player.rotation.y = PI
	await shot("02_paper_hud")
	day.perform_interaction("paper_living")
	await shot("03_paper_progress")
	game.get_node("QuestSystem").open_journal()
	await shot("04_journal")
	game.get_node("QuestSystem").close_journal()
	game.get_node("DayTwo").open_puzzle("code")
	await shot("04a_puzzle")
	game.get_node("DayTwo").puzzle.close()
	for name in ["DayOne","DayTwo"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
		game.get_node(name).hide()
	day.hud.hide()
	game.ui.hud.hide()
	game.get_node("QuestSystem").tracker.hide()
	game.get_node("QuestSystem").set_process(false)
	game.get_node("VillaMap/MapHUD").hide()
	game.get_node("VillaMap/MapHUD").set_process(false)
	game.set_process(false)
	game.player.set_control(false)
	game.cat_camera.make_current()
	var nest = game.get_node("Apartment/Staircase/DogNest")
	for data in [[Vector3(-.85,1.1,1.0),"05_round_bed"],[Vector3(.8,.70,.9),"06_sleeping_pose"]]:
		game.cat_camera.global_position = nest.global_position+data[0]
		game.cat_camera.look_at(nest.global_position+Vector3(0,.23,0))
		game.cat_camera.fov = 67
		await shot(data[1])
	game.stop_audio()
	game.queue_free()
	for i in range(3):await process_frame
	quit()
