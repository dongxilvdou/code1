extends SceneTree
var game: Node
var memes: Node
var checks := 0
var failures: Array[String] = []
var durations := {}
var capture := false
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("HOUSE_MEME_FAIL ",message)
func ticks(n: int) -> void:
	for i in range(n):await physics_frame
	await process_frame
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	root.push_input(event,true);await process_frame
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await process_frame
func aim(point: Vector3) -> void:
	var delta: Vector3=point-game.player.camera.global_position
	game.player.yaw=atan2(-delta.x,-delta.z);game.player.rotation.y=game.player.yaw
	game.player.pitch=atan2(delta.y,Vector2(delta.x,delta.z).length());game.player.head.rotation.x=game.player.pitch
func place(id: String) -> void:
	game.player.set_physics_process(false)
	game.player.global_position=Vector3(-2.5,.03,2.57) if id=="tv" else Vector3(3.40,.94,-5.10)
	game.player.velocity=Vector3.ZERO
	aim(memes.entries[id].target.global_position+Vector3(0,.035,0))
	await ticks(3)
func photo(file: String) -> void:
	if not capture:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/house_memes/"+file+".png")
func mouse_look(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	var yaw: float=game.player.yaw
	var event:=InputEventMouseMotion.new();event.position=root.get_visible_rect().size*.5;event.global_position=event.position;event.relative=Vector2(40,7)
	root.push_input(event,true);await process_frame
	expect(absf(game.player.yaw-yaw)>.04,label+": invisible decoder blocked mouse")
func run() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://logs/house_memes")
	game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false
	root.add_child(game);current_scene=game
	await ticks(8)
	game.ui.started.emit();await ticks(2);game.opening.request_skip()
	while game.opening.active or game.opening.finishing:await process_frame
	await ticks(8)
	expect(game.started and game.player.active and not game.cinematic_active,"New-game fixture did not finish opening")
	memes=game.get_node("HouseMemes")
	var manager=game.get_node("QuestSystem").manager
	for id in ["tv","banana"]:
		var entry: Dictionary=memes.entries[id]
		expect(entry.video.stream!=null,"Missing media "+id)
		expect(entry.video.mouse_filter==Control.MOUSE_FILTER_IGNORE and entry.video.focus_mode==Control.FOCUS_NONE,"Decoder takes focus "+id)
		await place(id)
		expect(memes.target_id()==id,"Target unreachable: "+id)
		game.update_target();expect(not game.ui.hint_label.text.is_empty(),"Missing interaction hint "+id)
		await photo(id+"_off")
		var quest_before: String=JSON.stringify(manager.make_save_data())
		var transform_before: Transform3D=game.player.global_transform
		await key(KEY_E)
		expect(entry.playing and entry.video.is_playing(),"E did not start "+id)
		expect(game.player.active and game.player.camera.current and not game.cinematic_active,"Prop changed player/camera "+id)
		if id=="banana":expect(not memes.banana.visible,"Banana not replaced")
		else:expect(memes.indicator.emission_energy_multiplier>0,"TV switch not lit")
		var began:=Time.get_ticks_msec()
		await mouse_look(id+" playing")
		aim(entry.plane.global_position);await ticks(15)
		expect(entry.plane.visible,"Projection not visible "+id)
		if id=="banana":
			var direction: Vector3=entry.plane.global_position.direction_to(game.player.camera.global_position)
			expect(entry.plane.global_basis.z.normalized().dot(direction)>.99,"Banana cat not facing view")
		await photo(id+"_playing")
		while entry.playing:
			await process_frame
			if Time.get_ticks_msec()-began>6500:expect(false,"Playback watchdog "+id);memes.finish(id)
		durations[id]=(Time.get_ticks_msec()-began)/1000.0
		expect(durations[id]>4.7 and durations[id]<5.4,"Not five seconds "+id+": "+str(durations[id]))
		expect(not entry.plane.visible and not entry.video.is_playing(),"Playback did not stop "+id)
		expect(game.player.global_position.is_equal_approx(transform_before.origin),"Player moved "+id)
		expect(JSON.stringify(manager.make_save_data())==quest_before,"Changed quest/inventory "+id)
		expect(memes.banana.visible and is_zero_approx(memes.indicator.emission_energy_multiplier),"Prop did not restore "+id)
		await mouse_look(id+" end")
		await photo(id+"_restored")
	# Re-entry, manual TV off and interruption do not retain a hidden object/sound.
	await place("tv");await key(KEY_E);await key(KEY_E)
	expect(not memes.entries.tv.playing,"TV switch cannot turn off")
	await place("banana");expect(memes.start("banana"),"Banana replay failed")
	game.toggle_pause();await ticks(3)
	expect(not memes.entries.banana.playing and memes.banana.visible,"Pause left banana hidden")
	game.toggle_pause();await ticks(2)
	await mouse_look("Pause resume")
	await place("tv");expect(memes.start("tv"),"TV replay failed")
	game.cinematic_active=true;await ticks(2)
	expect(not memes.entries.tv.playing,"Story did not stop optional TV")
	game.cinematic_active=false
	game.player.global_position=Vector3(0,.03,-8);await ticks(4)
	var background_count:=0
	for sound in game.find_children("*","AudioStreamPlayer",true,false):
		if sound.playing:
			background_count+=1
			expect(sound==game.rain_audio,"Extra non-source background audio: "+str(sound.get_path()))
	expect(background_count==1,"Garden should have exactly one background recording")
	print("HOUSE_MEME_TEST ",JSON.stringify({"checks":checks,"failures":failures,"durations":durations,"background_players":background_count}))
	game.queue_free();await ticks(3)
	quit(0 if failures.is_empty() else 1)
