extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.start_game()
	game.player.position = Vector3(-7,.05,7)
	game.player.yaw = -.6
	game.player.rotation.y = -.6
	game.toggle_photo()
	for i in range(40):await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/calico/in_game.png")
	game.stop_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit()
