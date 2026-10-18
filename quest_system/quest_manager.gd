class_name CalicoQuestManager
extends Node
## 任务配置只读。所有进度、标记和积分在本节点中保存。
signal changed
signal quest_completed(quest_id: StringName)
signal quest_failed(quest_id: StringName)
signal custom_result(event_id: StringName)
signal save_failed(message: String)
enum State { LOCKED, AVAILABLE, ACTIVE, COMPLETED, FAILED }
const SAVE_VERSION := 1
const MAX_EVENT_HISTORY := 1024
var catalog: CalicoQuestCatalog
var definitions: Dictionary = {}
var states: Dictionary = {}
var flags: Dictionary = {}
var values: Dictionary = {}
var validation_errors: PackedStringArray = []
var save_path := "user://calico_quests_v1.json"
var autosave := false
var last_save_error := ""
var _seen_events: Array = []
var _busy := false

func configure(source: CalicoQuestCatalog) -> bool:
	validation_errors.clear()
	definitions.clear()
	if source == null:
		validation_errors.append("未指定任务目录 Catalog。")
		return false
	catalog = source
	for quest in source.quests:
		if quest == null or quest.id == &"":
			validation_errors.append("存在空任务或空任务 ID。")
			continue
		if definitions.has(quest.id):
			validation_errors.append("重复任务 ID：" + str(quest.id))
		definitions[quest.id] = quest
	for quest in source.quests:
		if quest == null: continue
		if quest.objectives.is_empty(): validation_errors.append(str(quest.id) + " 没有目标。")
		var ids := {}
		for goal in quest.objectives:
			if goal == null or goal.id == &"" or goal.target_count < 1:
				validation_errors.append(str(quest.id) + " 存在无效目标。")
				continue
			if ids.has(goal.id): validation_errors.append(str(quest.id) + " 存在重复目标 ID。")
			ids[goal.id] = true
		for dependency in quest.prerequisite_quests:
			if dependency == null or not definitions.has(dependency.id):
				validation_errors.append(str(quest.id) + " 的前置任务未加入 Catalog。")
		for condition in quest.extra_conditions:
			if condition == null or condition.key == &"": validation_errors.append(str(quest.id) + " 存在空前置条件。")
		for result in quest.success_results + quest.failure_results:
			if result == null or result.key == &"": validation_errors.append(str(quest.id) + " 存在空结果。")
	var visited := {}
	for id in definitions: _check_cycle(id, {}, visited)
	if not validation_errors.is_empty(): return false
	_reset_state()
	return true

func _check_cycle(id: StringName, path: Dictionary, visited: Dictionary) -> void:
	if path.has(id):
		validation_errors.append("循环前置关系：" + str(id))
		return
	if visited.has(id): return
	path[id] = true
	for dependency in definitions[id].prerequisite_quests:
		if dependency != null and definitions.has(dependency.id): _check_cycle(dependency.id, path, visited)
	path.erase(id)
	visited[id] = true

func _reset_state() -> void:
	states.clear()
	flags.clear()
	values.clear()
	_seen_events.clear()
	for id in definitions:
		var counts := {}
		for goal in definitions[id].objectives: counts[str(goal.id)] = 0
		states[id] = {"status": State.LOCKED, "progress": counts}

func start_new_game() -> void:
	if _busy: return
	_reset_state()
	_refresh_available()
	_commit()

func get_status(id: StringName) -> int:
	return int(states.get(id, {}).get("status", State.LOCKED))

func get_progress(id: StringName, objective_id: StringName) -> int:
	return int(states.get(id, {}).get("progress", {}).get(str(objective_id), 0))

func prerequisites_met(quest: CalicoQuest) -> bool:
	var passed := 0
	for dependency in quest.prerequisite_quests:
		if get_status(dependency.id) == State.COMPLETED: passed += 1
	if not quest.prerequisite_quests.is_empty():
		if quest.prerequisite_mode == CalicoQuest.MatchMode.ALL and passed != quest.prerequisite_quests.size(): return false
		if quest.prerequisite_mode == CalicoQuest.MatchMode.ANY and passed == 0: return false
	for condition in quest.extra_conditions:
		match condition.kind:
			CalicoQuestCondition.Kind.FLAG_EQUALS:
				if bool(flags.get(str(condition.key), false)) != condition.expected_flag: return false
			CalicoQuestCondition.Kind.VALUE_AT_LEAST:
				if int(values.get(str(condition.key), 0)) < condition.required_value: return false
	return true

