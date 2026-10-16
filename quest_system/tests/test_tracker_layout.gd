extends SceneTree
var game: Node
var system: Node
var failures: Array[String] = []
var checks := 0
var capture := false
var output_dir := OS.get_environment("CALICO_QUEST_CAPTURE_DIR")

func _initialize() -> void:
	capture = "--quest-capture" in OS.get_cmdline_user_args()
	if output_dir.is_empty(): output_dir = "user://quest_test_previews"
	call_deferred("run")

func ticks(count: int = 12) -> void:
	for i in range(count): await physics_frame
	await process_frame

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func verify_visible_rows(context: String) -> void:
	var tracker: Control = system.tracker
	var scroll: ScrollContainer = tracker.task_list.get_parent()
	var clip := scroll.get_global_rect()
	for label in tracker.task_list.find_children("*", "Label", true, false):
		if not label.is_visible_in_tree(): continue
		var rect: Rect2 = label.get_global_rect()
		expect(rect.position.y >= clip.position.y - .5 and rect.end.y <= clip.end.y + .5, context + ": clipped label " + label.text)
	expect(tracker.panel.get_global_rect().end.y <= tracker.get_viewport_rect().size.y - 81, context + ": overlaps shortcuts")

func shot(name: String) -> void:
	if not capture: return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output_dir.path_join(name + ".png")) == OK, "Save screenshot " + name)

func run() -> void:
	root.size = Vector2i(1280, 800)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await ticks()
	system = game.get_node("QuestSystem")
	game.start_game()
	await ticks()
	var manager: CalicoQuestManager = system.manager
	expect(not manager.autosave, "Layout tests do not touch player save")
	manager.report_event(CalicoQuestObjective.Kind.MEOW)
	manager.report_event(CalicoQuestObjective.Kind.ENTER_ROOM, &"floor_1/dining")
	manager.report_event(CalicoQuestObjective.Kind.ENTER_ROOM, &"floor_1/kitchen")
	system._messages.clear()
	system.tracker._notice_time = 0
	await ticks()
	expect(system.tracker.footer.text.contains("1 个任务可接取"), "Reproduce two-line footer")
	var shown_labels: Array = system.tracker.task_list.find_children("*", "Label", true, false).filter(func(label): return label.is_visible_in_tree())
	expect(shown_labels.size() == 3, "Both default objectives and their title stay visible")
	verify_visible_rows("Available side quest")
	var scroll: Control = system.tracker.task_list.get_parent()
	print("TRACKER_METRICS ", JSON.stringify({"panel_height": system.tracker.panel.size.y, "list_height": system.tracker.task_list.get_combined_minimum_size().y, "visible_list_height": scroll.size.y, "footer_height": system.tracker.footer.size.y}))
	await shot("05_available_task_fixed")
	system.tracker.show_notice("已完成 · 一楼巡游\n探索积分 +10\n开启楼上探索")
	await ticks()
	verify_visible_rows("Available task plus completion notice")
	system.tracker_width = 220
	var goal: CalicoQuestObjective = manager.definitions[&"q03"].objectives[1]
	var original_text := goal.text
	goal.text = "到达二层的露台，沿着楼梯上楼后穿过阅读角，找到朝向室外花园的露台入口"
	system.tracker.refresh()
	await ticks()
	verify_visible_rows("Wrapped objective at narrow width")
	root.size = Vector2i(960, 600)
	await ticks()
	verify_visible_rows("Small window")
	goal.text = original_text
	system.tracker_width = 280
	manager.accept_quest(&"q05")
	await ticks()
	verify_visible_rows("Two active tasks")
	if "--check-overflow" in OS.get_cmdline_user_args():
		# Artificially enlarge the map card so the sidebar genuinely has less room.
		var map_card: Control = system.map_hud.mini_back
		var original_size := map_card.size
		map_card.size.y += 340
		await ticks()
		verify_visible_rows("Limited space folds whole rows")
		expect(system.tracker.overflow_hint.visible, "Hidden rows have an explicit journal hint")
		map_card.size = original_size
		await ticks()
		verify_visible_rows("Space restored")
		expect(not system.tracker.overflow_hint.visible, "Rows return when space returns")
	game.queue_free()
	await ticks(2)
	print("QUEST_LAYOUT_TESTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
