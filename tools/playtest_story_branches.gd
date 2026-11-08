extends SceneTree
const Rules=preload("res://story_branches/rules.gd")
const Service=preload("res://story_branches/state.gd")
const Copy=preload("res://story_branches/data.gd")
var game
var day
var branch
var fourth
var ending
var checks := 0
var failures: Array[String]=[]

func _initialize() -> void:call_deferred("run")
func ticks(count: int) -> void:
	for _i in range(count):await physics_frame
func verify(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("STORY_CHECK_FAILED ",message)
func key(code: Key) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;root.push_input(e,true);await process_frame
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await process_frame
func click(parent: Node, caption: String) -> bool:
	await process_frame
	for button in parent.find_children("*","Button",true,false):
		if button.text==caption or button.text.ends_with(caption):
			verify(not button.disabled,"Disabled button: "+caption)
			if button.disabled:return false
			button.grab_focus();await key(KEY_SPACE);await ticks(1);return true
	verify(false,"Missing button: "+caption);return false
func options(parent: Node, choices: Array) -> void:
	var nodes=parent.find_children("*","OptionButton",true,false)
	verify(nodes.size()>=choices.size(),"Missing option rows")
	for i in range(mini(nodes.size(),choices.size())):nodes[i].select(choices[i]);nodes[i].item_selected.emit(choices[i])
func dismiss() -> void:
	branch.cancel_runtime()
	if fourth.mouse_control.running:fourth.mouse_control.cancel()
	if not day.reader.mode.is_empty():day.reader.cancel()
	day.dialog="";day.hud.overlay.hide();fourth.panel.close();ending.ui.close()
	game.get_node("ActThree").panel.close();game.get_node("ActTwo").puzzle.close()
	game.cinematic_active=false;game.player.set_control(true)
func prepare(number: int, mouse := 0) -> void:
	dismiss();game._seed_demo_day(number)
	var flags={day.Notes.FLAGS[number]:true,"daily_note_ack_%d"%number:true}
	if number==11:flags.merge({"a10_eat":mouse==1,"br_mouse_resolved":mouse!=0,"a11_enter":true,"a11_memory":true})
	day.manager.apply_story_patch(flags,{"br_schema":1,"br_mouse":mouse,"br_mouse_intent":0},false)
	if number==11:verify(branch.state.migrate_legacy(),"Explicit old day11 fixture migrates")
	ending.initialized=true;ending.needs_restore=true
	await ticks(3);dismiss();branch.restore_world()
func capture(label_: String) -> void:
	if not "--branch-capture" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/story_%d_"%int(root.get_visible_rect().size.x)+label_+".png")

func unit_checks() -> void:
	var probe:=CalicoQuestManager.new();probe.configure(day.manager.catalog)
	var service=Service.new();service.manager=probe;service.system=game.get_node("QuestSystem")
	var cases=[
		[{"a10_eat":true},{"current_day":10},1,0,0,0],
		[{"a10_refused":true},{"current_day":10},0,1,0,0],
		[{"a10_catch":true,"a10_note":true,"a10_asked":true},{"current_day":10},0,0,0,0],
		[{"a11_escape":true},{"current_day":11},0,0,3,1],
		[{"a11_finished":true},{"current_day":11,"ending_choice":1},0,0,3,2],
		[{"a11_memory":true},{"current_day":11,"ending_choice":1},0,0,0,0]]
	for item in cases:
		probe.start_new_game();var data=probe.make_save_data();data.flags=item[0];data.values=item[1]
		verify(probe.restore_save_data(data,false) and service.migrate_legacy(),"Legacy migration failed: "+service.last_error)
		verify(probe.values.get("br_mouse")==item[2] and probe.values.get("br_mouse_intent")==item[3] and probe.values.get("br_ending")==item[4] and probe.values.get("br_phase")==item[5],"Legacy facts changed meaning")
		verify(not probe.flags.get("br_memory",false),"Paper memory granted researcher memory")
		var once=probe.make_save_data();verify(service.migrate_legacy() and once==probe.make_save_data(),"Migration is not idempotent")
	probe.start_new_game();var base=probe.make_save_data();base.flags={"a10_eat":true};base.values={"current_day":11,"br_schema":1,"br_mouse":2}
	probe.restore_save_data(base,false);var before=probe.make_save_data()
	verify(not service.migrate_legacy() and before==probe.make_save_data(),"Conflicting new save was silently rewritten")
	probe.start_new_game();probe.save_path="user://story_blocker/slot.json"
	var file=FileAccess.open("user://story_blocker",FileAccess.WRITE);file.store_string("block directory creation");file.close()
	before=probe.make_save_data()
	verify(not probe.apply_story_patch({"br_k2_spent":true},{"br_mouse_intent":2},true),"Failed physical save was accepted")
	verify(before==probe.make_save_data(),"Failed atomic save polluted flags, values or event history")
	verify(not probe.apply_story_patch({}, {"bad":1.5},false),"Float was accepted in integer state")
	var flags={"current_day":10,"a10_catch":true,"a10_note":true,"a10_asked":true,"br_k2_owned":true,"br_k2_ready":true,"br_k2_manual_read":true}
	verify(Rules.evaluate("rescue_mouse",flags).allowed,"Ready device cannot rescue")
	for key_ in ["a10_catch","a10_note","a10_asked","br_k2_owned","br_k2_ready"]:
		var missing=flags.duplicate();missing[key_]=false;verify(not Rules.evaluate("rescue_mouse",missing).allowed,"Missing prerequisite accepted: "+key_)
	flags.br_k2_spent=true;verify(not Rules.evaluate("rescue_mouse",flags).allowed,"Spent device can be reused")
	verify(Rules.validate_input("k2_ready",{"choices":Copy.K2_ANSWER}).is_empty(),"Correct calibration rejected")
	for choices_ in [[0,1,0],[1,0,0],[1,1,2]]:verify(not Rules.validate_input("k2_ready",{"choices":choices_}).is_empty(),"Bad calibration accepted")
	probe.free()

func aim_world(point: Vector3, stand: Vector3) -> void:
	game.player.global_position=stand;game.player.velocity=Vector3.ZERO;await ticks(6)
	var delta=point-game.player.camera.global_position
	game.player.yaw=atan2(-delta.x,-delta.z);game.player.rotation.y=game.player.yaw
	game.player.pitch=asin(delta.normalized().y);game.player.head.rotation.x=game.player.pitch
	game.player.camera.rotation=Vector3.ZERO;await process_frame

func equipment_and_mouse() -> void:
	await prepare(8)
	await aim_world(branch.world.box.get_node("BoxAim").global_position,branch.world.desk.to_global(Vector3(.44,.025,.92)))
	verify(branch.world.nearest_item()=="maintenance_box","Maintenance box is not reachable from the floor")
	await key(KEY_E);await ticks(2)
	verify(branch.panels.opened and branch.panels.active_view=="box","Actual E did not open the maintenance box")
	if not branch.panels.opened:branch.open_equipment("box")
	branch.panels.box_code="999";await click(branch.panels.actions,"打开维护盒")
	verify(not branch.flag("br_k2_owned"),"Wrong box code granted device")
	branch.panels.box_code=Copy.BOX_CODE;await click(branch.panels.actions,"打开维护盒");await click(branch.panels.actions,"阅读折页说明");await ticks(5);await key(KEY_ESCAPE);await click(branch.panels.actions,"带上校准器")
	verify(branch.flag("br_k2_owned") and branch.world.chest.visible,"Cross-day device was not equipped")
	await click(branch.panels.actions,"离线自检");verify(not branch.flag("br_k2_ready"),"Wrong settings passed self test")
	options(branch.panels.actions,Copy.K2_ANSWER);await click(branch.panels.actions,"离线自检")
	verify(branch.flag("br_k2_ready"),"Correct self test did not persist")
	await capture("equipment");branch.panels.close()
	day.manager.apply_story_patch({"a10_note_read":true,"daily_note_ack_10":true},{"current_day":10},false);fourth.begin_day(10);dismiss()
	day.manager.apply_story_patch({"a10_catch":true,"a10_note":true,"a10_asked":true},{},false);fourth.restore();fourth.open_mouse_story()
	await click(fourth.panel.detail,"启动校准器，放它走");verify(branch.value("br_mouse_intent")==0,"Opening confirmation consumed device")
	await click(branch.panels.actions,"返回");verify(not branch.flag("br_k2_spent"),"Cancelling confirmation consumed device")
	await click(fourth.panel.detail,"启动校准器，放它走");await click(branch.panels.actions,"启动并放走")
	verify(branch.value("br_mouse_intent")==2 and branch.flag("br_k2_spent"),"Rescue intent/charge were not committed together")
	verify(not branch.state.commit_mouse_intent(true),"Double click committed another rescue intent")
	verify(is_instance_valid(branch.film) and branch.film.running,"Independent rescue film did not start: "+branch.state.last_error)
	if not is_instance_valid(branch.film):return
	branch.film.toggle_pause();var time_=branch.film.clock;await ticks(3);verify(branch.film.clock==time_,"Pause did not freeze rescue")
	branch.film.resume();branch.film.clock=2.1;branch.film._tick(0);await capture("resist_button");var pending=day.manager.make_save_data();branch.cancel_runtime();day.manager.restore_save_data(pending);dismiss();await ticks(3)
	verify(is_instance_valid(branch.film) and branch.film.running and branch.flag("br_k2_spent"),"Pending rescue did not resume with spent charge")
	if is_instance_valid(branch.film):branch.film.skip()
	await ticks(3)
	verify(branch.value("br_mouse")==2 and not branch.flag("a10_eat") and branch.flag("br_mouse_resolved"),"Rescue produced wrong mouse fate")
	verify(not game.player.get_meta("holding_mouse",false) and not fourth.mouse_control.running,"Saved mouse is still held or swallowed")
	verify(fourth.day_complete(),"Rescued day ten cannot rest")
	dismiss();fourth.interact_item("nest");verify(fourth.panel.description.text==Copy.REST_SAVED,"Saved mouse uses old swallowing monologue")
	await click(fourth.panel.detail,"休息到明天");await ticks(3);verify(day.value("current_day")==11,"Saved mouse cannot advance to day eleven")

func ordinary_mouse() -> void:
	await prepare(10)
	day.manager.apply_story_patch({"a10_catch":true,"a10_note":true,"a10_asked":true,"br_k2_owned":true,"br_k2_ready":true,"br_k2_manual_read":true},{},false)
	fourth.restore();fourth.open_mouse_story()
	await click(fourth.panel.detail,"普通拒绝");await click(branch.panels.actions,"直接拒绝")
	verify(fourth.mouse_control.running and branch.value("br_mouse_intent")==1,"Ordinary refusal did not start saved forced action")
	verify(not branch.flag("br_k2_spent"),"Ordinary refusal silently consumed ready device")
	fourth.mouse_control.elapsed=fourth.mouse_control.DURATION;fourth.eat_mouse();await ticks(2)
	verify(branch.value("br_mouse")==1 and branch.flag("a10_eat") and fourth.day_complete(),"Ordinary refusal did not finish day ten")
	verify(not branch.world.mouse.visible,"Dead mouse is visible alive")
	dismiss();fourth.interact_item("nest");verify(fourth.panel.description.text==Copy.REST_LOST,"Ordinary refusal lost requested monologue")

func human_repairs() -> void:
	await aim_world(ending.target_position("device"),ending.world.equipment.to_global(Vector3(.35,.025,1.02)))
	verify(ending.nearest_item()=="device","Terminal is not reachable from cat height")
	await key(KEY_E);await ticks(2)
	verify(branch.panels.opened,"Actual E did not enter the terminal")
	if not branch.panels.opened:ending.interact_item("device")
	await click(branch.panels.actions,"检查转移条件")
	for label in Copy.BODY_FIELDS:await click(branch.panels.actions,label)
	await click(branch.panels.actions,"记录核对结果");verify(branch.flag("br_body_seen"),"Body verification was not recorded")
	branch.panels.show_view("repair");await click(branch.panels.actions,"检查电路隔离");await click(branch.panels.actions,"验证隔离")
	verify(not branch.flag("br_power_safe"),"Unsafe initial circuit was accepted")
	var buttons=branch.panels.actions.find_children("*","CheckButton",true,false)
	buttons[1].button_pressed=false;buttons[2].button_pressed=true
	await click(branch.panels.actions,"验证隔离");verify(branch.flag("br_power_safe"),"Safe circuit was not recorded")
	branch.panels.show_view("records")
	for label in Copy.RECORD_TABS:await click(branch.panels.actions,label)
	await click(branch.panels.actions,"收录档案");verify(branch.flag("br_records"),"Three records were not collected")
	await click(branch.panels.actions,"核对记忆证据");options(branch.panels.actions,Copy.MEMORY_ANSWER);await click(branch.panels.actions,"验证配对");await click(branch.panels.actions,"恢复记忆访问")
	verify(branch.flag("br_memory") and not branch.flag("br_imprint_cleared"),"Memory incorrectly clears imprint")
	if is_instance_valid(branch.film):branch.film.skip()
	await ticks(2);branch.panels.show_view("imprint")
	await click(branch.panels.actions,"停用自动重写");await click(branch.panels.actions,"清除强制通道");await click(branch.panels.actions,"确认清除");await click(branch.panels.actions,"运行离线验证");await click(branch.panels.actions,"拒绝执行")
	verify(branch.flag("br_imprint_cleared"),"Three-stage imprint repair did not finish")
	branch.panels.show_view("repair");await click(branch.panels.actions,"打开侧抽屉");await click(branch.panels.actions,"装入维护槽")
	branch.panels.show_view("routing")
	# Changing one socket clears its previous owner; all three inputs remain unique.
	for i in range(3):
		var rows=branch.panels.actions.find_children("*","OptionButton",true,false);rows[i].select(i+1);rows[i].item_selected.emit(i+1)
	await click(branch.panels.actions,"检查连接");verify(branch.flag("br_routing"),"Reverse routing was not verified")
	branch.panels.show_view("precheck");options(branch.panels.actions,[1])
	var spins=branch.panels.actions.find_children("*","SpinBox",true,false)
	for i in range(3):spins[i].value=Copy.VERIFY_TIME[i]
	await click(branch.panels.actions,"验证目标和时间");verify(branch.flag("br_target_verified"),"H-031/time precheck did not persist")
	await capture("precheck")

func finish_route(mouse: int, kind: int, repair_before_cat := false) -> void:
	await prepare(11,mouse)
	if kind==2:
		await human_repairs()
		await click(branch.panels.actions,"检查最终转移条件");await click(branch.panels.actions,"确认回到原身体")
	else:
		if repair_before_cat:await human_repairs();branch.panels.close()
		ending.interact_item("cage");ending.close_panel();ending.interact_item("vent")
		for label in ["拨开左扣","压下弯折边","推开格栅"]:await click(branch.panels.actions,label)
		verify(branch.value("br_ending")==0,"Opening grille locked ending")
		await click(branch.panels.actions,"查看猫身出口");await click(branch.panels.actions,"确认以猫身离开")
	verify(branch.value("br_ending")==kind and branch.value("br_phase")==1,"Final route did not commit before film")
	verify(not branch.state.commit_ending(kind),"Duplicate route confirmation succeeded")
	if not is_instance_valid(branch.film):verify(false,"No ending film");return
	var film=branch.film
	if kind==2:
		film.local_time=12;film._tick(0);verify(film.waiting,"Human ending skipped cat approach interaction")
		await click(film.choice_content,"蹲下，等它靠近");film._tick(4.2)
	else:
		film._tick(22.1);film._tick(3.6);film._tick(8.1);film._tick(3.1)
	film._tick(17)
	verify(film.waiting and branch.value("br_phase")==1 and not branch.flag("br_rescue_done"),"Ending completed before aftercare confirmation")
	await capture("rescue_%d_%d"%[mouse,kind]);await click(film.choice_content,"确认救援结果");await ticks(2)
	verify(branch.value("br_phase")==2 and branch.flag("br_rescue_done") and branch.flag("a11_finished") and branch.flag("a11_complete"),"Route did not finish rescue")
	verify(branch.value("br_mouse")==mouse and branch.flag("a10_eat")== (mouse==1),"Ending changed mouse fate")
	verify(branch.flag("a11_escape")== (kind==3),"Human route wrote cat escape")
	var before=day.manager.make_save_data()
	await click(branch.panels.actions,"重看结局");verify(branch.state.replay,"Replay is not read-only")
	branch.film.skip();await click(branch.film.choice_content,"确认救援结果");await ticks(2)
	verify(day.manager.make_save_data()==before,"Replay changed save facts or event history")
	if mouse==0:verify(not branch.panels.text_.text.contains("老鼠没有等到") and not branch.panels.text_.text.contains("冒险回来的老鼠"),"Unknown mouse fate was invented")

func run() -> void:
	create_timer(170).timeout.connect(func():printerr("STORY_TEST_TIMEOUT");quit(2))
	game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false;root.add_child(game);current_scene=game
	game.start_game();await ticks(10)
	day=game.get_node("DayOne");branch=game.get_node("StoryBranches");fourth=game.get_node("ActFour");ending=game.get_node("Ending")
	verify(day.manager.validation_errors.is_empty(),"Quest catalog invalid")
	unit_checks();await equipment_and_mouse();await ordinary_mouse()
	for mouse in [1,2]:
		for kind in [2,3]:await finish_route(mouse,kind)
	await finish_route(0,3,true)
	await finish_route(0,2)
	verify(not day.manager.autosave and not game.get_node("QuestSystem").save_enabled,"Tests can write player save")
	print("STORY_BRANCH_PLAYTEST ",JSON.stringify({"checks":checks,"failures":failures}))
	branch.set_physics_process(false);dismiss()
	for _i in range(2):await process_frame
	game.stop_audio();game.queue_free()
	for _i in range(3):await process_frame
	quit(0 if failures.is_empty() else 1)
