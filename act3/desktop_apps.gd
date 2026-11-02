extends Control
const DeskTheme=preload("res://act3/computer_theme.gd")
const Data=preload("res://act3/investigation_data.gd")
var computer
var panel: PanelContainer
var heading: Label
var toolbar: VBoxContainer
var scroll: ScrollContainer
var body: VBoxContainer
var status: Label
var address: LineEdit
var file_tree: Tree
var app=""
var page=""
var browser_page="site"
var zoomed=false
var history: Array=[]
var maximized=false
var moving=false
var custom_position=Vector2(-1,-1)
var viewport_size=Vector2.ZERO
var last_layout=Vector2.ZERO

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE;theme=DeskTheme.resource()
 panel=PanelContainer.new();add_child(panel);panel.add_theme_stylebox_override("panel",DeskTheme.box(Color("f8f9fa"),Color("aeb7c1"),1,7))
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",0);panel.add_child(column)
 var titlebar=PanelContainer.new();titlebar.add_theme_stylebox_override("panel",DeskTheme.box(Color("f1f3f6"),Color.TRANSPARENT,4,6));column.add_child(titlebar);titlebar.gui_input.connect(drag_title)
 var header=HBoxContainer.new();titlebar.add_child(header);header.mouse_filter=Control.MOUSE_FILTER_PASS
 heading=DeskTheme.label("",header,14,DeskTheme.INK,false);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
 button("—",header,func():panel.hide())
 button("□",header,func():maximized=not maximized;custom_position=Vector2(-1,-1);layout_window())
 var exit_=button("×",header,close_app);exit_.add_theme_font_size_override("font_size",22)
 exit_.add_theme_stylebox_override("hover",DeskTheme.box(Color("e81123")));exit_.add_theme_color_override("font_hover_color",Color.WHITE)
 toolbar=VBoxContainer.new();toolbar.add_theme_constant_override("separation",0);column.add_child(toolbar)
 scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
 body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",0);scroll.add_child(body)
 status=DeskTheme.label("",column,12,DeskTheme.MUTED,false);status.custom_minimum_size.y=25
 panel.minimum_size_changed.connect(func():call_deferred("layout_window"));panel.hide()
func button(value: String,parent: Node,action: Callable) -> Button:return DeskTheme.button(value,parent,action)
func paragraph(value: String,size_: int=18,parent: Node=null,color: Color=DeskTheme.INK) -> Label:
 return DeskTheme.label(value,body if parent==null else parent,size_,color)
func clear(parent: Node) -> void:
 for node in parent.get_children():parent.remove_child(node);node.queue_free()
func inset(parent: Node,padding: int=22,color: Color=Color.WHITE) -> VBoxContainer:
 var panel_=PanelContainer.new();panel_.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel_.add_theme_stylebox_override("panel",DeskTheme.box(color,Color.TRANSPARENT,padding,0));parent.add_child(panel_)
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",16);panel_.add_child(column);return column
func open_app(id: String) -> void:
 if app==id and not panel.visible:panel.show();return
 app=id;page="";zoomed=false;history.clear();custom_position=Vector2(-1,-1)
 browser_page="news" if computer.chapter.val("desktop_browser_page")==1 else "site";render()
func record(key: String) -> void:computer.chapter.record_evidence(key)
func show_page(value: String) -> void:page=value;zoomed=false;render()
func show_browser(value: String) -> void:
 browser_page=value;page="";computer.chapter.set_value("desktop_browser_page",1 if value=="news" else 0);render()
func news_from_chat() -> void:
 history.append({"app":"chat","page":"conversation"});app="browser";show_browser("news")
func close_app() -> void:
 if not history.is_empty():
  var previous=history.pop_back();app=previous.app;page=previous.page;zoomed=false;render()
 else:close_all()
func close_all() -> void:app="";page="";zoomed=false;history.clear();panel.hide()
func back() -> bool:
 if app.is_empty():return false
 if not panel.visible:close_all();return true
 if zoomed:zoomed=false;render()
 elif not page.is_empty():page="";render()
 else:close_app()
 return true
