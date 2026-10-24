extends SceneTree
## Real companion-chat, Theora playback and restoration checks. Never uses player save.
var game: Node
var day: Node
var third: Node
var fourth: Node
var secret: Node
var checks := 0
var failures: Array[String] = []
var capture := false
var ended_count := 0
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures.append(message);printerr("DOG_SECRET_FAIL ",message)
func ticks(n: int) -> void:
	for i in range(n):await physics_frame
	await process_frame
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code;event.physical_keycode = code;event.pressed = true
	root.push_input(event,true);await process_frame
	event = event.duplicate();event.pressed = false
	root.push_input(event,true);await process_frame
func dismiss() -> void:
	day.dialog = "";day.hud.overlay.hide()
	third.panel.close();fourth.panel.close()
	game.cinematic_active = false;game.player.set_control(true)
func snapshot() -> Dictionary:
	var data := {"quest":JSON.stringify(day.manager.make_save_data()),
		"player":game.player.global_transform,"collider":game.player.collider.transform,
		"camera":root.get_camera_3d(),"environment":game.player.camera.environment,"lights":[]}
	for pair in secret.lights:data.lights.append(pair[1])
	return data
func restored(before: Dictionary,label: String) -> void:
	expect(not secret.active and secret.phase==secret.Phase.IDLE,label+": event active")
	expect(game.player.active and game.player.is_physics_processing() and game.player.is_processing_unhandled_input(),label+": controls")
	expect(not game.cinematic_active and root.get_camera_3d()==before.camera,label+": camera")
	expect(game.player.global_transform.is_equal_approx(before.player),label+": player transform")
	expect(game.player.collider.transform.is_equal_approx(before.collider),label+": collision")
	expect(game.player.camera.environment==before.environment,label+": environment")
	expect(JSON.stringify(day.manager.make_save_data())==before.quest,label+": quest/save state")
	expect(not secret.video.is_playing() and not secret.projection.visible and not secret.ui.visible,label+": orphan media/UI")
	expect(secret.dog_actor.is_processing() and secret.finish_count==1,label+": dog/cleanup")
	for pair in secret.lights:expect(is_equal_approx(pair[0].light_energy,pair[1]),label+": light leak")
	for entry in secret.emissive_surfaces:
		var restored_material: Material = entry.mesh.material_override if entry.surface<0 else entry.mesh.get_surface_override_material(entry.surface)
		expect(restored_material==entry.original,label+": emissive override leak")
	for pair in secret.canvases:expect(pair[0].visible==pair[1],label+": HUD leak")
func ready_video() -> void:
	for i in range(secret.LINES.size()):secret.advance()
	while secret.phase==secret.Phase.DIMMING:await process_frame
	await ticks(12)
func photo(name_: String) -> void:
	if not capture:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/dog_secret/"+name_+".png")
