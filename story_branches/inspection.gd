extends CanvasLayer
## Preview/inspection only. The branch State service is intentionally not invented.
signal closed
signal submission_requested(action: StringName, preview_snapshot: Dictionary)
const Copy = preload("res://story_branches/data.gd")
const Paper = preload("res://quest_system/quest_theme.gd")
var game: Node
var world: Node
var shell: Control
var panel: PanelContainer
var column: VBoxContainer
var heading: Label
var text_: Label
var actions: VBoxContainer
var camera: Camera3D
var previous_camera: Camera3D
var previous_active := false
var previous_cinematic := false
var session := {}
var body_mask := 0
var record_mask := 0
var stages := {}
var active_view := ""
var development := false
var opened := false
var box: Node3D
var chest_attachment: Node3D
var hud_visible := false

func _ready() -> void:
	layer=48
	shell=Control.new();shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shell.mouse_filter=Control.MOUSE_FILTER_IGNORE;shell.theme=Paper.resource();add_child(shell)
	panel=PanelContainer.new();shell.add_child(panel);panel.add_theme_stylebox_override("panel",Paper.panel(24))
	column=VBoxContainer.new();column.add_theme_constant_override("separation",10);panel.add_child(column)
	heading=Label.new();heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;heading.add_theme_font_size_override("font_size",24);column.add_child(heading)
	var tabs:=HBoxContainer.new();column.add_child(tabs)
	for entry in [["原身体","body"],["档案","records"],["维修","repair"],["预检","precheck"]]:
		var b:=Button.new();b.text=entry[0];b.pressed.connect(show_view.bind(entry[1]));tabs.add_child(b)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
	var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
	text_=Label.new();text_.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text_.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text_.add_theme_font_size_override("font_size",20);content.add_child(text_)
	actions=VBoxContainer.new();actions.add_theme_constant_override("separation",6);content.add_child(actions)
	var notice:=Label.new();notice.text=Copy.PREVIEW_NOTICE;notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.add_theme_font_size_override("font_size",14);column.add_child(notice)
	var close_button:=Button.new();close_button.text="返回 · Esc";close_button.pressed.connect(close);column.add_child(close_button)
	shell.hide()

func open(game_: Node, world_: Node, dev := false) -> void:
	if opened:return
	game=game_;world=world_;development=dev;opened=true
	previous_camera=get_viewport().get_camera_3d();previous_active=game.player.active;previous_cinematic=game.cinematic_active
	hud_visible=game.ui.hud.visible;game.ui.hud.hide()
	game.cinematic_active=true;game.player.set_control(false);game.player.velocity=Vector3.ZERO
	session={} if dev else world.visual_snapshot();body_mask=0;record_mask=0
	camera=Camera3D.new();camera.name="BranchInspectionCamera";camera.near=.012;camera.far=35;game.add_child(camera)
	shell.show();show_view("front")

func stage(id: String) -> Node3D:
	if stages.has(id):return stages[id]
	var n: Node3D=load("res://story_branches/scenes/"+id+".tscn").instantiate()
	game.add_child(n);stages[id]=n
	n.position=Vector3(64,-20,0) if id=="recovery_bay" else Vector3(64,0,0) if id=="rescue_stage" else Vector3(64,-35,0)
	return n

func aim(marker: Node3D, mask_: int, env: Environment = null) -> void:
	camera.global_transform=marker.global_transform;camera.fov=marker.get_meta("fov",50.0);camera.cull_mask=mask_;camera.environment=env;camera.make_current()

func button(caption: String, callback: Callable, disabled := false) -> Button:
	var b:=Button.new();b.text=caption;b.custom_minimum_size.y=38;b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;b.disabled=disabled;b.pressed.connect(callback);actions.add_child(b);return b

func fresh(title: String, content: String) -> void:
	heading.text=title;text_.text=content
	for c in actions.get_children():actions.remove_child(c);c.queue_free()
	for n in stages.values():n.hide()