func render() -> void:
 clear(toolbar);clear(body);file_tree=null;address=null;panel.show();scroll.scroll_vertical=0
 var names={"computer":"此电脑","documents":"文档","photos":"照片","recycle":"回收站","browser":"浏览器","chat":"微信"}
 heading.text=names.get(app,"电脑");status.text=""
 if app=="browser":render_browser()
 elif app=="chat":render_chat()
 else:render_explorer()
 layout_window()
func render_browser() -> void:
 var tabs=HBoxContainer.new();tabs.add_theme_constant_override("separation",6);toolbar.add_child(tabs)
 button("◎  实验室官网",tabs,show_browser.bind("site"));button("◎  XX新闻",tabs,show_browser.bind("news"))
 if not history.is_empty():button("返回聊天",tabs,close_app)
 var row=HBoxContainer.new();toolbar.add_child(row)
 button("←",row,back);button("↻",row,render)
 address=LineEdit.new();address.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(address)
 address.text="https://www.xx-lab.example/" if browser_page=="site" else "https://news.xx.example/investigation/xx-lab"
 if page.begins_with("article_"):address.text+="/"+page.trim_prefix("article_")
 address.text_submitted.connect(func(value):show_browser("news" if "news" in value or "新闻" in value else "site"))
 button("前往",row,func():address.text_submitted.emit(address.text))
 status.text="已加载  ·  "+("XX生物实验室" if browser_page=="site" else "XX新闻")
 if browser_page=="site":render_site()
 else:render_news()
func render_site() -> void:
 var nav=inset(body,22);var row=HBoxContainer.new();row.add_theme_constant_override("separation",20);nav.add_child(row)
 var logo=paragraph("XX  生物实验室",22,row,Color("153e59"));logo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for entry in [["首页","home"],["关于我们","about"],["研究方向","research"],["科研环境","environment"]]:button(entry[0],row,scroll_section.bind(entry[1]))
 var hero=inset(body,32,Color("153e59"));hero.name="home"
 var hero_row=HBoxContainer.new();hero.add_child(hero_row)
 var hero_text=VBoxContainer.new();hero_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;hero_row.add_child(hero_text)
 paragraph("LIFE SCIENCE / CONSCIOUSNESS RESEARCH",13,hero_text,Color("9dcbdc"))
 paragraph("理解意识，探索生命的边界",31,hero_text,Color.WHITE)
 paragraph("意识机制 · 记忆信息 · 跨载体研究",17,hero_text,Color("d0e5ed"))
 var network=Control.new();network.custom_minimum_size=Vector2(230,150);hero_row.add_child(network)
 network.draw.connect(func():
  var points=[Vector2(28,75),Vector2(90,25),Vector2(103,122),Vector2(180,62),Vector2(210,132)]
  for a in range(points.size()):
   for b in range(a+1,points.size()):network.draw_line(points[a],points[b],Color(.40,.76,.84,.38),1.5,true)
   network.draw_circle(points[a],7,Color("84d2e1"));network.draw_arc(points[a],15,0,TAU,24,Color(.5,.85,.9,.3),1,true))
 var about=inset(body,26);about.name="about";paragraph("关于我们",24,about,Color("153e59"))
 paragraph("我们致力于人类意识的形成机制、信息保存与转移研究，探索生命科学与认知技术的交叉应用。",17,about)
 var research=inset(body,26,Color("f1f6f8"));research.name="research";paragraph("研究方向",24,research,Color("153e59"))
 var cards=HBoxContainer.new();cards.add_theme_constant_override("separation",18);research.add_child(cards)
 for item in [["01  意识机制","意识活动的观测、建模与形成机制研究。"],["02  记忆保存","记忆信息的长期记录、整理与保存。"],["03  信息转移","跨载体信息转移的基础研究。"]]:
  var card=inset(cards,18);paragraph(item[0],19,card,Color("236780"));paragraph(item[1],16,card)
 var environment=inset(body,26);environment.name="environment";paragraph("科研环境",24,environment,Color("153e59"))
 paragraph("独立的认知研究区、样本分析区和长期观测室。研究团队通过持续记录与跨学科合作，探索意识与生命科学的边界。",17,environment)
 var footer=inset(body,22,Color("153e59"));paragraph("XX生物实验室  |  科研合作 · 联系我们",14,footer,Color("bbd8e4"));record("site")
