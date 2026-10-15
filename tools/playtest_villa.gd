extends SceneTree
var failures: Array[String] = []
var game
var passages := 0

func _initialize() -> void:
	call_deferred("run_tests")

func ticks(count: int) -> void:
	for i in range(count):await physics_frame

func expect(value: bool, message: String) -> void:
	if not value:failures.append(message)

func place(x: float, z: float, y: float, yaw: float) -> void:
	game.player.position = Vector3(x-6,y,z-6)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = yaw
	game.player.rotation.y = yaw
	game.player.pitch = 0
	game.player.head.rotation.x = 0

func walk_until(axis: String, destination: float, max_ticks: int = 420) -> bool:
	var initial: float = game.player.position[axis]
	var ascending := destination>initial
	Input.action_press("move_forward")
	var arrived := false
	for i in range(max_ticks):
		await physics_frame
		var current: float = game.player.position[axis]
		if (ascending and current>=destination) or (not ascending and current<=destination):
			arrived = true
			break
	Input.action_release("move_forward")
	game.player.velocity.x = 0
	game.player.velocity.z = 0
	await ticks(4)
	return arrived

func face(yaw: float) -> void:
	game.player.yaw = yaw
	game.player.rotation.y = yaw

func run_tests() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.start_game()
	await ticks(10)
	expect(is_equal_approx(game.player.model.scale.x,.8),"Cat scale was reset by the rig")
	expect(absf(game.player.head.position.y-.224)<.015,"Cat eye height did not shrink with its model")
	expect(not game.has_node("Apartment/StandingMirror") and not game.has_node("MirrorReflection"),"Mirror rendering still present")
	var doors := get_nodes_in_group("villa_doors")
	expect(doors.size()>=16,"Room doors missing")
	# Every closed leaf must block the portal, and every opened leaf must clear it.
	for door in doors:
		var a: Vector3 = door.to_global(Vector3(door.leaf_width*.5,.25,-.30))
		var b: Vector3 = door.to_global(Vector3(door.leaf_width*.5,.25,.30))
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
		expect(not hit.is_empty() and hit.collider==door.leaf,"Closed door does not block: "+str(door.name))
		door.set_open(true)
	await ticks(65)
	for door in doors:
		var a: Vector3 = door.to_global(Vector3(door.leaf_width*.5,.25,-.30))
		var b: Vector3 = door.to_global(Vector3(door.leaf_width*.5,.25,.30))
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
		expect(hit.is_empty(),"Open door blocks passage: "+str(door.name))
	# E interaction from both sides, actual closed-door walking, and anti-crush pause.
	var test_door: Node3D
	for door in doors:
		if door.door_title=="卧室门" and door.global_position.y<1:test_door = door
	test_door.set_open(false,true)
	place(7.55,8.35,.02,PI)
	await ticks(8)
	game.update_target()
	expect(game.nearest_door==test_door,"Door interaction from hall not found")
	Input.action_press("move_forward")
	await ticks(40)
	Input.action_release("move_forward")
	expect(game.player.position.z<2.85,"Cat passed through a closed door")
	game.interact()
	await ticks(60)
	expect(test_door.is_open and not test_door.moving,"E did not open the door")
	place(7.55,9.6,.02,0)
	await ticks(8)
	game.update_target()
	expect(game.nearest_door==test_door,"Door interaction from room not found")
	game.interact()
	place(7.55,10.2,.02,0)
	await ticks(60)
	expect(not test_door.is_open and not test_door.moving,"E did not close the door from the room")
	test_door.set_open(true)
	await ticks(60)
	# Put the cat inside the closing sweep, wait for the safety stop, then clear it.
	game.player.position = test_door.to_global(Vector3(test_door.leaf_width*.60,.02,.36))
	game.player.velocity = Vector3.ZERO
	test_door.set_open(false)
	await ticks(60)
	expect(test_door.blocked and test_door.moving,"Door did not pause for the cat")
	place(2.6,10.2,.02,0)
	await ticks(60)
	expect(not test_door.moving and absf(test_door.leaf.rotation.y)<.01,"Door did not finish closing after the cat moved away")
	test_door.set_open(true)
	await ticks(60)
	# Use the actual controlled capsule to traverse every distinct doorway in the plan.
	var trials := [
		[5.95,3.95,.02,0.0,"一层 · 厨房"],
		[6.30,4.50,.02,-PI/2,"一层 · 卫生间"],
		[6.30,6.80,.02,-PI/2,"一层 · 洗衣间"],
		[7.55,8.40,.02,PI,"一层 · 客卧"],
		[5.95,10.7,.02,PI/2,"一层 · 客厅"],
		[2.60,.50,.02,0.0,"北侧花园"],
		[11.50,1.80,.02,-PI/2,"侧花园"],
		[5.95,11.5,.02,PI,"入户庭院"],
		[5.95,3.95,3.02,0.0,"二层 · 次卧 A"],
		[5.55,4.45,3.02,PI/2,"二层 · 主卧"],
		[5.55,6.95,3.02,PI/2,"二层 · 书房"],
		[7.55,8.40,3.02,PI,"二层 · 次卧 B"],
		[6.30,4.50,3.02,-PI/2,"二层 · 卫生间"],
		[6.30,6.80,3.02,-PI/2,"二层 · 衣帽储物"],
		[2.40,8.60,3.02,PI,"二层 · 露台"],
		[4.50,10.7,3.02,PI/2,"二层 · 露台"]
	]
	for t in trials:
		place(t[0],t[1],t[2],t[3])
		await ticks(8)
		Input.action_press("move_forward")
		await ticks(64)
		Input.action_release("move_forward")
		await ticks(4)
		game.update_room()
		expect(game.room_name==t[4],"Door blocked or room mismatch: "+t[4]+" => "+game.room_name+" "+str(game.player.position))
		passages += 1
	# Ascend both real stair flights, turn on the half landing, then exit to upstairs.
	place(10.0,8.0,.02,0)
	await ticks(8)
	var first := await walk_until("z",4.40-6)
	expect(first,"West stair flight blocked at "+str(game.player.position))
	expect(absf(game.player.position.y-1.5)<.10,"Half landing height incorrect: "+str(game.player.position.y))
	face(-PI/2)
	var turn := await walk_until("x",11.2-6,120)
	expect(turn,"Half landing turn blocked")
	face(PI)
	var second := await walk_until("z",8.02-6)
	expect(second,"East stair flight blocked at "+str(game.player.position))
	expect(absf(game.player.position.y-3.0)<.09,"Could not reach second-storey slab: "+str(game.player.position.y))
	var stair_top: float = game.player.position.y
	# Walk back down with floor snap, no jumping, teleporting or ramp substitute.
	face(0)
	var descent := await walk_until("z",4.40-6)
	expect(descent,"Upper stair descent blocked")
	face(PI/2)
	expect(await walk_until("x",10.0-6,120),"Downstairs landing turn blocked")
	face(PI)
	expect(await walk_until("z",8.02-6),"Lower stair descent blocked")
	expect(absf(game.player.position.y)<.09,"Could not return to ground floor: "+str(game.player.position.y))
	# Solid wall and a glass window must stop the smaller capsule.
	place(.65,9.0,.02,PI/2)
	await ticks(8)
	Input.action_press("move_forward")
	await ticks(90)
	Input.action_release("move_forward")
	expect(game.player.position.x>-5.85,"Cat escaped through an outer wall")
	place(.65,7.2,1.02,PI/2)
	expect(game.player.test_move(game.player.global_transform,Vector3(-.8,0,0)),"Window glass has no collision")
	# Resizing must keep crouching and jumping functional, not just shrink the mesh.
	place(2.6,8.8,.02,0)
	await ticks(8)
	Input.action_press("crouch")
	await ticks(20)
	expect(absf(game.player.head.position.y-.152)<.012,"Crouching eye height is incorrect")
	Input.action_release("crouch")
	await ticks(20)
	Input.action_press("jump")
	await ticks(1)
	Input.action_release("jump")
	var jump_peak := 0.0
	for i in range(75):
		await physics_frame
		jump_peak = maxf(jump_peak,game.player.position.y)
	expect(jump_peak>.9 and game.player.is_on_floor(),"Jump and landing failed after shrinking the cat")
	# Foot-level floor coverage checks from within every room, not from above the roof.
	for r in game.zone_records:
		var b: Rect2 = r.bounds
		var q := b.get_center()
		var floor_y := 3.0 if r.floor==1 else 0.0
		var origin := Vector3(q.x-6,floor_y+.5,q.y-6)
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin-Vector3.UP,1))
		expect(not hit.is_empty(),"Missing room floor: "+str(r.name))
	# Full house and floor sections restore the playable camera and control state.
	game.toggle_overview()
	game.set_section(1)
	expect(not game.get_node("Apartment/UpperFloor").visible,"Ground-floor section did not cut away upstairs")
	game.set_section(2)
	expect(game.get_node("Apartment/UpperFloor").visible and not game.get_node("Apartment/Roof").visible,"Upper-floor section incorrect")
	game.toggle_overview()
	expect(game.player.active and game.get_node("Apartment/Roof").visible,"Leaving overview did not restore the playable house")
	await ticks(2)
	expect(game.ui.room_label.text==game.room_name,"Overview left a stale room label")
	game.toggle_pause()
	expect(not game.player.active,"Pause failed")
	game.toggle_pause()
	expect(game.player.active,"Resume failed")
	print("VILLA_PLAYTEST ",JSON.stringify({"doors_tested":doors.size(),"doorways_walked":passages,"stair_top_m":stair_top,"jump_peak_m":jump_peak,"cat_scale":game.player.cat_scale,"failures":failures}))
	game.stop_audio()
	game.queue_free()
	await process_frame
	await process_frame
	game = null
	call_deferred("quit",0 if failures.is_empty() else 1)
