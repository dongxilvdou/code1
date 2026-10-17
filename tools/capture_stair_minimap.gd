extends SceneTree
## Actual GPU views; captures stay in ignored verification logs.
var game: Node
func _initialize() -> void:call_deferred("run")
func shot(label: String) -> void:
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/stairs_minimap/"+label+".png")
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)
		await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://logs/stairs_minimap")
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game)
	current_scene = game
	await physics_frame
	game.start_game()
	game.player.set_control(false)
	game.player.set_physics_process(false)
	game.set_process(false)
	game.get_node("QuestSystem").set_process(false)
	game.get_node("QuestSystem").tracker.hide()
	game.ui.hud.hide()
	var hud = game.get_node("VillaMap/MapHUD")
	hud.set_process(false)
	hud.set_physics_process(false)
	hud.hide()
	game.cat_camera.make_current()
	var views := [[Vector3(4.12,1.50,.90),Vector3(4.00,.64,.10)],[Vector3(5.10,3.35,-.60),Vector3(5.20,2.30,.10)],[Vector3(5.22,.35,1.38),Vector3(5.20,-1.30,-.60)]]
	var shots := 0
	for j in range(views.size()):
		var view: Array = views[j]
		for i in range(30):
			game.cat_camera.global_position = view[0]+Vector3(sin(i*.06)*.06,0,0)
			game.cat_camera.look_at(view[1]+Vector3(sin(i*.06)*.12,0,0))
			game.cat_camera.fov = 66
			await process_frame
			await RenderingServer.frame_post_draw
			if i%10==0:
				root.get_texture().get_image().save_png("res://logs/stairs_minimap/turn_%d_%02d.png"%[j,i])
			shots += 1
	game.ui.hud.show()
	hud.show()
	var count := 0
	for sample in [["floor_1",Vector3(2.15,.02,2.15),.0],["floor_2",Vector3(3.35,3.02,4.45),.43],["basement",Vector3(5.2,-2.698,-2.75),PI],["stairs",Vector3(4,1.50,-1.6),PI/2]]:
		game.player.position = sample[1]
		game.player.yaw = sample[2]
		game.player.rotation.y = sample[2]
		game.player.camera.make_current()
		game.player.head.rotation.x = 0
		hud.current_map = sample[0]
		var spec: Dictionary = hud.maps[sample[0]]
		hud.current_floor = "floor_2" if sample[0]=="floor_2" else "floor_1"
		hud.mini.spec = spec
		hud.mini.base_texture = hud.fetch_texture(spec.base)
		hud.mini.structure_texture = hud.fetch_texture(spec.structure)
		hud.mini.labels_texture = hud.fetch_texture(spec.labels)
		hud.mini.position_xz = Vector2(sample[1].x,sample[1].z)
		hud.mini.region = hud.room_at(spec,hud.mini.position_xz)
		hud.current_room = hud.mini.region.get("name","")
		hud._process(0)
		await shot("minimap_"+sample[0])
		count += 1
	# Verify actual M/Esc routing, including restoration of movement.
	hud.big.spec = hud.mini.spec
	hud.big.base_texture = hud.mini.base_texture
	hud.big.labels_texture = hud.mini.labels_texture
	hud.big.position_xz = hud.mini.position_xz
	await key(KEY_M)
	var opened: bool = hud.big_open and not game.player.active
	hud._process(0)
	await shot("full_map_stairs")
	await key(KEY_ESCAPE)
	var restored: bool = not hud.big_open and game.player.active and not game.ui.pause_panel.visible
	print("GPU_CAPTURE ",JSON.stringify({"turn_frames":shots,"minimaps":count,"M_open":opened,"Esc_restores_control":restored}))
	game.stop_audio()
	game.queue_free()
	for i in range(3):await process_frame
	quit(0 if opened and restored else 1)
