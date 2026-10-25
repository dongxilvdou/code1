extends SceneTree
## Current README screenshots from real scenes; never reads/writes the normal save.
var game: Node
const OUTPUT := "res://previews/showcase/"
func _initialize() -> void:call_deferred("run")
func ticks(count: int) -> void:
	for i in range(count):await physics_frame
	await process_frame
func photo(file: String) -> void:
	await ticks(8);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+file+".png")
func hide_ui() -> void:
	for layer in game.find_children("*","CanvasLayer",true,false):layer.hide()
func aim(point: Vector3) -> void:
	var delta: Vector3 = point-game.player.camera.global_position
	game.player.yaw = atan2(-delta.x,-delta.z);game.player.rotation.y = game.player.yaw
	game.player.pitch = atan2(delta.y,Vector2(delta.x,delta.z).length());game.player.head.rotation.x = game.player.pitch
func scene_photo(file: String, eye: Vector3, target: Vector3) -> void:
	game.cat_camera.global_position = eye;game.cat_camera.look_at(target)
	game.cat_camera.fov = 68;game.cat_camera.cull_mask = 1|4|16;game.cat_camera.make_current()
	await photo(file)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game);current_scene = game;await ticks(12)
	await photo("01_menu")
	game.ui.started.emit();await ticks(2)
	game.opening.autoplay = false;game.opening.timeline.seek(16,true);game.opening._update_comic()
	await photo("02_comic")
	game.opening.request_skip()
	while game.opening.active or game.opening.finishing:await process_frame
	await ticks(8)
	var day = game.get_node("DayOne");var fourth = game.get_node("ActFour")
	day.dialog = "";day.hud.overlay.hide()
	fourth.third.previous.seed_previous_days();fourth.begin_day(9);fourth.panel.close()
	day.manager.set_flag(&"daily_note_ack_9",true);game.cinematic_active = false;game.player.set_control(true)
	game.player.set_physics_process(false);game.player.global_position = Vector3(-2.35,.03,3.6)
	aim(Vector3(-4.8,.7,.9));game.player.camera.make_current()
	await photo("03_cat_view")
	game.player.global_position = Vector3(-3,-.035,-9.3)
	game.player.yaw = 0;game.player.rotation.y = 0;hide_ui()
	game.cat_camera.global_position = game.player.global_position+Vector3(.65,.42,-.90)
	game.cat_camera.look_at(game.player.global_position+Vector3(0,.20,0))
	game.cat_camera.fov = 60;game.cat_camera.cull_mask = 1|2|4|16;game.cat_camera.make_current()
	await photo("04_garden_cat")
	game.photo = false
	await scene_photo("05_computer_room",Vector3(1.4,4.35,5.15),Vector3(4.0,3.8,3.55))
	var dog = game.get_node("Apartment/Staircase/DogNest")
	await scene_photo("06_dog",dog.global_position+Vector3(-1.2,.50,-.35),dog.global_position+Vector3(-.08,.25,0))
	await scene_photo("07_basement",Vector3(2.1,-1.55,-.9),Vector3(-1.4,-2.0,-2.7))
	print("SHOWCASE_CAPTURE ",JSON.stringify({"screenshots":7,"saving_disabled":not game.get_node("QuestSystem").save_enabled}))
	game.queue_free();await ticks(3);quit()
