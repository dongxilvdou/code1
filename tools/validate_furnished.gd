extends SceneTree
var game
var failures: Array = []
var overlaps: Array = []

func _initialize() -> void:
	call_deferred("validate")

func furniture_parent(node: Node) -> Node:
	while node:
		if node.is_in_group("placed_furniture"):return node
		node = node.get_parent()
	return null

func validate() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_game()
	game.player.set_control(false)
	game.player.position = Vector3(0,10,0)
	for i in range(3):await physics_frame
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var sweep_samples := 0
	for door in get_nodes_in_group("villa_doors"):
		for sample in range(21):
			var angle: float = deg_to_rad(door.open_angle)*sample/20.0
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = door.collider.shape
			q.transform = door.global_transform*Transform3D(Basis(Vector3.UP,angle),Vector3.ZERO)*door.collider.transform
			q.collision_mask = 1
			q.margin = .005
			q.exclude = [door.leaf.get_rid()]
			for hit in space.intersect_shape(q,32):
				var asset := furniture_parent(hit.collider)
				if asset:
					var msg := "Door sweep: "+str(door.get_path())+" intersects "+str(asset.get_path())
					if msg not in failures:failures.append(msg)
			sweep_samples += 1
		door.set_open(true,true)
	for i in range(3):await physics_frame
	# Detect actual solid intersections between separate furniture instances.
	for asset in get_nodes_in_group("placed_furniture"):
		for col in asset.find_children("*","CollisionShape3D",true,false):
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = col.shape
			q.transform = col.global_transform
			q.collision_mask = 1
			q.margin = -.002
			for hit in space.intersect_shape(q,32):
				var other := furniture_parent(hit.collider)
				if other and other!=asset:
					var pair: Array = [str(asset.get_path()),str(other.get_path())]
					pair.sort()
					var msg: String = pair[0]+" <> "+pair[1]
					if msg not in overlaps:overlaps.append(msg)
	var capsule := CapsuleShape3D.new()
	capsule.height = .288
	capsule.radius = .096
	var route_results: Array = []
	const N := 65
	const STEP := .185
	for floor_index in range(2):
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = capsule
		q.collision_mask = 1
		q.margin = .003
		var clear: Dictionary = {}
		for x in range(N):
			for z in range(N):
				var p := Vector3(x*STEP-6,floor_index*3.0+.150,z*STEP-6)
				q.transform = Transform3D(Basis.IDENTITY,p)
				if space.intersect_shape(q,1).is_empty():clear[Vector2i(x,z)] = true
		var start := Vector2i(roundi((2.6 if floor_index==0 else 11.2)/STEP),roundi((10.2 if floor_index==0 else 8.05)/STEP))
		var queue: Array[Vector2i] = [start]
		var reached := {start:true}
		var cursor := 0
		while cursor<queue.size():
			var p: Vector2i = queue[cursor]
			cursor += 1
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i = p+offset
				if clear.has(next) and not reached.has(next):
					reached[next] = true
					queue.append(next)
		for zone in game.zone_records:
			if zone.floor!=floor_index:continue
			var count := 0
			var inset: Rect2 = zone.bounds.grow(-.25)
			for key in reached:
				if inset.has_point(Vector2(key)*STEP):count += 1
			route_results.append({"room":zone.name,"floor":floor_index,"reachable_points":count})
			if count<3:failures.append("Room unreachable: "+str(floor_index)+" "+zone.name)
		await process_frame
	var data := {"instances":get_nodes_in_group("placed_furniture").size(),"door_sweep_samples":sweep_samples,"rooms":route_results,"solid_overlaps":overlaps,"failures":failures}
	FileAccess.open("res://furniture_pack/furnished_validation.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("FURNISHED_VALIDATE ",JSON.stringify(data))
	game.stop_audio()
	game.free()
	quit(0 if failures.is_empty() and overlaps.is_empty() else 1)
