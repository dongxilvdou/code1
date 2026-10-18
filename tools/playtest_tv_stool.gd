extends "res://tools/playtest_map_stairs.gd"
var cabinet_bounds := AABB()
func run_tests() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game)
	current_scene = game
	await ticks(8)
	game.start_game()
	await ticks(8)
	var day = game.get_node("DayOne")
	if not day.dialog.is_empty():await key(KEY_ESCAPE)
	for flag in ["walk","run","open_living","stool","table","cup_moved","note_read"]:day.manager.set_flag(StringName(flag),true)
	day.reconcile_progress()
	day.restore_world()
	var shelf := day.get_node("TVSideShelf") as MeshInstance3D
	var shelf_bounds: AABB = shelf.global_transform*shelf.get_aabb()
	var first := true
	for prop in get_nodes_in_group("placed_furniture"):
		if prop.get_meta("asset_id","")!="tv_console" or prop.get_meta("placement_room","")!="Living":continue
		for mesh in prop.find_children("*","MeshInstance3D",true,false):
			var bounds: AABB = mesh.global_transform*mesh.get_aabb()
			cabinet_bounds = bounds if first else cabinet_bounds.merge(bounds)
			first = false
	expect(not first,"missing television cabinet")
	expect(not shelf_bounds.intersects(cabinet_bounds),"stool still intersects television cabinet")
	var clearance := cabinet_bounds.position.x-shelf_bounds.end.x
	expect(clearance>.08,"insufficient visible clearance")
	var leg_count := 0
	for node in day.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("ShelfLeg"):leg_count += 1
	expect(leg_count==4,"stool must have four supported legs: "+str(leg_count))
	day.set_physics_process(false)
	game.player.position = day.World.TV_RETRY_POSITION
	game.player.velocity = Vector3.ZERO
	var direction := Vector3(-1.28,0,2.93)-Vector3(game.player.position.x,0,game.player.position.z)
	face(atan2(-direction.x,-direction.z))
	await ticks(12)
	expect(game.player.is_on_floor() and absf(game.player.position.y-.52)<.02,"retry stool not standable")
	Input.action_press("move_forward")
	Input.action_press("jump")
	await ticks(2)
	Input.action_release("jump")
	var landed := false
	for i in range(65):
		await physics_frame
		if game.player.is_on_floor() and game.player.position.y>1.25:
			landed = true
			break
	Input.action_release("move_forward")
	game.player.velocity.x = 0
	game.player.velocity.z = 0
	expect(landed,"cannot jump from separated stool to television")
	day.set_physics_process(true)
	await ticks(4)
	expect(day.balancing,"television balancing task no longer triggers")
	if day.balancing:day.finish_balance(false)
	await ticks(12)
	expect(game.player.is_on_floor() and absf(game.player.position.y-.52)<.02,"balance failure did not return safely to stool")
	expect(game.player.position.x<shelf_bounds.end.x and game.player.position.x>shelf_bounds.position.x,"retry point is outside the stool")
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://logs/tv_stool")
		game.player.set_control(false)
		game.player.set_physics_process(false)
		game.set_process(false)
		day.set_process(false)
		day.hud.hide()
		game.ui.hud.hide()
		game.get_node("QuestSystem").set_process(false)
		game.get_node("QuestSystem").tracker.hide()
		var map = game.get_node("VillaMap/MapHUD")
		map.set_process(false)
		map.hide()
		game.cat_camera.make_current()
		game.cat_camera.fov = 68
		var views := [Vector3(-2.95,.85,3.95),Vector3(-2.85,.35,3.70),Vector3(-2.95,.90,3.0)]
		for i in range(views.size()):
			game.cat_camera.global_position = views[i]
			game.cat_camera.look_at(Vector3(-1.50,.54,3.0))
			for frame in range(8):await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://logs/tv_stool/view_%d.png" % i)
	print("TV_STOOL_TEST ",JSON.stringify({"cabinet_clearance_m":clearance,"jump_landing":landed,"failures":failures}))
	game.stop_audio()
	game.queue_free()
	await ticks(3)
	quit(0 if failures.is_empty() else 1)
