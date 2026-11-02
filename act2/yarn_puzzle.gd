extends PanelContainer
signal completed
const Rules=preload("res://act2/yarn_rules.gd")
const Board=preload("res://act2/yarn_board.gd")
const ThemeKit=preload("res://quest_system/quest_theme.gd")
var chapter
var rules=Rules.new()
var board: Control
var history: Array[int]=[]
var removed: Dictionary={}
var status: Label
var progress: Label
var zoom_label: Label
var undo_button: Button
var meter: ProgressBar

func _ready() -> void:
 add_theme_stylebox_override("panel",ThemeKit.panel(22))
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",14);add_child(column)
 var heading=HBoxContainer.new();column.add_child(heading)
 var title=caption("毛线里的秘密 / 折线迷宫",23,heading);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 action("返回 · Esc",heading,func():chapter.puzzle.close())
 var body=HBoxContainer.new();body.add_theme_constant_override("separation",22)
 body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
 board=Board.new();body.add_child(board);board.selected.connect(pull_thread)
 var sidebar=VBoxContainer.new();sidebar.custom_minimum_size.x=242;sidebar.add_theme_constant_override("separation",12);body.add_child(sidebar)
 caption("%d × %d  ·  %d 根线"%[Rules.WIDTH,Rules.HEIGHT,Rules.THREADS.size()],20,sidebar)
 caption("找出能抽走的线头，\n一层一层解开这个结。",15,sidebar)
 sidebar.add_child(HSeparator.new())
 caption("点击线身或箭头。线头沿箭头方向离开，线身顺着原来的折线收回。\n\n箭头前方若有其他线的任何一段，就会被挡住。先解开挡路的那根线。",15,sidebar)
 caption("悬停高亮整根线\n滚轮缩放 · 右键 / 中键拖动",13,sidebar)
 var zoom_row=HBoxContainer.new();sidebar.add_child(zoom_row)
 action("缩小 －",zoom_row,func():board.zoom_at(1.0/1.25,board.size*.5))
 action("放大 ＋",zoom_row,func():board.zoom_at(1.25,board.size*.5))
 zoom_label=caption("",13,sidebar)
 action("查看全图",sidebar,board.fit_view)
 var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;sidebar.add_child(spacer)
 progress=caption("",18,sidebar)
 meter=ProgressBar.new();meter.max_value=Rules.THREADS.size();meter.show_percentage=false;meter.custom_minimum_size.y=8;sidebar.add_child(meter)
 var rail=StyleBoxFlat.new();rail.bg_color=Color("e1d6c4");rail.set_corner_radius_all(4);meter.add_theme_stylebox_override("background",rail)
 var fill=rail.duplicate();fill.bg_color=Color("287a83");meter.add_theme_stylebox_override("fill",fill)
 undo_button=action("撤销上一步",sidebar,undo_thread)
 action("重新开始",sidebar,reset_threads)
 status=caption("",14,column);status.custom_minimum_size.y=44
 board.zoom_changed.connect(update_zoom)
 minimum_size_changed.connect(func():call_deferred("layout_panel"))
 resized.connect(layout_panel)
 get_viewport().size_changed.connect(layout_panel)
 hide();layout_panel()
func layout_panel() -> void:
 var viewport=get_viewport_rect().size
 size=Vector2(minf(1180,viewport.x-48),viewport.y-48)
 position=(viewport-size)*.5
func caption(text: String,font_size: int,parent: Node) -> Label:
 var label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.custom_minimum_size.x=220
 label.add_theme_font_size_override("font_size",font_size);parent.add_child(label)
 return label
func action(text: String,parent: Node,callback: Callable) -> Button:
 var button=Button.new();button.text=text;button.custom_minimum_size.y=36;button.focus_mode=Control.FOCUS_ALL
 ThemeKit.button(button);parent.add_child(button);button.pressed.connect(callback)
 return button
func open_puzzle(owner_) -> void:
 chapter=owner_;history.clear();removed.clear();board.clear_effects();board.removed=removed;board.fit_view()
 var old=chapter.val("yarn_v2_steps",0)>0
 if chapter.val("yarn_v3_version")==Rules.VERSION:
  var count=clampi(chapter.val("yarn_v3_steps"),0,Rules.THREADS.size())
  for step in range(count):
   var id=chapter.val("yarn_v3_history_%d"%step,-1)
   if id<0 or id>=Rules.THREADS.size() or removed.has(id) or rules.blocker(id,removed)>=0:break
   history.append(id);removed[id]=true
  status.text="进度已恢复。沿着线身追踪线头，看看前方被谁挡住了。"
  if history.size()!=count or chapter.val("yarn_v3_steps")!=count:
   save_threads();status.text="已恢复到最近一次有效的解线进度。"
 else:
  save_threads()
  status.text="毛线换成了新的密结，本关从头开始，其他任务进度保留。" if old else "从没有被挡住的线头开始。每解开一根线，都可能给其他线让出通路。"
 show();layout_panel();update_progress();update_zoom();board.queue_redraw()
 # Recover a save made after the final pull but before the quest flag was published.
 if history.size()==Rules.THREADS.size() and not chapter.flag("yarn_solved"):call_deferred("finish_if_complete")
func finish_if_complete() -> void:
 if visible and chapter.puzzle.mode=="yarn" and history.size()==Rules.THREADS.size():completed.emit()
func pull_thread(id: int) -> void:
 if not visible or id<0 or id>=Rules.THREADS.size() or removed.has(id):return
 var cell=rules.blocking_cell(id,removed)
 if cell>=0:
  board.show_blocker(id,cell)
  status.text="抽不动：箭头前方被红色的线挡住了。沿着那根线找到它的线头。"
  return
 history.append(id);removed[id]=true;save_threads();board.animate_pull(id);update_progress()
 status.text="线头抽出来了，新的通路露了出来。还剩 %d 根线。"%(Rules.THREADS.size()-history.size())
 if history.size()==Rules.THREADS.size():completed.emit()
func save_threads() -> void:
 # One atomic autosave; an array of IDs avoids the 64-bit mask limit.
 var values: Dictionary=chapter.day.manager.values
 for i in range(Rules.THREADS.size()):
  var key="yarn_v3_history_%d"%i
  if i<history.size():values[key]=history[i]
  else:values.erase(key)
 values["yarn_v3_version"]=Rules.VERSION
 chapter.set_value("yarn_v3_steps",history.size())
func undo_thread() -> void:
 if history.is_empty():return
 var id: int=history.pop_back();removed.erase(id);board.clear_effects();save_threads();update_progress()
 status.text="已放回上一根线。可以重新观察它与其他线的关系。"
func reset_threads() -> void:
 history.clear();removed.clear();board.clear_effects();save_threads();board.fit_view();update_progress()
 status.text="毛线已恢复原状。先找箭头前方没有其他线的线头。"
func update_progress() -> void:
 progress.text="已解开 %d / %d"%[history.size(),Rules.THREADS.size()]
 meter.value=history.size();undo_button.disabled=history.is_empty();board.queue_redraw()
func update_zoom() -> void:zoom_label.text="视图 %d%% · Esc 返回时自动保留进度"%roundi(board.zoom*100)
func suspend() -> void:
 board.clear_effects();hide()
