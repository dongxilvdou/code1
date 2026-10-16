extends SceneTree
var game
const OUT := "res://furniture_pack/previews/furnished_villa/"

func _initialize() -> void:
	call_deferred("capture")

func point(x: float,y: float,z: float) -> Vector3:
	return Vector3(x-6,y,z-6)

func shot(label: String) -> void:
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")

func room_shot(label: String, camera: Vector3, target: Vector3, fov: float = 64) -> void:
	game.inspection_camera.fov = fov
	game.inspection_camera.global_position = camera
	game.inspection_camera.look_at(target)
	await shot(label)

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_game()
	# Bake the once-updated indoor reflections while the complete house is visible.
	for i in range(20):await process_frame
	game.toggle_overview()
	game.ui.hud.hide()
	game.set_process(false)
	for door in get_nodes_in_group("villa_doors"):door.set_open(true,true)
	game.set_section(1)
	await room_shot("01_ground_floor",point(6.6,23,12),point(6,.4,6),43)
	game.set_section(2)
	await room_shot("02_upper_floor",point(6.6,26,12),point(6,3.4,6),43)
	game.set_section(3)
	for door in get_nodes_in_group("villa_doors"):door.set_open(door.starts_open,true)
	await room_shot("03_living",point(4.70,1.55,11.30),point(1.9,.70,7.8))
	game.inspection_camera.cull_mask = 1|4|8|16
	await room_shot("04_cat_living",point(2.60,.224,10.20),point(1.5,.50,7.7),73)
	game.inspection_camera.cull_mask = 1|2|4|16
	await room_shot("05_dining",point(4.70,1.60,4.60),point(2.3,.85,2.6),68)
	await room_shot("06_kitchen",point(5.65,1.65,3.25),point(9.2,.95,1.4),70)
	await room_shot("07_master",point(4.7,4.6,3.5),point(2.1,3.6,3.4),70)
	await room_shot("08_study",point(4.86,4.60,7.40),point(1.7,3.70,7.15),74)
	await room_shot("09_guest",point(7.9,1.6,11.65),point(9.9,.8,10.1),70)
	await room_shot("10_bathroom",point(6.95,1.7,4.66),point(8.5,.8,5.0),78)
	await room_shot("11_terrace",point(3.65,4.5,9.5),point(1.45,3.5,10.9),70)
	await room_shot("12_garden",point(3.8,1.6,-2.6),point(7.4,.65,-.65),64)
	await room_shot("13_bedroom_a",point(5.80,4.55,2.95),point(9.2,3.7,1.9),72)
	await room_shot("14_bedroom_b",point(7.9,4.6,11.65),point(9.9,3.8,10.1),70)
	await room_shot("15_room_signs",point(5.85,1.0,7.9),point(6.6,1.02,5.25),68)
	print("FURNISHED_CAPTURE ",JSON.stringify({"views":15,"furniture_instances":get_nodes_in_group("placed_furniture").size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
	game.stop_audio()
	game.free()
	for i in range(3):await process_frame
	quit()
