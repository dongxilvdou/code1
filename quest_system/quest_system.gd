extends Node
## 将 quest_system.tscn 添加到主场景根节点下，只添加一次。
@export var catalog: CalicoQuestCatalog
@export var player_path := NodePath("../Miso")
@export var map_path := NodePath("../VillaMap/MapHUD")
@export var save_file := "user://calico_quests_v1.json"
@export var save_enabled := true
@export_range(220, 420, 1) var tracker_width := 280.0
@export_range(4, 40, 1) var gap_below_map := 12.0
var manager: CalicoQuestManager
var tracker: Control
var game: Node
var player: Node
var map_hud: Control
var initialized := false
var session_started := false
var session_prepared := false
var menu_error := ""
var _last_room := ""
var _pending_doors: Dictionary = {}
var _messages: Array[String] = []
var _message_time := 0.0
var _journal_from_pause := false

func _ready() -> void:
	call_deferred("_connect_game")

func _connect_game() -> void:
	game = get_parent()
	player = get_node_or_null(player_path)
	map_hud = get_node_or_null(map_path) as Control
	if player == null or map_hud == null or not is_instance_valid(game.get("ui")):
		push_error("QuestSystem：请放在含 Miso 和 VillaMap 的主场景根节点下。")
		return
	manager = CalicoQuestManager.new()
	manager.name = "Manager"
	add_child(manager)
	var demo: Dictionary=get_tree().root.get_meta("calico_demo_session",{})
	if not demo.is_empty():
		save_file=demo.get("normal_save_file",save_file)
		save_enabled=false if demo.get("active",false) else bool(demo.get("normal_save_enabled",save_enabled))
	manager.save_path = save_file
	# 验证和截图使用独立、无存档模式，绝不改玩家任务进度。
	manager.autosave = save_enabled and not "--quest-test" in OS.get_cmdline_user_args()
	if not demo.is_empty():manager.autosave=false
	if not manager.configure(catalog):
		push_error("QuestSystem 配置错误：" + "；".join(manager.validation_errors))
		return
	var layer := CanvasLayer.new()
	layer.name = "QuestHUD"
	layer.layer = 13
	add_child(layer)
	tracker = load("res://quest_system/quest_tracker.gd").new()
	tracker.name = "Tracker"
	layer.add_child(tracker)
	tracker.setup(self)
	manager.quest_completed.connect(_on_completed)
	manager.quest_failed.connect(func(id: StringName): _messages.append("任务失败 · " + manager.definitions[id].title))
	manager.save_failed.connect(func(message: String):
		_messages.append("任务保存失败，请查看任务日志。")
		push_warning(message))
	player.meowed.connect(_on_meowed)
	# 父场景已先连接 interact()，这里收到信号时门的目标开合状态已更新。
	player.interacted.connect(_on_interacted)
	initialized = true
	game.refresh_save_menu()

func inspect_save() -> Dictionary:
	var info := {"exists":false,"valid":false,"day":1}
	if not initialized or not save_enabled:return info
	info.exists = FileAccess.file_exists(manager.save_path)
	if not info.exists:return info
	# Validate with an isolated manager. Opening the menu never changes player progress.
	var probe := CalicoQuestManager.new()
	if probe.configure(catalog):
		probe.save_path = manager.save_path
		info.valid = probe.load_game()
		if info.valid:info.day = int(probe.values.get("current_day",1))
	probe.free()
	return info

func prepare_session(new_game: bool) -> bool:
	menu_error = ""
	if not initialized or session_started:
		menu_error = "游戏尚未准备好，请稍后重试。"
		return false
	if not new_game:
		if not save_enabled or not manager.load_game():
			menu_error = "无法读取存档，原文件已保留。"
			return false
	else:
		# Back up before any reset or autosave can replace the user's existing file.
		if save_enabled and FileAccess.file_exists(manager.save_path):
			var path := ProjectSettings.globalize_path(manager.save_path)
			var error := DirAccess.copy_absolute(path,path+".bak")
			if error != OK:
				menu_error = "无法备份原存档，新游戏未开始："+error_string(error)
				return false
		manager.autosave = false
		manager.start_new_game()
		if save_enabled and not manager.save_game():
			menu_error = manager.last_save_error
			return false
	manager.autosave = save_enabled and not "--quest-test" in OS.get_cmdline_user_args()
	session_prepared = true
	return true

