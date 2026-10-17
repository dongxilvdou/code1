extends SceneTree
## Focused regression for depth fighting and rotating room labels.
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:failures.append(message)
func _initialize() -> void:call_deferred("run")

func faces(node: Node, transform: Transform3D, output: Array) -> void:
	if node is Node3D:transform = transform * node.transform
	var label := String(node.name)
	if node is MeshInstance3D and ("FlightStep" in label or "Nosing" in label or "EastRiser" in label or "HalfLanding" in label or "BasementStep" in label or "BasementLanding" in label or "TreadsAndLanding" in label):
		var vertices: PackedVector3Array = node.mesh.get_faces()
		var unique := {}
		for i in range(0,vertices.size(),3):
			var a := transform*vertices[i]
			var b := transform*vertices[i+1]
			var c := transform*vertices[i+2]
			var n := (b-a).cross(c-a).normalized()
			var axis := n.abs().max_axis_index()
			if absf(n[axis])<.99999:continue
			var u := (axis+1)%3
			var v := (axis+2)%3
			var lo := Vector2(minf(a[u],minf(b[u],c[u])),minf(a[v],minf(b[v],c[v])))
			var hi := Vector2(maxf(a[u],maxf(b[u],c[u])),maxf(a[v],maxf(b[v],c[v])))
			var key := str([axis,roundi(a[axis]*10000),signf(n[axis]),lo.snapped(Vector2.ONE*.0001),hi.snapped(Vector2.ONE*.0001)])
			if unique.has(key):continue
			unique[key] = true
			output.append({"node":node.get_instance_id(),"label":label,"axis":axis,"plane":roundi(a[axis]*10000),"sign":signf(n[axis]),"rect":Rect2(lo,hi-lo)})
	for child in node.get_children():faces(child,transform,output)

func conflicts(scene: Node) -> Array:
	var surfaces: Array = []
	faces(scene,Transform3D.IDENTITY,surfaces)
	var output: Array = []
	for i in range(surfaces.size()):
		var a: Dictionary = surfaces[i]
		for j in range(i+1,surfaces.size()):
			var b: Dictionary = surfaces[j]
			if a.node==b.node or a.axis!=b.axis or a.plane!=b.plane or a.sign!=b.sign:continue
			var area: Rect2 = a.rect.intersection(b.rect)
			if area.size.x*area.size.y>.0000001:output.append([a.label,b.label,a.axis,area.get_area()])
	return output

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://logs/stairs_minimap")
	var house: Node = load("res://scenes/villa.tscn").instantiate()
	var overlap := conflicts(house)
	check(overlap.is_empty(),"Coplanar stair surfaces: "+str(overlap))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline="):
			var old: Node = load(arg.trim_prefix("--baseline=")).instantiate()
			var old_shapes: Array[String] = []
			var new_shapes: Array[String] = []
			collision_signatures(old,Transform3D.IDENTITY,false,old_shapes)
			collision_signatures(house,Transform3D.IDENTITY,false,new_shapes)
			old_shapes.sort()
			new_shapes.sort()
			check(old_shapes==new_shapes,"Stair collision shapes changed")
			print("STAIR_BASELINE ",JSON.stringify({"before_conflicts":conflicts(old).size(),"after_conflicts":overlap.size(),"identical_colliders":old_shapes==new_shapes,"collider_count":new_shapes.size()}))
			old.free()
	house.free()
	var maps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://villa_maps/layout.json")).maps
	var canvas = load("res://villa_maps/map_canvas.gd").new()
	canvas.size = Vector2(200,200)
	var samples: Array = []
	var layout_usec := 0
	for id in maps:
		canvas.spec = maps[id]
		canvas.pixels_per_metre = 60 if id in ["stairs","basement"] else 11 if id=="garden" else 22
		var r: Array = canvas.spec.world_rect_xz
		check(canvas.world_to_pixel(Vector2(r[0]+r[2],r[1]+r[3])).is_equal_approx(Vector2(2048,2048)),id+": non-square texture coordinates")
		for room in canvas.spec.regions:
			canvas.position_xz = Vector2(room.label_xz[0],room.label_xz[1])
			canvas.region = room
			for angle in [0.0,.43,PI/2,PI,4.18]:
				canvas.map_angle = angle
				var start := Time.get_ticks_usec()
				var labels: Array = canvas.minimap_label_layout()
				layout_usec += Time.get_ticks_usec()-start
				check(not labels.is_empty(),id+" "+room.id+": no room labels at "+str(angle))
				check(labels.any(func(entry):return entry.id==room.id),id+" "+room.id+": current room label missing at "+str(angle))
				for entry in labels:
					check(Rect2(Vector2.ZERO,canvas.size).encloses(entry.rect),"Label outside minimap")
					var other: Dictionary = canvas.spec.regions.filter(func(item):return item.id==entry.id)[0]
					var poly := PackedVector2Array()
					for p in other.polygon_xz:poly.append(canvas.world_to_minimap(Vector2(p[0],p[1])))
					check(Geometry2D.is_point_in_polygon(entry.get("anchor",entry.rect.get_center()),poly),"Label anchor left its room")
				samples.append({"map":id,"room":room.id,"angle":angle,"labels":labels.size()})
	canvas.free()
	var result := {"checks":checks,"coplanar_conflicts":overlap,"label_samples":samples,"failures":failures}
	var file := FileAccess.open("res://logs/stairs_minimap/verification.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(result,"\t"))
	print("STAIR_MINIMAP_TEST ",JSON.stringify({"checks":checks,"label_samples":samples.size(),"coplanar_conflicts":overlap.size(),"mean_layout_ms":layout_usec/1000.0/samples.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func collision_signatures(node: Node, transform: Transform3D, in_stairs: bool, result: Array[String]) -> void:
	if node is Node3D:transform = transform*node.transform
	in_stairs = in_stairs or String(node.name) in ["Staircase","Basement"]
	if in_stairs and node is CollisionShape3D:
		var signature: Array = [transform.origin.snapped(Vector3.ONE*.0001),transform.basis]
		if node.shape is BoxShape3D:signature.append(node.shape.size.snapped(Vector3.ONE*.0001))
		else:signature.append(node.shape.get_class())
		result.append(str(signature))
	for child in node.get_children():collision_signatures(child,transform,in_stairs,result)
