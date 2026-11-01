extends CanvasLayer
const QuestSkin=preload("res://quest_system/quest_theme.gd")
var shell: Control
var title: Label
var message: Label
var pause_box: VBoxContainer
var progress: ProgressBar
signal resume_requested
signal exit_requested
func _ready() -> void:
 layer=60;shell=Control.new();add_child(shell);shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shell.mouse_filter=Control.MOUSE_FILTER_IGNORE;shell.theme=QuestSkin.resource()
 var panel=PanelContainer.new();shell.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);panel.offset_left=-350;panel.offset_right=350;panel.offset_top=-190;panel.offset_bottom=-28;panel.add_theme_stylebox_override("panel",QuestSkin.panel(18))
 var column=VBoxContainer.new();panel.add_child(column)
 title=Label.new();column.add_child(title);title.add_theme_font_size_override("font_size",20)
 message=Label.new();column.add_child(message);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.add_theme_font_size_override("font_size",15)
 progress=QuestSkin.progress(0,100);column.add_child(progress)
 pause_box=VBoxContainer.new();column.add_child(pause_box)
 var row=HBoxContainer.new();pause_box.add_child(row)
 for item in [["继续操作",resume_requested],["暂时离开（保留进度）",exit_requested]]:
  var b=Button.new();b.text=item[0];row.add_child(b);QuestSkin.button(b);b.pressed.connect(item[1].emit)
 pause_box.hide();shell.hide()
func show_hint(title_: String,text: String) -> void:
 title.text=title_;message.text=text;shell.show()
func set_paused(paused: bool) -> void:pause_box.visible=paused
