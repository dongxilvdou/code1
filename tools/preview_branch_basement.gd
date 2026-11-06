extends SceneTree
## Actual main scene, isolated quest session. No normal save read/write.
func _initialize() -> void:call_deferred("run")
func ticks(count: int) -> void:
	for i in range(count):await physics_frame
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled=false
	root.add_child(game);current_scene=game;await ticks(12);game.start_game();await ticks(12)
	var day=game.get_node("DayOne");var fourth=game.get_node("ActFour");var ending=game.get_node("Ending")
	fourth.third.previous.seed_previous_days();fourth.begin_day(11)
	fourth.set_value("locks",3)
	for flag_ in ["a6_permission","a11_enter","a11_complete","daily_note_ack_11","a11_memory"]:fourth.mark(flag_)
	fourth.restore();await ticks(8)
	day.dialog="";day.hud.overlay.hide();fourth.panel.close();ending.ui.close()
	game.player.position=Vector3(.60,-2.68,-2.55);game.player.velocity=Vector3.ZERO
	game.cinematic_active=false;game.player.set_control(true)
	var inspect=load("res://story_branches/inspection.gd").new();game.add_child(inspect)
	inspect.open(game,ending.world,true)
	print("BRANCH_PREVIEW ready; save_enabled=false; branch submissions are preview-only")
