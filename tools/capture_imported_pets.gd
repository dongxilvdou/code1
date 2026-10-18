extends SceneTree
var game: Node
var output := "res://logs/pet_replacement/"
func _initialize() -> void:call_deferred("run")
func shot(name: String) -> void:
	for i in range(6):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	for name in ["DayOne","DayTwo"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
		game.get_node(name).hide()
	root.add_child(game)
	current_scene = game
	await physics_frame
	game.start_game()
	game.player.set_control(false)
	game.player.set_physics_process(false)
	game.set_process(false)
	game.get_node("QuestSystem").set_process(false)
	game.get_node("QuestSystem").tracker.hide()
	game.ui.hud.hide()
	game.get_node("VillaMap/MapHUD").hide()
	game.get_node("VillaMap/MapHUD").set_process(false)
	game.cat_camera.make_current()
	game.cat_camera.global_position = Vector3(4.28,2.12,-.85)
	game.cat_camera.look_at(Vector3(4.60,1.86,-2.03))
	game.cat_camera.fov = 62
	await shot("01_landing_dog")
	# A close view of the actual player in the existing living room.
	game.player.position = Vector3(-3.20,.025,3.70)
	game.player.rotation.y = -.4
	game.player.model.preview_pose = "idle"
	game.cat_camera.global_position = Vector3(-2.40,.61,2.60)
	game.cat_camera.look_at(game.player.position+Vector3(0,.23,0))
	game.cat_camera.fov = 49
	await shot("02_new_player")
	# Inspect all baked poses at an actual sample time; no fabricated drawings.
	var cat = game.player.model
	cat.animate = false
	for state in ["walk","run","jump","stretch","sit"]:
		cat.animation_player.play(cat.clips[state],0)
		cat.animation_player.advance(0)
		cat.animation_player.seek(cat.animation_player.current_animation_length*.30,true)
		await shot("pose_"+state)
	cat.preview_pose = "game"
	cat.animate = true
	game.player.position = Vector3(-8,.95,8)
	game.player.rotation.y = 0
	game.player.pitch = 0
	game.player.head.rotation.x = 0
	game.player.camera.make_current()
	var paws = game.player.paws[0]
	paws.visible = true
	paws.airborne = true
	paws.vertical_speed = 1.5
	await shot("03_jump_paws")
	game.stop_audio()
	game.queue_free()
	for i in range(3):await process_frame
	print("IMPORTED_PETS_CAPTURE complete")
	quit()
