extends "res://tools/playtest_story_branches.gd"
## Scene-boundary fixtures test the new interaction paths; not a natural full run.
func click(parent: Node, caption: String) -> bool:
	if not "--mouse-input" in OS.get_cmdline_user_args():return await super.click(parent,caption)
	await process_frame
	for button in parent.find_children("*","Button",true,false):
		if button.text!=caption and not button.text.ends_with(caption):continue
		verify(not button.disabled,"Mouse button enabled: "+caption)
		if button.disabled:return false
		var ancestor: Node=button.get_parent()
		while ancestor!=null:
			if ancestor is ScrollContainer:ancestor.ensure_control_visible(button)
			ancestor=ancestor.get_parent()
		await process_frame;await process_frame
		var pos: Vector2=button.get_global_rect().get_center()
		verify(root.get_visible_rect().has_point(pos),"Button inside actual window: "+caption)
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=pos;event.pressed=true;root.push_input(event,true);await process_frame
		event=event.duplicate();event.pressed=false;root.push_input(event,true);await process_frame;await ticks(1);return true
	verify(false,"Missing clickable button: "+caption);return false

func settle_memory() -> void:
	for _i in range(8):
		await ticks(4)
		if is_instance_valid(branch.film) and branch.film.running and branch.film.get_script()==load("res://story_branches/memory_film.gd"):await key(KEY_SPACE)
		else:break

func setup_day(number: int) -> void:
	dismiss();game._seed_demo_day(number);await ticks(3);dismiss()
	day.manager.apply_story_patch({"daily_note_ack_%d"%number:true,day.Notes.FLAGS[number]:true},{},false)
	branch.restore_world();await ticks(3)

func read_document(id: String) -> void:
	var document=branch.world.documents[id]
	var floor_y:=3.02 if id in ["d1","d3"] else .02
	var found:=false
	for offset in [Vector3(0,0,.60),Vector3(0,0,-.60),Vector3(.65,0,0),Vector3(-.65,0,0)]:
		var stand: Vector3=document.global_position+offset;stand.y=floor_y
		await aim_world(document.aim.global_position,stand)
		if branch.world.nearest_document()==id:found=true;break
	verify(found,"Physical document reachable from cat height: "+id)
	if not found:return
	await key(KEY_E);await ticks(5)
	verify(day.reader.mode=="evidence" and branch.flag("br_doc_"+id+"_read"),"E displays and automatically records "+id)
	await capture(id);await key(KEY_ESCAPE);await settle_memory()

func desktop_document(id: String, tab := "") -> void:
	game.cinematic_active=true;game.player.set_control(false)
	var computer=game.get_node("ActThree").computer
	computer.open();computer.apps.open_app("documents");await ticks(2)
	await click(computer.apps.body,{"d2":"人员档案 / H-031","d5":"住宅分站 / 封存记录","d6":"H-031 归档 / 回迁方案"}[id]);await ticks(5)
	if id=="d5" and tab=="access":await click(computer.apps.body,"访问说明");await ticks(5)
	verify((branch.value("br_d5_read_mask")&(2 if tab=="access" else 1))!=0 if id=="d5" else branch.flag("br_doc_"+id+"_read"),"Desktop page records "+id+tab)
	await capture(id+tab);computer.close_computer();await settle_memory()

func collect_evidence() -> void:
	await read_document("d3");await read_document("d4")
	await desktop_document("d5")
	verify(branch.value("br_d5_read_mask")==1 and not branch.flag("br_doc_d5_read"),"One recording page is incomplete")
	await desktop_document("d5","access")
	verify(branch.value("br_memory_level")==0,"Late evidence alone does not invent early memories")
	await read_document("d1");verify(branch.value("br_memory_level")==1,"D1 with original photo restores M1")
	await desktop_document("d2");verify(branch.value("br_memory_level")==3,"Out-of-order collection queues M2 and M3")
	await desktop_document("d6");verify(branch.flag("br_return_plan_ready"),"D6 forms return plan")

