extends SceneTree
var game: Node
func _initialize() -> void:call_deferred("run")
func shot(name: String, position: Vector3, target: Vector3, fov: float = 65) -> void:
	game.cat_camera.global_position = position
	game.cat_camera.look_at(target)
	game.cat_camera.fov = fov
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/remodel/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://previews/remodel")
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game)
	current_scene = game
	await physics_frame
	await process_frame
	game.start_game()
	game.player.set_control(false)
	game.player.position = Vector3(-3,.02,4)
	for door in get_nodes_in_group("villa_doors"):door.set_open(true,true)
	game.cat_camera.make_current()
	game.ui.hud.hide()
	game.get_node("VillaMap/MapHUD").set_process(false)
	game.get_node("VillaMap/MapHUD").hide()
	game.set_process(false)
	var quests: Node = game.get_node("QuestSystem")
	quests.set_process(false)
	quests.set_physics_process(false)
	quests.tracker.hide()
	await shot("01_workshop",Vector3(1.85,1.50,5.65),Vector3(4.0,.9,3.72),72)
	await shot("02_drafting",Vector3(4.00,1.40,3.93),Vector3(4.05,.81,3.55),52)
	await shot("03_computer_room",Vector3(1.85,4.50,5.65),Vector3(4.10,4.02,3.55),72)
	await shot("04_workstation",Vector3(4.12,4.40,4.44),Vector3(4.12,4.07,3.42),62)
	await shot("05_basement_entry",Vector3(3.70,1.15,2.46),Vector3(5.14,-.85,-.40),66)
	await shot("06_basement_lower",Vector3(5.15,-1.35,-3.35),Vector3(5.20,-1.2,-.55),72)
	await shot("07_clear_table",Vector3(-2.50,1.50,-1.2),Vector3(-3.40,.77,-3.20),66)
	game.player.position = Vector3(5.20,-2.698,-2.75)
	game.player.rotation.y = PI
	game.player.yaw = PI
	game.player.head.rotation.x = 0
	game.player.pitch = 0
	game.player.camera.make_current()
	game.ui.hud.show()
	game.get_node("VillaMap/MapHUD").set_process(true)
	for i in range(8):await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/remodel/08_basement_cat.png")
	print("REMODEL_CAPTURE eight actual Godot views")
	game.stop_audio()
	game.queue_free()
	for i in range(3):await process_frame
	quit()
