extends SceneTree
## Exact 2D triangle intersections on coplanar, outward-facing chair surfaces.
var failures: Array = []
func _initialize() -> void:
	var chair: Node3D = load("res://furniture_pack/scenes/armchair.tscn").instantiate()
	var buckets := {}
	for mesh in chair.find_children("*","MeshInstance3D",true,false):
		var points: PackedVector3Array = mesh.mesh.get_faces()
		for i in range(0,points.size(),3):
			var a: Vector3 = mesh.transform*points[i]
			var b: Vector3 = mesh.transform*points[i+1]
			var c: Vector3 = mesh.transform*points[i+2]
			var normal := (b-a).cross(c-a).normalized()
			var axis := normal.abs().max_axis_index()
			if absf(normal[axis])<.99999:continue
			var key := str([axis,roundi(a[axis]*100000),signf(normal[axis])])
			var u := (axis+1)%3
			var v := (axis+2)%3
			var polygon := PackedVector2Array([Vector2(a[u],a[v]),Vector2(b[u],b[v]),Vector2(c[u],c[v])])
			if not buckets.has(key):buckets[key] = []
			buckets[key].append({"node":mesh.name,"polygon":polygon})
	for key in buckets:
		var faces: Array = buckets[key]
		for i in range(faces.size()):
			for j in range(i+1,faces.size()):
				if faces[i].node==faces[j].node:continue
				for polygon in Geometry2D.intersect_polygons(faces[i].polygon,faces[j].polygon):
					var area := 0.0
					for k in range(polygon.size()):area += polygon[k].cross(polygon[(k+1)%polygon.size()])*.5
					if absf(area)>.000001:failures.append([faces[i].node,faces[j].node,key,area])
	print("ARMCHAIR_SURFACES ",JSON.stringify({"coplanar_overlaps":failures.size(),"details":failures.slice(0,20)}))
	chair.free()
	quit(0 if failures.is_empty() else 1)
