extends SceneTree
var game: Node
var output := "res://logs/hakimi/"
func _initialize() -> void:call_deferred("run")
func shot(label: String) -> void:
	for i in range(5):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game)
	current_scene = game
	for i in range(8):await physics_frame
	await shot("00_hakimi_menu")
	if "--quick" in OS.get_cmdline_user_args():game.start_game()
	else:
		game.request_start_game(true)
		for time in [7.8,10.8,15.5,23.0]:
			while game.opening.active and game.opening.film_time<time:await process_frame
			await shot("intro_"+str(time))
		while game.opening.active:await process_frame
	var day = game.get_node("DayOne")
	var second = game.get_node("DayTwo")
	for i in range(6):await physics_frame
	day.page = day.INTRO.size()-1
	day.advance_dialog()
	for flag in ["walk","run","open_living","stool","table","cup_moved","note_read","light_off","papers_done","d2_started","d2_unlocked","d2_cat_fed","d2_dog_fed","d2_note","d2_washed","d2_cloth_sofa","d2_cloth_chair","d2_cloth_entry","ruler_found","yarn_freed","yarn_home"]:day.manager.set_flag(StringName(flag),true)
	day.manager.set_value(&"current_day",2)
	second.reconcile()
	day.restore_world()
	for i in range(6):await physics_frame
	game.cat_camera.make_current()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.position = Vector3.ZERO
	game.player.model.hide()
	game.cat_camera.global_position = Vector3(1.50,1.43,-4.91)
	game.cat_camera.look_at(second.world.basin_position+Vector3(0,.12,0))
	game.cat_camera.fov = 45
	second.interact_item("dog_bowl")
	second.interact_item("tap")
	second.set_physics_process(false)
	second.dish_clock = 1.5
	second.refresh_hud()
	await shot("01_faucet_rinse")
	second.set_value("dish_stage",9)
	second.set_value("d2_holding",0)
	second.restore_world()
	game.cat_camera.global_position = Vector3(3.80,2.85,-.35)
	game.cat_camera.look_at(Vector3(4.35,1.68,-1.41))
	game.cat_camera.fov = 65
	await shot("02_dog_dining_spot")
	day.set_process(false)
	second.set_process(false)
	day.hud.hide()
	game.ui.hud.hide()
	game.get_node("QuestSystem").set_process(false)
	game.get_node("QuestSystem").tracker.hide()
	var map = game.get_node("VillaMap/MapHUD")
	map.set_process(false)
	map.hide()
	game.player.model.show()
	game.player.position = Vector3(-3.0,.025,.3)
	game.player.rotation.y = 0
	game.player.model.animate = false
	game.cat_camera.global_position = Vector3(-2.0,.5,-.4)
	game.cat_camera.look_at(game.player.position+Vector3(0,.23,0))
	game.cat_camera.fov = 44
	for state in ["idle","walk","run","stretch","jump","crouch","sit"]:
		var model = game.player.model
		model.animation_player.play(model.clips[state],0)
		model.animation_player.advance(0)
		model.animation_player.seek(model.animation_player.current_animation_length*.65,true)
		await shot("cat_"+state)
	game.stop_audio()
	game.queue_free()
	for i in range(3):await process_frame
	print("HAKIMI_CAPTURE complete")
	quit()
