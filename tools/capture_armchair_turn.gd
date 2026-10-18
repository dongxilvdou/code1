extends SceneTree
## Actual living-room camera turns, including the former coincident geometry.
var game: Node
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://logs/armchair_turn")
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	for name in ["DayOne","DayTwo"]:game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	for i in range(8):await physics_frame
	game.start_game()
	game.player.set_control(false)
	game.player.set_physics_process(false)
	game.set_process(false)
	for name in ["DayOne","DayTwo"]:game.get_node(name).hide()
	game.get_node("DayOne").hud.hide()
	game.ui.hud.hide()
	game.get_node("QuestSystem").set_process(false)
	game.get_node("QuestSystem").tracker.hide()
	var map = game.get_node("VillaMap/MapHUD")
	map.set_process(false)
	map.hide()
	var chair := game.get_node("Apartment/GroundFloor/Furnishings/Living/Armchair_004") as Node3D
	var back := chair.get_node("Back_shell") as MeshInstance3D
	var fixed := back.transform
	var camera: Camera3D = game.cat_camera
	camera.make_current()
	camera.fov = 58
	var frames := 0
	for phase in ["before","after"]:
		back.transform = Transform3D(Basis.IDENTITY,Vector3(0,.66,-.36)) if phase=="before" else fixed
		for view in range(3):
			for i in range(24):
				var angle := (.35 if view==0 else -.35 if view==1 else PI)+ (float(i)/23-.5)*.5
				var position := Vector3(sin(angle)*1.3,.32 if view<2 else .70,cos(angle)*1.3)
				camera.global_position = chair.to_global(position)
				camera.look_at(chair.to_global(Vector3(0,.52,-.12)))
				await process_frame
				await RenderingServer.frame_post_draw
				if i in [0,12,23]:root.get_texture().get_image().save_png("res://logs/armchair_turn/%s_%d_%02d.png" % [phase,view,i])
				frames += 1
	back.transform = fixed
	print("ARMCHAIR_TURN_CAPTURE ",frames," frames; saves disabled")
	game.stop_audio()
	game.queue_free()
	for i in range(3):await process_frame
	quit()