func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://logs/dog_secret")
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game);current_scene = game;game.start_game()
	await ticks(10)
	day=game.get_node("DayOne");third=game.get_node("ActThree");fourth=game.get_node("ActFour");secret=game.get_node("DogSecret")
	dismiss()
	expect(is_equal_approx(secret.trigger_chance,.5),"Production chance is not 50%")
	expect(secret.video.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Invisible video blocks mouse look")
	expect(not secret.eligible() and not secret.begin(),"Early game triggered")
	fourth.third.previous.seed_previous_days()
	fourth.begin_day(8);dismiss()
	day.manager.set_flag(&"daily_note_ack_8",true)
	game.player.global_position=Vector3(1.45,.035,-3.9)
	game.player.yaw=-PI/2;game.player.rotation.y=-PI/2
	await ticks(3)
	expect(secret.eligible(),"Moved kitchen dog not eligible")
	# A zero roll still gives the original complete ordinary conversation.
	secret.trigger_chance=0
	fourth.interact_item("dog")
	expect(fourth.panel.mode=="story" and secret.pending_panel==fourth.panel,"Original chat lost")
	expect(not secret.active,"Triggered before normal chat finished")
	fourth.panel.close();await ticks(2)
	expect(not secret.active and game.player.active,"Zero chance triggered or blocked controls")
	# Actual chat dismissal enters the optional seven-line conversation.
	secret.trigger_chance=1
	fourth.interact_item("dog")
	fourth.panel.close();await ticks(2)
	expect(secret.active and secret.line_index==0,"Guaranteed roll failed")
	expect(secret.words.text=="曾经的我有一个能力，威能巨大，我不敢轻易尝试","Required dog line")
	expect(not secret.begin(),"Duplicate start allowed")
	var before := snapshot()
	ended_count=0
	secret.ended.connect(func(_cancelled):ended_count+=1)
	await photo("01_dialogue")
	for code in [KEY_M,KEY_B,KEY_J,KEY_V]:await key(code)
	expect(not game.photo and not game.inspecting and not game.get_node("VillaMap/MapHUD").big_open,"Input leak")
	var began := Time.get_ticks_msec()
	await ready_video()
	expect(secret.phase==secret.Phase.VIDEO and secret.video.is_playing(),"Video did not play")
	expect(secret.camera.current and not game.player.active,"Movie camera/control")
	var dark_count := 0
	for pair in secret.lights:
		if pair[1]>0 and pair[0].light_energy<pair[1]*.03:dark_count+=1
	expect(dark_count>0,"No actual light dimming")
	expect(not secret.emissive_surfaces.is_empty(),"No emissive lamp surfaces handled")
	for entry in secret.emissive_surfaces:expect(not entry.dark.emission_enabled,"Lamp still emits")
	expect(secret.projection.global_position.distance_to(secret._head_position()+Vector3.UP*.95)<.002,"Not above dog's head")
	var forward: Vector3=secret.projection.global_basis.z.normalized()
	expect(forward.dot(secret.projection.global_position.direction_to(secret.camera.global_position))>.99,"Billboard not facing player")
	await photo("02_projection")
	# Move only the temporary viewing camera to verify live billboarding.
	var original_camera: Transform3D = secret.camera.global_transform
	secret.camera.global_position+=Vector3(.3,.1,.15)
	await ticks(2)
	await process_frame
	await process_frame
	forward=secret.projection.global_basis.z.normalized()
	expect(forward.dot(secret.projection.global_position.direction_to(secret.camera.global_position))>.99,"Billboard did not follow viewpoint")
	secret.camera.global_transform=original_camera
	var position_before: float=secret.video.stream_position
	await ticks(20)
	expect(secret.video.stream_position>position_before,"Video frames not advancing")
	while secret.active and secret.phase==secret.Phase.VIDEO:
		await process_frame
		if Time.get_ticks_msec()-began>9000:
			expect(false,"Video did not finish");secret._on_video_finished()
	expect(secret.phase==secret.Phase.WHITEOUT and secret.white.color.a==1,"No full white at movie end")
	var white_began := Time.get_ticks_msec()
	await photo("03_whiteout")
	await ticks(165)
	expect(secret.phase==secret.Phase.WHITEOUT and secret.white.color.a==1,"White did not hold for three seconds")
	while secret.active and secret.phase==secret.Phase.WHITEOUT:await process_frame
	var white_seconds := (Time.get_ticks_msec()-white_began)/1000.0
	expect(white_seconds>=2.9 and white_seconds<3.25,"Wrong white hold duration: "+str(white_seconds))
	await ticks(75)
	expect(secret.phase==secret.Phase.RECOVERY and secret.white.color.a>0 and secret.white.color.a<1,"No gradual visual recovery")
	await photo("04_recovery")
	while secret.active:await process_frame
	await ticks(2)
	restored(before,"Natural")
	expect(ended_count==1 and not secret.last_cancelled,"Natural end repeated/cancelled")
	await photo("05_restored")
	# Cancel each phase; all use exactly the same restoration.
	for target in [secret.Phase.DIALOGUE,secret.Phase.DIMMING,secret.Phase.VIDEO,secret.Phase.WHITEOUT,secret.Phase.RECOVERY]:
		expect(secret.begin(),"Re-entry after cleanup")
		before=snapshot()
		if target!=secret.Phase.DIALOGUE:
			for i in range(secret.LINES.size()):secret.advance()
		if target>=secret.Phase.VIDEO:
			while secret.phase==secret.Phase.DIMMING:await process_frame
		if target>=secret.Phase.WHITEOUT:secret._on_video_finished()
		if target==secret.Phase.RECOVERY:
			secret.phase_time=secret.white_hold_seconds
			await process_frame
		await key(KEY_ESCAPE)
		secret.finish();secret.finish()
		restored(before,"Cancel "+str(target))
	# Day ten's required mouse dialogue wins over the easter egg.
	fourth.begin_day(10);dismiss()
	day.manager.set_flag(&"daily_note_ack_10",true)
	fourth.mark("a10_catch")
	fourth.interact_item("dog")
	expect(fourth.panel.mode=="eat" and not is_instance_valid(secret.pending_panel) and not secret.active,"Mouse task intercepted")
	dismiss()
	# Day-six feeding/unlocking remains exclusive; idle chat later can queue.
	third.begin_day(6);dismiss()
	day.manager.set_flag(&"daily_note_ack_6",true)
	day.manager.set_flag(&"a6_feed",true)
	day.manager.set_flag(&"a6_permission",false);third.restore()
	third.interact_item("dog")
	expect(day.flag("a6_permission") and not is_instance_valid(secret.pending_panel),"Stair permission intercepted")
	third.panel.close();await ticks(2)
	expect(not secret.active,"Unlocking conversation rolled the egg")
	secret.trigger_chance=0
	third.interact_item("dog");third.panel.close();await ticks(2)
	expect(not secret.active and game.player.active,"Act3 ordinary chat blocked")
	# Video missing is a safe no-op, no control/lighting ownership taken.
	var media: VideoStream = secret.video.stream
	secret.video.stream=null
	expect(not secret.begin() and game.player.active,"Missing clip softlock")
	secret.video.stream=media
	print("DOG_SECRET_TEST ",JSON.stringify({"checks":checks,"white_seconds":white_seconds,"video_seconds":6.0,"capture":capture,"failures":failures}))
	game.queue_free()
	await ticks(3)
	quit(0 if failures.is_empty() else 1)

