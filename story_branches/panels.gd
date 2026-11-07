extends "res://story_branches/inspection.gd"
const Rules=preload("res://story_branches/rules.gd")
var chapter: Node
var message := ""
var box_code := ""
var box_open := false
var manual_read := false
var box_errors := 0
var k2_choices := [0,0,2]
var switches := [true,true,false]
var memory_choices := [1,0,2]
var routing := [-1,-1,-1]
var target := -1
var verify_time := [0,0,0]
var vent_step := 0

func _ready() -> void:
	super._ready()
	for node in column.get_children():
		if node is Label and node.text==Copy.PREVIEW_NOTICE:node.hide()
	var tab_names := ["原身体观察","原始档案","维修","转移预检"]
	for i in range(4):column.get_child(1).get_child(i).text=tab_names[i]

func open(game_: Node, world_: Node, dev := false) -> void:
	message="";box_code="";box_open=false;manual_read=false;box_errors=0
	body_mask=7 if chapter.flag("br_body_seen") else 0;record_mask=7 if chapter.flag("br_records") else 0
	switches=[true,false,true] if chapter.flag("br_power_safe") else [true,true,false]
	k2_choices=Copy.K2_ANSWER.duplicate() if chapter.flag("br_k2_ready") else [0,0,2]
	memory_choices=[1,0,2];routing=Copy.ROUTING_ANSWER.duplicate() if chapter.flag("br_routing") else [-1,-1,-1]
	target=0 if chapter.flag("br_target_verified") else -1;verify_time=Copy.VERIFY_TIME.duplicate() if chapter.flag("br_target_verified") else [0,0,0]
	vent_step=3 if chapter.flag("a11_vent") else 0
	super.open(game_,world_,dev)

func fresh(title_: String, content: String) -> void:
	session=chapter.facts()
	super.fresh(title_,content)
	column.get_child(1).visible=chapter.flag("a11_enter") and chapter.day.value("current_day",1)==11 and active_view!="final"
	column.get_child(column.get_child_count()-1).visible=active_view!="final"
	if not message.is_empty():
		var feedback:=Label.new();feedback.text=message;feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;feedback.add_theme_color_override("font_color",Color("98643d"));actions.add_child(feedback)

func attempt(action: String, input: Dictionary, next: String) -> bool:
	var ok: bool=chapter.step(action,input)
	message="已记录。" if ok else chapter.state.last_error
	show_view(next)
	return ok

func select_row(label_: String, options: Array, selected: int, callback: Callable, disabled := false) -> void:
	var row:=VBoxContainer.new();actions.add_child(row)
	var label:=Label.new();label.text=label_;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(label)
	var option:=OptionButton.new();option.custom_minimum_size.y=38;row.add_child(option)
	for title_ in options:option.add_item(str(title_))
	option.select(selected);option.disabled=disabled;option.item_selected.connect(callback)

