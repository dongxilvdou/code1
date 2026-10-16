extends SceneTree
var checks := 0
var failures: Array[String] = []
const Kind = CalicoQuestObjective.Kind
const State = CalicoQuestManager.State

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func make_quest(id: String, count: int = 1) -> CalicoQuest:
	var quest := CalicoQuest.new()
	quest.id = StringName(id)
	quest.title = id
	var goal := CalicoQuestObjective.new()
	goal.id = &"goal"
	goal.kind = Kind.MEOW
	goal.target_count = count
	quest.objectives.append(goal)
	var reward := CalicoQuestResult.new()
	reward.kind = CalicoQuestResult.Kind.ADD_VALUE
	reward.key = &"score"
	reward.amount = 7
	quest.success_results.append(reward)
	return quest

func make_manager(quests: Array[CalicoQuest]) -> CalicoQuestManager:
	var catalog := CalicoQuestCatalog.new()
	catalog.quests = quests
	var manager := CalicoQuestManager.new()
	root.add_child(manager)
	expect(manager.configure(catalog), "Catalog configures: " + str(manager.validation_errors))
	manager.start_new_game()
	return manager

func run() -> void:
	var a := make_quest("a", 2)
	var b := make_quest("b")
	b.prerequisite_quests.append(a)
	var manager := make_manager([a, b])
	expect(manager.get_status(&"a") == State.ACTIVE and manager.get_status(&"b") == State.LOCKED, "Initial availability")
	manager.report_event(Kind.ENTER_ROOM, &"floor_1/kitchen")
	expect(manager.get_progress(&"a", &"goal") == 0, "Wrong events ignored")
	manager.report_event(Kind.MEOW, &"", 1, "one")
	manager.report_event(Kind.MEOW, &"", 1, "one")
	expect(manager.get_progress(&"a", &"goal") == 1, "Duplicate event ignored")
	manager.report_event(Kind.MEOW, &"", -1)
	expect(manager.get_progress(&"a", &"goal") == 1, "Negative progress ignored")
	manager.report_event(Kind.MEOW, &"", 99, "two")
	expect(manager.get_status(&"a") == State.COMPLETED and manager.values.score == 7, "Reward once and progress clamped")
	expect(manager.get_progress(&"b", &"goal") == 0 and manager.get_status(&"b") == State.ACTIVE, "Same event does not advance newly unlocked task")
	manager.report_event(Kind.MEOW, &"", 1, "two")
	expect(manager.values.score == 7 and manager.get_progress(&"b", &"goal") == 0, "Completion retry has no side effects")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(manager.make_save_data()))
	var restored := make_manager([a, b])
	expect(restored.restore_save_data(snapshot), "JSON roundtrip restores")
	expect(restored.values.score == 7 and restored.get_status(&"a") == State.COMPLETED, "Loading does not repeat rewards")
	restored.report_event(Kind.MEOW, &"", 1, "two")
	expect(restored.get_status(&"b") == State.ACTIVE, "Dedup survives save/load")
	var bad := snapshot.duplicate(true)
	bad.quests.a.progress.goal = -1
	expect(not restored.restore_save_data(bad) and restored.values.score == 7, "Corrupt progress rejected without changing state")
	bad = snapshot.duplicate(true)
	bad.values.score = "invalid"
	expect(not restored.restore_save_data(bad), "Malformed reward state rejected")
	bad = snapshot.duplicate(true)
	bad.version = 999
	expect(not restored.restore_save_data(bad), "Unknown save version rejected")
	restored.save_path = "user://quest_system_automated_tests/roundtrip.json"
	expect(restored.save_game(), "First atomic save")
	restored.report_event(Kind.MEOW, &"", 1, "three")
	expect(restored.save_game(), "Replace existing save")
	manager.save_path = restored.save_path
	expect(manager.load_game() and manager.values.score == 14, "Read persisted completion")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(restored.save_path))
	manager.free()
	restored.free()

	a = make_quest("a")
	b = make_quest("b")
	b.auto_accept = false
	var all_quest := make_quest("all")
	all_quest.prerequisite_quests.assign([a, b])
	var any_quest := make_quest("any")
	any_quest.auto_accept = false
	any_quest.prerequisite_mode = CalicoQuest.MatchMode.ANY
	any_quest.prerequisite_quests.assign([a, b])
	var gated := make_quest("gated")
	var flag := CalicoQuestCondition.new()
	flag.key = &"permission"
	gated.extra_conditions.append(flag)
	var threshold := CalicoQuestCondition.new()
	threshold.kind = CalicoQuestCondition.Kind.VALUE_AT_LEAST
	threshold.key = &"score"
	threshold.required_value = 10
	gated.extra_conditions.append(threshold)
	manager = make_manager([a, b, all_quest, any_quest, gated])
	expect(not manager.accept_quest(&"gated"), "Manual acceptance cannot bypass prerequisites")
	manager.report_event(Kind.MEOW)
	expect(manager.get_status(&"all") == State.LOCKED and manager.get_status(&"any") == State.AVAILABLE, "ALL versus ANY")
	expect(manager.accept_quest(&"b"), "Manual task accepts")
	manager.report_event(Kind.MEOW)
	expect(manager.get_status(&"all") == State.ACTIVE, "ALL unlocks after both complete")
	manager.set_flag(&"permission", true)
	expect(manager.get_status(&"gated") == State.ACTIVE, "Flag plus numeric threshold")
	manager.set_flag(&"permission", false)
	expect(manager.get_status(&"gated") == State.ACTIVE, "Accepted task stays active when prerequisite changes")
	var failure := CalicoQuestResult.new()
	failure.key = &"failed_flag"
	gated.failure_results.append(failure)
	var score: int = manager.values.score
	expect(manager.fail_quest(&"gated") and manager.flags.failed_flag, "Failure result executes")
	expect(not manager.fail_quest(&"gated") and manager.values.score == score, "Failure does not award success reward")
	manager.free()

	var room_quest := make_quest("room")
	room_quest.objectives[0].kind = Kind.ENTER_ROOM
	room_quest.objectives[0].room_id = "garden/any"
	manager = make_manager([room_quest])
	manager.report_event(Kind.ENTER_ROOM, &"floor_1/living")
	expect(manager.get_status(&"room") == State.ACTIVE, "Room target filter")
	manager.report_event(Kind.ENTER_ROOM, &"garden/north")
	expect(manager.get_status(&"room") == State.COMPLETED, "Garden wildcard")
	manager.free()

	var invalid := CalicoQuestCatalog.new()
	a = make_quest("cycle_a")
	b = make_quest("cycle_b")
	a.prerequisite_quests.append(b)
	b.prerequisite_quests.append(a)
	invalid.quests.assign([a, b])
	manager = CalicoQuestManager.new()
	expect(not manager.configure(invalid), "Cycle rejected")
	a.prerequisite_quests.clear()
	b.prerequisite_quests.clear()
	b.id = a.id
	expect(not manager.configure(invalid), "Duplicate quest IDs rejected")
	b.id = &"different"
	a.objectives.clear()
	expect(not manager.configure(invalid), "Empty objectives rejected")
	manager.free()
	manager = CalicoQuestManager.new()
	expect(manager.configure(load("res://quest_system/definitions/catalog.tres")), "Shipping task catalog loads and validates")
	manager.free()
	print("QUEST_UNIT_TESTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
