extends SceneTree
var game: Node
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://logs/comic")
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game);current_scene = game
	for i in range(8):await physics_frame
	game.request_start_game(true)
	game.opening.autoplay = false
	for time in [6.0,11.0,16.0,21.0,27.0,33.0,38.0,43.0,47.0,53.0]:
		game.opening.timeline.seek(time,true)
		game.opening._update_comic()
		for i in range(6):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/comic/shot_%02d.png"%int(time))
	for dimensions in [Vector2i(800,600),Vector2i(1920,800)]:
		root.size = dimensions
		for i in range(6):await process_frame
		game.opening.timeline.seek(16,true)
		game.opening._update_comic()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/comic/aspect_%d_%d.png"%[dimensions.x,dimensions.y])
	# Exercise the actual GUI press/release path on the rendered window too.
	var event := InputEventMouseButton.new()
	event.position = game.opening.skip_hint.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT;event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = event.duplicate();event.pressed = false
	root.push_input(event,true)
	for i in range(55):await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/comic/gameplay.png")
	print("COMIC_CAPTURE ",JSON.stringify({"pages":4,"meows":game.opening.meow_count,"control_restored":game.player.active,"repeated_dialog":game.get_node("DayOne").dialog}))
	game.queue_free()
	for i in range(3):await process_frame
	quit()