func show_view(id: String) -> void:
	if not opened:return
	if id=="front":id="overview" if chapter.flag("a11_enter") else "box"
	active_view=id
	match id:
		"mouse_rescue_confirm","mouse_refuse_confirm":
			var rescue: bool=id=="mouse_rescue_confirm"
			fresh("命令冲突 / 确认决定","设备只剩一次使用机会。你要趁短暂干扰放走老鼠吗？" if rescue else "你想转身离开，但身体已经开始发紧。仍然直接尝试拒绝吗？")
			button("启动并放走" if rescue else "直接拒绝",func():
				if not chapter.choose_mouse(rescue):message=chapter.state.last_error;show_view(id))
			button("返回",func():close();game.get_node("ActFour").open_mouse_story())
		"overview":
			fresh("转化装置","它说能让我回去。可它连我是谁都不肯告诉我。\n\n先核对身体和记录，再决定是否启动。调查装置与出口都不会立即锁定离开方式。")
			aim(world.retrofit.get_node("DrawerCam"),1|4|16,game.player.camera.environment)
			button("检查转移条件",show_view.bind("body"))
			button("停止本轮自动启动",func():
				if attempt("auto_stopped",{},"overview"):world.retrofit.play_action(&"emergency"),chapter.flag("br_auto_stopped"))
			button("先调查房间",close)
		"box":show_box()
		"k2":show_device_settings()
		"index":
			fresh("原始记录索引",Copy.RECORD_INDEX+"\n\n"+Copy.SYNC_STATUS)
			button("保留索引",func():attempt("index",{},"index"),chapter.flag("br_index"))
			button("暂时关闭",close)
		"body":
			fresh("H-031 / 原身体观察","照片里的成年男性躺在玻璃后。\n\n我记得这张脸。可我记得的……是从他的眼睛里往外看。\n\n逐项核对，确认后记录。")
			var bay:=stage("recovery_bay");bay.show();aim(bay.get_node("BodyInspectCam"),128,bay.get_node("StageCamera").environment)
			for i in range(3):button(("✓ " if body_mask&(1<<i) else "□ ")+Copy.BODY_FIELDS[i],check_body.bind(i))
			button("记录核对结果",func():attempt("body_seen",{"read_mask":body_mask},"body"),body_mask!=7 or chapter.flag("br_body_seen"))
			button("对照合照 / 工作照",show_view.bind("photos"));button("检查维修电路",show_view.bind("repair"))
		"photos":
			fresh("身份对照",Copy.PHOTO_NAME+"\n"+Copy.PHOTO_BACK+"\n\n"+Copy.LAB_PHOTO)
			for path_ in ["res://story_branches/art/clues/memory_photo.png","res://story_branches/art/clues/lab_photo.png"]:
				var image:=TextureRect.new();image.texture=load(path_);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size.y=175;actions.add_child(image)
			button("保留本地索引",func():attempt("index",{},"photos"),chapter.flag("br_index"));button("返回身体观察",show_view.bind("body"))
		"repair":show_repair()
		"power":show_power()
		"records":show_records()
		"memory":
			fresh("记忆核对","按身份、护理与操作日志配对。可重复选择同一编号。")
			for i in range(3):select_row(["转移前的意识源端","当前接收载体","照片中的照护者"][i],["H-031","C-031","D-017"],memory_choices[i],func(v: int):memory_choices[i]=v)
			button("验证配对",func():
				message=Rules.validate_input("memory",{"choices":memory_choices})
				show_view("memory_confirm" if message.is_empty() else "memory"))
			button("重新查看档案",show_view.bind("records"))
		"memory_confirm":
			fresh("恢复记忆访问","这将恢复被封存的研究员经历，不会自动解除强制指令。")
			button("恢复记忆访问",func():
				if chapter.step("memory",{"choices":memory_choices}):chapter.play_memory()
				else:message=chapter.state.last_error;show_view("memory_confirm"))
			button("返回核对",show_view.bind("memory"))
		"imprint":show_imprint()
		"channel_confirm":
			fresh("清除强制通道","保留自主行动与身体适应数据，只移除强制指令。")
			button("确认清除",func():attempt("channel_off",{"confirmed":true},"imprint"));button("返回",show_view.bind("imprint"))
		"offline":
			fresh("离线自主响应验证","此验证不接通运动执行，仅检查强制通道是否仍响应。\n\n「吃掉它。」")
			button("拒绝执行",func():
				if attempt("imprint_cleared",{"refused":true},"imprint"):
					message="强制响应 0，自主输入有效。\n我能停下来。它没有再把我拉回去。";show_view("imprint"))
			button("暂不验证",show_view.bind("imprint"))
		"routing":show_routing()
		"precheck":show_precheck()
		"human_confirm":
			fresh("返回原身体 / 最终确认","你的意识将离开 C-031，返回 H-031。米酥的生命维持会继续。\n\n转移启动后，本次流程不能中途改选出口。")
			button("确认回到原身体",func():
				if not chapter.confirm_ending(2):message=chapter.state.last_error;show_view("human_confirm"),not chapter.state.allowed("return_human").allowed)
			button("继续调查",show_view.bind("precheck"))
		"vent":show_vent()
		"cat_confirm":
			fresh("通往外面的路 / 最终确认","通道只够猫通过。继续前进将保留现在的身体。你也可以返回检查转移装置。")
			aim(world.vent_service.get_node("VentCam"),1|4|16,game.player.camera.environment)
			button("确认以猫身离开",func():
				if not chapter.confirm_ending(3):message=chapter.state.last_error;show_view("cat_confirm"),not chapter.state.allowed("escape_cat").allowed)
			button("继续调查",close)
		"final":
			fresh("回到自己的身体" if chapter.value("br_ending")==2 else "带着猫的身体回家",Copy.ending_text(chapter.value("br_ending"),chapter.value("br_mouse"),chapter.flag("br_memory"),chapter.flag("br_imprint_cleared")))
			if chapter.flag("br_legacy_completed") and not chapter.flag("br_rescue_done"):text_.text="旧版本的猫身归家记录已经完成。\n旧记录没有保存新增的救援过程，可以重看扩展尾声。"
			var rescue:=stage("rescue_stage");rescue.show();rescue.apply_visual_state({"br_mouse":chapter.value("br_mouse"),"branch":chapter.value("br_ending")});aim(rescue.get_node("RescueCam"),256,rescue.get_node("StageCamera").environment)
			button("重看结局",func():chapter.start_ending_film(true));button("返回主菜单",chapter.return_menu)

