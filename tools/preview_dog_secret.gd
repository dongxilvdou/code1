extends SceneTree
## Disposable day-eight preview: does not read or write the normal save.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game);current_scene = game;game.start_game()
	for i in range(10):await physics_frame
	var day = game.get_node("DayOne")
	var chapter = game.get_node("ActFour")
	day.dialog = "";day.hud.overlay.hide()
	chapter.third.previous.seed_previous_days()
	chapter.begin_day(8)
	chapter.panel.close()
	day.manager.set_flag(&"daily_note_ack_8",true)
	game.player.global_position = Vector3(1.45,.035,-3.9)
	game.player.yaw = -PI/2;game.player.rotation.y = -PI/2
	game.get_node("DogSecret").trigger_chance = 1.0
	chapter.interact_item("dog")
