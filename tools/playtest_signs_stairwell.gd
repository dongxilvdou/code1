extends "res://tools/playtest_basement.gd"
## Wall support, stair-mouth depth conflicts and actual rotating GPU views.

func signature(node: Node, pose: Transform3D, inside: bool, result: Array[String]) -> void:
	if node is Node3D:pose *= node.transform
	inside = inside or str(node.name) in ["Basement","Staircase"]
	if inside and node is CollisionShape3D:
		var entry: Array = [pose.origin.snapped(Vector3.ONE*.0001),pose.basis]
		entry.append(node.shape.size.snapped(Vector3.ONE*.0001) if node.shape is BoxShape3D else node.shape.get_class())
		result.append(str(entry))
	for child in node.get_children():signature(child,pose,inside,result)

func boxes(node: Node, pose: Transform3D, faces: Array) -> void:
	if node is Node3D:pose *= node.transform
	var name_ := str(node.name)
	if node is MeshInstance3D and node.mesh is BoxMesh and (name_.begins_with("Foundation_") or name_.begins_with("PlotGround_") or name_.begins_with("DistantGround_")):
		var bounds: AABB = pose*node.get_aabb()
		var area := AABB(Vector3(4.5,-.4,-2.3),Vector3(1.5,.5,4.0))
		if bounds.intersects(area):
			for axis in range(3):
				var u := (axis+1)%3;var v := (axis+2)%3
				for side in [-1,1]:
					var plane := bounds.position[axis] if side<0 else bounds.end[axis]
					if plane<area.position[axis] or plane>area.end[axis]:continue
					var rect := Rect2(Vector2(bounds.position[u],bounds.position[v]),Vector2(bounds.size[u],bounds.size[v]))
					rect = rect.intersection(Rect2(Vector2(area.position[u],area.position[v]),Vector2(area.size[u],area.size[v])))
					if rect.has_area():faces.append({"node":name_,"axis":axis,"plane":roundi(plane*10000),"side":side,"rect":rect})
	for child in node.get_children():boxes(child,pose,faces)

func layer_conflicts(house: Node) -> Array:
	var faces: Array = [];boxes(house,Transform3D.IDENTITY,faces)
	var result: Array = []
	for i in range(faces.size()):
		for j in range(i+1,faces.size()):
			var a: Dictionary = faces[i];var b: Dictionary = faces[j]
			if a.axis!=b.axis or a.plane!=b.plane or a.side!=b.side:continue
			var overlap: Rect2 = a.rect.intersection(b.rect)
			if overlap.get_area()>.000001:result.append([a.node,b.node,a.axis,overlap.get_area()])
	return result

func capture_view(name_: String, eye: Vector3, target: Vector3, fov := 67.0) -> void:
	if not capture:return
	game.cat_camera.position = eye;game.cat_camera.look_at(target);game.cat_camera.fov = fov
	for i in range(5):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/signs_stairwell/"+name_+".png")

func run_tests() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://logs/signs_stairwell")
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game);current_scene = game;game.start_game()
	await ticks(12);dismiss()
	var house: Node3D = game.get_node("Apartment")
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var signs := house.find_children("RoomSign_*","Node3D",true,false)
	verify(signs.size()==11,"Room signs were removed")
	for sign_ in signs:
		var normal: Vector3 = sign_.global_basis.z
		for x in [-.13,0,.13]:
			for y in [.001,.055,.109]:
				var point: Vector3 = sign_.to_global(Vector3(x,y,-.009))
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.001,point-normal*.025,1))
				verify(not hit.is_empty() and point.distance_to(hit.position)<.009,"Plaque is unsupported/embedded at "+str(sign_.get_path())+str(Vector2(x,y)))
	var conflict := layer_conflicts(house)
	verify(conflict.is_empty(),"Coplanar soil/slab cut faces at basement mouth: "+str(conflict))
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--baseline="):continue
		var old: Node3D = load(arg.trim_prefix("--baseline=")).instantiate()
		var before := layer_conflicts(old)
		# Compare serialized geometry on both sides. Runtime adds the dog's head
		# collider and opens the first cage, which are unrelated to this change.
		var current_saved: Node3D = load("res://scenes/villa.tscn").instantiate()
		var old_shapes: Array[String] = [];var new_shapes: Array[String] = []
		signature(old,Transform3D.IDENTITY,false,old_shapes);signature(current_saved,Transform3D.IDENTITY,false,new_shapes)
		old_shapes.sort();new_shapes.sort()
		verify(old_shapes==new_shapes,"Original stairs/cage/doorway collision changed")
		verify(before.size()>0,"Baseline did not reproduce the reported depth conflict")
		print("STAIRWELL_LAYERS ",JSON.stringify({"before":before,"after":conflict,"identical_stair_colliders":old_shapes==new_shapes}))
		old.free()
		current_saved.free()
	# Soil must remain outside the complete foundation footprint.
	var count := 0
	for mesh in house.get_node("Garden").get_children():
		if not mesh is MeshInstance3D or not (str(mesh.name).begins_with("PlotGround_") or str(mesh.name).begins_with("DistantGround_")):continue
		var b: AABB = mesh.global_transform*mesh.get_aabb()
		var footprint := Rect2(b.position.x,b.position.z,b.size.x,b.size.z)
		verify(footprint.intersection(Rect2(-6.125,-6.125,12.25,12.25)).get_area()<.00001,"Outdoor soil still extends under house")
		count += 1
	verify(count==8,"Exterior soil ring is incomplete")
	if capture:
		game.player.set_control(false);game.player.set_physics_process(false);game.set_process(false)
		game.get_node("QuestSystem").process_mode = Node.PROCESS_MODE_DISABLED
		game.get_node("QuestSystem").tracker.hide()
		game.get_node("DayOne").hud.hide();game.ui.hud.hide()
		game.get_node("VillaMap/MapHUD").process_mode = Node.PROCESS_MODE_DISABLED
		game.get_node("VillaMap/MapHUD").hide()
		game.cat_camera.make_current()
		for door in get_nodes_in_group("villa_doors"):door.set_open(true,true)
		await capture_view("01_laundry",Vector3(-.32,.86,.45),Vector3(.61,1.08,.05),63)
		await capture_view("02_wardrobe",Vector3(-.32,3.86,.45),Vector3(.61,4.08,.05),63)
		await capture_view("03_kitchen",Vector3(-.15,1.70,-1.2),Vector3(-.05,2.40,-2.31),66)
		await capture_view("04_bedroom_a",Vector3(-.15,4.70,-1.2),Vector3(-.05,5.40,-2.31),66)
		await capture_view("05_basement_sign",Vector3(5.01,.85,2.12),Vector3(5.86,1.10,1.8),66)
		# Ninety genuine camera-turn frames looking upward at the north slab edge.
		for i in range(90):
			var t := i/89.0
			game.cat_camera.position = Vector3(5.20+sin(t*TAU)*.10,-.80,-.75)
			game.cat_camera.look_at(Vector3(5.20+sin(t*TAU)*.22,-.11,-2.40))
			game.cat_camera.fov = 70
			await process_frame
			if i%15==0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://logs/signs_stairwell/turn_%02d.png"%i)
	print("SIGNS_STAIRWELL_TEST ",JSON.stringify({"checks":checks,"signs":signs.size(),"layer_conflicts":conflict.size(),"turn_frames":90 if capture else 0,"failures":failures}))
	game.stop_audio();game.queue_free();await ticks(3)
	quit(0 if failures.is_empty() else 1)