func show_box() -> void:
	fresh("电脑桌下 / 维护盒","维护盒使用接收载体尾号。\n编号在照片和电脑账户上。")
	box=chapter.world.box;aim(box.get_node("BoxInspectCam"),1|4|16,game.player.camera.environment)
	if chapter.flag("br_k2_owned"):
		text_.text="校准器已经佩戴在胸前。";button("查看校准器",show_view.bind("k2"));return
	if not box_open:
		var code:=LineEdit.new();code.placeholder_text="三位数字";code.max_length=3;code.text=box_code;code.text_changed.connect(func(v: String):box_code=v);actions.add_child(code)
		button("打开维护盒",func():
			if box_code==Copy.BOX_CODE:box_open=true;message="盒盖打开了。";show_view("box");box.play_action(&"box")
			else:box_errors+=1;message="试试 C-031 中的数字。" if box_errors>=3 else "号码不匹配，再看看接收载体编号。";show_view("box"))
	else:
		box.apply_visual_state({"box_open":true,"box_digits":box_code})
		button("检查设备",func():message="K-2：一个凹下的按钮，三枚指示灯，背后有短挂带。";show_view("box"))
		button("阅读折页说明",func():manual_read=true;message=Copy.K2_MANUAL;show_view("box"))
		button("带上校准器",func():
			if attempt("k2_owned",{"code":box_code,"manual_read":manual_read},"box"):show_view("k2"),not manual_read)

func show_device_settings() -> void:
	fresh("装备 / K-2 便携校准器",Copy.K2_MANUAL)
	if not chapter.flag("br_k2_owned"):
		text_.text="校准器放在二楼电脑桌下的维修盒。";button("返回",close);return
	chest_attachment=null
	var chest: Node3D=chapter.world.chest
	camera.global_position=game.player.to_global(Vector3(.34,.22,-.58));camera.look_at(chest.global_position);camera.cull_mask=1|2|4|16;camera.fov=38
	var readonly: bool=chapter.flag("br_k2_ready") or chapter.flag("br_k2_spent")
	if chapter.value("br_mouse")!=0:
		text_.text+="\n\n本次命令已有结果。设备现在保留作线索。"
		readonly=true
	select_row("载体编号",["H-031","C-031","D-017"],k2_choices[0],func(v: int):k2_choices[0]=v,readonly)
	select_row("工作模式",["记忆读取","强制通道干扰","自动执行"],k2_choices[1],func(v: int):k2_choices[1]=v,readonly)
	select_row("输出档位",["低","中","高"],k2_choices[2],func(v: int):k2_choices[2]=v,readonly)
	button("需重新维护，本流程中不可再次使用" if chapter.flag("br_k2_spent") else "载体匹配完成，可用次数 1" if readonly else "离线自检",func():attempt("k2_ready",{"choices":k2_choices},"k2"),readonly)
	button("合上说明",close)