func scroll_section(id: String) -> void:
 var target=body.find_child(id,true,false)
 if target:scroll.ensure_control_visible(target)
func render_news() -> void:
 var top=inset(body,22,Color("173f62"));var nav=HBoxContainer.new();top.add_child(nav)
 var masthead=paragraph("XX新闻",29,nav,Color.WHITE);masthead.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for name_ in ["首页","社会","科技","调查"]:
  var link=button(name_,nav,show_browser.bind("news"));link.add_theme_color_override("font_color",Color("d9e6ef"))
 var content=inset(body,30)
 if page.begins_with("article_"):
  var article=Data.NEWS[int(page.trim_prefix("article_"))]
  paragraph("首页  /  调查  /  XX生物实验室",14,content,DeskTheme.MUTED)
  paragraph(article.title,29,content);paragraph("XX新闻调查组  ·  一个月前",14,content,DeskTheme.MUTED)
  content.add_child(HSeparator.new());paragraph(article.body,20,content)
  button("← 返回专题报道",content,show_page.bind(""));record("news")
 else:
  paragraph("跟踪调查 / XX生物实验室",28,content)
  paragraph("一个月前的报道  ·  社会关注",14,content,DeskTheme.MUTED);content.add_child(HSeparator.new())
  for i in range(Data.NEWS.size()):
   var entry=Data.NEWS[i]
   var title_=button(entry.title,content,show_page.bind("article_%d"%i));title_.alignment=HORIZONTAL_ALIGNMENT_LEFT;title_.add_theme_font_size_override("font_size",22);title_.add_theme_color_override("font_color",Color("184b77"))
   paragraph(entry.body.split("\n")[-1].left(84)+"……",16,content,DeskTheme.MUTED)
   paragraph("调查报道  ·  一个月前",13,content,DeskTheme.MUTED);content.add_child(HSeparator.new())
func avatar(parent: Node,name_: String,color: Color) -> void:
 var block=PanelContainer.new();block.custom_minimum_size=Vector2(42,42);block.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;block.add_theme_stylebox_override("panel",DeskTheme.box(color,Color.TRANSPARENT,4,3));parent.add_child(block)
 var text_=DeskTheme.label(name_,block,19,Color.WHITE,false);text_.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text_.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
func render_chat() -> void:
 status.text="历史会话  ·  一个月前"
 var split=HBoxContainer.new();split.add_theme_constant_override("separation",0);split.custom_minimum_size.y=580;body.add_child(split)
 var rail=inset(split,10,Color("2e2e2e"));rail.get_parent().custom_minimum_size.x=64;rail.get_parent().size_flags_horizontal=Control.SIZE_FILL
 avatar(rail,"我",Color("4d7791"));var rail_icons=paragraph("\n◉\n\n♙\n\n▣",23,rail,Color("b9b9b9"));rail_icons.custom_minimum_size.x=0;rail_icons.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var contacts=inset(split,12,Color("e8e8e8"));contacts.get_parent().custom_minimum_size.x=240;contacts.get_parent().size_flags_horizontal=Control.SIZE_FILL
 var search=LineEdit.new();search.placeholder_text="搜索";contacts.add_child(search)
 var contact=button("X主任  ·  一个月前",contacts,show_page.bind("conversation"));contact.custom_minimum_size.y=74;contact.alignment=HORIZONTAL_ALIGNMENT_LEFT
 contact.add_theme_stylebox_override("normal",DeskTheme.box(Color("d7d7d7") if page=="conversation" else Color("e8e8e8")))
 paragraph("有关实验室负面消息……",13,contacts,DeskTheme.MUTED)
 var conversation=inset(split,24,Color("f5f5f5"))
 if page!="conversation":
  paragraph("微信",34,conversation,Color("a8a8a8"));paragraph("选择左侧会话，查看已有聊天记录。",16,conversation,DeskTheme.MUTED);return
 paragraph("X主任",21,conversation);conversation.add_child(HSeparator.new())
 var time=paragraph("一个月前  09:12",13,conversation,Color("929292"));time.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 bubble(conversation,"有关实验室负面消息，你联系人去处理一下。",false)
 bubble(conversation,"xxxxxxxxxxxxx",false,true)
 bubble(conversation,"收到。",true)
 var space=Control.new();space.size_flags_vertical=Control.SIZE_EXPAND_FILL;conversation.add_child(space)
 conversation.add_child(HSeparator.new());paragraph("☺   ▧   ▢    ⋯",20,conversation,DeskTheme.MUTED)
 var input_=TextEdit.new();input_.editable=false;input_.placeholder_text="当前会话仅保留历史记录";input_.custom_minimum_size.y=65;conversation.add_child(input_)
 record("chat")
