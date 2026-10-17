extends SceneTree
var game: Node
var checks := 0
var failures: Array[String] = []
var end_events := 0
var natural_seconds := 0.0
var obstruction_samples := 0
const SAVE := "user://opening_automated_tests/continue.json"

func _initialize() -> void:call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:failures.append(message)
func ticks(count: int) -> void:
	for i in range(count):await physics_frame
	await process_frame
func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	root.push_input(e,true)
	await process_frame
	e = e.duplicate()
	e.pressed = false
	root.push_input(e,true)
	await process_frame
func click(button: Button) -> void:
	var e := InputEventMouseButton.new()
	e.position = button.get_global_rect().get_center()
	e.global_position = e.position
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	root.push_input(e,true)
	await process_frame
	e = e.duplicate()
	e.pressed = false
	root.push_input(e,true)
	await process_frame
func enter(saved := false) -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = saved
	if saved:game.get_node("QuestSystem").save_file = SAVE
	root.add_child(game)
	current_scene = game
	end_events = 0
	game.opening.finished.connect(func(_skipped: bool):end_events += 1)
	await ticks(6)
func leave() -> void:
	game.queue_free()
	await ticks(3)
	game = null
func restored(label: String) -> void:
	expect(not game.cinematic_active and not game.opening.active,label+": intro still active")
	expect(game.started and game.player.active,label+": movement not enabled")
	expect(game.player.is_physics_processing() and game.player.is_processing_unhandled_input(),label+": controller processing not restored")
	expect(game.player.camera.current,label+": wrong camera after ending")
	expect(not game.ui.welcome.visible and game.ui.hud.visible,label+": menu/HUD not restored")
	expect(not game.ui.pause_panel.visible,label+": Esc also opened pause menu")
	expect(game.player.model.preview_pose=="game" and game.player.model.animate,label+": model driver not restored")
	expect(not game.opening.score.playing and not game.opening.meow.playing and not game.opening.paw.playing,label+": film audio still playing")
	expect(game.opening.finish_count==1 and end_events==1,label+": duplicate finish")
	expect(game.get_node("VillaMap/MapHUD").available(),label+": map unavailable")
	var sun: DirectionalLight3D = game.opening.sun_source
	expect(sun.basis.is_equal_approx(game.opening.snapshot.sun_basis),label+": sun orientation leaked")
	expect(sun.light_color.is_equal_approx(game.opening.snapshot.sun_color),label+": sun tint leaked")
	expect(game.player.collider.basis.is_equal_approx(Basis.IDENTITY),label+": collider changed")

func run() -> void:
	await enter()
	var intro: Node = game.opening
	expect(intro.should_play(false) and not intro.should_play(true),"Default save-aware playback policy")
	intro.playback_policy = 1
	expect(intro.should_play(true),"Always playback policy")
	intro.playback_policy = 2
	expect(not intro.should_play(false) and intro.should_play(true,true),"Off policy and forced preview")
	intro.playback_policy = 0
	# Use the real main-menu signal, not the bypass API used by older tests.
	game.ui.started.emit()
	expect(game.cinematic_active and not game.started,"Menu did not route through intro")
	expect(not game.player.active and not game.player.is_physics_processing(),"Actor controller competes with cutscene")
	var manager: Node = game.get_node("QuestSystem").manager
	var quest_snapshot := JSON.stringify(manager.make_save_data())
	await key(KEY_M)
	await key(KEY_B)
	await key(KEY_J)
	await key(KEY_V)
	await key(KEY_Q)
	expect(not game.get_node("VillaMap/MapHUD").big_open and not game.inspecting and not game.photo,"Game shortcuts leaked through cinematic")
	var elapsed := 0
	var sphere := SphereShape3D.new()
	sphere.radius = .04
	while game.cinematic_active and elapsed<2200:
		await physics_frame
		elapsed += 1
		if game.opening.film_time<27 and game.opening.active:
			expect(JSON.stringify(manager.make_save_data())==quest_snapshot,"Cutscene advanced quest state")
		if elapsed%15==0 and game.opening.active:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = sphere
			query.transform = game.opening.camera.global_transform
			query.collision_mask = 1
			var hits: Array = game.get_world_3d().direct_space_state.intersect_shape(query,1)
			expect(hits.is_empty(),"Camera intersects real scene geometry at "+str(game.opening.film_time))
			obstruction_samples += 1
	await ticks(4)
	natural_seconds = elapsed/60.0
	restored("Natural finish")
	expect(natural_seconds>27 and natural_seconds<29,"Film duration outside 28-second target")
	expect(game.opening.actor_distance>2.5 and game.opening.actor_distance<4.5,"Actor failed real ground movement")
	expect(game.player.is_on_floor(),"Actor not grounded at finish")
	var origin: Vector3 = game.player.position
	Input.action_press("move_forward")
	await ticks(24)
	Input.action_release("move_forward")
	expect(game.player.position.distance_to(origin)>.15,"Movement did not work after intro")
	await key(KEY_ESCAPE)
	expect(game.ui.pause_panel.visible and not game.player.active,"Normal pause broken after intro")
	await key(KEY_ESCAPE)
	await key(KEY_M)
	expect(game.get_node("VillaMap/MapHUD").big_open,"Map did not open after intro")
	await key(KEY_ESCAPE)
	await leave()
	# Early skip, stretch skip, walking skip, title skip: same finish path each time.
	for time in [0.1,8.0,16.0,23.0]:
		await enter()
		game.request_start_game(true)
		while game.opening.film_time<time:await physics_frame
		await key(KEY_ESCAPE)
		game.opening.request_skip()
		game.opening.request_skip()
		await ticks(45)
		restored("Skip "+str(time))
		await leave()
	# Layout and clicked skip are exercised at 4:3 and ultrawide sizes too.
	for dimensions in [Vector2i(800,600),Vector2i(1920,800)]:
		root.size = dimensions
		await enter()
		game.request_start_game(true)
		await ticks(2)
		var rect: Rect2 = game.opening.skip_hint.get_global_rect()
		expect(rect.position.x>=0 and rect.end.x<=root.get_visible_rect().size.x,"Skip outside viewport")
		await click(game.opening.skip_hint)
		await ticks(45)
		restored("Button skip "+str(dimensions))
		await leave()
	# Broken/stopped timeline must release input rather than soft-lock the game.
	await enter()
	game.request_start_game(true)
	game.opening.timeline.stop()
	await ticks(3)
	restored("Timeline stopped")
	await leave()
	# Only write a separate test save, never the real player's quest file.
	if FileAccess.file_exists(SAVE):
		expect(false,"Test save already exists; refused overwrite")
	else:
		await enter()
		manager = game.get_node("QuestSystem").manager
		manager.start_new_game()
		manager.set_flag(&"opening_test",true)
		manager.save_path = SAVE
		expect(manager.save_game(),"Create isolated continue fixture")
		await leave()
		await enter(true)
		var saved_position: Vector3 = game.player.position
		game.request_start_game()
		await ticks(8)
		expect(not game.cinematic_active and game.started and game.player.active,"Existing save incorrectly starts film")
		expect(game.player.position.distance_to(saved_position)<.05,"Continue flow moved the player")
		expect(game.get_node("QuestSystem").manager.flags.get("opening_test",false),"Continue failed to load original quest state")
		await leave()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("OPENING_PLAYTEST ",JSON.stringify({"checks":checks,"natural_seconds":natural_seconds,"camera_volume_samples":obstruction_samples,"skip_cases":6,"save_continue":true,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
