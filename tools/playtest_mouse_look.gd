extends SceneTree
## Run with a window: the headless display server cannot capture a real pointer.
var game: Node
var secret: Node
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:call_deferred("run")
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("MOUSE_LOOK_FAIL ",message)
func ticks(count: int) -> void:
	for i in range(count):await physics_frame
	await process_frame
func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=true
	root.push_input(event,true);await process_frame
	event=event.duplicate();event.pressed=false
	root.push_input(event,true);await process_frame
func mouse(position_: Vector2,relative: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=position_;event.global_position=position_;event.relative=relative
	root.push_input(event,true)
	await process_frame
func can_look(label: String) -> void:
	var player=game.player
	expect(player.active and player.is_processing_unhandled_input(),label+": input disabled")
	expect(player.camera.current,label+": wrong camera")
	expect(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,label+": pointer not captured")
	var view:=root.get_visible_rect().size
	for point in [Vector2(.2,.2),Vector2(.5,.5),Vector2(.8,.7)]:
		var yaw_before: float=player.yaw
		var pitch_before: float=player.pitch
		var camera_before: Basis=player.camera.global_basis
		await mouse(view*point,Vector2(48,12))
		expect(absf(player.yaw-yaw_before)>.05,label+": horizontal mouse swallowed at "+str(point))
		expect(absf(player.pitch-pitch_before)>.01,label+": vertical mouse swallowed")
		expect(not player.camera.global_basis.is_equal_approx(camera_before),label+": view did not turn")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Run this integration test without --headless to check captured mouse input.")
		quit(2);return
	game=load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled=false
	root.add_child(game);current_scene=game
	await ticks(8)
	# New game, skip comic, then actual first-person play (no direct controller calls).
	game.ui.started.emit()
	expect(game.opening.active,"New game comic missing")
	await key(KEY_ESCAPE)
	await ticks(45)
	secret=game.get_node("DogSecret")
	expect(secret.video.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Hidden decoder still receives GUI input")
	expect(secret.video.focus_mode==Control.FOCUS_NONE,"Hidden decoder can steal focus")
	await can_look("New game")
	# Normal pause still releases pointer; resume restores mouse look.
	await key(KEY_ESCAPE)
	expect(game.ui.pause_panel.visible and not game.player.active,"Pause broken")
	expect(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Pause pointer hidden")
	await key(KEY_ESCAPE)
	await can_look("Resume")
	# Actual sixth-day+ kitchen event; run the genuine six-second video and recovery.
	var day=game.get_node("DayOne")
	var fourth=game.get_node("ActFour")
	fourth.third.previous.seed_previous_days()
	fourth.begin_day(8)
	fourth.panel.close()
	day.manager.set_flag(&"daily_note_ack_8",true)
	game.player.global_position=Vector3(1.45,.035,-3.9)
	await ticks(3)
	await can_look("Kitchen before egg")
	expect(secret.begin(),"Egg did not begin")
	var yaw_before: float=game.player.yaw
	await mouse(root.get_visible_rect().size*.5,Vector2(80,20))
	expect(is_equal_approx(game.player.yaw,yaw_before),"Dialogue leaked mouse input")
	for i in range(secret.LINES.size()):secret.advance()
	var began:=Time.get_ticks_msec()
	while secret.active:
		await process_frame
		if Time.get_ticks_msec()-began>16000:
			expect(false,"Egg watchdog")
			secret.finish(true)
	await ticks(3)
	await can_look("Natural egg end")
	for phase in [secret.Phase.DIALOGUE,secret.Phase.DIMMING,secret.Phase.VIDEO,secret.Phase.WHITEOUT,secret.Phase.RECOVERY]:
		expect(secret.begin(),"Cannot replay egg")
		if phase!=secret.Phase.DIALOGUE:
			for i in range(secret.LINES.size()):secret.advance()
		if phase>=secret.Phase.VIDEO:
			while secret.phase==secret.Phase.DIMMING:await process_frame
		if phase>=secret.Phase.WHITEOUT:secret._on_video_finished()
		if phase==secret.Phase.RECOVERY:
			secret.phase_time=secret.white_hold_seconds
			await process_frame
		await key(KEY_ESCAPE)
		await ticks(2)
		await can_look("Skip "+str(phase))
	print("MOUSE_LOOK_TEST ",JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()}))
	game.queue_free()
	await ticks(3)
	quit(0 if failures.is_empty() else 1)