func _refresh_available() -> void:
	for id in definitions:
		if get_status(id) not in [State.LOCKED, State.AVAILABLE]: continue
		var quest: CalicoQuest = definitions[id]
		states[id].status = (State.ACTIVE if quest.auto_accept else State.AVAILABLE) if prerequisites_met(quest) else State.LOCKED

func accept_quest(id: StringName) -> bool:
	if _busy or not definitions.has(id) or get_status(id) not in [State.LOCKED, State.AVAILABLE]: return false
	if not prerequisites_met(definitions[id]): return false
	states[id].status = State.ACTIVE
	_commit()
	return true

func set_flag(key: StringName, value: bool) -> void:
	if _busy: return
	flags[str(key)] = value
	_refresh_available()
	_commit()

func set_value(key: StringName, value: int) -> void:
	if _busy: return
	values[str(key)] = value
	_refresh_available()
	_commit()

func report_event(kind: int, target: StringName = &"", amount: int = 1, event_id: String = "") -> void:
	if _busy or amount <= 0 or (not event_id.is_empty() and event_id in _seen_events): return
	_busy = true
	var dirty := false
	var finished: Array[StringName] = []
	var effects: Array[StringName] = []
	# 冻结本次事件开始时的任务集合，避免同一事件推进刚解锁的任务。
	var active: Array = states.keys().filter(func(id): return get_status(id) == State.ACTIVE)
	for id in active:
		var quest: CalicoQuest = definitions[id]
		for goal in quest.objectives:
			if int(goal.kind) != kind: continue
			var wanted := StringName(goal.room_id) if goal.kind == CalicoQuestObjective.Kind.ENTER_ROOM else goal.target_id
			var matches_group := str(wanted).ends_with("/any") and str(target).begins_with(str(wanted).trim_suffix("any"))
			if wanted != &"" and wanted != &"any" and wanted != target and not matches_group: continue
			var old := get_progress(id, goal.id)
			var count := mini(old + amount, goal.target_count)
			states[id].progress[str(goal.id)] = count
			dirty = dirty or count != old
		var done := true
		for goal in quest.objectives:
			if get_progress(id, goal.id) < goal.target_count: done = false
		if done:
			states[id].status = State.COMPLETED
			_apply_results(quest.success_results, effects)
			finished.append(id)
	if not event_id.is_empty():
		_seen_events.append(event_id)
		if _seen_events.size() > MAX_EVENT_HISTORY: _seen_events.pop_front()
		# 保存去重记录，即使这次事件没有匹配目标。
		dirty = true
	_refresh_available()
	if dirty: _commit()
	# 内部结算及存档完成后才允许外部订阅者响应；重入不会重复结算。
	_busy = false
	for id in finished: quest_completed.emit(id)
	for key in effects: custom_result.emit(key)

func fail_quest(id: StringName) -> bool:
	if _busy or get_status(id) != State.ACTIVE: return false
	_busy = true
	states[id].status = State.FAILED
	var effects: Array[StringName] = []
	_apply_results(definitions[id].failure_results, effects)
	_refresh_available()
	_commit()
	_busy = false
	quest_failed.emit(id)
	for key in effects: custom_result.emit(key)
	return true

func _apply_results(results: Array[CalicoQuestResult], effects: Array[StringName]) -> void:
	for result in results:
		var key := str(result.key)
		match result.kind:
			CalicoQuestResult.Kind.SET_FLAG: flags[key] = result.flag_value
			CalicoQuestResult.Kind.ADD_VALUE: values[key] = int(values.get(key, 0)) + result.amount
			CalicoQuestResult.Kind.EMIT_EVENT: effects.append(result.key)