func show_view(id: String) -> void:
	if not opened:return
	active_view=id
	match id:
		"front":
			fresh("转化装置 / 模型检查",Copy.REPAIR)
			aim(world.retrofit.get_node("DrawerCam"),1|4|16,game.player.camera.environment)
			button("打开备件抽屉",func():world.retrofit.play_action(&"drawer"))
			button("演示模块插入",func():world.retrofit.play_action(&"module"))
			button("演示急停短行程",func():session.br_auto_stopped=true;world.retrofit.apply_visual_state(session);world.retrofit.play_action(&"emergency"))
			button("复位设备模型",func():world.retrofit.apply_visual_state(session))
			button("观察侧装面板",func():
				camera.global_position=world.chamber.to_global(Vector3(.75,.50,.95));camera.look_at(world.chamber.to_global(Vector3(.40,.48,.30)));camera.fov=42)
			button("通风格栅",show_view.bind("vent"))
			button("举报材料",show_view.bind("report"))
			if development:
				button("K-2 维修盒 / 四态",show_view.bind("box"))
				button("护理回忆片场",show_view.bind("memory"))
				button("撤离片场",show_view.bind("rescue"))
		"body":
			fresh("H-031 / 原身体观察","同一位男性研究员。\n独立维持回路仍在工作。\n核对三个字段后才可记录（本次为会话预览）。")
			var bay:=stage("recovery_bay");bay.show();bay.apply_visual_state({})
			aim(bay.get_node("BodyInspectCam"),128,bay.get_node("StageCamera").environment)
			for i in range(3):button(("✓ " if body_mask&(1<<i) else "□ ")+Copy.BODY_FIELDS[i],check_body.bind(i))
			button("记录核对结果",func():session.br_body_seen=true;submission_requested.emit(&"br_body_seen",session.duplicate());show_view("body"),body_mask!=7)
			button("对照合照 / 工作照",show_view.bind("photos"))
			button("面部近景",func():aim(bay.get_node("BodyDetailCam"),128,bay.get_node("StageCamera").environment))
		"photos":
			fresh("身份对照",Copy.PHOTO_NAME+"\n"+Copy.PHOTO_BACK+"\n\n"+Copy.LAB_PHOTO)
			for path_ in ["res://story_branches/art/clues/memory_photo.png","res://story_branches/art/clues/lab_photo.png"]:
				var image:=TextureRect.new();image.texture=load(path_);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size.y=175;actions.add_child(image)
			var bay:=stage("recovery_bay");bay.show()
			button("返回身体观察",show_view.bind("body"))
		"repair":
			fresh("检修侧 / 独立维持",Copy.REPAIR+"\n\nL：维持（保持接通）\nT：转移（隔离）\nM：维护（接入）\n\n下列操作只演示模型，不改变当前主线。")
			aim(world.retrofit.get_node("ServiceCam"),1|4|16,game.player.camera.environment)
			button("演示隔离通过：维持 / 关 / 接",func():session.br_power_safe=true;world.retrofit.apply_visual_state(session))
			button("演示三线正式连接",func():session.br_routing=true;world.retrofit.apply_visual_state(session))
			button("查看抽屉 / 模块",show_view.bind("front"))
			button("复位线路",func():session.erase("br_power_safe");session.erase("br_routing");world.retrofit.apply_visual_state(session))
		"records":
			var allowed: bool=session.get("br_body_seen",false) and session.get("br_power_safe",false)
			fresh("原始档案","先核对身体并完成电路隔离，再逐项阅读。\n会话关闭后未提交的核对会清空。" if not allowed else "依次阅读三个页签。阅读不会自动恢复记忆、解除钢印或选择结局。")
			for i in range(3):button(("✓ " if record_mask&(1<<i) else "")+Copy.RECORD_TABS[i],read_record.bind(i),not allowed)
			button("收录档案（预览）",func():session.br_records=true;submission_requested.emit(&"br_records",session.duplicate());text_.text="三项已完整阅读。预览不提交正式任务状态。",not allowed or record_mask!=7)
			button("补查早期照片与编号",show_view.bind("photos"))
		"precheck":
			fresh("转移预检 / 待剧情服务接入","身体核对："+str(session.get("br_body_seen",false))+"\n电路隔离："+str(session.get("br_power_safe",false))+"\n\n模型接口已就绪。当前版本沿用原第十一天结局。新分支的提交、救鼠与转移时序，须接入配套开发指导中的 State 服务。")
			button("回到模型检查",show_view.bind("front"))
		"vent":
			fresh("通风格栅 / 逃生近景","左扣 → 下压弯边 → 推开格栅。\n原西墙仍有碰撞，不创建穿墙捷径。")
			aim(world.vent_service.get_node("VentCam"),1|4|16,game.player.camera.environment)
			button("播放开启动作",func():world.vent_service.apply_visual_state({});world.vent_service.play_action(&"vent"))
			button("恢复关闭姿态",func():world.vent_service.apply_visual_state({}))
			button("返回",show_view.bind("front"))
		"report":
			fresh(Copy.REPORT_TITLE,Copy.REPORT)
			aim(world.report_evidence.get_node("ReportReadCam"),1|4|16,game.player.camera.environment)
			button("返回装置",show_view.bind("front"))
		"box":
			fresh("桌下维修盒 / K-2","维护盒使用接收载体尾号：031\n\n以下为无存档模型预览，不领取真实道具。")
			if not is_instance_valid(box):
				box=load("res://story_branches/scenes/maintenance_box.tscn").instantiate();game.add_child(box)
				var desk: Node3D=preload("res://furniture_pack/quest_props/props.gd").furniture(game,"work_desk","ComputerRoom")
				box.global_transform=desk.global_transform*Transform3D(Basis.IDENTITY,Vector3(.44,.44,.20))
			box.show();aim(box.get_node("BoxInspectCam"),1|4|16)
			button("开盒",func():box.play_action(&"box"))
			for state_ in ["未校准","就绪","已消耗","待完成救鼠"]:button(state_,show_k2.bind(state_))
			button("关闭盒盖",func():box.apply_visual_state({}))
			button("仅盒内显示 / 未领取",func():
				box.apply_visual_state({"box_open":true})
				if is_instance_valid(chest_attachment):chest_attachment.hide())
			button("返回",show_view.bind("front"))
		"memory":
			fresh("短闪回 / 护理米酥","研究员第一人称。复用当前米酥外观，打开笼门、放下旧毯子。\n\n片场独立，不移动实际观察笼。")
			var memory:=stage("memory_vignette");memory.show();aim(memory.get_node("CarePOV"),512,memory.get_node("StageCamera").environment)
			button("播放护理动作",func():memory.play_action(&"care"))
			button("返回",show_view.bind("front"))
		"rescue":
			fresh("撤离布景 / 转运","独立门口片场。担架和运输盒由分支快照决定显示。\n当前提供布景及演员定位点，正式撤离时序待接线。")
			var rescue:=stage("rescue_stage");rescue.show();aim(rescue.get_node("RescueCam"),256,rescue.get_node("StageCamera").environment)
			for result in range(3):button(["老鼠：未知","老鼠：死亡","老鼠：获救"][result],func():rescue.apply_visual_state({"br_mouse":result,"branch":3}))
			button("返回",show_view.bind("front"))

