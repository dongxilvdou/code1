extends SceneTree
var game
const OUTPUT := "res://previews/ui/"

func _initialize() -> void:
	call_deferred("capture")

func shot(path: String) -> void:
	for i in range(18):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.make_dir_recursive_absolute("res://logs/ui")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await shot(OUTPUT+"main_menu.png")
	game.ui.open_settings()
	await shot("res://logs/ui/settings.png")
	game.ui.close_settings()
	# Check the smaller window too, using the same responsive layouts.
	root.size = Vector2i(960,600)
	await shot("res://logs/ui/main_menu_small.png")
	root.size = Vector2i(1280,800)
	game.ui.start_button.pressed.emit()
	await shot(OUTPUT+"hud.png")
	game.player.position = Vector3(.3,.02,-1.5)
	game.player.yaw = -PI/2
	game.player.rotation.y = -PI/2
	game.player.head.rotation.x = 0
	game.player.velocity = Vector3.ZERO
	await shot("res://logs/ui/interaction.png")
	game.toggle_pause()
	await shot("res://logs/ui/pause.png")
	game.toggle_pause()
	game.toggle_overview()
	await shot("res://logs/ui/overview.png")
	game.toggle_overview()
	root.size = Vector2i(960,600)
	await shot("res://logs/ui/hud_small.png")
	print("UI_CAPTURE main menu, settings, HUD, interaction, pause, overview and small-window layouts")
	game.queue_free()
	await process_frame
	await process_frame
	quit()
