extends RefCounted
## Exact axis-aligned solid union. Internal and coincident faces are discarded.
## Coordinates are quantized to 0.1 mm to keep shared wall junctions identical.

static func solid_union(volumes: Array, materials: Array, floor_y: float, exterior: bool = false) -> ArrayMesh:
	var coordinates: Array = [[],[],[]]
	var boxes: Array = []
	for volume in volumes:
		var lo := Vector3i()
		var hi := Vector3i()
		for axis in range(3):
			lo[axis] = roundi(volume[0][axis]*10000)
			hi[axis] = roundi(volume[1][axis]*10000)
			coordinates[axis].append(lo[axis])
			coordinates[axis].append(hi[axis])
		boxes.append([lo,hi])
	var lookup: Array = [{},{},{}]
	for axis in range(3):
		coordinates[axis].sort()
		var unique: Array = []
		for number in coordinates[axis]:
			if unique.is_empty() or unique[-1]!=number:unique.append(number)
		coordinates[axis] = unique
		for i in range(unique.size()):lookup[axis][unique[i]] = i
	var dimensions := Vector3i(coordinates[0].size()-1,coordinates[1].size()-1,coordinates[2].size()-1)
	var occupied := PackedByteArray()
	occupied.resize(dimensions.x*dimensions.y*dimensions.z)
	for bounds in boxes:
		var a := Vector3i(lookup[0][bounds[0].x],lookup[1][bounds[0].y],lookup[2][bounds[0].z])
		var b := Vector3i(lookup[0][bounds[1].x],lookup[1][bounds[1].y],lookup[2][bounds[1].z])
		for x in range(a.x,b.x):
			for y in range(a.y,b.y):
				for z in range(a.z,b.z):occupied[(x*dimensions.y+y)*dimensions.z+z] = 1
	var builders: Array[SurfaceTool] = []
	for mat in materials:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(mat)
		builders.append(st)
	var face_counts: Array[int] = []
	face_counts.resize(materials.size())
	for axis in range(3):
		var u := (axis+1)%3
		var v := (axis+2)%3
		for side in [-1,1]:
			for plane in range(dimensions[axis]+1):
				# Greedy merge each planar surface into maximal rectangles.
				var mask := PackedInt32Array()
				mask.resize(dimensions[u]*dimensions[v])
				for j in range(dimensions[v]):
					for i in range(dimensions[u]):
						var cell := Vector3i()
						cell[axis] = plane-1 if side==1 else plane
						cell[u] = i
						cell[v] = j
						var neighbour := cell
						neighbour[axis] += side
						if not has_cell(occupied,dimensions,cell) or has_cell(occupied,dimensions,neighbour):continue
						var midpoint := Vector3()
						midpoint[axis] = coordinates[axis][plane]/10000.0+side*.002
						midpoint[u] = (coordinates[u][i]+coordinates[u][i+1])/20000.0
						midpoint[v] = (coordinates[v][j]+coordinates[v][j+1])/20000.0
						var outside := midpoint.x< -6 or midpoint.x>6 or midpoint.z< -6 or midpoint.z>6
						if floor_y>1 and midpoint.x< -2 and midpoint.z>3:outside = true
						mask[j*dimensions[u]+i] = 2 if exterior and outside and axis!=1 else 1
				for j in range(dimensions[v]):
					var i := 0
					while i<dimensions[u]:
						var material_id := mask[j*dimensions[u]+i]
						if material_id==0:
							i += 1
							continue
						var width := 1
						while i+width<dimensions[u] and mask[j*dimensions[u]+i+width]==material_id:width += 1
						var height := 1
						while j+height<dimensions[v]:
							var complete := true
							for k in range(width):
								if mask[(j+height)*dimensions[u]+i+k]!=material_id:complete = false
							if not complete:break
							height += 1
						var a := Vector3()
						a[axis] = coordinates[axis][plane]/10000.0
						a[u] = coordinates[u][i]/10000.0
						a[v] = coordinates[v][j]/10000.0
						var b := a
						b[u] = coordinates[u][i+width]/10000.0
						var c := b
						c[v] = coordinates[v][j+height]/10000.0
						var d := a
						d[v] = c[v]
						var normal := Vector3()
						normal[axis] = side
						var st: SurfaceTool = builders[material_id-1]
						for point in [a,c,b,a,d,c] if side==1 else [a,b,c,a,c,d]:
							st.set_normal(normal)
							st.add_vertex(point)
						face_counts[material_id-1] += 1
						for row in range(height):
							for column in range(width):mask[(j+row)*dimensions[u]+i+column] = 0
						i += width
	var mesh := ArrayMesh.new()
	for i in range(builders.size()):
		if face_counts[i]>0:builders[i].commit(mesh)
	return mesh

