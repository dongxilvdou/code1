extends SceneTree
## Reproducible furniture library; metres, Y up, front +Z, floor-centred origins.
const BASE := "res://furniture_pack/"
var item: Node3D
var materials: Dictionary = {}
var meshes: Dictionary = {}
var records: Array = []
var failures: Array = []
var serial := 0
var collider_count := 0

func _initialize() -> void:
	call_deferred("build")

func add(n: Node, parent: Node = null) -> void:
	if parent == null: parent = item
	parent.add_child(n, true)
	n.owner = item

func material(key: String, color: Color, pattern: int = 0, rough: float = .7, metal: float = 0) -> void:
	var m: Material
	if pattern != 0:
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = load(BASE + "materials/surface.gdshader")
		shader_mat.set_shader_parameter("tint", color)
		shader_mat.set_shader_parameter("pattern", pattern)
		shader_mat.set_shader_parameter("finish", rough)
		shader_mat.set_shader_parameter("wood_texture",load(BASE+"textures/oak_grain.png"))
		shader_mat.set_shader_parameter("fabric_texture",load(BASE+"textures/linen_weave.png"))
		shader_mat.set_shader_parameter("stone_texture",load(BASE+"textures/mineral_detail.png"))
		m = shader_mat
	else:
		var standard := StandardMaterial3D.new()
		standard.albedo_color = color
		standard.roughness = rough
		standard.metallic = metal
		m = standard
	m.resource_name = key
	ResourceSaver.save(m, BASE + "materials/" + key + ".tres")
	m.take_over_path(BASE + "materials/" + key + ".tres")
	materials[key] = m

func palette() -> void:
	material("oak", Color("a68054"), 1)
	material("walnut", Color("62462e"), 1)
	material("linen", Color("d6c6aa"), 2, .93)
	material("cream", Color("ece3d1"), 2, .92)
	material("sage_fabric", Color("788977"), 2, .92)
	material("rust", Color("a46040"), 2, .93)
	material("sage", Color("91a18b"), 0, .64)
	material("ivory", Color("e6dfcf"), 0, .58)
	material("porcelain", Color("eeeae0"), 0, .22)
	material("stone", Color("c6bda9"), 3, .54)
	material("brass", Color("9d7c43"), 0, .32, .75)
	material("steel", Color("828b88"), 0, .3, .82)
	material("charcoal", Color("303938"), 0, .45, .15)
	material("shadow", Color("262d29"), 0, .9)
	material("glass_black", Color("1b292c"), 0, .12, .35)
	material("rope", Color("bba780"), 2, .97)
	material("book_green", Color("5c7068"))
	material("book_red", Color("9a5947"))

