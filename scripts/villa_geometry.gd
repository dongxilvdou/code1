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
