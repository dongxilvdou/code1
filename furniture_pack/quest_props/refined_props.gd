@static_unload
extends RefCounted
## Metre-scale silhouettes and surface detail, shared by world and carried props.
static var materials := {}

static func material(key: String, color: Color, roughness := .55, metal := 0.0) -> StandardMaterial3D:
	if materials.has(key):return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metal
	materials[key] = m
	return m

static func mesh_node(parent: Node3D, name_: String, mesh: Mesh, m: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = name_
	n.mesh = mesh
	n.material_override = m
	parent.add_child(n)
	n.position = pos
	return n

static func ellipsoid(parent: Node3D, name_: String, pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var n := mesh_node(parent,name_,mesh,m,pos)
	n.scale = size
	return n

static func rod(parent: Node3D, name_: String, a: Vector3, b: Vector3, radius: float, m: Material) -> void:
	if a.distance_to(b)<.00001:return
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 10
	var n := mesh_node(parent,name_,mesh,m,(a+b)*.5)
	n.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

static func line(parent: Node3D, name_: String, points: Array[Vector3], radius: float, m: Material) -> void:
	for i in range(points.size()-1):rod(parent,name_,points[i],points[i+1],radius,m)

static func fin(parent: Node3D, name_: String, outline: Array[Vector3], m: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,outline.size()-1):
		for p in [outline[0],outline[i],outline[i+1]]:st.add_vertex(p)
	st.generate_normals()
	mesh_node(parent,name_,st.commit(),m)
	var rib := material("fin_rays",Color("748d90"),.45)
	for i in range(2,outline.size()):rod(parent,"FinRay",outline[0],outline[i],.00065,rib)
	for i in range(1,outline.size()-1):
		for j in range(1,5):rod(parent,"FineFinRay",outline[0],outline[i].lerp(outline[i+1],j/5.0),.00035,rib)

static func lathe(parent: Node3D, name_: String, profile: Array[Vector2], m: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(profile.size()-1):
		for col in range(64):
			var vertices: Array[Vector3] = []
			for ij in [Vector2i(row,col),Vector2i(row,col+1),Vector2i(row+1,col+1),Vector2i(row+1,col)]:
				var p := profile[ij.x]
				var a: float = ij.y*TAU/64.0
				vertices.append(Vector3(p.x*cos(a),p.y,p.x*sin(a)))
			for idx in [0,2,1,0,3,2]:st.add_vertex(vertices[idx])
	st.generate_normals()
	mesh_node(parent,name_,st.commit(),m)

static func fish(parent: Node3D, cooked: bool) -> void:
	var skin := material("roasted_skin" if cooked else "silver_skin",Color("b68148") if cooked else Color("92afb2"),.47 if cooked else .30,.08 if cooked else .38)
	skin.albedo_color = Color.WHITE
	skin.albedo_texture = load("res://furniture_pack/quest_props/roast_skin.png" if cooked else "res://furniture_pack/quest_props/fish_skin.png")
	var fin_mat := material("roasted_fins" if cooked else "blue_fins",Color("8c5836") if cooked else Color("526f79"),.57)
	fin_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var belly := material("fish_belly",Color("d4dacc"),.42,.12)
	var dark := material("eye_black",Color("101b21"),.12)
	var iris := material("eye_iris",Color("d6bb77"),.28,.3)
	var profile: Array[Vector3] = [Vector3(-.18,.007,.011),Vector3(-.14,.018,.027),Vector3(-.09,.033,.048),Vector3(-.03,.041,.062),Vector3(.035,.040,.060),Vector3(.085,.033,.048),Vector3(.125,.024,.034),Vector3(.15,.009,.016),Vector3(.158,.002,.003)]
	if cooked:profile = profile.slice(3)
	var y0 := .060 if cooked else .043
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(profile.size()-1):
		for a in range(32):
			for corner in [Vector2i(r,a),Vector2i(r+1,a),Vector2i(r+1,a+1),Vector2i(r,a),Vector2i(r+1,a+1),Vector2i(r,a+1)]:
				var p := profile[corner.x]
				var angle: float = corner.y*TAU/32.0
				st.set_uv(Vector2((p.x+.18)/.338,corner.y/32.0))
				st.add_vertex(Vector3(p.x,y0+p.y*cos(angle),p.z*sin(angle)))
	st.generate_normals()
	mesh_node(parent,"TaperedFishBody",st.commit(),skin)
	# Defined gill covers, eyes, jaw and lips remain readable at cat eye height.
	for side in [-1,1]:
		ellipsoid(parent,"GillCover",Vector3(.073,y0+.015,side*.034),Vector3(.047,.043,.023),skin)
		ellipsoid(parent,"EyeRing",Vector3(.119,y0+.021,side*.025),Vector3(.012,.009,.010),iris)
		ellipsoid(parent,"Pupil",Vector3(.120,y0+.023,side*.027),Vector3(.007,.006,.007),dark)
		ellipsoid(parent,"EyeGlint",Vector3(.121,y0+.025,side*.028),Vector3(.0015,.0015,.0015),belly)
		var seam: Array[Vector3] = []
		for j in range(9):
			var a := -.9+j*.22
			seam.append(Vector3(.06+.012*cos(a),y0+.028*sin(a),side*(.043+.003*cos(a))))
		line(parent,"GillSlit",seam,.0012,fin_mat)
		fin(parent,"PectoralFin",[Vector3(.047,y0,.044*side),Vector3(-.017,y0-.020,.107*side),Vector3(-.036,y0-.019,.082*side),Vector3(.010,y0,.051*side)],fin_mat)
	rod(parent,"Mouth",Vector3(.150,y0-.002,-.012),Vector3(.150,y0-.002,.012),.0015,dark)
	fin(parent,"DorsalFin",[Vector3(-.085 if not cooked else -.025,y0+.029,0),Vector3(-.042,y0+.058,0),Vector3(.015,y0+.055,0),Vector3(.047,y0+.035,0)],fin_mat)
	if not cooked:
		fin(parent,"ForkedTail",[Vector3(-.173,y0,0),Vector3(-.245,y0,.071),Vector3(-.227,y0,.013),Vector3(-.237,y0,-.066),Vector3(-.175,y0,-.007)],fin_mat)
		var scale_mat := material("scale_edges",Color("adc5c3"),.32,.3)
		for row in range(8):
			var x := -.115+row*.022
			var width := .058*sqrt(maxf(.1,1.0-pow((x+.015)/.16,2)))
			for side in [-1,1]:
				for band in range(3):
					var z: float = side*width*(.16+band*.24)
					var y := y0+.037*sqrt(maxf(.1,1.0-pow(z/.063,2)))*sqrt(maxf(.1,1.0-pow((x+.015)/.17,2)))
					line(parent,"ScaleArc",[Vector3(x-.005,y,z-.005),Vector3(x-.002,y+.0015,z),Vector3(x-.005,y,z+.005)],.00055,scale_mat)
	else:
		var flesh := material("cooked_flesh",Color("ead8b5"),.76)
		ellipsoid(parent,"CutFace",Vector3(-.030,y0,0),Vector3(.002,.077,.116),flesh)
		for j in range(7):
			var z := -.043+j*.014
			rod(parent,"FlakedFlesh",Vector3(-.032,y0-.022,z),Vector3(-.032,y0+.022,z+.004),.0008,belly)
		var charred := material("grill_marks",Color("745034"),.85)
		for x in [.0,.036,.072]:rod(parent,"RoastScoring",Vector3(x-.008,y0+.038,-.023),Vector3(x+.008,y0+.035,.022),.0016,charred)
		lathe(parent,"CeramicDinnerPlate",[Vector2(0,.008),Vector2(.115,.008),Vector2(.158,.018),Vector2(.167,.024),Vector2(.164,.029),Vector2(.150,.026),Vector2(.112,.015),Vector2(0,.015)],material("plate_glaze",Color("e5e3d6"),.23))
		lathe(parent,"GlazedRim",[Vector2(.156,.026),Vector2(.162,.028)],material("plate_rim",Color("668d83"),.28))

static func finish_imported(visual: Node3D, id: String) -> void:
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original: Material = mesh.mesh.surface_get_material(surface)
			if not original is StandardMaterial3D:continue
			var key: String = original.resource_name
			if key=="amber" and id.begins_with("medicine_"):
				mesh.set_surface_override_material(surface,material("sealed_amber",Color("806048"),.34))
			elif key.begins_with("medicine_") and id.begins_with("medicine_"):
				var label_mat := original.duplicate() as StandardMaterial3D
				label_mat.albedo_texture = load("res://act3/textures/sealed_%s.png"%id)
				mesh.set_surface_override_material(surface,label_mat)
			elif key=="amber" and id=="feeder":
				var glass := material("amber_glass",Color(.64,.43,.22,.23),.16)
				glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.set_surface_override_material(surface,glass)
			elif (id.begins_with("shirt") and key in ["blue","red","gold"]) or (id=="cat_bed" and key=="paper"):
				var cloth := original.duplicate() as StandardMaterial3D
				cloth.albedo_texture = load("res://furniture_pack/textures/linen_weave.png")
				cloth.albedo_color = Color("78939d") if key=="blue" else Color("a77c78") if key=="red" else Color("bda372") if key=="gold" else Color("e5dfca")
				cloth.uv1_triplanar = true
				cloth.uv1_scale = Vector3.ONE*5.0
				cloth.roughness = .96
				mesh.set_surface_override_material(surface,cloth)
			elif id=="step_stool" and key=="cork":
				mesh.set_surface_override_material(surface,load("res://furniture_pack/materials/oak.tres"))

	if id=="feeder":
		var kibble := material("kibble",Color("9f7045"),.9)
		var grain := SphereMesh.new()
		grain.radius = .5
		grain.height = 1
		grain.radial_segments = 12
		grain.rings = 6
		grain.material = kibble
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = grain
		batch.instance_count = 448
		for i in range(448):
			var a := i*2.39996
			var r := .104*sqrt(float(i%32)/32.0)
			var pos := Vector3((-.155 if i<224 else .155)+cos(a)*r,.715+floori((i%224)/32.0)*.023,sin(a)*r)
			batch.set_instance_transform(i,Transform3D(Basis(Vector3.UP,a).scaled(Vector3(.035,.025,.032)),pos))
		var grains := MultiMeshInstance3D.new()
		grains.name = "SettledDryFood"
		grains.multimesh = batch
		visual.add_child(grains)
	elif id=="letter":
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var m: Material = mesh.mesh.surface_get_material(surface)
				if m is StandardMaterial3D and m.resource_name=="letter":
					var printed := m.duplicate() as StandardMaterial3D
					printed.albedo_texture = load("res://furniture_pack/quest_props/care_letter.png")
					mesh.set_surface_override_material(surface,printed)
