extends SceneTree
## Opens the actual main scene in a disposable, save-disabled basement session.
## Normal launches still follow the existing day-eleven entrance/lock progression.
func _initialize() -> void:call_deferred("open_preview")

func open_preview() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game);current_scene = game
	game.start_game()
	for i in range(12):await physics_frame
	var day = game.get_node("DayOne")
	var chapter = game.get_node("ActFour")
	chapter.third.previous.seed_previous_days()
	chapter.begin_day(11)
	chapter.set_value("locks",3)
	for flag_ in ["a6_permission","a11_enter","a11_complete","daily_note_ack_11"]:chapter.mark(flag_)
	chapter.restore();day.dialog = "";day.hud.overlay.hide();chapter.panel.close()
	game.cinematic_active = false;game.player.set_control(true)
	game.player.position = Vector3(2.0,-2.68,-2.75)
	game.player.velocity = Vector3.ZERO;game.player.yaw = PI/2;game.player.rotation.y = PI/2
	game.player.pitch = -.04;game.player.head.rotation.x = -.04
	game.ui.toast("地下室预览 · E 开关笼门 · M 地图 · V 查看猫咪 · 此预览不读写存档",7)
	print("BASEMENT_PREVIEW ready, save_enabled=false")
