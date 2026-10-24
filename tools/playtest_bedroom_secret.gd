extends SceneTree
var game: Node
var event: Node
var day: Node
var fourth: Node
var checks := 0
var failures: Array[String] = []
var capture := false
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("BEDROOM_SECRET_FAIL ",message)
func ticks(n: int) -> void:
	for i in range(n):await physics_frame
	await process_frame
func key(code: Key) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true
	root.push_input(e,true);await process_frame
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await process_frame
func photo(name_: String) -> void:
	if not capture:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/bedroom_secret/"+name_+".png")
func state() -> Dictionary:
	var result: Dictionary={"quest":JSON.stringify(day.manager.make_save_data()),"transform":game.player.global_transform,
		"camera":root.get_camera_3d(),"environment":game.player.camera.environment,"door":event.room_door.leaf.transform,
		"open":event.room_door.is_open,"locked":event.room_door.locked}
	return result
func restored(before: Dictionary,label: String) -> void:
	expect(not event.active and not game.cinematic_active,label+": event not released")
	expect(game.player.active and game.player.is_physics_processing() and game.player.is_processing_unhandled_input(),label+": input not restored")
	expect(root.get_camera_3d()==before.camera and game.player.camera.environment==before.environment,label+": camera/environment")
	expect(game.player.global_transform.is_equal_approx(before.transform),label+": player moved")
	expect(JSON.stringify(day.manager.make_save_data())==before.quest,label+": task/inventory changed")
	expect(event.room_door.is_open==before.open and event.room_door.locked==before.locked and event.room_door.leaf.transform.is_equal_approx(before.door),label+": door not restored")
	expect(not event.video.is_playing() and not event.projection.visible and not event.ui.visible,label+": lingering video/UI")
	for entry in event.lamps:expect(is_equal_approx(entry[0].light_energy,entry[1]),label+": lamp leak")
	for entry in event.surfaces:
		var material_: Material=entry.mesh.material_override if entry.surface<0 else entry.mesh.get_surface_override_material(entry.surface)
		expect(material_==entry.original,label+": material leak")
	if DisplayServer.get_name()!="headless":
		expect(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,label+": mouse not captured")
		var old_yaw: float=game.player.yaw
		var motion:=InputEventMouseMotion.new();motion.position=root.get_visible_rect().size*.5;motion.global_position=motion.position;motion.relative=Vector2(45,8)
		root.push_input(motion,true);await process_frame
		expect(absf(game.player.yaw-old_yaw)>.04,label+": mouse look swallowed")
func aim_button() -> void:
	game.player.global_position=event.desk.global_position+Vector3(-.40,.03,.72)
	var delta: Vector3=event.button.to_global(Vector3(0,-.04,0))-game.player.camera.global_position
	game.player.yaw=atan2(-delta.x,-delta.z);game.player.rotation.y=game.player.yaw
	game.player.pitch=atan2(delta.y,Vector2(delta.x,delta.z).length());game.player.head.rotation.x=game.player.pitch
func dog_photo(dog: Node3D,name_: String,offset: Vector3) -> void:
	if not capture:return
	game.cat_camera.global_position=dog.global_position+offset
	game.cat_camera.look_at(dog.global_position+Vector3(-.08,.25,0))
	game.cat_camera.fov=52;game.cat_camera.make_current()
	await ticks(4);await photo(name_)
	game.player.camera.make_current()