func equipment() -> void:
	await aim_world(branch.world.box.get_node("BoxAim").global_position,branch.world.desk.to_global(Vector3(.44,.025,.92)))
	verify(branch.world.nearest_item()=="maintenance_box","K2 box reachable from original floor")
	await key(KEY_E);await ticks(3)
	branch.panels.box_code="031";await click(branch.panels.actions,"打开维护盒")
	await click(branch.panels.actions,"阅读折页说明");await ticks(5)
	await process_frame;await process_frame;await process_frame
	verify(branch.flag("br_k2_manual_read") and day.reader.selected=="k2_manual","Displayed manual persists")
	await key(KEY_ESCAPE);verify(branch.panels.opened and not game.player.active,"Nested reader returns to box")
	await click(branch.panels.actions,"带上校准器");options(branch.panels.actions,Copy.K2_ANSWER);await click(branch.panels.actions,"离线自检")
	verify(branch.flag("br_k2_ready"),"K2 independent self-test completes")
	branch.panels.close();await ticks(2)

func mouse_event(saved: bool) -> void:
	day.manager.apply_story_patch({"a10_catch":true},{},false);fourth.restore();fourth.open_mouse_story()
	await click(fourth.panel.detail,"查看纸条");await ticks(5)
	await process_frame;await process_frame;await process_frame
	verify(branch.flag("a10_note"),"Mouse paper automatically read")
	await click(fourth.panel.detail,"返回");await click(fourth.panel.detail,"向阿嚼求证")
	for _i in range(3):await click(fourth.panel.detail,"继续听阿嚼说")
	await click(fourth.panel.detail,"听完阿嚼的话")
	await click(fourth.panel.detail,"启动校准器，放它走" if saved else "普通拒绝")
	verify(branch.value("br_mouse_intent")==0,"Opening decision does not consume charge")
	await click(branch.panels.actions,"启动并放走" if saved else "直接拒绝")
	await ticks(3);await key(KEY_SPACE);await ticks(5)
	verify(branch.value("br_mouse")== (2 if saved else 1),"Mouse movie commits correct result")
	verify(branch.flag("br_imprint_cleared")==saved,"Only rescue permanently clears imprint")
	dismiss();fourth.interact_item("nest");await click(fourth.panel.detail,"休息到明天");await ticks(6)

func alert_check() -> void:
	verify(branch.value("current_day")==11 and branch.flag("br_route_locked"),"Night locks route and advances date")
	verify(branch.alert.activated and game.get_node("HouseMemes").story_tv_active,"Alarm owns TV override")
	verify(not game.get_node("HouseMemes").start("tv"),"Old TV easter egg cannot override alarm")
	if is_instance_valid(branch.alert.intro):await key(KEY_SPACE)
	await ticks(5)
	verify(branch.flag("br_day11_alert_received") and branch.value("br_day11_intro_state")==2,"Intro receives basement target")
	verify(not branch.flag("daily_note_ack_11") and day.Notes.read(day),"Alarm does not forge note reading or require it")
	await capture("alarm")

func repair() -> void:
	await click(ending.ui.actions,"核对原身体与设备");await ticks(2)
	await click(branch.panels.actions,"检查转移条件")
	for label in Copy.BODY_FIELDS:await click(branch.panels.actions,label)
	await click(branch.panels.actions,"记录核对结果");branch.panels.show_view("repair")
	await click(branch.panels.actions,"检查电路隔离");await click(branch.panels.actions,"验证隔离")
	verify(not branch.flag("br_power_safe"),"Unsafe supply rejected")
	var switches_=branch.panels.actions.find_children("*","CheckButton",true,false)
	switches_[1].button_pressed=false;switches_[2].button_pressed=true;await click(branch.panels.actions,"验证隔离")
	branch.panels.show_view("imprint")
	if branch.flag("br_imprint_cleared"):
		await click(branch.panels.actions,"核验已解除状态")
	else:
		await click(branch.panels.actions,"停用自动重写");await click(branch.panels.actions,"清除强制通道")
		await click(branch.panels.actions,"确认清除");await click(branch.panels.actions,"运行离线验证");await click(branch.panels.actions,"拒绝执行")
	verify(branch.flag("br_imprint_cleared") and branch.flag("br_imprint_verified"),"Onsite clearance/verification complete")
	branch.panels.show_view("repair");await click(branch.panels.actions,"打开侧抽屉");await click(branch.panels.actions,"装入维护槽")
	branch.panels.show_view("routing");options(branch.panels.actions, [1,2,3]);await click(branch.panels.actions,"检查连接")
	branch.panels.show_view("precheck");options(branch.panels.actions,[1])
	var spins=branch.panels.actions.find_children("*","SpinBox",true,false)
	for i in range(3):spins[i].value=Copy.VERIFY_TIME[i]
	await click(branch.panels.actions,"验证目标和时间");await capture("return_precheck")
	await click(branch.panels.actions,"检查最终转移条件");await click(branch.panels.actions,"确认回到原身体")

