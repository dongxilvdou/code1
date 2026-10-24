extends SceneTree
## Save-free coverage of real ambience playback, house regions and cinematic mixing.
var checks := 0
var failures: Array[String] = []
var game: Node
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures.append(message);printerr("AMBIENCE_FAIL ",message)
func ticks(n: int) -> void:
	for i in range(n):await physics_frame
	await process_frame
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game);current_scene = game
	# Enter through the real new-game flow, including its one-time intro cleanup.
	game.ui.started.emit();await ticks(2);game.opening.request_skip();await ticks(45)
	var audio = game.rain_audio
	expect(audio.stream is AudioStreamOggVorbis,"Summer audio not installed")
	expect(audio.stream.loop and audio.playing,"Ambience not looping/playing")
	expect(audio.stream.get_length()>1019 and audio.stream.get_length()<1022,"Full 17-minute source was truncated")
	for point in [Vector3(-4,0,2),Vector3(1,0,-4),Vector3(.5,3,-4),Vector3(4.5,1.5,-1.5),Vector3(-4,-2,-3),Vector3(8,-2,-3),Vector3(-4,.98,4.5)]:
		expect(not audio.is_outdoor_at(point),"Indoor / basement / jump classified outdoors: "+str(point))
	for point in [Vector3(0,0,8),Vector3(0,0,-8),Vector3(-8,0,0),Vector3(8,0,0),Vector3(-4,3,4.5),Vector3(-4,3.8,4.5)]:
		expect(audio.is_outdoor_at(point),"Garden / terrace classified indoors: "+str(point))
	expect(not audio.is_outdoor_at(Vector3(0,0,6.04),false),"Door boundary jitter from inside")
	expect(audio.is_outdoor_at(Vector3(0,0,6.04),true),"Door boundary jitter from outside")
	expect(not audio.is_outdoor_at(Vector3(0,0,5.8),true),"Door return does not re-enter room")
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(-4,.03,2)
	await ticks(180)
	expect(absf(audio.volume_db-audio.indoor_volume_db)<.12,"Room not quiet")
	var start_position: float = audio.get_playback_position()
	var indoor_db: float = audio.volume_db
	game.player.global_position = Vector3(0,.03,8)
	await ticks(1)
	expect(audio.volume_db>indoor_db and audio.volume_db<indoor_db+2,"Outdoor sound jumped instead of fading")
	await ticks(180)
	expect(absf(audio.volume_db-audio.outdoor_volume_db)<.12,"Garden did not get louder")
	expect(audio.volume_db-indoor_db>19,"Indoor/outdoor contrast too small")
	expect(audio.playing and audio.get_playback_position()>start_position+2,"Room change restarted the recording")
	game.player.global_position = Vector3(-4,3.03,4.5)
	await ticks(12)
	expect(audio.outdoors,"Real upstairs terrace position not detected")
	game.player.global_position = Vector3(-4,.03,4.5)
	await ticks(180)
	expect(not audio.outdoors and absf(audio.volume_db-audio.indoor_volume_db)<.12,"Ground floor under terrace not muffled")
	# The existing opening owns volume while active, then returns it to the room mix.
	var intro = game.opening
	game.cinematic_active = true
	expect(intro.play(),"Comic cannot start with new audio")
	await ticks(3)
	expect(game.cinematic_active and intro.active,"Opening state changed unexpectedly")
	game.player.global_position = Vector3(0,.03,8)
	await ticks(8)
	expect(is_equal_approx(audio.volume_db,-36),"Outdoor mix fought opening fade")
	intro.request_skip()
	await ticks(40)
	expect(not intro.active and not game.cinematic_active and game.player.active,"Opening did not release original controls")
	game.player.set_physics_process(false)
	# Other cutscenes must be free to set their own volume, too.
	# The normal opening reset has just returned the actor to its indoor spawn.
	game.player.global_position = Vector3(0,.03,8)
	game.cinematic_active = true;audio.volume_db = -38
	await ticks(10)
	expect(is_equal_approx(audio.volume_db,-38),"Cinematic volume override overwritten")
	game.cinematic_active = false
	await ticks(180)
	expect(absf(audio.volume_db-audio.outdoor_volume_db)<.12,"Outdoor mix did not resume after cinematic: "+str({"db":audio.volume_db,"position":game.player.global_position,"outside":audio.outdoors,"cinematic":game.cinematic_active}))
	var length: float = audio.stream.get_length()
	audio.seek(length-.15)
	await ticks(45)
	expect(audio.playing and audio.get_playback_position()<2,"Audio did not wrap at end of recording")
	game.set_volume(.25)
	expect(absf(AudioServer.get_bus_volume_db(0)-linear_to_db(.25))<.01,"Existing settings volume broken")
	game.stop_audio();await ticks(4)
	expect(not audio.playing,"Shutdown restarted the ambience")
	print("AMBIENCE_TEST ",JSON.stringify({"checks":checks,"failures":failures,"duration":length,"indoor_db":audio.indoor_volume_db,"outdoor_db":audio.outdoor_volume_db}))
	game.queue_free();await ticks(3)
	quit(0 if failures.is_empty() else 1)
