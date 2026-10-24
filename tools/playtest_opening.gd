extends SceneTree
## Save-isolated integration checks for the motion comic and real first-day flow.
var game: Node
var checks := 0
var failures: Array[String] = []
var end_events := 0
var shots := {}
var natural_seconds := 0.0
const SAVE := "user://opening_comic_tests/continue.json"
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures.append(message)
func ticks(count: int) -> void:
	for i in range(count):await physics_frame
	await process_frame
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code;event.physical_keycode = code;event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = event.duplicate();event.pressed = false
	root.push_input(event,true)
	await process_frame
func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT;event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = event.duplicate();event.pressed = false
	root.push_input(event,true)
	await process_frame
func enter(saved := false) -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = saved
	if saved:game.get_node("QuestSystem").save_file = SAVE
	root.add_child(game);current_scene = game
	end_events = 0
	game.opening.finished.connect(func(_skipped: bool):end_events += 1)
	game.opening.shot_changed.connect(func(index: int):shots[index] = true)
	await ticks(6)
func leave() -> void:
	game.queue_free()
	await ticks(3)
	game = null
func restored(label: String) -> void:
	var intro = game.opening
	var day = game.get_node("DayOne")
	expect(not intro.active and not intro.finishing and not game.cinematic_active,label+": still in cinematic")
	expect(game.started and game.player.active,label+": no player control")
	expect(game.player.is_physics_processing() and game.player.is_processing_unhandled_input(),label+": controller disabled")
	expect(game.player.camera.current,label+": wrong gameplay camera")
	expect(not intro.overlay.visible and not game.ui.welcome.visible,label+": overlay stuck")
	expect(game.ui.hud.visible and not game.ui.pause_panel.visible,label+": HUD/pause wrong")
	expect(day.dialog.is_empty() and day.flag("intro_seen"),label+": duplicate opening monologue")
	expect(not day.flag("daily_note_ack_1"),label+": skipped required daily note")
	expect(not intro.score.playing and not intro.meow.playing,label+": audio not stopped")
	expect(intro.finish_count==1 and end_events==1,label+": finish was repeated")
	expect(game.get_node("VillaMap/MapHUD").available(),label+": map unavailable")
	expect(game.player.position.distance_to(day.SPAWN)<.2,label+": wrong start position")