func bubble(parent: Node,text_: String,mine: bool,link_: bool=false) -> void:
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",10);parent.add_child(row)
 if mine:
  var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(spacer)
 else:avatar(row,"X",Color("526b7b"))
 var panel_=PanelContainer.new();panel_.add_theme_stylebox_override("panel",DeskTheme.box(Color("95ec69") if mine else Color.WHITE,Color("e4e4e4"),13,4));row.add_child(panel_)
 if link_:
  var link=LinkButton.new();link.text=text_;link.focus_mode=Control.FOCUS_ALL;link.add_theme_color_override("font_color",Color("1674b8"));link.add_theme_color_override("font_focus_color",Color("1674b8"));panel_.add_child(link);link.pressed.connect(news_from_chat)
 else:
  var label_=DeskTheme.label(text_,panel_,17);label_.custom_minimum_size.x=80 if mine else 320
 if mine:avatar(row,"我",Color("5a9275"))
 else:
  var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(spacer)
func render_explorer() -> void:
 var row=HBoxContainer.new();toolbar.add_child(row);button("←",row,back);button("⌂",row,open_app.bind("computer"))
 var path_=LineEdit.new();path_.editable=false;path_.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(path_)
 path_.text="此电脑 > "+{"computer":"此电脑","documents":"文档","photos":"图片","recycle":"回收站"}.get(app,app)
 var search=LineEdit.new();search.placeholder_text="搜索 "+heading.text;search.custom_minimum_size.x=190;row.add_child(search)
 var split=HBoxContainer.new();split.add_theme_constant_override("separation",0);body.add_child(split)
 var nav=inset(split,12,Color("f5f6f7"));nav.get_parent().custom_minimum_size.x=164;nav.get_parent().size_flags_horizontal=Control.SIZE_FILL
 for entry in [["⌂  主页","computer"],["▣  此电脑","computer"],["▤  文档","documents"],["▧  图片","photos"],["♻  回收站","recycle"]]:
  var nav_button=button(entry[0],nav,open_app.bind(entry[1]));nav_button.alignment=HORIZONTAL_ALIGNMENT_LEFT
  if entry[1]==app:nav_button.add_theme_stylebox_override("normal",DeskTheme.box(Color("e3edf7")))
 var content=inset(split,20)
 if page in ["photo","lab_photo"]:
  paragraph("实验室工作照.jpg",19,content);show_photo(content,"res://act3/textures/lab_photo.png")
  paragraph("是照片里的那个人……原来，那里不是家里。",16,content);record("photo");status.text="实验室工作照.jpg  ·  图片查看器"
 elif app=="recycle":
  var commands=HBoxContainer.new();content.add_child(commands)
  var restore_=button("还原选定项目",commands,restore_photo);restore_.disabled=computer.chapter.flag("lab_photo_restored")
  var delete_=button("永久删除",commands,func():pass);delete_.disabled=true
  file_tree=Tree.new();file_tree.columns=4;file_tree.column_titles_visible=true;file_tree.hide_root=true;file_tree.select_mode=Tree.SELECT_ROW
  file_tree.custom_minimum_size.y=450;content.add_child(file_tree)
  for i in range(4):file_tree.set_column_title(i,["名称","原位置","删除日期","类型"][i]);file_tree.set_column_custom_minimum_width(i,[225,190,105,100][i])
  var tree_root=file_tree.create_item()
  if not computer.chapter.flag("lab_photo_restored"):
   var item=file_tree.create_item(tree_root);item.set_text(0,"实验室工作照.jpg");item.set_icon(0,DeskTheme.icon("photo"));item.set_text(1,"C:\\Users\\C-031\\Pictures");item.set_text(2,"一个月前");item.set_text(3,"JPG 图像");item.set_metadata(0,"photo")
  file_tree.item_activated.connect(func():
   if file_tree.get_selected():show_page("photo"))
  status.text="0 个项目" if computer.chapter.flag("lab_photo_restored") else "1 个项目  ·  双击文件或选中后按 Enter 打开"
 elif app=="photos":
  paragraph("图片",24,content)
  if computer.chapter.flag("lab_photo_restored"):button("实验室工作照.jpg",content,show_page.bind("lab_photo"))
  show_photo(content,"res://act2/memory_photo.png");status.text="图片  ·  已收藏的合照"
 elif app=="documents":
  paragraph("文档",23,content);paragraph("此文件夹为空。",17,content,DeskTheme.MUTED);status.text="0 个项目"
 else:
  paragraph("文件夹",23,content)
  for entry in [["文档","documents"],["图片","photos"],["回收站","recycle"]]:
   var folder=button(entry[0],content,open_app.bind(entry[1]));folder.icon=DeskTheme.icon("folder");folder.alignment=HORIZONTAL_ALIGNMENT_LEFT
  paragraph("设备和驱动器",21,content);paragraph("本地磁盘 (C:)    67.2 GB 可用，共 237 GB",16,content,DeskTheme.MUTED)
  var disk=ProgressBar.new();disk.value=71.6;disk.show_percentage=false;disk.custom_minimum_size.y=10;content.add_child(disk);status.text="3 个文件夹  ·  1 个驱动器"
