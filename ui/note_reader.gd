extends CanvasLayer
const Catalog=preload("res://ui/notes_catalog.gd")
const QuestSkin=preload("res://quest_system/quest_theme.gd")
var day
var shell: Control
var panel: PanelContainer
var image: TextureRect
var text: Label
var title: Label
var list: VBoxContainer
var scroll: ScrollContainer
var confirm: Button
var mode=""
var selected=""
var zoomed=false
var text_mode=false
var snapshot: Dictionary={}
func _ready() -> void:
 layer=65
 shell=Control.new();add_child(shell);shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shell.theme=QuestSkin.resource()
 var shade=ColorRect.new();shell.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.62)
 var center=CenterContainer.new();shell.add_child(center);center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel=PanelContainer.new();center.add_child(panel);panel.add_theme_stylebox_override("panel",QuestSkin.panel(22))
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);panel.add_child(column)
 title=Label.new();column.add_child(title);title.add_theme_font_size_override("font_size",22)
 var row=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(row)
 var list_scroll=ScrollContainer.new();row.add_child(list_scroll);list_scroll.custom_minimum_size.x=210;list_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 list=VBoxContainer.new();list_scroll.add_child(list);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll=ScrollContainer.new();row.add_child(scroll);scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
 var contents=VBoxContainer.new();scroll.add_child(contents);contents.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 image=TextureRect.new();contents.add_child(image);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 text=Label.new();contents.add_child(text);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.add_theme_font_size_override("font_size",19)
 var controls=HBoxContainer.new();column.add_child(controls)
 make_button("放大 / 还原",controls,func():zoomed=not zoomed;layout())
 make_button("图片 / 清晰文字",controls,func():text_mode=not text_mode;layout())
 confirm=make_button("",controls,accept)
 make_button("返回 · Esc",controls,cancel)
 shell.hide()
func make_button(label_: String,parent: Node,action: Callable) -> Button:
 var b=Button.new();b.text=label_;b.custom_minimum_size.y=38;parent.add_child(b);QuestSkin.button(b);b.pressed.connect(action);return b
func begin(kind: String) -> void:
 if mode.is_empty():snapshot={"cinematic":day.game.cinematic_active,"control":day.player.active,"mouse":Input.mouse_mode,"focus":get_viewport().gui_get_focus_owner()}
 if kind=="album":
  var style=StyleBoxTexture.new();style.texture=Catalog.load_image("res://assets/notes/album_surface.png");style.region_rect=Rect2(90,100,1356,820)
  for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(side,26)
  panel.add_theme_stylebox_override("panel",style)
 else:panel.add_theme_stylebox_override("panel",QuestSkin.panel(22))
 mode=kind;day.game.cinematic_active=true;day.player.set_control(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 shell.show();zoomed=false;text_mode=false
func open_daily(number: int) -> void:
 begin("daily");show_entry("day%d"%number);rebuild_list(false)
 confirm.text="我读完了，开始今天任务 · E";confirm.show();confirm.grab_focus()
func open_sheet(id: String) -> void:
 begin("sheet");show_entry(id);rebuild_list(false);confirm.text="收起 · E";confirm.show()
func open_album() -> void:
 begin("album");rebuild_list(true)
 var ids=Catalog.collected(day)
 show_entry(ids[-1] if not ids.is_empty() else "")
 confirm.hide()
func rebuild_list(album: bool) -> void:
 for child in list.get_children():list.remove_child(child);child.queue_free()
 list.get_parent().visible=album
 if not album:return
 var heading=Label.new();heading.text="收好的线索";list.add_child(heading)
 for id in Catalog.collected(day):
  var b=make_button(Catalog.data(id).title,list,show_entry.bind(id));b.custom_minimum_size.x=195;b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var found=0
 for key in Catalog.PAPER_KEYS:
  if day.flag("paper_"+key) or day.flag("papers_done"):found+=1
 var count=Label.new();count.text="第一天纸片：%d / 4\nC 随时翻阅线索册"%found;list.add_child(count)
func show_entry(id: String) -> void:
 selected=id
 var entry=Catalog.data(id);title.text=entry.title;text.text=entry.text
 image.texture=Catalog.texture(id) if not id.is_empty() else null
 scroll.scroll_vertical=0;scroll.scroll_horizontal=0;layout()
func layout() -> void:
 if shell==null:return
 var viewport=get_viewport().get_visible_rect().size
 panel.custom_minimum_size=Vector2(minf(1080,viewport.x-50),minf(780,viewport.y-55))
 var width=panel.custom_minimum_size.x-(270 if mode=="album" else 65)
 image.custom_minimum_size=Vector2(width*(1.5 if zoomed else 1.0),(panel.custom_minimum_size.y-120)*(1.5 if zoomed else 1.0))
 image.visible=not text_mode and image.texture!=null
 text.visible=text_mode or image.texture==null
 text.custom_minimum_size=Vector2(width,150)
func _process(_delta: float) -> void:
 if not mode.is_empty():layout()
func accept() -> void:
 var daily=mode=="daily";close()
 if daily:day.advance_dialog()
func cancel() -> void:
 var daily=mode=="daily";close()
 if daily:day.dialog="";day.refresh_hud()
func close() -> void:
 if mode.is_empty():return
 mode="";shell.hide()
 day.game.cinematic_active=snapshot.get("cinematic",false);day.player.set_control(snapshot.get("control",true));Input.mouse_mode=snapshot.get("mouse",Input.MOUSE_MODE_CAPTURED)
 var focus=snapshot.get("focus")
 if is_instance_valid(focus) and focus is Control and focus.is_visible_in_tree():focus.grab_focus()
 snapshot.clear()
func _input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo:return
 if mode.is_empty():
  if event.keycode==KEY_C and day.active_play():open_album();get_viewport().set_input_as_handled()
  return
 if event.keycode==KEY_ESCAPE:cancel()
 elif event.keycode in [KEY_E,KEY_ENTER,KEY_SPACE] and mode!="album":accept()
 elif event.keycode==KEY_C:cancel()
 else:
  get_viewport().set_input_as_handled();return
 get_viewport().set_input_as_handled()
