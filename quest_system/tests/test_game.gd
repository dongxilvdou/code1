extends SceneTree
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
	if capture: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	root.size = Vector2i(1280, 800)
	game = load("res://scenes/main.tscn").instantiate()
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
	expect(manager.get_progress(&"q01", &"living") == 1, "Initial room tracked using map regions")
	expect(manager.get_status(&"q01") == State.ACTIVE, "Arrival awaits real meow")
	var map: Control = game.get_node("VillaMap/MapHUD")
	var panel: Control = quests.tracker.panel
	expect(panel.visible and panel.position.y >= map.mini_back.get_global_rect().end.y + 10, "Tracker is under minimap")
	expect(is_equal_approx(panel.position.x, map.mini_back.position.x), "Tracker left-aligns to map")
	expect(panel.get_global_rect().end.y < quests.tracker.get_viewport_rect().size.y - 65, "Tracker clears bottom shortcuts")
	await shot("01_under_minimap")
	await key(KEY_Q)
	expect(manager.get_status(&"q01") == State.COMPLETED, "Q input completes arrival")
	expect(manager.values.exploration_points == 5, "Actual completion reward")
	expect(manager.get_status(&"q02") == State.ACTIVE, "Next quest unlocked")
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
	expect(manager.get_progress(&"q02", &"dining") == 1, "Dining region event")
	await visit(Vector3(2.5, .02, -4.2))
	expect(manager.get_status(&"q02") == State.COMPLETED, "Kitchen region completes downstairs")
	expect(manager.flags.downstairs_done and manager.get_status(&"q05") == State.AVAILABLE, "Flag and ANY prerequisite unlock optional quest")
	quests.open_journal()
	await ticks()
	var accept_buttons: Array[Node] = quests.tracker.journal_list.find_children("*", "Button", true, false)
	expect(accept_buttons.size() == 1, "Journal exposes available task acceptance")
	if not accept_buttons.is_empty(): accept_buttons[0].pressed.emit()
	quests.close_journal()
	expect(manager.get_status(&"q05") == State.ACTIVE, "Journal button accepts optional task")
	root.size = Vector2i(960, 600)
	await ticks(8)
	print("QUEST_LAYOUT ", JSON.stringify({"window": str(root.size), "viewport": str(quests.tracker.get_viewport_rect()), "panel": str(panel.get_global_rect()), "minimum": str(panel.get_combined_minimum_size())}))
	expect(panel.get_global_rect().end.y < quests.tracker.get_viewport_rect().size.y - 65, "Small window fits sidebar")
	await shot("03_small_window")
	root.size = Vector2i(1280, 800)
	await visit(Vector3(-2.5, 3.02, .9))
	expect(manager.get_progress(&"q03", &"study") == 1, "Upstairs study is not confused with ground floor")
	await visit(Vector3(-3, 3.02, 4.8))
	expect(manager.get_status(&"q03") == State.COMPLETED, "Terrace completes upstairs")
	# Use the existing actual E-interaction position from the project's door tests.
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
	await key(KEY_E)
	expect(manager.get_progress(&"q04", &"door") == 0, "Door is not counted before opening animation finishes")
	await ticks(65)
	expect(manager.get_progress(&"q04", &"door") == 1, "Actual opened door counted once")
	await visit(Vector3(0, .02, -8))
	expect(manager.get_status(&"q04") == State.COMPLETED and manager.flags.villa_explored, "North garden finishes main chain")
	for i in range(3):
		await ticks(60)
		await key(KEY_Q)
	expect(manager.get_status(&"q05") == State.COMPLETED and manager.values.exploration_points == 55, "Optional quest and total reward")
	quests.open_journal()
	await shot("04_completed")
	quests.close_journal()
	# Reset is explicit and restores the tutorial without altering the house.
	quests.restart_quests()
	await visit(Vector3(-3.4, .02, 4.2))
	expect(manager.get_status(&"q01") == State.ACTIVE and manager.values.is_empty(), "Explicit reset clears task rewards")
	expect(manager.get_progress(&"q01", &"living") == 1, "Reset resumes room reporting")
	game.queue_free()
	await ticks(2)
	print("QUEST_GAME_TESTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
