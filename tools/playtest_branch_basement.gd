extends SceneTree
var game: Node
var checks := 0
var failures: Array[String] = []
const OUTPUT := "res://logs/basement_review/"
func _initialize() -> void:call_deferred("run")
func ticks(count: int) -> void:
	for i in range(count):await physics_frame
	await process_frame
func verify(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("BRANCH_CHECK_FAILED ",message)
func aim(pos: Vector3) -> void:
	var delta: Vector3=pos-game.player.camera.global_position
	game.player.yaw=atan2(-delta.x,-delta.z);game.player.rotation.y=game.player.yaw
	game.player.pitch=atan2(delta.y,Vector2(delta.x,delta.z).length());game.player.head.rotation.x=game.player.pitch
func photo(title: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await ticks(6);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+title+".png")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false
	root.add_child(game);current_scene=game;await ticks(12);game.start_game();await ticks(12)
	var day=game.get_node("DayOne");var fourth=game.get_node("ActFour");var ending=game.get_node("Ending")
	fourth.third.previous.seed_previous_days();fourth.begin_day(11);fourth.set_value("locks",3)
	for f in ["a6_permission","a11_enter","a11_complete","daily_note_ack_11","a11_memory"]:fourth.mark(f)
	fourth.restore();await ticks(8)
	day.dialog="";day.hud.overlay.hide();fourth.panel.close();ending.ui.close();game.cinematic_active=false;game.player.set_control(true)
	var world=ending.world;world.restore(true,false)
	verify(world.chamber.find_children("Retrofit","",true,false).size()==1,"Exactly one retrofit required")
	verify(world.items.vent.find_children("GrillePivot","",true,false).size()==1,"Exactly one grille required")
	verify(world.chamber.get_node_or_null("ControlHousing")==null,"Old control housing survived")
	verify(world.report_source!=null,"Original archive folder was not bound")
	verify(world.report_source==null or not world.report_source.visible,"Old top archive was duplicated")
	world.restore(false,false);verify(world.report_source.visible,"Leaving ending hides original archive")
	world.restore(true,false)
	for i in range(3):
		var cage=game.get_node("Apartment/Basement/MedicalLaboratory/ObservationCage_%02d"%(i+1))
		verify(cage.get_node("Leaf/Sign").text.contains(["失踪","终止","C-031"][i]),"Cage override lost in ready")
		verify(cage.get_node("Leaf/CollisionShape3D").shape!=null,"Cage lost collision")
	# Real controller dimensions / line of sight at both standing and crouching eye height.
	game.player.global_position=Vector3(-2.74,-2.68,-2.85);await ticks(10)
	for crouch in [false,true]:
		if crouch:Input.action_press("crouch")
		await ticks(15);aim(world.items.report.global_position);await ticks(2)
		verify(ending.nearest_item()=="report","Report E unavailable: crouch="+str(crouch))
		Input.action_release("crouch")
	ending.interact_item("report")
	verify(ending.ui.body.text==preload("res://story_branches/data.gd").REPORT,"Report text changed")
	verify(not day.flag("br_records"),"Report incorrectly grants branch records")
	await photo("07_report_fulltext");ending.on_action("close");await ticks(3)
	verify(game.player.active and not game.cinematic_active,"Report leaves input disabled")
	game.player.global_position=Vector3(.60,-2.68,-2.55);await ticks(10);aim(world.items.device.global_position);await ticks(2)
	verify(ending.nearest_item()=="device","Device E occluded at prescribed position")
	game.cat_camera.global_position=Vector3(2.9,-1.35,-2.7);game.cat_camera.look_at(Vector3(-2.25,-1.65,-2.48));game.cat_camera.make_current()
	await photo("01_entrance")
	game.player.camera.make_current();await photo("02_cat_device")
	game.cat_camera.global_position=Vector3(-3.0,-2.05,-2.4);game.cat_camera.look_at(Vector3(-4.6,-2.23,-.7));game.cat_camera.make_current()
	await photo("03_cage_and_vent");game.player.camera.make_current()
	var inspect=load("res://story_branches/inspection.gd").new();game.add_child(inspect)
	var original_camera: Camera3D=root.get_camera_3d();var original_pos: Vector3=game.player.global_position
	inspect.open(game,world,true);await ticks(3)
	world.retrofit.play_action(&"drawer");await create_timer(.35).timeout
	verify(is_equal_approx(world.retrofit.get_node("DrawerSlide").position.z,.535),"Drawer travel incorrect")
	await photo("05_drawer_open")
	for repeat_ in range(2):
		for state in [{},{"br_auto_stopped":true},{"br_power_safe":true,"br_module":true,"br_routing":true}]:
			world.retrofit.apply_visual_state(state)
			verify(world.retrofit.get_node("LifeLED").material_override.emission_enabled,"Life line cut by emergency")
			verify(world.retrofit.get_node("ModuleInstalled").visible==state.get("br_module",false),"Module restoration incorrect")
	inspect.show_view("vent");world.vent_service.play_action(&"vent");await create_timer(.85).timeout
	verify(absf(world.grille.rotation.y+1.05)<.001,"Vent choreography failed")
	await photo("06_vent_open")
	inspect.show_view("body");await ticks(3);await photo("04_h031_observation")
	var bay=inspect.stages.recovery_bay
	inspect.aim(bay.get_node("BodyDetailCam"),128,bay.get_node("StageCamera").environment);await photo("04b_h031_face")
	var chest_y: float=bay.get_node("BreathingChest").position.y
	await create_timer(.3).timeout
	verify(not is_equal_approx(chest_y,bay.get_node("BreathingChest").position.y),"Patient is not breathing")
	verify(bay.get_node("ResearcherH031/ShortHair")!=null,"Male face/hair missing")
	verify(bay.find_children("*","CollisionObject3D",true,false).is_empty(),"Off-map stage has physics")
	verify((game.player.camera.cull_mask&128)==0,"Player sees recovery stage layer")
	inspect.show_view("records");verify(inspect.text_.text.contains("先核对"),"Record prerequisites not enforced")
	for i in range(3):inspect.check_body(i)
	inspect.session.br_body_seen=true;inspect.session.br_power_safe=true
	for i in range(3):inspect.read_record(i)
	verify(inspect.record_mask==7,"Record read mask incomplete")
	await photo("08_terminal_records")
	inspect.show_view("box");inspect.box.play_action(&"box");await create_timer(.4).timeout
	verify(inspect.box.get_node("BoxDoorPivot").rotation_degrees.y< -104,"Maintenance door travel incorrect")
	await photo("09_maintenance_box")
	for state in ["未校准","就绪","已消耗","待完成救鼠"]:
		inspect.show_k2(state);await ticks(3);await photo("k2_"+str(["未校准","就绪","已消耗","待完成救鼠"].find(state)))
	inspect.show_view("memory");inspect.stages.memory_vignette.play_action(&"care");await create_timer(1.45).timeout;await photo("10_care_memory")
	verify((inspect.stages.memory_vignette.get_node("MemoryMiso").visuals.find_children("*","MeshInstance3D",true,false)[0].layers&512)!=0,"Memory cat layer escaped isolation")
	inspect.show_view("rescue");await ticks(3);await photo("11_rescue_stage")
	inspect.close();await ticks(3)
	verify(root.get_camera_3d()==original_camera,"Inspection failed to restore original camera")
	verify(game.player.active and not game.cinematic_active,"Inspection failed to restore input")
	verify(game.player.global_position.distance_to(original_pos)<.03,"Inspection moved player")
	verify(not day.flag("br_body_seen") and not day.flag("br_power_safe"),"Model preview wrote branch facts")
	verify(not game.get_node("QuestSystem").save_enabled and not day.manager.autosave,"Test enables normal saving")
	# Escape follows the same cleanup path as the close button.
	inspect.open(game,world,true);await ticks(2)
	var key:=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;Input.parse_input_event(key);await ticks(3)
	verify(not inspect.opened and game.player.active,"Esc did not cleanly close inspection")
	var result:={"checks":checks,"failures":failures};print("BRANCH_BASEMENT_TEST ",JSON.stringify(result))
	var f:=FileAccess.open(OUTPUT+"results.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	game.stop_audio();game.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