func sorted_quests() -> Array[CalicoQuest]:
	var quests: Array[CalicoQuest] = catalog.quests.duplicate()
	quests.sort_custom(func(a: CalicoQuest, b: CalicoQuest):
		if a.main_quest != b.main_quest: return a.main_quest
		if a.priority != b.priority: return a.priority > b.priority
		return str(a.id) < str(b.id))
	return quests

func _commit() -> void:
	if autosave and not save_game(): save_failed.emit(last_save_error)
	changed.emit()

func make_save_data() -> Dictionary:
	return {"version": SAVE_VERSION, "paper_layout": 2, "quests": states.duplicate(true), "flags": flags.duplicate(), "values": values.duplicate(), "seen_events": _seen_events.duplicate()}

func restore_save_data(data: Dictionary) -> bool:
	# 先验证完整数据，再修改当前游戏；坏存档不会污染正在运行的状态。
	if data.get("version") != SAVE_VERSION: return false
	for key in ["quests", "flags", "values"]:
		if not data.get(key) is Dictionary: return false
	if not data.get("seen_events", []) is Array: return false
	for key in data.flags:
		if not data.flags[key] is bool: return false
	for key in data.values:
		if not _whole_number(data.values[key]): return false
	for event in data.get("seen_events", []):
		if not event is String: return false
	# Only migrate the former 17-paper layout. Never change the caller's save.
	data = data.duplicate(true)
	if data.get("paper_layout",1) == 1 and definitions.has(&"day1_papers") and data.quests.has("day1_papers"):
		var papers: Variant = data.quests.get("day1_papers",{})
		if not papers is Dictionary or not papers.get("progress") is Dictionary:return false
		var old_count: Variant = papers.progress.get("collect_paper",0)
		if not _whole_number(old_count) or old_count < 0 or old_count > 17:return false
		var finished: bool = papers.get("status") == State.COMPLETED or data.flags.get("papers_done",false)
		var new_count := 0
		for spot in ["living","dining","kitchen","study1"]:
			if finished:data.flags["paper_"+spot] = true
			if data.flags.get("paper_"+spot,false):new_count += 1
		papers.progress["collect_paper"] = new_count
		if new_count == 4:
			data.flags["papers_done"] = true
			papers.status = State.COMPLETED
	for id in definitions:
		if not data.quests.has(str(id)): continue
		var entry: Variant = data.quests[str(id)]
		if not entry is Dictionary or not entry.get("progress") is Dictionary: return false
		if not _whole_number(entry.get("status")) or int(entry.status) < State.LOCKED or int(entry.status) > State.FAILED: return false
		for goal in definitions[id].objectives:
			var count: Variant = entry.progress.get(str(goal.id), 0)
			if not _whole_number(count) or count < 0 or count > goal.target_count: return false
	_reset_state()
	flags = data.flags.duplicate()
	for key in data.values:
		if key != "cleanliness":values[key] = int(data.values[key])
	_seen_events = data.get("seen_events", []).slice(-MAX_EVENT_HISTORY)
	for id in definitions:
		if not data.quests.has(str(id)): continue
		var entry: Dictionary = data.quests[str(id)]
		states[id].status = int(entry.status)
		for goal in definitions[id].objectives: states[id].progress[str(goal.id)] = int(entry.progress.get(str(goal.id), 0))
	_refresh_available()
	changed.emit()
	return true

func _whole_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func save_game() -> bool:
	last_save_error = ""
	var path := ProjectSettings.globalize_path(save_path)
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK: return _save_error("无法创建任务存档目录：" + error_string(error))
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return _save_error("无法写入任务存档：" + error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(make_save_data(), "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK: return _save_error("任务存档写入失败：" + error_string(error))
	error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK: return _save_error("任务存档替换失败：" + error_string(error))
	return true

func _save_error(message: String) -> bool:
	last_save_error = message
	return false

func load_game() -> bool:
	if not FileAccess.file_exists(save_path): return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(save_path)) != OK:return false
	var parsed: Variant = parser.data
	return parsed is Dictionary and restore_save_data(parsed)