func check_body(index: int) -> void:body_mask|=1<<index;show_view("body")

func read_record(index: int) -> void:
	record_mask|=1<<index;show_view("records");text_.text=Copy.RECORDS[index]
	if index==2:text_.text+="\n\n录音内容（字幕替代，尚无配音）：\n"+Copy.RECORDING_CAPTION

func show_k2(name_: String) -> void:
	var state_ := {"br_k2_owned":true,"br_k2_ready":name_!="未校准","br_k2_spent":name_ in ["已消耗","待完成救鼠"]}
	box.apply_visual_state(state_)
	if not is_instance_valid(chest_attachment):
		chest_attachment=preload("res://story_branches/k2_attachment.gd").new();game.player.add_child(chest_attachment)
	chest_attachment.apply_visual_state(state_)
	camera.global_position=game.player.to_global(Vector3(.34,.22,-.58));camera.look_at(chest_attachment.global_position);camera.cull_mask=1|2|4|16;camera.fov=38
	if name_=="待完成救鼠":chest_attachment.play_action(&"k2_press")

func close() -> void:
	if not opened:return
	opened=false;shell.hide()
	if is_instance_valid(previous_camera):previous_camera.make_current()
	if is_instance_valid(camera):camera.queue_free()
	for n in stages.values():n.queue_free()
	stages.clear()
	if is_instance_valid(box):box.queue_free()
	if is_instance_valid(chest_attachment):chest_attachment.queue_free()
	world.retrofit.apply_visual_state(world.visual_snapshot());world.vent_service.apply_visual_state({"a11_vent":game.get_node("DayOne").flag("a11_vent")})
	game.cinematic_active=previous_cinematic;game.player.set_control(previous_active)
	game.ui.hud.visible=hud_visible
	session.clear();body_mask=0;record_mask=0;closed.emit()

func _process(_delta: float) -> void:
	if not opened:return
	var size_: Vector2=get_viewport().get_visible_rect().size
	var w:=minf(480,size_.x*.44)
	panel.position=Vector2(size_.x-w-24,24);panel.size=Vector2(w,size_.y-48)
	panel.custom_minimum_size=Vector2(w,0)

func _input(event: InputEvent) -> void:
	if not opened:return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		close();get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if opened:close()
