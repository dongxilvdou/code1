extends SceneTree
var game
const DIRECTORY := "res://screenshots/villa_details"

func _initialize() -> void:
	call_deferred("capture")

func save_shot(label: String) -> void:
	for i in range(10):await process_frame
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(DIRECTORY+"/"+label+".png")

func capture() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	await save_shot("00_title")
	game.start_game()
	game.toggle_overview()
	game.ui.hud.hide()
	game.orbit_yaw = -.75
	game.orbit_pitch = .48
	game.orbit_distance = 24
	await save_shot("01_exterior")
	game.orbit_yaw = -.18
	game.orbit_pitch = 1.10
	game.orbit_distance = 21
	game.set_section(1)
	await save_shot("02_ground_floor")
	game.set_section(2)
	await save_shot("03_upper_floor")
	game.toggle_overview()
	game.player.set_control(false)
	game.player.position = Vector3(4,.02,2.2)
	game.player.rotation.y = 0
	game.player.yaw = 0
	game.player.head.rotation.x = .05
	game.ui.hud.show()
	await save_shot("04_cat_stairs")
	game.player.position = Vector3(-3.4,.02,4.2)
	game.player.rotation.y = 0
	game.player.yaw = 0
	game.player.head.rotation.x = -.08
	await save_shot("05_cat_living")
	game.player.position = Vector3(-.08,3.02,4.4)
	game.player.head.rotation.x = -.02
	game.player.rotation.y = PI/2
	game.player.yaw = PI/2
	await save_shot("06_terrace")
	game.player.position = Vector3(4,.02,2.3)
	game.player.rotation.y = 0
	game.player.yaw = 0
	game.toggle_photo()
	await save_shot("07_cat_scale")
	game.toggle_photo()
	game.ui.toast_time = 0
	game.player.position = Vector3(1.55,.02,1.35)
	game.player.rotation.y = PI
	game.player.yaw = PI
	game.player.head.rotation.x = .23
	await save_shot("08_door_closed")
	for door in get_nodes_in_group("villa_doors"):door.set_open(true)
	await create_timer(1.1).timeout
	await save_shot("09_door_open")
	game.toggle_overview()
	game.ui.hud.hide()
	game.inspection_camera.global_position = Vector3(-9,2.1,5)
	game.inspection_camera.look_at(Vector3(-9,2.5,1))
	game.set_process(false)
	await save_shot("10_tree_detail")
	game.inspection_camera.global_position = Vector3(-3.4,.25,5.0)
	game.inspection_camera.look_at(Vector3(-.8,.12,4.1))
	await save_shot("11_corner_detail")
	DirAccess.make_dir_recursive_absolute(DIRECTORY+"/motion")
	var samples: Array = []
	var probes := [Vector3(-.8,.08,4.114),Vector3(-.893,.08,4.05),Vector3(-.8,.24,4.1)]
	for frame in range(48):
		game.inspection_camera.global_position = Vector3(-3.6+frame*.026,.25,5.0)
		game.inspection_camera.look_at(Vector3(-.8,.12,4.1))
		await RenderingServer.frame_post_draw
		var frame_image := root.get_texture().get_image()
		frame_image.save_png(DIRECTORY+"/motion/%03d.png" % frame)
		var colors: Array = []
		for probe in probes:
			var pixel: Vector2 = game.inspection_camera.unproject_position(probe)
			var color := frame_image.get_pixel(clampi(roundi(pixel.x),0,frame_image.get_width()-1),clampi(roundi(pixel.y),0,frame_image.get_height()-1))
			colors.append([color.r,color.g,color.b])
		samples.append(colors)
	FileAccess.open(DIRECTORY+"/corner_motion_samples.json",FileAccess.WRITE).store_string(JSON.stringify(samples))
	print("VILLA_CAPTURE twelve real-engine views and 48 corner-motion frames saved")
	game.stop_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit()