static func has_cell(cells: PackedByteArray, size: Vector3i, p: Vector3i) -> bool:
	if p.x<0 or p.y<0 or p.z<0 or p.x>=size.x or p.y>=size.y or p.z>=size.z:return false
	return cells[(p.x*size.y+p.y)*size.z+p.z]!=0

static func refine_stair_rails(stairs: Node3D) -> void:
	if stairs.has_node("StairHandrails"):return
	# Replace only the twelve original rail pieces in the furnished baked scene.
	for i in range(1501,1513):
		var old:=stairs.get_node_or_null("Detail_%04d"%i)
		if old is MeshInstance3D:old.free()
	var rails:=Node3D.new()
	rails.name="StairHandrails"
	stairs.add_child(rails)
	rails.owner=stairs.owner
	var metal:=StandardMaterial3D.new()
	metal.albedo_color=Color(.22,.24,.25)
	metal.metallic=.25;metal.roughness=.58
	var timber:=StandardMaterial3D.new()
	timber.albedo_color=Color(.32,.20,.105)
	timber.roughness=.54
	for upper in [false,true]:
		var x:=4.665 if upper else 4.535
		var a:=Vector3(x,2.4 if upper else .9,-.5 if upper else 1.5)
		var b:=Vector3(x,3.9 if upper else 2.4,1.5 if upper else -.5)
		stair_rail_piece(rails,"UpperHandrail" if upper else "LowerHandrail",a,b,.028,timber)
		# Balusters sit on actual tread centres and meet the pitched handrail exactly.
		for i in range(9):
			var z: float=(-.5+(i+.5)*2.0/9) if upper else (1.5-(i+.5)*2.0/9)
			var floor_y: float=(1.5 if upper else 0.0)+(i+1)/6.0
			var top_y: float=(2.4+.75*(z+.5)) if upper else (.9+.75*(1.5-z))
			var foot:=Vector3(x,floor_y,z)
			var label:="%s%02d"%["Upper" if upper else "Lower",i+1]
			stair_rail_piece(rails,label+"Baluster",foot,Vector3(x,top_y,z),.013,metal)
			var plate:=MeshInstance3D.new()
			plate.name=label+"Footplate"
			var plate_mesh:=BoxMesh.new()
			plate_mesh.size=Vector3(.026,.012,.070)
			plate.mesh=plate_mesh;plate.material_override=metal
			plate.position=foot+Vector3.UP*.006
			rails.add_child(plate);plate.owner=rails.owner
			for offset in [-.024,.024]:
				var bolt:=foot+Vector3(0,.012,offset)
				stair_rail_piece(rails,label+"AnchorBolt",bolt,bolt+Vector3.UP*.004,.0035,metal)
			stair_rail_piece(rails,label+"Collar",Vector3(x,top_y-.045,z),Vector3(x,top_y-.016,z),.020,metal)
			# Posts have matching collision; their inset preserves the clear walking lanes.
			var body:=StaticBody3D.new()
			body.name=label+"PostBody"
			rails.add_child(body);body.owner=rails.owner
			body.position=(foot+Vector3(x,top_y,z))*.5
			var shape:=CollisionShape3D.new()
			var bounds:=BoxShape3D.new()
			bounds.size=Vector3(.026,top_y-floor_y,.026)
			shape.shape=bounds
			body.add_child(shape);shape.owner=rails.owner
		# Short rounded returns remove exposed handrail ends at each floor.
		var end:=b if upper else a
		var tip:=Vector3(x,end.y,1.58)
		stair_rail_piece(rails,"EndExtension",end,tip,.028,timber)
		stair_rail_piece(rails,"EndReturn",tip,tip-Vector3.UP*.12,.028,timber)
	# A continuous rounded U turn over the landing joins the two flights.
	var bend:=SurfaceTool.new()
	bend.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(24):
		for j in range(16):
			for corner in [Vector2i(0,0),Vector2i(1,1),Vector2i(1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)]:
				var theta: float=PI-(i+corner.x)*PI/24
				var phi: float=(j+corner.y)*TAU/16
				var radial:=Vector3(cos(theta),0,-sin(theta))
				var normal:=Vector3.UP*cos(phi)+radial*sin(phi)
				bend.set_normal(normal)
				bend.add_vertex(Vector3(4.6,2.4,-.5)+radial*.065+normal*.028)
	var turn:=MeshInstance3D.new()
	turn.name="LandingBend";turn.mesh=bend.commit();turn.material_override=timber
	rails.add_child(turn);turn.owner=rails.owner

static func stair_rail_piece(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, material_: Material) -> void:
	var piece:=MeshInstance3D.new()
	piece.name=label
	var mesh:=CylinderMesh.new()
	mesh.top_radius=radius;mesh.bottom_radius=radius
	mesh.height=a.distance_to(b);mesh.radial_segments=16
	piece.mesh=mesh;piece.material_override=material_
	piece.position=(a+b)*.5
	piece.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	parent.add_child(piece);piece.owner=parent.owner
