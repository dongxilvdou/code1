extends SceneTree
var game: Node
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:call_deferred("run")
func ticks(count: int) -> void:
	for i in range(count):await physics_frame
func verify(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("BRANCH_CLUE_FAILED ",message)
func photo(title: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await ticks(3);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/basement_review/"+title+".png")
func key(code: Key) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.pressed=true;Input.parse_input_event(e);await ticks(2)
	e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await ticks(2)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false
	root.add_child(game);current_scene=game;await ticks(12);game.start_game();await ticks(12)
	var day=game.get_node("DayOne");var third=game.get_node("ActThree")
	third.previous.seed_previous_days();third.begin_day(7)
	for f in ["a7_power","a7_computer_power","daily_note_ack_7"]:third.mark(f)
	third.restore()
	day.dialog="";day.hud.overlay.hide();third.panel.close();game.cinematic_active=false;game.player.set_control(true)
	var computer=third.computer
	computer.open();await photo("12_computer_login");computer.close_computer()
	for password in ["米酥","C031","c-031","C 031"]:
		day.manager.set_flag(&"a7_login",false);computer.open();computer.password.text=password;computer.submit_password()
		verify(third.flag("a7_login"),"Login rejected compatible password: "+password)
		computer.close_computer()
	day.manager.set_flag(&"a7_login",false);computer.open();computer.password.text="wrong";computer.submit_password()
	verify(not third.flag("a7_login"),"Invalid password accepted");computer.close_computer()
	third.set_flag("a7_login",true)
	for f in ["photo","site","chat","news"]:third.set_flag("a7_read_"+f,true)
	computer.apps.open_app("documents");await ticks(2)
	var found := false
	for label in computer.apps.body.find_children("*","Label",true,false):
		if label.text==preload("res://story_branches/data.gd").RECORD_INDEX:found=true
	verify(found,"Original-record index is absent from existing desktop")
	await photo("13_computer_index")
	computer.close_computer();third.panel.close();game.cinematic_active=false;game.player.set_control(true)
	var original_camera: Camera3D=root.get_camera_3d();var original_position: Vector3=game.player.global_position
	var real_cage: Node3D=game.get_node("Apartment/Basement/MedicalLaboratory/ObservationCage_03")
	var cage_transform: Transform3D=real_cage.global_transform
	for skip_ in [true,false]:
		var memory=load("res://story_branches/memory_player.gd").new();game.add_child(memory);memory.play(game)
		await ticks(5)
		verify(not game.player.active and game.cinematic_active,"Memory does not block real player")
		if skip_:
			await create_timer(1.35).timeout;await photo("14_memory_care")
			await key(KEY_ESCAPE)
			verify(memory.paused and memory.pause_panel.visible,"Esc fails to pause memory")
			memory.finish()
		else:await create_timer(2.1).timeout
		await ticks(4)
		verify(root.get_camera_3d()==original_camera and game.player.active,"Memory camera/control not restored")
		verify(game.player.global_position.distance_to(original_position)<.04,"Memory moved real player")
		verify(real_cage.global_transform.is_equal_approx(cage_transform),"Memory moved real cage")
	verify(not day.manager.autosave and not day.flag("br_memory"),"Preview commits branch progress")
	print("BRANCH_CLUES_TEST ",JSON.stringify({"checks":checks,"failures":failures}))
	game.stop_audio();game.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