func run() -> void:
	await enter()
	var intro = game.opening
	expect(intro.valid_book,"Book failed validation: "+intro.error_message)
	expect(intro.pages.size()==4 and intro.cues.size()==11,"Missing story pages/cues")
	expect(intro.should_play(false) and not intro.should_play(true),"Save-aware playback")
	intro.playback_policy = 1
	expect(intro.should_play(true),"Always policy")
	intro.playback_policy = 2
	expect(not intro.should_play(false) and intro.should_play(true,true),"Off / force policy")
	intro.playback_policy = 0
	game.ui.started.emit()
	expect(game.cinematic_active and not game.started,"Menu did not start comic")
	expect(not game.player.active and not game.player.is_physics_processing(),"Competing player controller")
	var manager = game.get_node("QuestSystem").manager
	var state := JSON.stringify(manager.make_save_data())
	var actor: Transform3D = game.player.global_transform
	var sun: Transform3D = intro.sun_source.global_transform
	var lighting: Color = intro.sun_source.light_color
	var camera: Camera3D = root.get_camera_3d()
	for code in [KEY_M,KEY_B,KEY_J,KEY_V,KEY_Q]:await key(code)
	expect(not game.photo and not game.inspecting and not game.get_node("VillaMap/MapHUD").big_open,"Input leaked through comic")
	var began := Time.get_ticks_msec()
	var sampled := -1
	while intro.active:
		await process_frame
		if int(intro.film_time)!=sampled:
			sampled = int(intro.film_time)
			expect(game.player.global_transform.is_equal_approx(actor),"Comic moved real cat")
			expect(JSON.stringify(manager.make_save_data())==state,"Comic advanced quest state")
			expect(root.get_camera_3d()==camera,"Comic changed 3D camera")
		if Time.get_ticks_msec()-began>65000:
			expect(false,"Watchdog: did not end")
			intro.request_skip()
	natural_seconds = (Time.get_ticks_msec()-began)/1000.0
	await ticks(40)
	restored("Natural")
	expect(natural_seconds>54 and natural_seconds<58,"55-second autoplay duration")
	expect(shots.size()==11,"A story cue was skipped")
	expect(intro.meow_count==1,"Cat close-up must meow exactly once")
	expect(intro.sun_source.global_transform.is_equal_approx(sun) and intro.sun_source.light_color==lighting,"Lighting changed")
	var origin: Vector3 = game.player.position
	Input.action_press("move_forward")
	await ticks(24)
	Input.action_release("move_forward")
	expect(game.player.position.distance_to(origin)>.15,"Movement after comic")
	await key(KEY_ESCAPE)
	expect(game.ui.pause_panel.visible,"Pause unavailable")
	await key(KEY_ESCAPE)
	await key(KEY_M)
	expect(game.get_node("VillaMap/MapHUD").big_open,"Map unavailable")
	await key(KEY_ESCAPE)
	# First-day note still gates tasks and can be acknowledged normally.
	var day = game.get_node("DayOne")
	day.show_dialog("note")
	expect(not game.player.active and not day.flag("daily_note_ack_1"),"Note gating")
	day.advance_dialog()
	expect(game.player.active and day.flag("daily_note_ack_1"),"Note acknowledgement")
	await leave()
	for time in [0.1,10.0,15.0,28.0,38.0,52.0]:
		await enter()
		game.request_start_game(true)
		intro = game.opening
		intro.timeline.seek(time,true);intro._update_comic()
		await key(KEY_ESCAPE)
		intro.request_skip();intro.request_skip()
		await ticks(45)
		restored("Skip "+str(time))
		expect(intro.meow_count<=1,"Skip repeated meow")
		await leave()
	for dimensions in [Vector2i(800,600),Vector2i(1920,800)]:
		root.size = dimensions
		await enter()
		game.request_start_game(true)
		await ticks(2)
		intro = game.opening
		var area := root.get_visible_rect()
		var rect: Rect2 = intro.skip_hint.get_global_rect()
		expect(area.encloses(rect),"Skip outside viewport")
		var board_rect := Rect2(intro.board.position,intro.PAGE_SIZE*intro.board.scale)
		expect(area.grow(1).encloses(board_rect),"Comic cropped by aspect ratio")
		await click(intro.skip_hint)
		await ticks(45)
		restored("Button "+str(dimensions))
		await leave()
	await enter()
	game.request_start_game(true)
	intro = game.opening;intro.autoplay = false
	intro.allow_skip = false
	intro.request_skip()
	expect(intro.active and not intro.finishing,"Skip disabled setting")
	intro.allow_skip = true
	for i in range(3):await key(KEY_SPACE)
	expect(intro.last_shot==3 and intro.meow_count==1,"Advance to cat close-up")
	intro._update_comic();intro._update_comic()
	expect(intro.meow_count==1,"Repeat render triggered meow")
	while intro.active and not intro.finishing:await key(KEY_SPACE)
	await ticks(45)
	restored("Manual reading")
	await leave()
	await enter()
	game.request_start_game(true)
	game.opening.timeline.stop()
	await ticks(45)
	restored("Stopped timeline")
	await leave()
	# Isolated fixture; never reads/writes the player's normal save.
	if FileAccess.file_exists(SAVE):
		expect(false,"Existing test save refused overwrite")
	else:
		await enter()
		manager = game.get_node("QuestSystem").manager
		manager.start_new_game()
		manager.set_flag(&"opening_test",true)
		manager.set_flag(&"intro_seen",true)
		manager.save_path = SAVE
		expect(manager.save_game(),"Write isolated continue fixture")
		await leave()
		await enter(true)
		game.request_continue_game()
		await ticks(8)
		expect(game.started and not game.opening.active and game.opening.finish_count==0,"Continue replayed comic")
		expect(game.get_node("QuestSystem").manager.flags.get("opening_test",false),"Continue lost save data")
		await leave()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("COMIC_OPENING_TEST ",JSON.stringify({"checks":checks,"seconds":natural_seconds,"pages":4,"cues":11,"skip_cases":8,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
