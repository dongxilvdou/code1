extends RefCounted
## Solid folded leaves and tapered branching wood, with no overlapping alpha cards.

static func branch(builder, points: Array[Vector3], radius: float, parent: Node) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var sides := 10
	for i in range(points.size()):
		var tangent := (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var right := tangent.cross(Vector3.FORWARD).normalized()
		if right.length()<.1:right = Vector3.RIGHT
		var up := tangent.cross(right).normalized()
		var ring: Array[Vector3] = []
		var r := radius*lerpf(1.0,.19,float(i)/(points.size()-1))
		for j in range(sides):
			var angle := TAU*j/sides
			ring.append(points[i]+(right*cos(angle)+up*sin(angle))*r*(1+.08*sin(j*3+i)))
		rings.append(ring)
	for i in range(rings.size()-1):
		for j in range(sides):
			var k := (j+1)%sides
			for p in [rings[i][j],rings[i+1][j],rings[i+1][k],rings[i][j],rings[i+1][k],rings[i][k]]:st.add_vertex(p)
	st.generate_normals()
	var obj: MeshInstance3D = builder.mesh_obj(st.commit(),Vector3.ZERO,"bark",parent)
	obj.name = "Branch"

static func leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(0,-.10,0)
	var b := Vector3(-.055,-.025,0)
	var c := Vector3(-.045,.065,0)
	var d := Vector3(0,.15,.005)
	var e := Vector3(.045,.065,0)
	var f := Vector3(.055,-.025,0)
	var m := Vector3(0,.025,.018)
	for face in [[a,b,m],[b,c,m],[c,d,m],[d,e,m],[e,f,m],[f,a,m]]:
		for v in face:st.add_vertex(v)
	st.generate_normals()
	return st.commit()

static func tree(builder, pos: Vector3, size: float, seed_value: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var tree := Node3D.new()
	tree.name = "BranchingTree_%s" % seed_value
	tree.position = pos
	tree.scale = Vector3.ONE*size
	builder.attach(tree,builder.garden)
	var trunk: Array[Vector3] = []
	for i in range(9):trunk.append(Vector3(.07*sin(i*.67),i*.43,.05*cos(i*.7)-.05))
	branch(builder,trunk,.17,tree)
	var clusters: Array[Vector3] = []
	for i in range(18):
		var start := trunk[3+i%5]
		var angle := i*2.39996+random.randf_range(-.2,.2)
		var radial := Vector3(cos(angle),0,sin(angle))
		var reach := random.randf_range(1.0,1.65)*(1.18-.035*(i%5))
		var end := start+radial*reach+Vector3.UP*random.randf_range(.65,1.15)
		branch(builder,[start,start+radial*reach*.36+Vector3.UP*.15,start.lerp(end,.72),end],.065,tree)
		for j in range(3):
			var twig_end := end+Vector3(random.randf_range(-.40,.40),random.randf_range(.05,.48),random.randf_range(-.40,.40))
			branch(builder,[start.lerp(end,.70),end,twig_end],.018,tree)
			clusters.append(twig_end)
	clusters.append(trunk[-1]+Vector3.UP*.20)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color.WHITE
	leaf_mat.vertex_color_use_as_albedo = true
	leaf_mat.vertex_color_is_srgb = true
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_mat.roughness = .88
	leaf_mat.backlight_enabled = true
	leaf_mat.backlight = Color(.04,.07,.02)
	# Store the leaves in a native ArrayMesh. Unlike GPU-only instance buffers,
	# this survives both headless scene generation and normal editor saves.
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_arrays := leaf_mesh().surface_get_arrays(0)
	var vertices: PackedVector3Array = leaf_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = leaf_arrays[Mesh.ARRAY_NORMAL]
	for center in clusters:
		for i in range(36):
			var scatter := Vector3(clampf(random.randfn(0,.22),-.43,.43),clampf(random.randfn(0,.17),-.32,.32),clampf(random.randfn(0,.22),-.43,.43))
			var basis := Basis.from_euler(Vector3(random.randf_range(-1.1,1.1),random.randf()*TAU,random.randf()*TAU))
			basis = basis.scaled(Vector3.ONE*random.randf_range(.75,1.10))
			var tint := random.randf()
			var color := Color(.14,.28,.08).lerp(Color(.34,.47,.16),tint)
			for j in range(vertices.size()):
				leaves.set_color(color)
				leaves.set_normal((basis*normals[j]).normalized())
				leaves.add_vertex(center+scatter+basis*vertices[j])
			# Fine twigs connect each leaf base to its terminal branch.
			var end := center+scatter+basis*vertices[0]
			var side := (end-center).cross(Vector3.UP).normalized()*.0025
			for p in [center-side,end-side,end+side,center-side,end+side,center+side]:
				leaves.set_color(Color(.27,.21,.12))
				leaves.set_normal(Vector3.UP)
				leaves.add_vertex(p)
	var foliage := MeshInstance3D.new()
	foliage.name = "IndividualLeaves"
	foliage.mesh = leaves.commit()
	foliage.material_override = leaf_mat
	builder.attach(foliage,tree)
	var body := StaticBody3D.new()
	builder.attach(body,tree)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = .20
	shape.height = 3.4
	collision.shape = shape
	collision.position.y = 1.7
	builder.attach(collision,body)
	for i in range(5):
		var direction := Vector3(cos(i*TAU/5),0,sin(i*TAU/5))
		branch(builder,[direction*.53+Vector3.UP*.035,direction*.27+Vector3.UP*.12,Vector3.UP*.30],.048,tree)

static func grasses(builder, center: Vector3, length: float, width: float, seed_value: int, parent: Node) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(int(length*width*110)):
		var p := center+Vector3(random.randf_range(-length/2,length/2),0,random.randf_range(-width/2,width/2))
		var angle := random.randf()*TAU
		var side := Vector3(cos(angle),0,sin(angle))*.012
		var tip := p+Vector3(random.randf_range(-.05,.05),random.randf_range(.12,.34),random.randf_range(-.05,.05))
		for v in [p-side,tip,p+side]:st.add_vertex(v)
	st.generate_normals()
	var obj: MeshInstance3D = builder.mesh_obj(st.commit(),Vector3.ZERO,"leaf",parent)
	obj.name = "OrnamentalGrasses"