func save_current_progress() -> bool:
	menu_error = ""
	if not initialized or not session_started or not save_enabled:
		menu_error = "当前游戏无法保存。"
		return false
	var day := game.get_node_or_null("DayOne")
	if day:day.reconcile_progress()
	if not manager.save_game():
		menu_error = manager.last_save_error
		return false
	return true

func exploration_active() -> bool:
	return initialized and bool(game.started) and map_hud.available() and not map_hud.big_open and not tracker.journal_visible()

func _physics_process(delta: float) -> void:
	if not initialized: return
	if game.started and not session_started:
		session_started = true
		var exists := FileAccess.file_exists(manager.save_path)
		if not session_prepared and (not manager.autosave or not manager.load_game()):
			if manager.autosave and exists:
				# 保留坏文件供排查，停用自动覆盖；用户可以从日志主动重置。
				manager.autosave = false
				manager.last_save_error = "任务存档格式不兼容或损坏。已保留原文件；可在任务日志重置。"
				_messages.append(manager.last_save_error)
			manager.start_new_game()
	if not exploration_active(): return
	_message_time -= delta
	if _message_time <= 0.0 and not _messages.is_empty():
		tracker.show_notice(_messages.pop_front())
		_message_time = 3.5
	var room := current_room_id()
	if room != "" and room != _last_room:
		_last_room = room
		manager.report_event(CalicoQuestObjective.Kind.ENTER_ROOM, StringName(room))
	for id in _pending_doors.keys():
		var door: Variant = _pending_doors[id]
		if not is_instance_valid(door) or not door.is_open:
			_pending_doors.erase(id)
		elif not door.moving and not door.blocked:
			_pending_doors.erase(id)
			manager.report_event(CalicoQuestObjective.Kind.OPEN_DOOR, door.name)

func current_room_id() -> String:
	if map_hud.current_map.is_empty(): return ""
	var p: Vector3 = player.global_position
	var room: Dictionary = map_hud.room_at(map_hud.maps[map_hud.current_map], Vector2(p.x, p.z))
	return map_hud.current_map + "/" + str(room.get("id", "any"))

func _on_meowed() -> void:
	if exploration_active(): manager.report_event(CalicoQuestObjective.Kind.MEOW)

func _on_interacted() -> void:
	if not exploration_active(): return
	var door: Variant = game.nearest_door
	if is_instance_valid(door) and door.is_open: _pending_doors[door.get_instance_id()] = door

func _on_completed(id: StringName) -> void:
	var quest: CalicoQuest = manager.definitions[id]
	_messages.append("已完成 · " + quest.title + ("\n" + quest.result_text if not quest.result_text.is_empty() else ""))

func open_journal() -> void:
	if not initialized or not game.started or tracker.journal_visible(): return
	if game.cinematic_active:return
	if game.photo or game.inspecting or map_hud.big_open or game.ui.settings_panel.visible: return
	_journal_from_pause = game.ui.pause_panel.visible
	if not _journal_from_pause: game.toggle_pause()
	tracker.set_journal_visible(true)

func close_journal() -> void:
	tracker.set_journal_visible(false)
	if not _journal_from_pause:
		game.ui.pause_panel.hide()
		game.resume_game()

func restart_quests() -> void:
	manager.autosave = save_enabled and not "--quest-test" in OS.get_cmdline_user_args()
	manager.last_save_error = ""
	manager.start_new_game()
	_last_room = ""
	_pending_doors.clear()
	_messages.clear()
	tracker.show_notice("任务进度已重新开始")
	var day := game.get_node_or_null("DayOne")
	if day:day.restart_day()

func _input(event: InputEvent) -> void:
	if not initialized or not event is InputEventKey or not event.pressed or event.echo: return
	if tracker.confirmation.visible: return
	if event.keycode == KEY_J:
		if tracker.journal_visible(): close_journal()
		else: open_journal()
		if tracker.journal_visible() or (game.started and not game.ui.pause_panel.visible): get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and tracker.journal_visible():
		close_journal()
		get_viewport().set_input_as_handled()
