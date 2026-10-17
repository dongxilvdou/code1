extends "res://tools/playtest_map_stairs.gd"
func run_tests() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.start_game()
	place(3.0,24.0,.02,0.0)
	# Garden positions use the same player origin convention; find a known clear lawn.
	game.player.position = Vector3(-8,.08,8)
	await ticks(30)
	await key(KEY_V)
	expect(game.photo,"V did not enable third-person view")
	expect(game.cat_camera.current,"Third-person camera is not active")
	expect(game.player.active,"Third-person disabled the existing movement controller")
	var origin: Vector3 = game.player.position
	Input.action_press("move_forward")
	await ticks(30)
	await process_frame
	expect(game.player.position.distance_to(origin)>.15,"Third-person walking did not move")
	expect(game.player.model.last_state=="walk","Walk animation not selected")
	Input.action_press("sprint")
	await ticks(35)
	await process_frame
	expect(game.player.model.last_state=="run","Run animation not selected")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await ticks(30)
	Input.action_press("jump")
	await ticks(8)
	Input.action_release("jump")
	await process_frame
	expect(game.player.model.airborne,"Jump did not leave the ground")
	expect(game.player.model.last_state=="jump","Jump animation not selected")
	expect(game.player.model.vertical_speed>0,"Jump velocity not connected to rig")
	await ticks(100)
	await process_frame
	expect(game.player.is_on_floor(),"Cat did not land")
	expect(game.player.model.last_state=="idle","Idle did not resume after landing")
	await key(KEY_V)
	expect(not game.photo and game.player.camera.current,"First-person did not resume")
	expect(game.player.collider.rotation.length()<.0001,"Player collider tilted")
	print("CALICO_GAME_VALIDATE ",JSON.stringify({"third_person":true,"walk_run_jump":true,"failures":failures}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
