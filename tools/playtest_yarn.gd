extends "res://tools/playtest_v2.gd"
func run_tests() -> void:
 create_timer(75).timeout.connect(func():printerr("YARN timeout");quit(2))
 game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false;root.add_child(game);current_scene=game
 game.start_game();await ticks(8)
 day=game.get_node("DayOne");second=game.get_node("DayTwo");chapter=game.get_node("ActTwo");third=game.get_node("ActThree");dismiss()
 await prepare_day(4);chapter.set_flag("toy_requested");chapter.interact_item("yarn");await ticks(4)
 await check_dense_yarn()
 verify(not day.manager.autosave,"Yarn validation can overwrite the player's save")
 print("YARN_PLAYTEST ",JSON.stringify({"checks":checks,"failures":failures}))
 game.stop_audio();game.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
