extends "res://tools/playtest_villa.gd"
## Integration regression: real input routing, missing-import PNGs and stair lanes.
var map_hud
var stair_trials: Array = []

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame

func stair_route(label: String, x1: float, x2: float, rate: int, mode: String = "", diagonal: float = 0.0) -> void:
	Engine.physics_ticks_per_second = rate
	game.player.step_view_offset = 0.0
	game.player.camera.position.y = 0.0
	place(x1,8.0,.02,diagonal)
	await ticks(10)
	if not mode.is_empty():Input.action_press(mode)
	var ok := true
	if diagonal!=0:
		ok = await walk_until("z",6.9-6,rate*4) and ok
		face(0)
	ok = await walk_until("z",4.40-6,rate*9) and ok
	expect(absf(game.player.position.y-1.5)<.08,label+": failed half landing")
	face(-PI/2)
	ok = await walk_until("x",x2-6,rate*5) and ok
	face(PI)
	ok = await walk_until("z",8.02-6,rate*9) and ok
	expect(absf(game.player.position.y-3.0)<.08,label+": failed upper landing")
	await ticks(4)
	expect(map_hud.current_map=="floor_2",label+": map did not follow upstairs exit")
	face(0)
	ok = await walk_until("z",4.40-6,rate*9) and ok
	face(PI/2)
	ok = await walk_until("x",10.0-6,rate*5) and ok
	face(PI)
	ok = await walk_until("z",8.02-6,rate*9) and ok
	if not mode.is_empty():Input.action_release(mode)
	await ticks(8)
	expect(absf(game.player.position.y)<.08,label+": failed ground landing")
	expect(map_hud.current_map=="floor_1",label+": map did not follow downstairs exit")
	expect(ok,label+": blocked on stair route")
	stair_trials.append({"mode":label,"physics_hz":rate,"completed":ok})

func run_tests() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	# Simulate the malformed merged collider; runtime must repair it too.
	game.get_node("Miso/CollisionShape3D").rotation.x = PI*.5
	game.get_node("Miso/CollisionShape3D").scale = Vector3(1,1.3,1)
	root.add_child(game)
	current_scene = game
	map_hud = game.get_node("VillaMap/MapHUD")
	await ticks(4)
	expect(not map_hud.visible,"Map covers the welcome screen")
	game.start_game()
	await ticks(8)
	expect(game.player.collider.basis.is_equal_approx(Basis.IDENTITY),"Collider rotation/scale not repaired")
	expect(map_hud.visible and map_hud.current_map=="floor_1","Minimap did not start on ground floor")
	var loader = load("res://villa_maps/map_textures.gd")
	for spec in map_hud.maps.values():
		for layer in ["base","structure","labels"]:
			var path: String = "res://villa_maps/"+spec[layer]
			var texture: Texture2D = loader.load_texture(path,true)
			expect(texture!=null and texture.get_width()>0,"Missing-import fallback failed: "+path)
	await key(KEY_M)
	expect(map_hud.big_open and map_hud.big.visible and not game.player.active,"M did not open the map and stop movement")
	await key(KEY_B)
	await key(KEY_V)
	expect(not game.inspecting and not game.photo,"Map leaked input to overview/photo mode")
	await key(KEY_ESCAPE)
	expect(not map_hud.big_open and game.player.active and not game.ui.pause_panel.visible,"Esc did not close only the map")
	await key(KEY_M)
	await key(KEY_M)
	expect(game.player.active and not map_hud.big_open,"M could not close map")
	await key(KEY_ESCAPE)
	await key(KEY_M)
	expect(game.ui.pause_panel.visible and not map_hud.big_open and not game.player.active,"Map bypassed pause")
	await key(KEY_ESCAPE)
	await key(KEY_B)
	await ticks(3)
	expect(game.inspecting and not map_hud.visible,"Map obscures building overview")
	await key(KEY_B)
	await ticks(3)
	expect(game.player.active and map_hud.visible,"Map/control did not restore after overview")
	# Position, room highlight, facing, airborne floor retention and outdoor switch.
	for trial in [[2.6,10.2,.02,"floor_1"],[2.0,2.0,3.02,"floor_2"],[10.0,4.4,1.52,"stairs"],[2.0,-1.0,.02,"garden"]]:
		place(trial[0],trial[1],trial[2],0)
		await ticks(8)
		expect(map_hud.current_map==trial[3],"Incorrect map at "+str(trial))
		for canvas in [map_hud.mini,map_hud.big]:
			expect(canvas.base_texture!=null and canvas.labels_texture!=null,"Empty map canvas")
			expect(canvas.position_xz.distance_to(Vector2(game.player.position.x,game.player.position.z))<.01,"Player map marker misplaced")
	place(2.0,2.0,3.02,-PI/2)
	await ticks(8)
	await process_frame
	expect(absf(map_hud.map_angle+PI/2)<.01,"Minimap direction does not match camera")
	Input.action_press("jump")
	await ticks(1)
	Input.action_release("jump")
	await ticks(15)
	expect(map_hud.current_map=="floor_2","Jump changed map floor")
	await stair_route("left_edge",9.58,10.78,60)
	await stair_route("right_edge",10.42,11.62,60)
	await stair_route("diagonal_left",9.73,11.2,60,"",-.25)
	await stair_route("diagonal_right",10.27,11.2,60,"",.25)
	await stair_route("crouch",10.0,11.2,60,"crouch")
	await stair_route("sprint_30hz",10.0,11.2,30,"sprint")
	await stair_route("walk_120hz",10.0,11.2,120)
	Engine.physics_ticks_per_second = 60
	print("MAP_STAIRS_PLAYTEST ",JSON.stringify({"map_layers_checked":12,"stair_routes":stair_trials,"failures":failures}))
	game.stop_audio()
	game.queue_free()
	await process_frame
	await process_frame
	game = null
	call_deferred("quit",0 if failures.is_empty() else 1)
