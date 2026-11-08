extends SceneTree
## Formal catalog integration. Sample q01-q05 rewards/prerequisites remain covered by test_quests.gd.
var output_dir := OS.get_environment("CALICO_QUEST_CAPTURE_DIR")
const Kind = CalicoQuestObjective.Kind
const State = CalicoQuestManager.State
var failures: Array[String] = []
var checks := 0
var game: Node
var quests: Node
var capture := false

func _initialize() -> void:
	capture = "--quest-capture" in OS.get_cmdline_user_args()
	if output_dir.is_empty(): output_dir = "user://quest_test_previews"
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func ticks(count: int = 6) -> void:
	for i in range(count): await physics_frame
	await process_frame

func shot(filename: String) -> void:
	if not capture: return
	await ticks(12)
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output_dir.path_join(filename + ".png"))
	expect(error == OK, "Capture " + filename)

func visit(p: Vector3) -> void:
	game.player.global_position = p
	game.player.velocity = Vector3.ZERO
	await ticks(3)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(2)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await ticks(2)

func run() -> void:
	create_timer(90).timeout.connect(func():printerr("QUEST_GAME_TIMEOUT");quit(2))
	if capture: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	root.size = Vector2i(1280, 800)
	root.content_scale_size=root.size
	game = load("res://scenes/main.tscn").instantiate()
	game.comic_intro_completed=true # Opening comic has its own test suite.
	root.add_child(game)
	current_scene = game
	await ticks(10)
	quests = game.get_node("QuestSystem")
	expect(quests.initialized, "Module initializes in actual main scene")
	if not quests.initialized:
		quit(1)
		return
	expect(not quests.tracker.panel.visible, "Tracker hidden in welcome screen")
	game.start_game()
	await ticks(10)
	var manager: CalicoQuestManager = quests.manager
	expect(not manager.autosave, "Tests cannot overwrite player save")
	expect(manager.get_progress(&"day1_arrival", &"note_read") == 0, "Arrival awaits actual paper presentation")
	expect(manager.get_status(&"day1_arrival") == State.ACTIVE, "Formal arrival task starts active")
	var map: Control = game.get_node("VillaMap/MapHUD")
	var panel: Control = quests.tracker.panel
	expect(not panel.visible, "Main story card suppresses the duplicate quest sidebar")
	expect(is_equal_approx(panel.position.x, map.mini_back.position.x), "Tracker left-aligns to map")
	expect(panel.get_global_rect().end.y < quests.tracker.get_viewport_rect().size.y - 65, "Tracker clears bottom shortcuts")
	await shot("01_under_minimap")
	await key(KEY_Q)
	expect(manager.get_status(&"day1_arrival") == State.ACTIVE, "Meowing cannot bypass the formal tutorial")
	var day=game.get_node("DayOne")
	day.show_dialog("note")
	for _i in range(4):await process_frame
	expect(manager.get_progress(&"day1_arrival", &"note_read") == 1, "Displayed daily paper records the actual objective")
	await key(KEY_ESCAPE)
	expect(manager.get_status(&"day1_lights") == State.LOCKED, "Reading alone does not complete the tutorial")
	await key(KEY_J)
	expect(quests.tracker.journal_visible() and not game.player.active, "J opens journal and stops movement")
	expect(not map.visible and not panel.visible, "Map and sidebar hidden in journal")
	await key(KEY_M)
	expect(not map.big_open and quests.tracker.journal_visible(), "Map cannot interrupt journal")
	await shot("02_journal")
	await key(KEY_ESCAPE)
	expect(not quests.tracker.journal_visible() and game.player.active and not game.ui.pause_panel.visible, "Esc closes journal and restores play")
	await key(KEY_M)
	expect(map.big_open and not panel.visible, "Big map hides quests")
	await key(KEY_ESCAPE)
	expect(not map.big_open and game.player.active, "Map close restores control")
	game.toggle_pause()
	await ticks()
	expect(not panel.visible, "Pause hides tracker")
	quests.open_journal()
	quests.close_journal()
	expect(game.ui.pause_panel.visible and not game.player.active, "Journal opened from pause returns to pause")
	game.toggle_pause()
	game.toggle_photo()
	await ticks()
	expect(not panel.visible, "Cat view hides tracker")
	game.toggle_photo()
	game.toggle_overview()
	await ticks()
	expect(not panel.visible, "Overview hides tracker")
	game.toggle_overview()
	await visit(Vector3(-2.6, .02, -3.7))
	expect(quests._last_room.contains("dining"), "Dining region still reported")
	await visit(Vector3(2.5, .02, -4.2))
	expect(quests._last_room.contains("kitchen"), "Kitchen region still reported")
	expect(manager.get_status(&"day1_arrival") == State.ACTIVE, "Room visits cannot replace the tutorial tasks")
	quests.open_journal()
	await ticks()
	var accept_buttons: Array[Node] = quests.tracker.journal_list.find_children("*", "Button", true, false)
	expect(accept_buttons.is_empty(), "No unrelated sample task acceptance appears in the formal journal")
	quests.close_journal()
	expect(manager.get_status(&"day1_arrival") == State.ACTIVE, "Browsing journal preserves the active task")
	root.size = Vector2i(960, 600)
	root.content_scale_size=root.size
	await ticks(8)
	print("QUEST_LAYOUT ", JSON.stringify({"window": str(root.size), "viewport": str(quests.tracker.get_viewport_rect()), "panel": str(panel.get_global_rect()), "minimum": str(panel.get_combined_minimum_size())}))
	expect(panel.get_global_rect().end.y < quests.tracker.get_viewport_rect().size.y - 65, "Small window fits sidebar")
	await shot("03_small_window")
	root.size = Vector2i(1280, 800)
	await visit(Vector3(-2.5, 3.02, .9))
	expect(quests._last_room.contains("floor_2"), "Upstairs study is not confused with ground floor")
	await visit(Vector3(-3, 3.02, 4.8))
	expect(quests._last_room.contains("terrace"), "Terrace region still reported")
	# Door collision and actual E input are covered by playtest_branch_routes.gd.
	# Here, test the map's target selection without bypassing the formal tutorial's gates.
	var door: Node
	for candidate in get_nodes_in_group("villa_doors"):
		if candidate.door_title == "工作书房门" and candidate.global_position.y < 1: door = candidate
	door.set_open(false, true)
	game.player.yaw = PI
	game.player.rotation.y = PI
	game.player.pitch = 0
	game.player.head.rotation.x = 0
	await visit(Vector3(1.55, .02, 2.35))
	game.update_target()
	expect(game.nearest_door == door, "Existing interaction selects door")
	expect(not door.is_open, "Selecting a door cannot open it automatically")
	await visit(Vector3(0, .02, -8))
	expect(quests._last_room.contains("garden"), "North garden region still reported")
	for i in range(3):
		await ticks(60)
		await key(KEY_Q)
	expect(not manager.values.has("exploration_points"), "Removed sample quests cannot grant unrelated rewards")
	quests.open_journal()
	await shot("04_completed")
	quests.close_journal()
	# Reset is explicit and restores the tutorial without altering the house.
	quests.restart_quests()
	await visit(Vector3(-3.4, .02, 4.2))
	expect(manager.get_status(&"day1_arrival") == State.ACTIVE and int(manager.values.get("current_day",1))==1, "Explicit reset starts the formal first day")
	expect(manager.get_progress(&"day1_arrival", &"note_read") == 0, "Reset requires reading the new game's paper")
	game.queue_free()
	await ticks(2)
	print("QUEST_GAME_TESTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