func show_repair() -> void:
	if not chapter.flag("br_auto_stopped") and not chapter.step("auto_stopped"):message=chapter.state.last_error
	fresh("维修 / 独立维持回路",Copy.REPAIR+"\n\n自动启动已暂停。急停只隔离本轮转移，不切断维持供电。")
	aim(world.retrofit.get_node("ServiceCam"),1|4|16,game.player.camera.environment)
	button("检查电路隔离",show_view.bind("power"))
	button("核对记忆证据" if not chapter.flag("br_memory") else "重看研究员记忆",show_view.bind("memory") if not chapter.flag("br_memory") else chapter.play_memory,not chapter.state.allowed("memory").allowed)
	button("处理强制指令通道",show_view.bind("imprint"))
	button("打开侧抽屉",func():world.retrofit.play_action(&"drawer");message="替换模块就在抽屉里。";show_module_button(),not chapter.flag("br_power_safe"))
	button("反向传输接线",show_view.bind("routing"));button("转移预检",show_view.bind("precheck"))

func show_module_button() -> void:
	button("装入维护槽",func():
		if attempt("module",{},"repair"):world.retrofit.play_action(&"module"),chapter.flag("br_module"))

func show_power() -> void:
	fresh("维修 / 电路隔离","检修时保留维持供电，隔离转移执行，再接入维护桥。\n\n未验证的调整不会生效。")
	aim(world.retrofit.get_node("ServiceCam"),1|4|16,game.player.camera.environment)
	for i in range(3):
		var b:=CheckButton.new();b.text=["维持回路","转移回路","维护桥接"][i];b.button_pressed=switches[i];b.disabled=chapter.flag("br_power_safe");b.toggled.connect(func(v: bool):switches[i]=v);actions.add_child(b)
	button("已验证：维持稳定 / 转移隔离 / 维护接入" if chapter.flag("br_power_safe") else "验证隔离",func():attempt("power_safe",{"switches":switches},"power"),chapter.flag("br_power_safe"))
	button("返回维修",show_view.bind("repair"))

func show_records() -> void:
	var allowed: bool=chapter.flag("br_body_seen") and chapter.flag("br_power_safe")
	fresh("原始档案","逐项阅读身份、护理与转化日志，再收录档案。" if allowed else "完整日志需要先核对原身体并验证维持供电。照片和编号备份随时可查。")
	for i in range(3):button(("✓ " if record_mask&(1<<i) else "□ ")+Copy.RECORD_TABS[i],read_record.bind(i),not allowed)
	button("收录档案",func():attempt("records",{"read_mask":record_mask},"records"),not allowed or record_mask!=7 or chapter.flag("br_records"))
	button("补查照片与编号",show_view.bind("photos"));button("核对记忆证据",show_view.bind("memory"),not chapter.flag("br_records"))

func read_record(index: int) -> void:
	record_mask|=1<<index;show_view("records");text_.text=Copy.RECORDS[index]
	if index==2:
		text_.text+="\n\n"+Copy.RECORDING_CAPTION
		button("重听现场记录",chapter.play_recording)

func show_imprint() -> void:
	fresh("维修 / 强制指令通道","记忆访问与强制执行是独立通道。先停用自动重写，再清除通道，最后验证自主响应。")
	if chapter.flag("br_imprint_cleared"):
		text_.text="强制响应 0，自主输入有效。\n我能停下来。它没有再把我拉回去。"
		text_.text+="\n先前只是临时干扰，本次永久关闭强制通道。" if chapter.flag("br_k2_spent") else "\n这次来得太晚了。" if chapter.value("br_mouse")==1 else ""
	button("✓ 已停用自动重写" if chapter.flag("br_rewrite_off") else "停用自动重写",func():attempt("rewrite_off",{},"imprint"),chapter.flag("br_rewrite_off") or not chapter.state.allowed("rewrite_off").allowed)
	button("✓ 已清除强制通道" if chapter.flag("br_channel_off") else "清除强制通道",show_view.bind("channel_confirm"),chapter.flag("br_channel_off") or not chapter.state.allowed("channel_off").allowed)
	button("✓ 自主响应已验证" if chapter.flag("br_imprint_cleared") else "运行离线验证",show_view.bind("offline"),chapter.flag("br_imprint_cleared") or not chapter.state.allowed("imprint_cleared").allowed)
	button("返回维修",show_view.bind("repair"))

