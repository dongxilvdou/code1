extends SceneTree
const SAVE := "user://quest_system_automated_tests/controller.json"
var checks := 0
var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func ticks(count: int = 8) -> void:
	for i in range(count): await physics_frame
	await process_frame

func enter_game() -> Node:
	game = load("res://scenes/main.tscn").instantiate()
	var system: Node = game.get_node("QuestSystem")
	system.save_file = SAVE
	root.add_child(game)
	current_scene = game
	await ticks()
	game.start_game()
	await ticks()
	return system

func leave_game() -> void:
	game.queue_free()
	await ticks(3)

func run() -> void:
	# 只使用测试专用文件，不接触实际玩家存档。
	if FileAccess.file_exists(SAVE):
		printerr("Test save already exists; refusing to replace it: ", SAVE)
		quit(1)
		return
	var system: Node = await enter_game()
	expect(system.manager.autosave, "Controller enables autosave")
	game.player.meowed.emit()
	await ticks()
	expect(FileAccess.file_exists(SAVE), "Controller writes progress")
	expect(system.manager.get_status(&"q01") == CalicoQuestManager.State.COMPLETED, "First session finishes arrival")
	await leave_game()
	system = await enter_game()
	expect(system.manager.get_status(&"q01") == CalicoQuestManager.State.COMPLETED, "New main scene restores completion")
	expect(system.manager.values.exploration_points == 5, "Reload does not issue reward again")
	expect(system.manager.get_status(&"q02") == CalicoQuestManager.State.ACTIVE, "Reload restores next task")
	system.restart_quests()
	expect(system.manager.values.is_empty(), "Reset clears persisted score")
	await leave_game()
	system = await enter_game()
	expect(system.manager.get_status(&"q01") == CalicoQuestManager.State.ACTIVE and system.manager.values.is_empty(), "Reset persists to next session")
	await leave_game()
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("{\"version\":999}")
	file.close()
	system = await enter_game()
	expect(not system.manager.autosave, "Invalid save disables destructive auto-overwrite")
	expect(FileAccess.get_file_as_string(SAVE) == "{\"version\":999}", "Invalid file is preserved")
	expect(not system.manager.last_save_error.is_empty(), "Invalid save is explained to player")
	system.restart_quests()
	expect(system.manager.autosave and system.manager.last_save_error.is_empty(), "Explicit reset recovers autosave")
	await leave_game()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("QUEST_PERSISTENCE_TESTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