func mesh_node(label: String, mesh: Mesh, p: Vector3, key: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	n.mesh = mesh
	n.position = p
	n.material_override = materials[key]
	add(n)
	return n

func collision(p: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var body: StaticBody3D = item.get_node_or_null("Collision")
	if body == null:
		body = StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = 1
		body.collision_mask = 2
		add(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = Transform3D(basis, p)
	shape.name = "Solid_%03d" % collider_count
	collider_count += 1
	add(shape, body)

func triangle(st: SurfaceTool, points: Array, normals: Array) -> void:
	# Godot front faces are clockwise, viewed from outside.
	var order := [0, 1, 2]
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(normals[0]+normals[1]+normals[2]) > 0:
		order = [0, 2, 1]
	for k in order:
		st.set_normal(normals[k])
		st.set_uv(Vector2(points[k].x + points[k].z, points[k].y + points[k].z))
		st.add_vertex(points[k])

func axis_values(h: float, r: float) -> Array:
	return [-h, -h+r*.07612, -h+r*.29289, -h+r*.61732, -h+r, h-r, h-r*.61732, h-r*.29289, h-r*.07612, h]

func rounded_mesh(size: Vector3, bevel: float) -> Mesh:
	var r := minf(bevel, minf(size.x, minf(size.y, size.z)) * .48)
	var key := "%s_%f" % [size, r]
	if meshes.has(key): return meshes[key]
	var half := size * .5
	var inner := half - Vector3.ONE * r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in range(3):
		var u := (axis+1)%3
		var v := (axis+2)%3
		var xs := axis_values(half[u], r)
		var ys := axis_values(half[v], r)
		for side in [-1, 1]:
			for x in range(xs.size()-1):
				for y in range(ys.size()-1):
					var points: Array = []
					var normals: Array = []
					for ij in [Vector2i(x,y),Vector2i(x+1,y),Vector2i(x+1,y+1),Vector2i(x,y+1)]:
						var p := Vector3.ZERO
						p[axis] = half[axis]*side
						p[u] = xs[ij.x]
						p[v] = ys[ij.y]
						var q := p.clamp(-inner, inner)
						var normal := (p-q).normalized()
						points.append(q+normal*r)
						normals.append(normal)
					triangle(st, [points[0],points[1],points[2]], [normals[0],normals[1],normals[2]])
					triangle(st, [points[0],points[2],points[3]], [normals[0],normals[2],normals[3]])
	st.index()
	var mesh := st.commit()
	var path := BASE + "meshes/bevel_%s.res" % key.md5_text().substr(0,12)
	ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	mesh.take_over_path(path)
	meshes[key] = mesh
	return mesh

func block(label: String, p: Vector3, size: Vector3, key: String, bevel: float = .008, solid: bool = true, tilt: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var n := mesh_node(label, rounded_mesh(size, bevel), p, key)
	n.rotation = tilt
	if solid: collision(p, size, n.basis)
	return n

func rod(label: String, a: Vector3, b: Vector3, radius: float, key: String, top: float = -1, solid: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 32
	var n := mesh_node(label, mesh, (a+b)*.5, key)
	n.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	if solid: collision(n.position, Vector3(radius*2, mesh.height, radius*2), n.basis)
	return n

func ball(label: String, p: Vector3, size: Vector3, key: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1
	mesh.radial_segments = 32
	mesh.rings = 16
	var n := mesh_node(label, mesh, p, key)
	n.scale = size

func ring(label: String, p: Vector3, radius: float, tube: float, key: String, scale_z: float = 1) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-tube
	mesh.outer_radius = radius+tube
	mesh.rings = 48
	mesh.ring_segments = 10
	var n := mesh_node(label, mesh, p, key)
	n.scale.z = scale_z

func lathe(label: String, profile: Array, p: Vector3, key: String, stretch: Vector3 = Vector3.ONE) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(profile.size()-1):
		for i in range(64):
			var points: Array = []
			var normals: Array = []
			for pair in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
				var a: float = TAU * pair.x / 64.0
				var q: Vector2 = profile[pair.y]
				var tangent: Vector2 = profile[mini(pair.y+1,profile.size()-1)]-profile[maxi(pair.y-1,0)]
				var normal2 := Vector2(tangent.y,-tangent.x).normalized()
				points.append(Vector3(cos(a)*q.x,q.y,sin(a)*q.x)*stretch)
				normals.append((Vector3(cos(a)*normal2.x,normal2.y,sin(a)*normal2.x)/stretch).normalized())
			triangle(st,[points[0],points[1],points[2]],[normals[0],normals[1],normals[2]])
			triangle(st,[points[0],points[2],points[3]],[normals[0],normals[2],normals[3]])
	st.index()
	mesh_node(label,st.commit(),p,key)

func piping(label: String, p: Vector3, width: float, depth: float, radius: float, key: String) -> void:
	var corners := [Vector2(width*.5-radius,depth*.5-radius),Vector2(-width*.5+radius,depth*.5-radius),Vector2(-width*.5+radius,-depth*.5+radius),Vector2(width*.5-radius,-depth*.5+radius)]
	var points: Array[Vector3] = []
	for k in range(4):
		for i in range(9):
			var a := (k*PI*.5) + i*PI/16.0
			points.append(p+Vector3(corners[k].x+cos(a)*radius,0,corners[k].y+sin(a)*radius))
	for i in range(points.size()):rod(label,points[i],points[(i+1)%points.size()],.0025,key)

func legs(width: float, depth: float, height: float, key: String = "oak", radius: float = .028, splay: float = .025) -> void:
	for x in [-1,1]:
		for z in [-1,1]:
			var a := Vector3(x*(width*.5+splay),0,z*(depth*.5+splay))
			var b := Vector3(x*width*.5,height,z*depth*.5)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var delta := b-a
			for i in range(32):
				var points: Array = []
				var normals: Array = []
				for ij in [Vector2i(i,0),Vector2i(i+1,0),Vector2i(i+1,1),Vector2i(i,1)]:
					var angle: float = ij.x*TAU/32.0
					var radial := Vector3(cos(angle),0,sin(angle))
					points.append((a if ij.y==0 else b)+radial*radius*(1 if ij.y==0 else 1.22))
					normals.append(Vector3(radial.x,-(delta.dot(radial)+radius*.22)/height,radial.z).normalized())
				triangle(st,[points[0],points[1],points[2]],[normals[0],normals[1],normals[2]])
				triangle(st,[points[0],points[2],points[3]],[normals[0],normals[2],normals[3]])
				triangle(st,[a,points[0],points[1]],[Vector3.DOWN,Vector3.DOWN,Vector3.DOWN])
				triangle(st,[b,points[2],points[3]],[Vector3.UP,Vector3.UP,Vector3.UP])
			st.index()
			var n := mesh_node("Tapered_leg",st.commit(),Vector3.ZERO,key)
			# Flat-ended convex legs meet the floor exactly even when splayed.
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 2
			add(body,n)
			var shape := CollisionShape3D.new()
			shape.shape = n.mesh.create_convex_shape()
			add(shape,body)
			collider_count += 1

func handle(x: float, y: float, z: float, vertical: bool = false, length: float = .12) -> void:
	var d := Vector3(0,length*.5,0) if vertical else Vector3(length*.5,0,0)
	var p := Vector3(x,y,z)
	rod("Handle",p-d,p+d,.006,"brass")
	for side in [-1,1]:rod("Handle_mount",p+d*side-Vector3(0,0,.025),p+d*side,.005,"brass")

func door_panel(p: Vector3, width: float, height: float, key: String = "sage") -> void:
	block("Door_inset",p,Vector3(width-.06,height-.06,.018),key,.004,false)
	for side in [-1,1]:
		block("Door_stile",p+Vector3(side*(width-.035)*.5,0,.012),Vector3(.035,height,.035),key,.004,false)
		block("Door_rail",p+Vector3(0,side*(height-.035)*.5,.012),Vector3(width-.07,.035,.035),key,.004,false)

func case_shell(width: float, height: float, depth: float, bottom: float, key: String = "oak", upper_shelf: float = -1) -> void:
	for side in [-1,1]:block("Cabinet_side",Vector3(side*(width-.035)*.5,(height+bottom)*.5,0),Vector3(.035,height-bottom,depth),key)
	block("Cabinet_back",Vector3(0,(height+bottom)*.5,-depth*.5+.015),Vector3(width-.07,height-bottom,.03),key)
	for y in [bottom+.018,height-.018 if upper_shelf<0 else upper_shelf]:block("Cabinet_shelf",Vector3(0,y,0),Vector3(width,.036,depth),key)

func begin(id: String) -> void:
	item = Node3D.new()
	item.name = id.to_pascal_case()
	collider_count = 0
	root.add_child(item)

func finish(id: String, title: String, room: String, note: String) -> void:
	# Fuse repeated thread/welt details to avoid dozens of draw calls per cushion/post.
	for prefix in ["Seat_welt","Mattress_welt","Rope_turn"]:
		var repeats: Array = []
		for child in item.get_children():
			if child is MeshInstance3D and str(child.name).begins_with(prefix):repeats.append(child)
		if repeats.size()>1:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var mat: Material = repeats[0].material_override
			for child in repeats:
				st.append_from(child.mesh,0,child.transform)
				child.free()
			var combined := MeshInstance3D.new()
			combined.name = prefix
			combined.mesh = st.commit()
			combined.material_override = mat
			add(combined)
	var bounds := AABB()
	var started := false
	var triangles := 0
	for child in item.get_children():
		if child is MeshInstance3D:
			if child.mesh is ArrayMesh and child.mesh.resource_path.is_empty():
				var mesh_path := BASE+"meshes/"+id+"_"+str(child.name)+".res"
				ResourceSaver.save(child.mesh,mesh_path,ResourceSaver.FLAG_COMPRESS)
				child.mesh.take_over_path(mesh_path)
			var box: AABB = child.transform * child.mesh.get_aabb()
			bounds = bounds.merge(box) if started else box
			started = true
			for s in range(child.mesh.get_surface_count()):
				var arrays: Array = child.mesh.surface_get_arrays(s)
				triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
	var dims := [snappedf(bounds.size.x,.001),snappedf(bounds.size.y,.001),snappedf(bounds.size.z,.001)]
	var record := {"id":id,"name":title,"room":room,"dimensions_m":dims,"bounds_min_m":[bounds.position.x,bounds.position.y,bounds.position.z],"triangles":triangles,"collision_shapes":collider_count,"note":note,"scene":BASE+"scenes/"+id+".tscn"}
	item.set_meta("furniture",record)
	var packed := PackedScene.new()
	var err := packed.pack(item)
	if err == OK: err = ResourceSaver.save(packed,record.scene)
	if err != OK or absf(bounds.position.y)>.006:failures.append(id+" save/origin invalid")
	records.append(record)
	item.free()

func sofa(armchair: bool = false) -> void:
	var id := "armchair" if armchair else "sofa"
	begin(id)
	var width := .88 if armchair else 2.12
	var fabric := "sage_fabric" if armchair else "linen"
	legs(width-.2,.68,.18,"walnut",.032)
	block("Timber_lower_frame",Vector3(0,.22,0),Vector3(width-.08,.14,.84),"walnut",.035)
	block("Upholstered_base",Vector3(0,.315,0),Vector3(width-.04,.15,.9),fabric,.05)
	# Recess the chair back into its arms; shared side/bottom planes z-fight.
	block("Back_shell",Vector3(0,.664 if armchair else .66,-.36),Vector3(width-.06 if armchair else width,.592 if armchair else .60,.18),fabric,.065)
	for side in [-1,1]:block("Soft_arm",Vector3(side*(width-.16)*.5,.57,0),Vector3(.16,.42,.94),fabric,.07)
	var count := 1 if armchair else 3
	var seat_w := (width-.35)/count
	for i in range(count):
		var x := (i-(count-1)*.5)*seat_w
		block("Seat_cushion",Vector3(x,.435,.04),Vector3(seat_w-.012,.15,.71),fabric,.06)
		piping("Seat_welt",Vector3(x,.469,.04),seat_w-.032,.69,.07,"cream")
		block("Back_cushion",Vector3(x,.719,-.225),Vector3(seat_w-.014,.40,.16),fabric,.065,false,Vector3(-.11,0,0))
	if not armchair:
		block("Terracotta_throw_pillow",Vector3(-.68,.67,.02),Vector3(.33,.34,.13),"rust",.06,false,Vector3(-.2,.1,-.18))
		block("Sage_throw_pillow",Vector3(.70,.67,.015),Vector3(.32,.34,.12),"sage_fabric",.06,false,Vector3(-.2,-.1,.16))
	finish(id,"休闲扶手椅" if armchair else "三人布艺沙发","客厅","座高约 0.51 m；沙发底部 0.15 m，猫仅可蹲伏靠近，不作为穿行通道。")

func coffee_table() -> void:
	begin("coffee_table")
	legs(.88,.42,.41,"oak",.026,.03)
	block("Rounded_tabletop",Vector3(0,.425,0),Vector3(1.12,.05,.62),"oak",.024)
	block("Lower_open_shelf",Vector3(0,.19,0),Vector3(.90,.025,.44),"oak",.009)
	for z in [-.20,.20]:block("Shelf_edge",Vector3(0,.215,z),Vector3(.9,.025,.018),"walnut",.004,false)
	finish("coffee_table","圆角双层茶几","客厅","桌面高 0.45 m；开放下层可供猫跳上。")

func tv_console() -> void:
	begin("tv_console")
	legs(1.56,.30,.16,"walnut",.023,0)
	case_shell(1.8,.52,.42,.16)
	block("Open_center_shelf",Vector3(0,.34,0),Vector3(.52,.025,.39),"oak")
	for side in [-1,1]:
		block("Interior_divider",Vector3(side*.28,.34,0),Vector3(.025,.32,.39),"oak")
		for j in range(14):block("Fluted_front",Vector3(side*.584+(j-6.5)*.038,.34,.213),Vector3(.024,.30,.023),"walnut",.008,false)
		collision(Vector3(side*.584,.34,.213),Vector3(.55,.30,.025))
		ball("Door_pull",Vector3(side*.40,.37,.243),Vector3(.024,.024,.024),"brass")
	finish("tv_console","藤条感木格电视柜","客厅","两侧封闭柜与中央开放层板；未附电视。")

func dining_table() -> void:
	begin("dining_table")
	legs(1.32,.62,.72,"oak",.038,.035)
	block("Dining_top",Vector3(0,.735,0),Vector3(1.6,.05,.85),"oak",.024)
	for z in [-.31,.31]:block("Long_apron",Vector3(0,.65,z),Vector3(1.36,.10,.028),"oak")
	for x in [-.66,.66]:block("Short_apron",Vector3(x,.65,0),Vector3(.028,.10,.62),"oak")
	finish("dining_table","四至六人餐桌","餐厨","桌面高 0.76 m；桌下横撑底高 0.60 m，留有完整钻行空间。")

func dining_chair() -> void:
	begin("dining_chair")
	legs(.36,.34,.43,"oak",.021,.03)
	block("Seat_frame",Vector3(0,.425,0),Vector3(.46,.045,.46),"oak",.022)
	block("Upholstered_seat",Vector3(0,.465,.008),Vector3(.425,.045,.415),"sage_fabric",.021)
	for x in [-.19,.19]:rod("Back_post",Vector3(x,.41,-.18),Vector3(x,.88,-.24),.018,"oak",.021,true)
	block("Curved_backrest",Vector3(0,.785,-.227),Vector3(.45,.17,.045),"oak",.02,true,Vector3(-.08,0,0))
	for x in [-.18,.18]:rod("Side_stretcher",Vector3(x,.24,-.18),Vector3(x,.24,.18),.012,"oak",-1,true)
	finish("dining_chair","软垫橡木餐椅","餐厨","座面高 0.488 m；前后开放，猫可从椅下穿行。")

func faucet(p: Vector3) -> void:
	rod("Tap_base",p,p+Vector3(0,.18,0),.018,"steel")
	rod("Tap_neck",p+Vector3(0,.18,0),p+Vector3(0,.21,.09),.014,"steel")
	rod("Tap_spout",p+Vector3(0,.21,.09),p+Vector3(0,.17,.14),.014,"steel")
	rod("Tap_lever",p+Vector3(.025,.10,0),p+Vector3(.075,.15,0),.007,"steel")

func kitchen(sink: bool = false) -> void:
	var id := "sink_cabinet" if sink else "kitchen_cabinet"
	begin(id)
	var width := .8 if sink else .6
	block("Recessed_plinth",Vector3(0,.06,-.03),Vector3(width-.08,.12,.48),"walnut")
	case_shell(width,.86,.57,.12,"ivory",.61 if sink else -1)
	if sink:
		for side in [-1,1]:block("Sink_worktop_side",Vector3(side*.325,.88,0),Vector3(.15,.04,.62),"stone")
		for z in [-.26,.26]:block("Sink_worktop_rail",Vector3(0,.88,z),Vector3(.50,.04,.10),"stone")
		# True open basin: rim, inner walls and recessed bottom, no solid slab covering it.
		for x in [-.235,.235]:block("Sink_side_wall",Vector3(x,.785,0),Vector3(.03,.19,.43),"steel",.012,false)
		for z in [-.20,.20]:block("Sink_end_wall",Vector3(0,.785,z),Vector3(.44,.19,.03),"steel",.012,false)
		block("Sink_bottom",Vector3(0,.698,0),Vector3(.47,.025,.40),"steel",.012)
		rod("Drain",Vector3(0,.711,0),Vector3(0,.713,0),.027,"charcoal")
		faucet(Vector3(0,.9,-.265))
		item.get_node("Tap_spout").rotation.x = deg_to_rad(135)
		for x in [-.198,.198]:door_panel(Vector3(x,.49,.294),.39,.70)
		handle(-.05,.66,.34,true)
		handle(.05,.66,.34,true)
	else:
		block("Stone_countertop",Vector3(0,.88,0),Vector3(width+.02,.04,.62),"stone",.012)
		for y in [.24,.49,.74]:
			door_panel(Vector3(0,y,.294),.58,.24)
			handle(0,y+.055,.34)
	# Cabinet fronts are closed props, with no hollow shortcuts through them.
	collision(Vector3(0,.49,.27),Vector3(width,.74,.045))
	finish(id,"不锈钢水槽地柜" if sink else "三抽厨房地柜","餐厨","柜体标准深 0.60 m，台面高 0.90 m；可沿墙模块化拼接。")

func cooker() -> void:
	begin("cooker")
	block("Range_body",Vector3(0,.43,0),Vector3(.6,.86,.58),"ivory",.02)
	block("Oven_frame",Vector3(0,.40,.302),Vector3(.53,.48,.025),"charcoal",.018,false)
	block("Oven_glass",Vector3(0,.39,.32),Vector3(.45,.34,.012),"glass_black",.016,false)
	handle(0,.64,.36,false,.40)
	for x in [-.20,-.067,.067,.20]:rod("Control_dial",Vector3(x,.78,.292),Vector3(x,.78,.325),.025,"brass")
	block("Hob",Vector3(0,.878,0),Vector3(.62,.044,.62),"charcoal",.015)
	for x in [-.15,.15]:
		for z in [-.16,.16]:
			ring("Burner",Vector3(x,.907,z),.072,.009,"steel")
			for offset in [-.08,.08]:block("Pan_support",Vector3(x+offset,.914,z),Vector3(.012,.018,.20),"charcoal",.004,false)
	finish("cooker","复古灶台烤箱","餐厨","灶台高约 0.92 m；静态外观资产，不含烹饪交互。")

func fridge() -> void:
	begin("fridge")
	block("Fridge_body",Vector3(0,.90,0),Vector3(.70,1.80,.68),"ivory",.05)
	block("Lower_freezer",Vector3(0,.34,.35),Vector3(.68,.60,.075),"sage",.03)
	block("Upper_door",Vector3(0,1.22,.35),Vector3(.68,1.12,.075),"sage",.035)
	handle(-.24,1.19,.435,true,.38)
	handle(-.24,.46,.435,true,.18)
	block("Maker_badge",Vector3(.15,1.60,.393),Vector3(.15,.028,.006),"brass",.003,false)
	for x in range(9):block("Lower_vent",Vector3((x-4)*.048,.075,.392),Vector3(.027,.025,.008),"charcoal",.004,false)
	finish("fridge","鼠尾草绿双门冰箱","餐厨","高 1.80 m；把手已计入总深度。")

func bed() -> void:
	begin("bed")
	legs(1.44,1.80,.36,"oak",.04,0)
	block("Floating_bed_frame",Vector3(0,.365,0),Vector3(1.70,.09,2.12),"oak",.03)
	block("Mattress",Vector3(0,.49,0),Vector3(1.60,.20,2.00),"cream",.07)
	piping("Mattress_welt",Vector3(0,.54,0),1.58,1.98,.08,"linen")
	block("Quilt",Vector3(0,.608,.30),Vector3(1.64,.055,1.38),"sage_fabric",.025,false)
	for x in [-.80,.80]:block("Draped_quilt_edge",Vector3(x,.50,.30),Vector3(.045,.25,1.38),"sage_fabric",.021,false)
	for x in [-.40,.40]:block("Pillow",Vector3(x,.64,-.66),Vector3(.65,.13,.42),"cream",.06,false)
	block("Headboard_frame",Vector3(0,.76,-1.08),Vector3(1.78,.86,.10),"oak",.04)
	block("Upholstered_headboard",Vector3(0,.85,-1.015),Vector3(1.60,.56,.055),"linen",.025,false)
	for x in [-.50,0,.50]:ball("Headboard_button",Vector3(x,.85,-.982),Vector3(.018,.018,.008),"walnut")
	finish("bed","双人软包木床","卧室","床垫 1.60 × 2.00 m；床下净高 0.32 m，大于猫的 0.288 m 碰撞体高度。")

func nightstand() -> void:
	begin("nightstand")
	legs(.36,.30,.18,"oak",.023,0)
	case_shell(.50,.55,.42,.18)
	door_panel(Vector3(0,.445,.218),.46,.17,"ivory")
	handle(0,.46,.26)
	block("Drawer_floor",Vector3(0,.35,0),Vector3(.46,.025,.38),"oak")
	collision(Vector3(0,.445,.21),Vector3(.46,.17,.04))
	finish("nightstand","单抽开放床头柜","卧室","台面高 0.55 m；下方为开放收纳层。")

func wardrobe() -> void:
	begin("wardrobe")
	block("Plinth",Vector3(0,.055,0),Vector3(1.36,.11,.54),"walnut")
	case_shell(1.40,2.12,.60,.11,"oak")
	block("Crown",Vector3(0,2.145,0),Vector3(1.46,.05,.65),"oak",.015)
	for x in [-.345,.345]:door_panel(Vector3(x,1.115,.313),.68,1.96,"sage")
	for x in [-.055,.055]:handle(x,1.03,.36,true,.20)
	collision(Vector3(0,1.12,.31),Vector3(1.40,2,.045))
	finish("wardrobe","双门衣柜","卧室","高 2.17 m；适配 3 m 层高与现有门洞。柜门为静态部件。")

func desk() -> void:
	begin("desk")
	legs(1.12,.45,.73,"oak",.025,0)
	block("Desktop",Vector3(0,.755,0),Vector3(1.30,.05,.65),"oak",.022)
	block("Drawer_box",Vector3(.39,.63,0),Vector3(.40,.20,.54),"oak",.012)
	door_panel(Vector3(.39,.63,.281),.38,.17,"sage")
	handle(.39,.66,.32)
	block("Rear_support",Vector3(0,.65,-.24),Vector3(1.15,.10,.022),"oak")
	finish("desk","单抽书桌","书房","台面高 0.78 m；左侧膝部与猫通道保持开放。")

func bookcase() -> void:
	begin("bookcase")
	block("Plinth",Vector3(0,.055,0),Vector3(.86,.11,.29),"walnut")
	case_shell(.90,1.82,.34,.11)
	for y in [.48,.91,1.34]:block("Shelf",Vector3(0,y,0),Vector3(.85,.03,.32),"oak")
	for level in range(3):
		for i in range(5):
			var x := -.30+i*.055
			var y: float = [.505,.935,1.365][level]
			var h := .23 + ((i+level)%3)*.025
			block("Book",Vector3(x,y+h*.5,-.025),Vector3(.043,h,.19),"book_green" if (i+level)%2 else "book_red",.004,false)
			block("Spine_band",Vector3(x,y+.045,.074),Vector3(.037,.008,.004),"brass",.001,false)
	finish("bookcase","开放四层书架","书房","层板高 0.48 / 0.91 / 1.34 m，逐层可供猫攀跳；书本可单独隐藏。")

func vanity() -> void:
	begin("bath_vanity")
	legs(.65,.35,.20,"walnut",.025,0)
	case_shell(.80,.76,.50,.20,"sage")
	for x in [-.195,.195]:door_panel(Vector3(x,.48,.261),.38,.51,"sage")
	for x in [-.05,.05]:handle(x,.60,.31,true,.10)
	collision(Vector3(0,.48,.25),Vector3(.8,.53,.04))
	block("Stone_top",Vector3(0,.785,0),Vector3(.86,.05,.56),"stone",.018)
	lathe("Open_porcelain_basin",[Vector2(.04,0),Vector2(.13,.015),Vector2(.21,.085),Vector2(.225,.135),Vector2(.217,.15),Vector2(.203,.135),Vector2(.185,.08),Vector2(.11,.026),Vector2(.025,.022)],Vector3(0,.81,.025),"porcelain",Vector3(1.25,1,.85))
	rod("Drain",Vector3(0,.833,.025),Vector3(0,.837,.025),.025,"steel")
	faucet(Vector3(0,.81,-.22))
	finish("bath_vanity","台上盆浴室柜","卫浴","盆口高约 0.96 m；含真实凹盆与龙头，无镜子。")

func toilet() -> void:
	begin("toilet")
	lathe("Pedestal",[Vector2(.01,0),Vector2(.16,0),Vector2(.17,.025),Vector2(.13,.12),Vector2(.115,.24),Vector2(.18,.32)],Vector3(0,0,.055),"porcelain",Vector3(1,1,1.30))
	lathe("Open_bowl",[Vector2(.10,.21),Vector2(.16,.26),Vector2(.20,.34),Vector2(.205,.39),Vector2(.19,.405),Vector2(.173,.39),Vector2(.14,.31),Vector2(.045,.25)],Vector3(0,0,.07),"porcelain",Vector3(1,1,1.40))
	ring("Seat_ring",Vector3(0,.42,.07),.19,.022,"ivory",1.4)
	block("Cistern",Vector3(0,.545,-.22),Vector3(.39,.43,.18),"porcelain",.05)
	block("Cistern_lid",Vector3(0,.772,-.22),Vector3(.40,.035,.19),"porcelain",.017)
	rod("Flush_button",Vector3(.08,.791,-.22),Vector3(.08,.796,-.22),.022,"steel")
	collision(Vector3(0,.18,.07),Vector3(.27,.36,.37))
	collision(Vector3(0,.35,.07),Vector3(.39,.11,.55))
	finish("toilet","圆润陶瓷坐便器","卫浴","座圈高 0.442 m；凹盆与底座独立建模。")

func bench() -> void:
	begin("garden_bench")
	legs(1.18,.38,.43,"charcoal",.025,0)
	for i in range(5):block("Seat_slat",Vector3(0,.448,(i-2)*.095),Vector3(1.50,.035,.08),"oak",.012)
	for x in [-.59,.59]:rod("Back_support",Vector3(x,.33,-.19),Vector3(x,.91,-.29),.022,"charcoal",-1,true)
	for y in [.63,.75,.87]:block("Back_slat",Vector3(0,y,-.19-(y-.33)*.17),Vector3(1.50,.09,.03),"oak",.012,true,Vector3(-.17,0,0))
	for x in [-.66,.66]:
		rod("Arm_support",Vector3(x,.44,.16),Vector3(x,.65,.16),.018,"charcoal",-1,true)
		block("Arm_rest",Vector3(x,.67,-.01),Vector3(.07,.035,.50),"oak",.015)
	finish("garden_bench","木条花园长椅","花园","座高 0.466 m；椅下无横向封板，保留猫穿行空间。")

func cat_tree() -> void:
	begin("cat_tree")
	block("Weighted_base",Vector3(0,.035,0),Vector3(.72,.07,.60),"oak",.028)
	for p in [Vector3(-.18,.07,-.08),Vector3(.18,.07,.08)]:
		var top := 1.22 if p.x<0 else .67
		rod("Sisal_post",p,Vector3(p.x,top,p.z),.055,"rope",-1,true)
		for i in range(int((top-.07)/.018)):ring("Rope_turn",Vector3(p.x,.085+i*.018,p.z),.055,.002,"rope")
	block("First_step",Vector3(.16,.345,.05),Vector3(.42,.06,.40),"oak",.026)
	block("Middle_perch",Vector3(.13,.70,.04),Vector3(.49,.06,.46),"oak",.028)
	block("Middle_pad",Vector3(.13,.747,.04),Vector3(.44,.035,.41),"linen",.017,false)
	block("Top_perch",Vector3(-.12,1.24,-.05),Vector3(.56,.06,.48),"oak",.028)
	block("Top_pad",Vector3(-.12,1.29,-.05),Vector3(.51,.045,.43),"sage_fabric",.021,false)
	rod("Toy_string",Vector3(-.30,1.20,.12),Vector3(-.30,1.04,.12),.002,"rope")
	ball("Toy_ball",Vector3(-.30,1.005,.12),Vector3(.065,.065,.065),"rust")
	finish("cat_tree","三层剑麻猫爬架","猫用品","落脚面依次约 0.38 / 0.77 / 1.31 m；台面间距适配当前猫跳跃能力。")

func floor_lamp() -> void:
	begin("floor_lamp")
	rod("Weighted_base",Vector3(0,0,0),Vector3(0,.04,0),.19,"charcoal",.18,true)
	rod("Stem",Vector3(0,.04,0),Vector3(0,1.50,0),.014,"brass",-1,true)
	lathe("Linen_shade",[Vector2(.24,1.26),Vector2(.15,1.63),Vector2(.146,1.63),Vector2(.235,1.26)],Vector3.ZERO,"cream")
	for y in [1.26,1.63]:ring("Shade_binding",Vector3(0,y,0),.24 if y<1.3 else .15,.004,"linen")
	ball("Bulb",Vector3(0,1.41,0),Vector3(.07,.10,.07),"ivory")
	finish("floor_lamp","亚麻黄铜落地灯","客厅","高 1.634 m；灯罩开放，预设不带实时光源，摆放后按房间需要添加。")

func build() -> void:
	for folder in ["scenes","meshes","materials","previews"]:DirAccess.make_dir_recursive_absolute(BASE+folder)
	palette()
	sofa()
	sofa(true)
	coffee_table()
	tv_console()
	dining_table()
	dining_chair()
	kitchen()
	kitchen(true)
	cooker()
	fridge()
	bed()
	nightstand()
	wardrobe()
	desk()
	bookcase()
	vanity()
	toilet()
	bench()
	cat_tree()
	floor_lamp()
	FileAccess.open(BASE+"catalog.json",FileAccess.WRITE).store_string(JSON.stringify({"units":"metres","up":"+Y","front":"+Z","pivot":"floor centre","cat_eye_m":.224,"cat_capsule_height_m":.288,"items":records},"\t"))
	print("FURNITURE_BUILD ",JSON.stringify({"items":records.size(),"shared_bevel_meshes":meshes.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