func complete_route(route: int) -> void:
	day.manager.apply_story_patch({"a11_enter":true,"a11_locks":true},{"locks":3},false)
	ending.enter_laboratory();await ticks(5);await process_frame;await process_frame;await process_frame
	verify(not branch.state.commit_ending(3 if route==3 else 2),"Service rejects opposite route")
	if route==3:await repair()
	else:
		if route==1:
			await click(ending.ui.actions,"回想昨天的纸条");await click(ending.ui.actions,"我应该到处看看")
			ending.interact_item("cage");await ticks(3);ending.close_panel();branch.open_panel("vent")
		else:
			verify(branch.flag("br_escape_path_known") and not branch.flag("a11_cage"),"Mouse guide does not forge cage investigation")
			await click(ending.ui.actions,"检查通风格栅")
		for label in ["拨开左扣","压下弯折边","推开格栅"]:await click(branch.panels.actions,label)
		await click(branch.panels.actions,"查看猫身出口");await click(branch.panels.actions,"确认以猫身离开")
	await ticks(3);verify(is_instance_valid(branch.film) and branch.film.running,"Route starts actual movie")
	if not is_instance_valid(branch.film):return
	await key(KEY_SPACE);await ticks(3)
	await capture("ending_%d_%d"%[route,branch.value("br_mouse")])
	await click(branch.film.choice_content,"确认本次经历" if route==1 else "确认救援结果");await ticks(4)
	verify(branch.value("br_phase")==2 and branch.flag("a11_finished"),"Ending completion saved")
	verify(branch.flag("br_rescue_done")== (route!=1),"Rescue marked only when actually shown")
	var before=day.manager.make_save_data();branch.start_ending_film(true);await ticks(3);await key(KEY_SPACE);await ticks(3)
	await click(branch.film.choice_content,"确认本次经历" if route==1 else "确认救援结果");await ticks(3)
	verify(before==day.manager.make_save_data(),"Ending replay is read-only")

func run() -> void:
	if "--native-window" in OS.get_cmdline_user_args():root.content_scale_size=root.size
	create_timer(180).timeout.connect(func():printerr("PRE11_SCENE_TIMEOUT");quit(2))
	game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false;root.add_child(game);current_scene=game;game.start_game();await ticks(12)
	day=game.get_node("DayOne");branch=game.get_node("StoryBranches");fourth=game.get_node("ActFour");ending=game.get_node("Ending");dismiss()
	for prepared in [false,true]:
		for saved in [false,true]:
			await setup_day(10)
			if prepared:await collect_evidence()
			if saved:await equipment()
			await mouse_event(saved);await alert_check()
			var expected:=3 if prepared else 2 if saved else 1
			verify(branch.value("br_route")==expected,"Correct locked scene route")
			await complete_route(expected)
	print("PRE11_SCENE_TEST ",JSON.stringify({"checks":checks,"failures":failures}))
	branch.set_physics_process(false);dismiss();game.stop_audio();game.queue_free()
	for _i in range(4):await process_frame
	quit(0 if failures.is_empty() else 1)