func show_photo(parent: Node,path_: String) -> void:
 var picture=TextureRect.new();picture.texture=load(path_);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.custom_minimum_size.y=620 if zoomed else 330;parent.add_child(picture)
 button("还原照片" if zoomed else "放大照片",parent,toggle_zoom)
func restore_photo() -> void:
 computer.chapter.set_flag("lab_photo_restored");app="photos";show_page("lab_photo")
func toggle_zoom() -> void:zoomed=not zoomed;render()
func drag_title(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  moving=event.pressed
  if event.double_click:maximized=not maximized;custom_position=Vector2(-1,-1);layout_window()
 elif event is InputEventMouseMotion and moving and not maximized:
  custom_position=panel.position+event.relative;layout_window()
func _input(event: InputEvent) -> void:
 if event is InputEventMouseButton and not event.pressed:moving=false
func layout_window() -> void:
 if not is_instance_valid(panel) or app.is_empty():return
 var viewport=get_viewport().get_visible_rect().size
 var dimensions=Vector2(viewport.x-32,viewport.y-112) if maximized else Vector2(minf(1120,viewport.x-64),minf(748,viewport.y-130))
 var desired=(viewport-dimensions)*.5-Vector2(0,12) if custom_position.x<0 else custom_position
 panel.size=dimensions
 panel.position=Vector2(clampf(desired.x,0,maxf(0,viewport.x-panel.size.x)),clampf(desired.y,0,maxf(0,viewport.y-panel.size.y-54)))
 body.custom_minimum_size.x=maxf(400,dimensions.x-20)
 scroll.custom_minimum_size.y=maxf(280,dimensions.y-toolbar.get_combined_minimum_size().y-75)
 viewport_size=viewport;last_layout=dimensions
func _process(_delta: float) -> void:
 if not app.is_empty() and viewport_size!=get_viewport().get_visible_rect().size:layout_window()