func show_routing() -> void:
	fresh("维修 / 反向连接","读取源端必须是当前承载意识的猫身；写入原身体；以原始档案核验身份。每个接点只连接一条线。")
	aim(world.retrofit.get_node("ServiceCam"),1|4|16,game.player.camera.environment)
	for i in range(3):select_row(["源端读取","目标写入","身份核验"][i],["未连接","当前猫载体","原身体 H-031","原始档案"],routing[i]+1,func(v: int):
		var port:=v-1
		for other in range(3):
			if other!=i and routing[other]==port:routing[other]=-1
		routing[i]=port;show_view("routing"),chapter.flag("br_routing"))
	button("已验证" if chapter.flag("br_routing") else "检查连接",func():attempt("routing",{"choices":routing},"routing"),chapter.flag("br_routing"))
	button("重新查看档案",show_view.bind("records"))

func show_precheck() -> void:
	fresh("转移预检","目的载体与最后一次操作时间必须匹配。\n\n鼠类模板是旧测试模板，禁止作为恢复目标。")
	var readonly: bool=chapter.flag("br_target_verified")
	if readonly:text_.text+="\n\n已验证：H-031 / %02d:%02d:%02d"%Copy.VERIFY_TIME
	select_row("目的载体",["请选择目标","H-031 原身体","C-031 当前猫载体","R-000 鼠类测试模板"],target+1,func(v: int):target=v-1,readonly)
	var row:=HBoxContainer.new();actions.add_child(row)
	for i in range(3):
		var spin:=SpinBox.new();spin.min_value=0;spin.max_value=23 if i==0 else 59;spin.value=verify_time[i];spin.editable=not readonly;spin.custom_minimum_size.x=105;spin.value_changed.connect(func(v: float):verify_time[i]=int(v));row.add_child(spin)
	button("目标和时间已验证" if readonly else "验证目标和时间",func():attempt("target_verified",{"target":target,"time":verify_time},"precheck"),readonly)
	var checklist:=Label.new();checklist.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for key in Rules.HUMAN_FACTS:checklist.text+=("✓ " if chapter.flag(key) else "□ ")+Rules.NAMES[key]+"\n"
	actions.add_child(checklist)
	button("检查最终转移条件",show_view.bind("human_confirm"),not chapter.state.allowed("return_human").allowed)
	button("继续调查",close)

func show_vent() -> void:
	fresh("监控底下 / 通风格栅","右扣已经锈断。左扣、弯折边和格栅还可以松开。\n未完全打开时离开，需重新拨开。")
	aim(world.vent_service.get_node("VentCam"),1|4|16,game.player.camera.environment)
	if not chapter.flag("a11_memory") or not chapter.flag("a11_cage"):
		text_.text="先回想纸条，再检查01号笼里的猫毛和旧抓痕。";button("继续调查",close);return
	if chapter.flag("a11_vent"):
		text_.text="格栅已经打开。前代灰白猫从这里离开了笼子。\n打开出口还不意味着已经选择逃走。";button("查看猫身出口",show_view.bind("cat_confirm"));button("继续调查",close);return
	button(["拨开左扣","压下弯折边","推开格栅"][mini(vent_step,2)],func():
		vent_step+=1
		if vent_step==3:
			if not chapter.state.patch({"a11_vent":true},{}):vent_step=2;message=chapter.state.last_error
			else:world.vent_service.play_action(&"vent")
		show_view("vent"))

func close() -> void:
	if is_instance_valid(chapter.recording):chapter.recording.stop()
	# Owned world props remain attached to their original furniture/player.
	box=null;chest_attachment=null
	super.close()
	body_mask=0;record_mask=0;vent_step=0
	if is_instance_valid(chapter) and chapter.state!=null:chapter.world.restore(chapter.facts())

func _input(event: InputEvent) -> void:
	if not opened:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if active_view!="final":close()
			get_viewport().set_input_as_handled()

		elif event.keycode==KEY_E:
			var focus:=get_viewport().gui_get_focus_owner()
			if focus is Button and not focus.disabled:focus.pressed.emit()
			get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	# Cameras and stages are owned by the game root. During scene destruction,
	# siblings may already be gone; ordinary close() is only for a live scene.
	opened=false
	stages.clear();camera=null;box=null;chest_attachment=null
