extends SceneTree
## A disposable session starting at day ten; normal saves are never read or written.
func _initialize() -> void:
	call_deferred("open_preview")

func open_preview() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	var quests=game.get_node("QuestSystem")
	quests.save_enabled=false
	root.add_child(game)
	current_scene=game
	for i in range(120):
		if quests.initialized:break
		await process_frame
	if not quests.initialized:
		push_error("第十天试玩初始化失败。")
		quit(1)
		return
	var chapter=game.get_node("ActFour")
	chapter.start_chapter()
	if not chapter.day.initialized:
		push_error("第十天试玩无法开始。")
		quit(1)
		return
	for number in [8,9]:
		if chapter.today()!=number:chapter.begin_day(number)
		chapter.mark("daily_note_ack_%d"%number)
		for goal in chapter.GOALS[number]:chapter.mark(goal)
		chapter.mark("a%d_complete"%number)
	chapter.begin_day(10)
	root.title="哈基米模拟器 · 第十天试玩（不保存）"
	print("DAY10_PREVIEW_READY current_day=",chapter.today()," save_enabled=",quests.save_enabled," autosave=",quests.manager.autosave)
