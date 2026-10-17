extends SceneTree
var game: Node
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game)
	current_scene = game
	for i in range(8):await physics_frame
	game.request_start_game(true)
	DirAccess.make_dir_recursive_absolute("res://previews/opening")
	var shots := [2.0,5.5,8.0,11.0,15.0,18.5,23.0,25.5,27.5]
	var index := 0
	while game.cinematic_active:
		await process_frame
		if index<shots.size() and game.opening.film_time>=shots[index]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://previews/opening/%02d.png" % index)
			index += 1
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/opening/09_gameplay.png")
	print("OPENING_CAPTURE ",JSON.stringify({"shots":index,"seconds":28,"actor_distance":game.opening.actor_distance,"camera_corrections":game.opening.collision_corrections,"restored":game.player.active}))
	game.stop_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit()
