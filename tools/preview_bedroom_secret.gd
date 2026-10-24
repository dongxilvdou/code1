extends SceneTree
## Disposable preview. Never loads or writes the normal save.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game);current_scene = game;game.start_game()
	for i in range(10):await physics_frame
	var day = game.get_node("DayOne")
	var chapter = game.get_node("ActFour")
	day.dialog = "";day.hud.overlay.hide()
	chapter.third.previous.seed_previous_days();chapter.begin_day(8);chapter.panel.close()
	day.manager.set_flag(&"daily_note_ack_8",true)
	var secret = game.get_node("BedroomSecret")
	game.player.global_position = secret.desk.global_position+Vector3(-.40,.03,.72)
	var delta: Vector3 = secret.button.to_global(Vector3(0,-.04,0))-game.player.camera.global_position
	game.player.yaw = atan2(-delta.x,-delta.z);game.player.rotation.y = game.player.yaw
	game.player.pitch = atan2(delta.y,Vector2(delta.x,delta.z).length())
	game.player.head.rotation.x = game.player.pitch
	secret.room_door.locked = false;secret.room_door.set_open(true,true)
	print("次卧彩蛋预览：按 E 阅读警告，再按 E 确认；Esc 可随时取消。此预览不保存。")
