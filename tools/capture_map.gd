extends SceneTree
var game
var hud
const OUTPUT := "res://screenshots/maps/"

func _initialize() -> void:
	call_deferred("capture")

func shot(label: String) -> void:
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+label+".png")

func place(x: float,y: float,z: float,yaw: float) -> void:
	game.player.position = Vector3(x-6,y,z-6)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = yaw
	game.player.rotation.y = yaw
	game.player.pitch = -.02
	game.player.head.rotation.x = -.02
	game.player.step_view_offset = 0.0
	game.player.camera.position.y = 0.0
	for i in range(6):await physics_frame

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_game()
	hud = game.get_node("VillaMap/MapHUD")
	await shot("01_minimap")
	hud.set_big(true)
	await shot("02_ground_floor_map")
	hud.set_big(false)
	await place(10.0,.02,8.02,0)
	await shot("03_stair_entrance")
	await place(10.0,1.52,4.4,-PI/2)
	hud.set_big(true)
	await shot("04_stair_map")
	hud.set_big(false)
	await place(11.2,3.02,8.05,PI)
	hud.set_big(true)
	await shot("05_upper_floor_map")
	hud.set_big(false)
	await place(2.0,.02,-1.0,0)
	hud.set_big(true)
	await shot("06_garden_map")
	game.stop_audio()
	game.queue_free()
	await process_frame
	await process_frame
	print("MAP_CAPTURE 6 views saved")
	quit()