func run() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://logs/bedroom_secret")
	game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false
	root.add_child(game);current_scene=game;game.start_game();await ticks(10)
	day=game.get_node("DayOne");fourth=game.get_node("ActFour");event=game.get_node("BedroomSecret")
	day.dialog="";day.hud.overlay.hide()
	fourth.third.previous.seed_previous_days();fourth.begin_day(8);fourth.panel.close()
	day.manager.set_flag(&"daily_note_ack_8",true)
	var dog=game.get_node("Apartment/Staircase/DogNest")
	dog.pose_mode="lie";dog._process(.01);dog.set_pose("lie",true)
	await dog_photo(dog,"01_dog_front",Vector3(-1.1,.42,-.34))
	await dog_photo(dog,"02_dog_side",Vector3(-1.10,.70,-.60))
	expect(is_equal_approx(dog.get_node("Bed").rotation.y,-PI/2),"Bed entry not facing front paws")
	expect(absf(dog.get_node("Dog").position.z)<.01,"Dog not centered in bed")
	var rim: MeshInstance3D=dog.get_node("Bed").find_child("Continuous round bolster",true,false)
	var minimum:=10.0
	var maximum:=0.0
	for vertex in rim.mesh.get_faces():
		var point: Vector3=dog.to_local(rim.to_global(vertex))
		if point.x<-.47 and absf(point.z)<.20:maximum=maxf(maximum,point.y);minimum=minf(minimum,point.y)
	expect(maximum<.145 and minimum>.06,"Front bolster must stay below forepaws and above plinth")
	dog.pose_mode="auto"
	# Rule out interactions from other rooms or looking away.
	game.player.global_position=Vector3(-3,.03,3)
	expect(not event.available(),"Button reachable from downstairs")
	aim_button();await ticks(3)
	expect(event.available(),"Hidden red button not reachable from open knee space")
	game.update_target()
	expect(game.ui.hint_label.text.contains("红色按钮"),"Button hint missing")
	await photo("03_button")
	event.room_door.locked=false;event.room_door.set_open(true,true)
	var before:=state()
	await key(KEY_E)
	expect(event.active and event.phase==event.Phase.WARNING,"First E did not warn")
	expect(event.confirm_button.text.contains("再次按下"),"Explicit confirmation missing")
	expect(event.room_door.is_open and not event.video.is_playing(),"First press already changed room")
	await photo("04_warning")
	await key(KEY_ESCAPE);await ticks(2)
	await restored(before,"Warning cancel")
	aim_button();await ticks(2)
	before=state()
	await key(KEY_E);await key(KEY_E)
	expect(event.phase==event.Phase.CLOSING,"Second press did not start door closure")
	var began:=Time.get_ticks_msec()
	while event.active and event.phase!=event.Phase.PLAYING:
		await process_frame
		if Time.get_ticks_msec()-began>4000:expect(false,"Door/dimming watchdog");event.finish()
	expect(event.phase==event.Phase.PLAYING and not event.room_door.is_open and not event.room_door.moving,"Door not closed before video")
	expect(event.room_door.locked and event.fill.light_energy>0,"Room must have low visibility while closed")
	expect(event.camera.current and event.camera.environment.ambient_light_energy>0,"Room completely black / wrong camera")
	var sight := PhysicsRayQueryParameters3D.create(event.camera.global_position,event.projection.global_position,1)
	expect(game.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(),"Desk/chair hides video")
	var video_began:=Time.get_ticks_msec()
	await ticks(12);await photo("05_movie")
	expect(event.video.is_playing() and event.projection.visible,"Video not rendering")
	var direction: Vector3=event.projection.global_position.direction_to(event.camera.global_position)
	expect(event.projection.global_basis.z.normalized().dot(direction)>.99,"Projection not facing player")
	expect(event.projection.global_position.distance_to(event.bed.global_position+Vector3(0,1.30,0))<.001,"Cat not above bed")
	while event.active and event.phase==event.Phase.PLAYING:
		await process_frame
		if Time.get_ticks_msec()-video_began>8000:expect(false,"Video watchdog");event.finish()
	var movie_seconds: float=(Time.get_ticks_msec()-video_began)/1000.0
	while event.active:await process_frame
	await ticks(2)
	expect(movie_seconds>5.8 and movie_seconds<6.3,"Playback duration not six seconds: "+str(movie_seconds))
	await restored(before,"Natural")
	await photo("06_restored")
	# No duplicate confirmation; cancellation recovers an originally closed/locked door too.
	for target in [event.Phase.WARNING,event.Phase.CLOSING,event.Phase.DIMMING,event.Phase.PLAYING]:
		aim_button();await ticks(2)
		event.room_door.locked=true;event.room_door.set_open(false,true)
		before=state()
		expect(event.open_warning(),"Reentry failed")
		if target!=event.Phase.WARNING:event.confirm();event.confirm()
		while event.active and event.phase<target:await process_frame
		await key(KEY_ESCAPE);event.finish();event.finish()
		await ticks(2)
		await restored(before,"Cancel "+str(target))
	aim_button();await ticks(2)
	var stream: VideoStream=event.video.stream
	event.video.stream=null
	expect(not event.open_warning() and game.player.active,"Missing media blocks input")
	event.video.stream=stream
	expect(event.video.mouse_filter==Control.MOUSE_FILTER_IGNORE and event.video.focus_mode==Control.FOCUS_NONE,"Invisible video swallows mouse")
	print("BEDROOM_SECRET_TEST ",JSON.stringify({"checks":checks,"movie_seconds":movie_seconds,"capture":capture,"failures":failures}))
	game.queue_free();await ticks(3)
	quit(0 if failures.is_empty() else 1)

