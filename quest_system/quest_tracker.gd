extends Control
const QuestTheme = preload("res://quest_system/quest_theme.gd")
const PAPER := QuestTheme.PAPER
const MUTED := QuestTheme.MUTED
const ACCENT := QuestTheme.BRASS
const GREEN := QuestTheme.SAGE
const STATUS := ["未解锁", "可接取", "进行中", "已完成", "已失败"]
var system: Node
var manager: CalicoQuestManager
var font: SystemFont
var panel: PanelContainer
var sidebar_column: VBoxContainer
var task_scroll: ScrollContainer
var task_list: VBoxContainer
var overflow_hint: Label
var footer: Label
var notice: Label
var journal: Control
var journal_list: VBoxContainer
var journal_summary: Label
var confirmation: ConfirmationDialog
var _notice_time := 0.0
var journal_panel: PanelContainer

func setup(owner_system: Node) -> void:
	system = owner_system
	manager = system.manager
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	panel = PanelContainer.new()
	panel.name = "TaskPanelBelowMinimap"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", QuestTheme.panel(14))
	add_child(panel)
	var column := VBoxContainer.new()
	sidebar_column = column
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	_label("探 索 手 记", 12, ACCENT, column)
	var scroll := ScrollContainer.new()
	task_scroll = scroll
	scroll.name = "TaskListViewport"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(scroll)
	task_list = VBoxContainer.new()
	task_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_list.add_theme_constant_override("separation", 12)
	scroll.add_child(task_list)
	overflow_hint = _label("更多目标请按 J 查看", 12, MUTED, column)
	overflow_hint.hide()
	notice = _label("", 13, GREEN, column)
	notice.hide()
	footer = _label("J  任务日志", 12, MUTED, column)
	_build_journal()
	manager.changed.connect(refresh)
	refresh()

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(.56, .62, .54, .30)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _label(value: String, font_size: int, color: Color, parent: Node) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(value: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size.y = 40
	QuestTheme.button(button)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _card(quest: CalicoQuest, parent: Node, detailed: bool) -> void:
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation", 5)
	parent.add_child(card)
	var status := manager.get_status(quest.id)
	var category := "主线" if quest.main_quest else "支线"
	_label((category + " · " if detailed else "") + quest.title, 17 if detailed else 15, PAPER, card)
	if detailed:
		_label(STATUS[status],12,GREEN if status == CalicoQuestManager.State.COMPLETED else ACCENT,card)
		_label(quest.description,15,MUTED,card)
	for goal in quest.objectives:
		var count := manager.get_progress(quest.id, goal.id)
		var complete := count >= goal.target_count
		_label(("✓ " if complete else "○ ") + goal.text + "  %d/%d" % [count, goal.target_count], 14, GREEN if complete else PAPER, card)
		card.add_child(QuestTheme.progress(count,goal.target_count))
	if detailed:
		var requirements := PackedStringArray()
		for prerequisite in quest.prerequisite_quests: requirements.append(prerequisite.title)
		if not requirements.is_empty():
			_label("前置（" + ("全部" if quest.prerequisite_mode == CalicoQuest.MatchMode.ALL else "任意") + "）：" + "、".join(requirements), 13, MUTED, card)
		if not quest.result_text.is_empty(): _label("接下来 · " + quest.result_text, 13, ACCENT, card)
		if status == CalicoQuestManager.State.AVAILABLE:
			_button("接取任务", card, func(): manager.accept_quest(quest.id))
		var divider := HSeparator.new()
		card.add_child(divider)

func refresh() -> void:
	_clear(task_list)
	var count := 0
	var available := 0
	var completed := 0
	for quest in manager.sorted_quests():
		if not relevant_today(quest):continue
		var status := manager.get_status(quest.id)
		if status == CalicoQuestManager.State.COMPLETED: completed += 1
		if status == CalicoQuestManager.State.AVAILABLE: available += 1
		if status == CalicoQuestManager.State.ACTIVE:
			if count < 2: _card(quest, task_list, false)
			count += 1
	if count == 0: _label("这段探索已经完成" if completed == manager.definitions.size() else "暂无进行中的任务", 16, PAPER, task_list)
	footer.text = "J  任务日志   ·   积分 %d" % int(manager.values.get("exploration_points", 0))
	if count > 2: footer.text += "\n另有 %d 个进行中任务" % (count - 2)
	if available > 0: footer.text += "\n%d 个任务可接取" % available
	if journal_visible(): _refresh_journal()

func relevant_today(quest: CalicoQuest) -> bool:
	var today := int(manager.values.get("current_day",1))
	if today>=6 and not str(quest.id).begins_with("a%d_"%today):return false
	return true

func _build_journal() -> void:
	journal = Control.new()
	journal.name = "QuestJournal"
	journal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(journal)
	var shade := ColorRect.new()
	shade.color = Color(.025,.020,.015,.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journal.add_child(shade)
	journal_panel = PanelContainer.new()
	journal_panel.add_theme_stylebox_override("panel",QuestTheme.panel(28))
	journal.add_child(journal_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	journal_panel.add_child(column)
	_label("哈 基 米 模 拟 器   /   探 索",12,ACCENT,column)
	_label("探索手记", 28, PAPER, column)
	journal_summary = _label("", 15, ACCENT, column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	journal_list = VBoxContainer.new()
	journal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_list.add_theme_constant_override("separation", 14)
	scroll.add_child(journal_list)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_button("返回游戏 / J / Esc", buttons, system.close_journal)
	_button("重新开始任务…", buttons, func(): confirmation.popup_centered(Vector2i(440, 170)))
	confirmation = ConfirmationDialog.new()
	confirmation.title = "重新开始任务"
	confirmation.dialog_text = "清除任务进度、任务标记和探索积分？\n角色位置与房屋保持当前状态。"
	confirmation.ok_button_text = "重新开始"
	confirmation.cancel_button_text = "取消"
	confirmation.add_theme_font_override("font", font)
	confirmation.confirmed.connect(system.restart_quests)
	journal.add_child(confirmation)
	journal.hide()

func _refresh_journal() -> void:
	_clear(journal_list)
	journal_summary.text = "探索积分：%d    ·    任务进度自动保存" % int(manager.values.get("exploration_points", 0))
	if not manager.autosave: journal_summary.text = "探索积分：%d    ·    当前未启用自动保存" % int(manager.values.get("exploration_points", 0))
	if not manager.last_save_error.is_empty(): journal_summary.text += "\n" + manager.last_save_error
	for state in [CalicoQuestManager.State.ACTIVE,CalicoQuestManager.State.AVAILABLE,CalicoQuestManager.State.LOCKED,CalicoQuestManager.State.COMPLETED,CalicoQuestManager.State.FAILED]:
		for quest in manager.sorted_quests():
			if manager.get_status(quest.id) == state:_card(quest, journal_list, true)

func journal_visible() -> bool:
	return is_instance_valid(journal) and journal.visible

func set_journal_visible(value: bool) -> void:
	journal.visible = value
	if value: _refresh_journal()

func show_notice(message: String) -> void:
	notice.text = message
	notice.show()
	_notice_time = 4.0

func _box_height(box: VBoxContainer) -> float:
	# ScrollContainer 的最小高度不包含内容，所以单独测量目标列表。
	# 逐项计算也避免 hide()/show() 后 Container 最小尺寸的延迟更新。
	var height := 0.0
	var count := 0
	for child in box.get_children():
		if not child is Control or not child.visible: continue
		count += 1
		if child == task_scroll: continue
		if child is VBoxContainer:
			height += _box_height(child)
		else:
			# get_minimum_size() 立即重算刚改变宽度的 Label 换行高度。
			height += maxf(child.custom_minimum_size.y, child.get_minimum_size().y)
	return height + maxi(0, count - 1) * box.get_theme_constant("separation")

func _sidebar_height() -> float:
	var padding := panel.get_theme_stylebox("panel").get_minimum_size().y
	return ceilf(padding + _box_height(sidebar_column) + (_box_height(task_list) if task_scroll.visible else 0.0)) + 2.0

func _fold_last_row() -> bool:
	var cards := task_list.get_children()
	cards.reverse()
	for card in cards:
		if not card is Control or not card.visible: continue
		if card is VBoxContainer:
			var rows: Array = card.get_children().filter(func(row): return row is Control and row.visible)
			# 保留任务标题和至少一个目标；否则折叠整个任务卡片。
			if rows.size() > 2:
				rows.back().hide()
				return true
		card.hide()
		return true
	return false

func _process(delta: float) -> void:
	if not is_instance_valid(system): return
	var viewport := get_viewport_rect().size
	var journal_size := Vector2(minf(1000,viewport.x-64),viewport.y-64)
	journal_panel.position = (viewport-journal_size)*.5
	journal_panel.size = journal_size
	panel.visible = system.exploration_active()
	if not panel.visible: return
	_notice_time -= delta
	notice.visible = _notice_time > 0
	# The story card already explains the active main objective. Keep the map
	# area quiet; this sidebar remains available for side quests and notices.
	var story = system.game.get_node_or_null("DayOne")
	var has_side_quest := false
	for quest in manager.sorted_quests():
		if relevant_today(quest) and not quest.main_quest and manager.get_status(quest.id)==CalicoQuestManager.State.ACTIVE:has_side_quest = true
	var story_card: bool = story != null and story.initialized and story.hud.card.visible and not has_side_quest
	task_scroll.visible = not story_card
	footer.visible = not story_card
	(sidebar_column.get_child(0) as Label).text = "手记已更新" if story_card else "探 索 手 记"
	if story_card and not notice.visible:
		panel.hide()
		return
	var map_card: Control = system.map_hud.mini_back
	var rect := map_card.get_global_rect()
	panel.position = Vector2(rect.position.x, rect.end.y + system.gap_below_map)
	var width := minf(system.tracker_width, get_viewport_rect().size.x - panel.position.x - 24)
	var available_height := maxf(0, get_viewport_rect().size.y - panel.position.y - 82)
	panel.size.x = width
	# 自动换行的高度依赖最终宽度；第一次显示时也先给文字分配宽度。
	var content_width := maxf(1, width - panel.get_theme_stylebox("panel").get_minimum_size().x)
	for label in sidebar_column.find_children("*", "Label", true, false):
		label.size.x = content_width
	# 每次重新考虑全部行，窗口变大或提示消失后自动展开。
	for card in task_list.get_children():
		if not card is Control: continue
		card.show()
		for row in card.get_children():
			if row is Control: row.show()
	overflow_hint.hide()
	var desired := _sidebar_height()
	# 空间紧张时优先保留当前目标，短暂的完成提示可以收起。
	if desired > available_height and notice.visible:
		notice.hide()
		desired = _sidebar_height()
	if desired > available_height:
		overflow_hint.show()
		desired = _sidebar_height()
		while desired > available_height and _fold_last_row():
			desired = _sidebar_height()
	# 不用硬裁切留下半行文字；极小空间下仍可使用 J 打开日志。
	panel.visible = desired <= available_height
	panel.size = Vector2(width, minf(maxf(80 if story_card else 150, desired), available_height))
