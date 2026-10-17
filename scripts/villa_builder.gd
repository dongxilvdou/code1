extends "res://scripts/house_builder.gd"
## The reviewed V1 floor plan. Coordinates (x,z) are metres from its NW corner.
const STOREY := 3.0
const WALL_TOP := 2.82
const CENTER := Vector2(6,6)
var ground_floor: Node3D
var upper_floor: Node3D
var stair_group: Node3D
var garden: Node3D
var roof_group: Node3D
var light_group: Node3D
var wall_volumes: Array = []
var skirting_volumes: Array = []
var cornice_volumes: Array = []
var door_count := 0
const Geometry = preload("res://scripts/villa_geometry.gd")
const Foliage = preload("res://scripts/villa_foliage.gd")
const Basement = preload("res://scripts/villa_basement.gd")

func at(x: float, y: float, z: float) -> Vector3:
	return Vector3(x-6,y,z-6)

func folder(label: String) -> Node3D:
	var n := Node3D.new()
	n.name = label
	attach(n)
	return n

func surface_material(key: String, color: Color, texture: String, scale_uv: float, midpoint: float, strength: float, roughness: float = .8) -> void:
	var m := ShaderMaterial.new()
	m.resource_name = key
	m.shader = load("res://shaders/villa_surface.gdshader")
	m.set_shader_parameter("surface_color",color)
	m.set_shader_parameter("detail_texture",load("res://assets/"+texture+".png"))
	m.set_shader_parameter("texture_scale",scale_uv)
	m.set_shader_parameter("detail_midpoint",midpoint)
	m.set_shader_parameter("detail_strength",strength)
	m.set_shader_parameter("surface_roughness",roughness)
	m.set_shader_parameter("wall_finish",key=="villa_wall")
	mats[key] = m

func volume(pos: Vector3, size: Vector3) -> Array:
	return [pos-size*.5,pos+size*.5]

func finish_material(key: String, color: String, texture: String, uv_scale: Vector3, rough: float = .75, relief: float = .001, tile: bool = false) -> void:
	var m := ShaderMaterial.new()
	m.resource_name = key
	m.shader = load("res://shaders/villa_finish.gdshader")
	m.set_shader_parameter("surface_color",Color(color))
	m.set_shader_parameter("detail_texture",load("res://furniture_pack/textures/"+texture+".png"))
	m.set_shader_parameter("texture_scale",uv_scale)
	m.set_shader_parameter("roughness",rough)
	m.set_shader_parameter("relief",relief)
	m.set_shader_parameter("tiled",tile)
	mats[key] = m

func room_finishes() -> void:
	var interior := ShaderMaterial.new()
	interior.resource_name = "RoomSpecificPlasterAndTile"
	interior.shader = load("res://shaders/villa_interior.gdshader")
	interior.set_shader_parameter("plaster_texture",load("res://furniture_pack/textures/plaster_detail.png"))
	mats.villa_wall = interior
	finish_material("villa_floor","a78d6d","oak_planks",Vector3(.8333,1,.4167),.73,.0014)
	finish_material("villa_trim","615347","oak_grain",Vector3(1,.7,.7),.72,.0007)
	finish_material("door_wood","8a7258","oak_grain",Vector3(1,.45,1),.66,.001)
	finish_material("villa_ceiling","e6e8e3","plaster_detail",Vector3.ONE*1.2,.94,.00025)
	finish_material("villa_tile","c4cfce","mineral_detail",Vector3.ONE*1.5,.58,.0006,true)
	mats.villa_tile.set_shader_parameter("tile_size",Vector2(.30,.30))
	finish_material("kitchen_floor","c1c3b5","mineral_detail",Vector3.ONE*1.4,.64,.0006,true)
	finish_material("utility_floor","a6b5b6","mineral_detail",Vector3.ONE*2,.72,.0005,true)
	finish_material("study_floor","80674f","oak_planks",Vector3(.8333,1,.4167),.76,.0014)
	finish_material("master_floor","aa9c85","oak_planks",Vector3(.8333,1,.4167),.76,.0014)
	finish_material("bed_a_floor","b3aa9d","oak_planks",Vector3(.8333,1,.4167),.78,.0014)
	finish_material("bed_b_floor","b19878","oak_planks",Vector3(.8333,1,.4167),.75,.0014)
	for key in ["master_floor","bed_a_floor"]:mats[key].set_shader_parameter("rotate_grain",true)

func union_mesh(label: String, boxes: Array, keys: Array, parent: Node, floor_y: float, outside: bool = false, solid: bool = false) -> void:
	var palette: Array = []
	for key in keys:palette.append(mats[key])
	var mesh := Geometry.solid_union(boxes,palette,floor_y,outside)
	var obj := MeshInstance3D.new()
	obj.name = label
	obj.mesh = mesh
	attach(obj,parent)
	if solid:
		var body := StaticBody3D.new()
		attach(body,obj)
		var col := CollisionShape3D.new()
		col.shape = mesh.create_trimesh_shape()
		attach(col,body)

func build() -> Node3D:
	rng.seed = 7041
	root = Node3D.new()
	root.name = "GardenVilla"
	materials()
	# Use recognisable material colours with a neutral texture detail layer.
	surface_material("villa_wall",Color(.90,.89,.86),"plaster",.65,.61,.35)
	surface_material("villa_outer",Color(.87,.855,.81),"plaster",.55,.61,.4)
	surface_material("villa_floor",Color(.72,.59,.44),"wood",.8,.31,2.1,.68)
	surface_material("villa_tile",Color(.79,.82,.80),"bath_tile",.65,.67,1.1,.48)
	surface_material("villa_trim",Color(.38,.29,.20),"wood",1.1,.31,1.1,.72)
	surface_material("villa_ceiling",Color(.95,.95,.93),"plaster",.6,.61,.16)
	material("roof_tile",Color(.27,.29,.30),"",1,0,.84)
	material("roof_edge",Color(.22,.24,.25),"",1,.12,.63)
	material("grass",Color(.32,.43,.22),"",1,0,1)
	material("leaf",Color(.19,.39,.20),"",1,0,.85)
	material("leaf_light",Color(.34,.51,.24),"",1,0,.85)
	mats.leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface_material("path_stone",Color(.69,.67,.61),"plaster",1.8,.61,.5)
	surface_material("concrete",Color(.65,.66,.63),"plaster",1,.61,.45)
	surface_material("sage_paint",Color(.60,.66,.58),"plaster",.8,.61,.5)
	surface_material("door_wood",Color(.52,.38,.25),"wood",.55,.31,1.5,.65)
	material("door_panel",Color(.67,.72,.65),"",1,0,.75)
	material("hardware",Color(.20,.22,.20),"",1,.7,.34)
	material("stone_cap",Color(.67,.65,.58),"",1,0,.88)
	material("bark",Color(.25,.19,.13),"",1,0,.98)
	material("soil",Color(.20,.15,.10),"",1,0,1)
	var masonry := ShaderMaterial.new()
	masonry.shader = load("res://shaders/villa_masonry.gdshader")
	mats.masonry = masonry
	var roof_material := ShaderMaterial.new()
	roof_material.shader = load("res://shaders/villa_roof.gdshader")
	mats.roof_tile = roof_material
	var lawn_material := ShaderMaterial.new()
	lawn_material.shader = load("res://shaders/villa_ground.gdshader")
	mats.grass = lawn_material
	var paving_material := ShaderMaterial.new()
	paving_material.shader = load("res://shaders/villa_paving.gdshader")
	mats.path_stone = paving_material
	mats.glow.albedo_color = Color(1,.94,.83)
	mats.glow.emission = Color(1,.92,.78)
	mats.glow.emission_energy_multiplier = 1.3
	material("window_glass",Color(.45,.63,.68,.12),"",1,.05,.09)
	mats.window_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats.window_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	room_finishes()
	ground_floor = folder("GroundFloor")
	upper_floor = folder("UpperFloor")
	stair_group = folder("Staircase")
	garden = folder("Garden")
	roof_group = folder("Roof")
	light_group = folder("Lighting")
	build_garden()
	build_slabs()
	build_storey(ground_floor,0,false)
	build_storey(upper_floor,3,true)
	build_staircase()
	Basement.build(self)
	build_roof()
	build_exterior_details()
	build_lighting()
	register_plan()
	load("res://scripts/villa_furnishings.gd").new().apply(self)
	build_room_signs()
	root.set_meta("door_count",door_count)
	return root

func room_sign(title: String, x: float, z: float, y: float, yaw: float, parent: Node3D) -> void:
	var sign: Node3D = load("res://furniture_pack/scenes/decor_room_plaque.tscn").instantiate()
	sign.name = "RoomSign_"+title
	sign.position = at(x,y,z)
	sign.rotation.y = deg_to_rad(yaw)
	sign.set("room_title",title)
	attach(sign,parent)

func build_room_signs() -> void:
	# Discreet plaques on fixed jamb-side walls, readable from the corridor.
	for floor_y in [0.0,3.0]:
		var p := ground_floor if floor_y==0 else upper_floor
		room_sign("卫生间",6.61,5.25,floor_y+1.02,-90,p)
		room_sign("洗衣间" if floor_y==0 else "衣帽间",6.61,7.46,floor_y+1.02,-90,p)
		room_sign("工作书房" if floor_y==0 else "电脑房",8.28,8.81,floor_y+1.02,180,p)
		room_sign("厨房" if floor_y==0 else "次卧 A",6.78,3.69,floor_y+1.02,0,p)
	room_sign("主卧",5.29,5.18,4.02,90,upper_floor)
	room_sign("书房",5.29,7.68,4.02,90,upper_floor)

func rect_floor(label: String, x1: float, z1: float, x2: float, z2: float, top: float, thick: float, key: String, parent: Node, solid: bool = true) -> void:
	box(label,at((x1+x2)/2,top-thick/2,(z1+z2)/2),Vector3(x2-x1,thick,z2-z1),key,solid,parent)

func build_slabs() -> void:
	Basement.split_slab(self,"Foundation",Rect2(-.125,-.125,12.25,12.25),0,.25,"villa_floor",ground_floor)
	# Upper floor slab is split around the full staircase opening, not a solid lid.
	rect_floor("UpperSlabNorth",-.125,-.125,12.125,3.6,3,.18,"villa_floor",upper_floor)
	rect_floor("UpperSlabWest",-.125,3.6,9.2,7.5,3,.18,"villa_floor",upper_floor)
	rect_floor("UpperSlabSouth",-.125,7.5,12.125,12.125,3,.18,"villa_floor",upper_floor)
	# White ceiling finishes below the upper slab; retain the staircase opening.
	# Keep them with the upper floor so the ground-floor cutaway stays open.
	rect_floor("GroundCeilingNorth",-.125,-.125,12.125,3.6,2.823,.018,"villa_ceiling",upper_floor,false)
	rect_floor("GroundCeilingWest",-.125,3.6,9.2,7.5,2.823,.018,"villa_ceiling",upper_floor,false)
	rect_floor("GroundCeilingSouth",-.125,7.5,12.125,12.125,2.823,.018,"villa_ceiling",upper_floor,false)
	for floor_y in [0.0,3.0]:
		var parent := ground_floor if floor_y==0 else upper_floor
		rect_floor("WetRoomFloor",6.775,3.675,9.125,6.125,floor_y+.006,.01,"villa_tile",parent,false)
		rect_floor("UtilityFloor",6.775,6.275,9.125,7.425,floor_y+.006,.01,"utility_floor",parent,false)
		if floor_y==0:
			rect_floor("KitchenFinish",5.275,.125,11.875,3.525,.006,.01,"kitchen_floor",parent,false)
	rect_floor("StudyTimber",.125,5.475,5.125,8.925,3.006,.01,"study_floor",upper_floor,false)
	rect_floor("MasterTimber",.125,.125,5.125,5.325,3.006,.01,"master_floor",upper_floor,false)
	rect_floor("BedroomATimber",5.275,.125,11.875,3.525,3.006,.01,"bed_a_floor",upper_floor,false)
	rect_floor("BedroomBTimber",6.775,8.975,11.875,11.875,3.006,.01,"bed_b_floor",upper_floor,false)
	# An uncovered terrace lies over the living room; the reading corner stays indoors.
	rect_floor("TerraceFinish",.08,9.08,3.925,11.925,3.007,.012,"path_stone",upper_floor,false)
	# Upper ceiling follows the L shape, leaving the SW terrace open to the sky.
	rect_floor("CeilingNorth",-.125,-.125,12.125,9.0,6,.18,"villa_ceiling",roof_group)
	rect_floor("CeilingSouthWing",4,9,12.125,12.125,6,.18,"villa_ceiling",roof_group)

func wall_piece(label: String, axis: String, value: float, start: float, finish: float, base_y: float, low: float, high: float, parent: Node, outer: bool) -> void:
	if finish-start<.005 or high-low<.005:return
	var thickness := .25 if outer else .15
	var pos := at((start+finish)/2,base_y+(low+high)/2,value) if axis=="h" else at(value,base_y+(low+high)/2,(start+finish)/2)
	var size := Vector3(finish-start,high-low,thickness) if axis=="h" else Vector3(thickness,high-low,finish-start)
	wall_volumes.append(volume(pos,size))
	if low==0:
		# Fully cover the wall end by 14 mm. No wood/paint faces share a plane.
		var trim_size := Vector3(finish-start+.028,.14,thickness+.036) if axis=="h" else Vector3(thickness+.036,.14,finish-start+.028)
		skirting_volumes.append(volume(Vector3(pos.x,base_y+.073,pos.z),trim_size))
		trim_size.y = .021
		trim_size.x += .012
		trim_size.z += .012
		skirting_volumes.append(volume(Vector3(pos.x,base_y+.1535,pos.z),trim_size))
	if high==WALL_TOP:
		var crown := Vector3(finish-start+.044,.075,thickness+.060) if axis=="h" else Vector3(thickness+.060,.075,finish-start+.044)
		cornice_volumes.append(volume(Vector3(pos.x,base_y+2.7775,pos.z),crown))

func opening(a: float, b: float, kind: String = "door") -> Dictionary:
	return {"a":a,"b":b,"kind":kind}

func wall(label: String, axis: String, value: float, start: float, finish: float, base_y: float, holes: Array, parent: Node, outer: bool = false) -> void:
	var cursor := start
	for hole in holes:
		wall_piece(label,axis,value,cursor,hole.a,base_y,0,WALL_TOP,parent,outer)
		var window: bool = hole.kind=="window"
		var sill := .75 if window else 0.0
		# A working kitchen counter is 0.90 m high; its window sill sits above it.
		if window and label=="GroundNorth" and hole.a>7:sill = 1.08
		var lintel := 2.25 if window else 2.20
		if window:wall_piece(label+"_SillWall",axis,value,hole.a,hole.b,base_y,0,sill,parent,outer)
		wall_piece(label+"_Header",axis,value,hole.a,hole.b,base_y,lintel,WALL_TOP,parent,outer)
		if hole.kind!="arch":frames(label,axis,value,hole.a,hole.b,base_y,sill,lintel,parent,window,.25 if outer else .15)
		if hole.kind in ["door","french"]:doorway(label,axis,value,hole.a,hole.b,base_y,parent,hole.kind=="french")
		cursor = hole.b
	wall_piece(label,axis,value,cursor,finish,base_y,0,WALL_TOP,parent,outer)

func frames(label: String, axis: String, value: float, a: float, b: float, y: float, sill: float, head_y: float, parent: Node, glass: bool, wall_depth: float) -> void:
	var height := head_y-sill
	for edge in [a,b]:
		var pos := at(edge,y+sill+height/2,value) if axis=="h" else at(value,y+sill+height/2,edge)
		var size := Vector3(.055,height,.29) if axis=="h" else Vector3(.29,height,.055)
		box(label+"_Jamb",pos,size,"villa_trim",false,parent)
	for h in [head_y,sill] if glass else [head_y]:
		var pos := at((a+b)/2,y+h,value) if axis=="h" else at(value,y+h,(a+b)/2)
		var size := Vector3(b-a+.05,.055,.29) if axis=="h" else Vector3(.29,.055,b-a+.05)
		box(label+"_Trim",pos,size,"villa_trim",false,parent)
	# Projecting architraves sit clear of the plaster, with a second raised edge.
	for side in [-1,1]:
		var offset: float = side*(wall_depth*.5+.022)
		for edge in [a-.052,b+.052]:
			var p := at(edge,y+sill+height/2,value+offset) if axis=="h" else at(value+offset,y+sill+height/2,edge)
			var s := Vector3(.065,height+.13,.036) if axis=="h" else Vector3(.036,height+.13,.065)
			box(label+"_Architrave",p,s,"villa_trim",false,parent)
		var p := at((a+b)/2,y+head_y+.055,value+offset) if axis=="h" else at(value+offset,y+head_y+.055,(a+b)/2)
		var s := Vector3(b-a+.17,.075,.04) if axis=="h" else Vector3(.04,.075,b-a+.17)
		box(label+"_ArchitraveHead",p,s,"villa_trim",false,parent)
	if not glass:return
	var pos := at((a+b)/2,y+(sill+head_y)/2,value)
	var size := Vector3(b-a-.055,height-.055,.016)
	if axis=="v":
		pos = at(value,y+(sill+head_y)/2,(a+b)/2)
		size = Vector3(.016,height-.055,b-a-.055)
	box(label+"_Glass",pos,size,"window_glass",true,parent)
	var divisions := maxi(1,int((b-a)/1.1))
	for i in range(1,divisions+1):
		var edge: float = lerpf(a,b,float(i)/(divisions+1))
		pos = at(edge,y+(sill+head_y)/2,value) if axis=="h" else at(value,y+(sill+head_y)/2,edge)
		size = Vector3(.038,height,.04) if axis=="h" else Vector3(.04,height,.038)
		box(label+"_Mullion",pos,size,"villa_trim",false,parent)
	var sill_pos := at((a+b)/2,y+sill-.025,value) if axis=="h" else at(value,y+sill-.025,(a+b)/2)
	var sill_size := Vector3(b-a+.12,.065,.40) if axis=="h" else Vector3(.40,.065,b-a+.12)
	box(label+"_WindowSill",sill_pos,sill_size,"villa_trim",true,parent)
	var latch := at(a+.12,y+1.30,value-.035) if axis=="h" else at(value-.035,y+1.30,a+.12)
	box(label+"_WindowLatch",latch,Vector3(.025,.12,.025),"hardware",false,parent)

func doorway(label: String, axis: String, value: float, a: float, b: float, y: float, parent: Node, glazed: bool) -> void:
	var title := "房门"
	var angle := 100.0
	if label.contains("WetWest"):
		title = "卫生间门" if a<5 else "衣帽间门" if y>1 else "洗衣间门"
	elif label.contains("GuestNorth"):
		title = "电脑房门" if y>1 else "工作书房门"
		angle = -100
	elif label.contains("KitchenOrBed"):title = "次卧门" if y>1 else "厨房门"
	elif label.contains("WestPartition"):
		title = "厨房门" if y<1 else "主卧门" if a<5 else "书房门"
		angle = -100
	elif label.contains("Terrace"):
		title = "露台门"
		angle = -100
	elif label.ends_with("North"):
		title = "花园门"
		angle = -100
	elif label.ends_with("South"):title = "入户门"
	elif label.ends_with("East"):
		title = "厨房侧门"
		angle = -100
	var width := b-a-.085
	var pieces := 2 if width>1.25 else 1
	for part in range(pieces):
		var right_hinge := pieces==2 and part==1
		var hinge := b-.038 if right_hinge else a+.038
		var door := Node3D.new()
		door.name = "Door_%02d" % door_count
		door.position = at(hinge,y,value) if axis=="h" else at(value,y,hinge)
		door.rotation.y = (0.0 if axis=="h" else -PI/2)+(PI if right_hinge else 0.0)
		door.set_script(load("res://scripts/villa_door.gd"))
		door.set("door_title",title)
		door.set("leaf_width",width/pieces)
		door.set("open_angle",-angle if right_hinge else angle)
		# Common circulation and work spaces are open on arrival; private rooms stay closed.
		door.set("starts_open",title in ["厨房门","书房门","衣帽间门","洗衣间门","露台门"])
		attach(door,parent)
		door_count += 1
		var leaf := AnimatableBody3D.new()
		leaf.name = "Leaf"
		leaf.collision_layer = 1
		leaf.collision_mask = 2
		attach(leaf,door)
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = Vector3(width/pieces,2.13,.055)
		col.shape = shape
		col.position = Vector3(width/pieces/2,1.10,0)
		attach(col,leaf)
		var w := width/pieces
		if glazed:
			for x in [.055,w-.055]:box("DoorStile",Vector3(x,1.1,0),Vector3(.11,2.13,.058),"door_wood",false,leaf)
			for h in [.09,.45,1.27,2.11]:box("DoorRail",Vector3(w/2,h,0),Vector3(w-.22,.09,.058),"door_wood",false,leaf)
			box("DoorGlazing",Vector3(w/2,1.28,0),Vector3(w-.22,1.56,.014),"window_glass",false,leaf)
			box("DoorKickPanel",Vector3(w/2,.28,0),Vector3(w-.22,.25,.035),"door_wood",false,leaf)
		else:
			box("DoorLeaf",Vector3(w/2,1.10,0),Vector3(w,2.13,.055),"door_wood",false,leaf)
			for side in [-1,1]:
				for h in [.55,1.55]:
					box("InsetPanel",Vector3(w/2,h,side*.031),Vector3(w-.20,.78,.012),"door_panel",false,leaf)
					for x in [.10,w-.10]:box("PanelBead",Vector3(x,h,side*.040),Vector3(.022,.81,.018),"villa_trim",false,leaf)
					for edge in [h-.40,h+.40]:box("PanelBead",Vector3(w/2,edge,side*.040),Vector3(w-.18,.022,.018),"villa_trim",false,leaf)
		for side in [-1,1]:
			box("HandlePlate",Vector3(w-.12,1.02,side*.046),Vector3(.055,.17,.025),"hardware",false,leaf)
			rod(Vector3(w-.12,1.04,side*.06),Vector3(w-.12,1.04,side*.11),.016,"hardware",leaf)
			rod(Vector3(w-.12,1.04,side*.11),Vector3(w-.24,1.04,side*.11),.018,"hardware",leaf)
		for h in [.25,1.10,1.95]:cylinder(Vector3(.015,h,.025),.018,.10,"hardware",-1,leaf)

func build_storey(parent: Node3D, y: float, upper: bool) -> void:
	wall_volumes = []
	skirting_volumes = []
	cornice_volumes = []
	var prefix := "Upper" if upper else "Ground"
	if not upper:
		wall(prefix+"North","h",0,0,12,y,[opening(1.4,3.8,"french"),opening(7.2,9.8,"window")],parent,true)
		wall(prefix+"South","h",12,0,12,y,[opening(1.0,4.1,"window"),opening(5.45,6.45),opening(8,10.8,"window")],parent,true)
		wall(prefix+"West","v",0,0,12,y,[opening(1,3,"window"),opening(5.7,8.7,"window")],parent,true)
		wall(prefix+"East","v",12,0,12,y,[opening(1.3,2.3),opening(2.65,3.25,"window"),opening(9.7,11.3,"window")],parent,true)
		wall("Ground_WestPartition","v",5.2,0,3.6,y,[opening(1.2,3.0,"french")],parent)
		wall("Ground_WestPartition","v",5.2,3.6,12,y,[opening(6.0,7.5,"arch"),opening(10.1,11.5,"arch")],parent)
	else:
		wall(prefix+"North","h",0,0,12,y,[opening(.9,3.7,"window"),opening(6.7,10.4,"window")],parent,true)
		wall(prefix+"South","h",12,4,12,y,[opening(4.3,6,"window"),opening(8,10.8,"window")],parent,true)
		wall(prefix+"West","v",0,0,9,y,[opening(1,3.8,"window"),opening(6,8.3,"window")],parent,true)
		wall(prefix+"East","v",12,0,12,y,[opening(1.1,2.8,"window"),opening(9.7,11.3,"window")],parent,true)
		wall(prefix+"WestPartition","v",5.2,0,9,y,[opening(4.0,4.95),opening(6.5,7.4)],parent)
		wall(prefix+"StudyDivide","h",5.4,0,5.2,y,[],parent)
		wall(prefix+"TerraceNorth","h",9,0,4,y,[opening(1.6,3.1,"french")],parent)
		wall(prefix+"TerraceEast","v",4,9,12,y,[opening(10.15,11.35,"french")],parent)
		rail("TerraceWest",at(.08,y,9.04),at(.08,y,11.96),1.08,parent)
		rail("TerraceSouth",at(.08,y,11.96),at(3.93,y,11.96),1.08,parent)
	wall(prefix+"KitchenOrBed","h",3.6,5.2,12,y,[opening(5.45,6.45)],parent)
	wall(prefix+"WetWest","v",6.7,3.6,7.5,y,[opening(4.05,4.95),opening(6.35,7.25)],parent)
	wall(prefix+"WetEast","v",9.2,3.6,7.5,y,[],parent)
	wall(prefix+"UtilityDivide","h",6.2,6.7,9.2,y,[],parent)
	wall(prefix+"StairEntrance","h",7.5,6.7,12,y,[opening(10.65,11.75,"arch")] if upper else [opening(9.45,10.55,"arch"),opening(10.65,11.75,"arch")],parent)
	wall(prefix+"GuestWest","v",6.7,8.9,12,y,[],parent)
	wall(prefix+"GuestNorth","h",8.9,6.7,12,y,[opening(7.1,8.0)],parent)
	union_mesh(prefix+"Walls",wall_volumes,["villa_wall","villa_outer"],parent,y,true,true)
	union_mesh(prefix+"Skirting",skirting_volumes,["villa_trim"],parent,y)
	union_mesh(prefix+"Cornice",cornice_volumes,["villa_ceiling"],parent,y)
	# Omit the identical dado stripe that previously made every room look alike.

func rail(label: String, a: Vector3, b: Vector3, height: float, parent: Node) -> void:
	var length := a.distance_to(b)
	var count := int(ceil(length/.42))
	for i in range(count+1):
		var pos := a.lerp(b,float(i)/count)
		box(label+"_Baluster",pos+Vector3.UP*(height/2),Vector3(.045,height,.045),"roof_edge",false,parent)
	rod(a+Vector3.UP*height,b+Vector3.UP*height,.038,"roof_edge",parent)
	# A continuous transparent collision keeps the cat inside the railing.
	var midpoint := (a+b)/2+Vector3.UP*(height/2)
	var body := StaticBody3D.new()
	body.name = label+"_GuardCollision"
	body.position = midpoint
	attach(body,parent)
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(.06,height,length+.04) if absf(a.x-b.x)<.01 else Vector3(length+.04,height,.06)
	shape.shape = bounds
	attach(shape,body)

func stair_collision(label: String, pos: Vector3, size: Vector3, parent: Node) -> void:
	# Collision remains as individual boxes; only the render mesh is welded.
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	attach(body,parent)
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	shape.shape = bounds
	attach(shape,body)

func build_staircase() -> void:
	# Eighteen true risers, nine per flight. Actual step collisions are retained.
	var riser := STOREY/18.0
	var depth := 2.55/9
	var surfaces: Array = []
	for i in range(9):
		var h := (i+1)*riser
		var z := 7.5-depth*(i+.5)
		stair_collision("WestFlightStep%02d" % (i+1),at(10.0,h/2,z),Vector3(1.1,h,depth+.008),stair_group)
		# Abutting visual volumes have no overlapping side strips.
		surfaces.append(volume(at(10.0,h/2,z),Vector3(1.1,h,depth)))
		# A recessed top and projecting front expose only the vertical nosing.
		box("WestNosing",at(10.0,h-.022,z+depth/2+.001),Vector3(1.12,.036,.016),"villa_trim",false,stair_group)
	# The half landing bridges both flights at 1.5 m, with its underside unobstructed.
	stair_collision("HalfLanding",at(10.60,1.42,4.395),Vector3(2.30,.16,1.11),stair_group)
	surfaces.append(volume(at(10.60,1.42,4.395),Vector3(2.30,.16,1.11)))
	for i in range(9):
		var h := 1.5+(i+1)*riser
		var z := 4.95+depth*(i+.5)
		stair_collision("EastFlightStep%02d" % (i+10),at(11.2,h-.08,z),Vector3(1.1,.16,depth+.008),stair_group)
		surfaces.append(volume(at(11.2,h-.08,z),Vector3(1.1,.16,depth)))
		box("EastRiser",at(11.2,h-riser/2-.004,z-depth/2-.002),Vector3(1.096,riser-.008,.018),"villa_trim",false,stair_group)
		box("EastNosing",at(11.2,h-.022,z-depth/2-.004),Vector3(1.12,.036,.018),"villa_trim",false,stair_group)
	# Union removes hidden/coplanar landing faces; the final tread ends at the slab edge.
	union_mesh("StairTreadsAndLanding",surfaces,["villa_floor"],stair_group,0)
	# Slim inner handrails preserve the walkable 1.10 m flights.
	rod(at(10.56,.96,7.38),at(10.56,2.43,4.99),.028,"roof_edge",stair_group)
	rod(at(10.64,2.43,4.99),at(10.64,3.90,7.38),.028,"roof_edge",stair_group)
	for i in range(5):
		var t := float(i)/4
		var z: float = lerpf(7.38,4.99,t)
		var y: float = lerpf(.16,1.5,t)
		rod(at(10.56,y,z),at(10.56,y+.86,z),.015,"roof_edge",stair_group)
		rod(at(10.64,3-y,z),at(10.64,3-y+.86,z),.015,"roof_edge",stair_group)

func custom_mesh(label: String, triangles: Array[Vector3], key: String, parent: Node, solid: bool = true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in triangles:st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var obj := mesh_obj(mesh,Vector3.ZERO,key,parent)
	obj.name = label
	if solid:
		var body := StaticBody3D.new()
		attach(body,obj)
		var col := CollisionShape3D.new()
		col.shape = mesh.create_trimesh_shape()
		attach(col,body)
	return obj

func build_roof() -> void:
	var nw := at(-.28,6.12,-.28)
	var ne := at(12.28,6.12,-.28)
	var sw := at(-.28,6.12,9.18)
	var se := at(12.28,6.12,9.18)
	var rn := at(6,7.48,-.28)
	var rs := at(6,7.48,9.18)
	custom_mesh("MainGabledRoof",[nw,sw,rs,nw,rs,rn,rn,rs,se,rn,se,ne],"roof_tile",roof_group)
	custom_mesh("NorthGable",[nw,rn,ne],"villa_outer",roof_group)
	custom_mesh("SouthGable",[sw,se,rs],"villa_outer",roof_group)
	for pair in [[nw,sw],[ne,se],[rn,rs],[nw,rn],[rn,ne],[sw,rs],[rs,se]]:
		rod(pair[0],pair[1],.045,"roof_edge",roof_group)
	for i in range(27):
		var x := -.28+i*(12.56/26)
		var h := 6.13+1.36*(1.0-absf(x-6)/6.28)
		rod(at(x,h,-.28),at(x,h,9.18),.012,"roof_edge",roof_group)
	var a := at(3.94,6.48,8.95)
	var b := at(12.28,6.48,8.95)
	var c := at(3.94,6.12,12.28)
	var d := at(12.28,6.12,12.28)
	custom_mesh("SouthWingRoof",[a,c,d,a,d,b],"roof_tile",roof_group)
	for pair in [[a,c],[c,d],[d,b]]:rod(pair[0],pair[1],.055,"roof_edge",roof_group)
	for i in range(18):
		var x := 3.94+i*(8.34/17)
		rod(at(x,6.49,8.95),at(x,6.13,12.28),.012,"roof_edge",roof_group)
	for i in range(27):
		box("RidgeCap",at(6,7.50,-.20+i*.35),Vector3(.20,.07,.33),"roof_edge",false,roof_group)

func build_exterior_details() -> void:
	# Raised stone plinth, with actual clear gaps at external doors.
	for x in [-.15,12.15]:
		var spans := [[0,12]] if x<0 else [[0,1.26],[2.34,12]]
		for s in spans:box("StonePlinth",at(x,.21,(s[0]+s[1])/2),Vector3(.065,.42,s[1]-s[0]),"masonry",false,ground_floor)
	for z in [-.15,12.15]:
		var spans := [[-.18,1.35],[3.85,12.18]] if z<0 else [[-.18,5.40],[6.50,12.18]]
		for s in spans:box("StonePlinth",at((s[0]+s[1])/2,.21,z),Vector3(s[1]-s[0],.42,.065),"masonry",false,ground_floor)
	# The slab edge is covered by a fascia; cornices finish the eaves below the roof.
	for y in [2.91,5.91]:
		var parent := upper_floor if y<4 else roof_group
		for x in [-.16,12.16]:
			var length := 9.0 if y>4 and x<0 else 12.24
			box("Fascia",at(x,y,length/2-.12),Vector3(.10,.14,length),"villa_ceiling",false,parent)
		box("NorthFascia",at(6,y,-.16),Vector3(12.40,.14,.10),"villa_ceiling",false,parent)
		box("SouthFascia",at(6 if y<4 else 8.04,y,12.16),Vector3(12.4 if y<4 else 8.3,.14,.10),"villa_ceiling",false,parent)
	for x in [-.26,12.26]:
		rod(at(x,6.10,-.28),at(x,6.10,9.25),.055,"roof_edge",roof_group)
		for z in [.25,8.65]:
			rod(at(x,6.05,z),at(x,.18,z),.038,"roof_edge",ground_floor)
			for y in [.5,2.3,4.1,5.8]:box("DownpipeBracket",at(x,y,z),Vector3(.10,.035,.09),"hardware",false,ground_floor)
	# A small timber entrance canopy and a stone threshold articulate the main door.
	for x in [5.02,6.88]:
		box("PorchPost",at(x,1.13,12.96),Vector3(.13,2.26,.13),"villa_trim",true,ground_floor)
		box("PostFoot",at(x,.11,12.96),Vector3(.19,.22,.19),"masonry",true,ground_floor)
	box("CanopyBeam",at(5.95,2.30,12.96),Vector3(2.12,.17,.16),"villa_trim",false,ground_floor)
	box("PorchCanopy",at(5.95,2.46,12.55),Vector3(2.25,.12,1.27),"roof_edge",false,ground_floor)
	for x in [5.08,5.65,6.25,6.82]:box("CanopyRafter",at(x,2.36,12.56),Vector3(.065,.12,1.18),"villa_trim",false,ground_floor)
	box("EntranceThreshold",at(5.95,-.02,12.52),Vector3(2.2,.08,1.15),"path_stone",true,ground_floor)
	for x in [5.04,6.86]:
		box("PorchSconce",at(x,1.72,12.21),Vector3(.12,.26,.13),"hardware",false,ground_floor)
		box("PorchLampGlass",at(x,1.72,12.28),Vector3(.08,.18,.025),"glow",false,ground_floor)
	plaque("07",at(6.85,2.06,12.20),0,52,Color(.25,.29,.25))

func garden_strip(a: Vector2, b: Vector2, width: float) -> void:
	var p := box("GardenPath",Vector3((a.x+b.x)/2-11,-.017,(a.y+b.y)/2-16),Vector3(width,.045,a.distance_to(b)),"path_stone",true,garden)
	p.rotation.y = atan2(b.x-a.x,b.y-a.y)

func garden_loop(points: Array[Vector2], width: float) -> void:
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in range(points.size()):
		var incoming := (points[i]-points[(i+points.size()-1)%points.size()]).normalized()
		var outgoing := (points[(i+1)%points.size()]-points[i]).normalized()
		var n1 := Vector2(-incoming.y,incoming.x)
		var n2 := Vector2(-outgoing.y,outgoing.x)
		var bisector := (n1+n2).normalized()
		var offset := bisector*(width*.5/maxf(.3,bisector.dot(n1)))
		left.append(Vector3(points[i].x+offset.x-11,-.012,points[i].y+offset.y-16))
		right.append(Vector3(points[i].x-offset.x-11,-.012,points[i].y-offset.y-16))
	var triangles: Array[Vector3] = []
	for i in range(points.size()):
		var j := (i+1)%points.size()
		triangles.append_array([left[i],right[i],right[j],left[i],right[j],left[j]])
	custom_mesh("ContinuousGardenPath",triangles,"path_stone",garden,true)

func build_garden() -> void:
	Basement.split_slab(self,"PlotGround",Rect2(-5,-10,22,28),-.04,.18,"grass",garden)
	Basement.split_slab(self,"DistantGround",Rect2(-44,-46,100,100),-.18,.12,"grass",garden,false)
	var walk: Array[Vector2] = [Vector2(3,25),Vector2(3,5.8),Vector2(5.6,3.2),Vector2(14.8,3.2),Vector2(19.2,5.8),Vector2(19.2,24.5),Vector2(12,25.2)]
	garden_loop(walk,1.15)
	garden_strip(Vector2(11,22),Vector2(11,28),1.6)
	box("GardenTerrace",Vector3(0,-.028,-7),Vector3(12,.05,2),"villa_floor",true,garden)
	box("FrontParkingPad",Vector3(7.95,-.028,9.15),Vector3(3.1,.05,5.1),"path_stone",true,garden)
	# The first map is enclosed by a stone perimeter; no neighbouring district yet.
	for x in [-11.0,11.0]:
		box("GardenBoundary",Vector3(x,.82,-2),Vector3(.18,1.72,28),"masonry",true,garden)
		box("BoundaryCap",Vector3(x,1.71,-2),Vector3(.26,.09,28.22),"stone_cap",false,garden)
	for z in [-16.0,12.0]:
		box("GardenBoundary",Vector3(0,.82,z),Vector3(21.82,1.72,.18),"masonry",true,garden)
		box("BoundaryCap",Vector3(0,1.71,z),Vector3(21.74,.09,.26),"stone_cap",false,garden)
	box("PedestrianGate",Vector3(0,.84,11.89),Vector3(2,1.72,.08),"villa_trim",true,garden)
	box("DriveGate",Vector3(7.95,.84,11.89),Vector3(3.5,1.72,.08),"villa_trim",true,garden)
	var tree_index := 0
	for info in [[3.3,3.2,1.05],[18.8,2.9,1.0],[2.0,17.0,.83],[20.0,16.0,.92]]:
		Foliage.tree(self,Vector3(info[0]-11,-.04,info[1]-16),info[2],381+tree_index)
		tree_index += 1
	for info in [[7.0,1.0,7.5,.85],[.8,8.5,.9,4.4],[20.4,9.1,.85,3.8]]:
		box("PlantingBorder",Vector3(info[0]+info[2]/2-11,.045,info[1]+info[3]/2-16),Vector3(info[2],.16,info[3]),"terra",true,garden)
		var center := Vector3(info[0]+info[2]/2-11,.15,info[1]+info[3]/2-16)
		box("PlantingSoil",center-Vector3.UP*.015,Vector3(info[2]-.10,.03,info[3]-.10),"soil",false,garden)
		Foliage.grasses(self,center,info[2]-.16,info[3]-.16,int(info[0]*31+100),garden)

func build_lighting() -> void:
	var world := WorldEnvironment.new()
	world.name = "VillaEnvironment"
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(.36,.59,.83)
	sky_mat.sky_horizon_color = Color(.55,.70,.81)
	sky_mat.ground_bottom_color = Color(.26,.30,.24)
	sky_mat.ground_horizon_color = Color(.43,.50,.38)
	sky_mat.sky_curve = .15
	sky_mat.ground_curve = .15
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(.96,.98,1)
	e.ambient_light_energy = .23
	e.ambient_light_sky_contribution = 0.0
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	e.ssao_enabled = true
	e.ssao_radius = .3
	e.ssao_intensity = .90
	e.ssao_light_affect = .15
	e.ssil_enabled = false
	e.fog_enabled = false
	e.volumetric_fog_enabled = false
	e.glow_enabled = false
	world.environment = e
	attach(world,light_group)
	var sun := DirectionalLight3D.new()
	sun.name = "DaylightSun"
	sun.rotation_degrees = Vector3(-48,-38,0)
	sun.light_color = Color(1,.98,.95)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	attach(sun,light_group)
	for floor_y in [0.0,3.0]:
		for room in [[2.6,2.0,5.8],[2.6,7.8,6.5],[8.1,1.8,5.8],[7.9,4.9,3.0],[7.9,6.9,2.4],[8.6,10.3,4.6],[5.95,7.8,4.2]]:
			if floor_y==3 and room[0]==2.6 and room[1]>5:room = [2.6,7.0,4.3]
			var pos := at(room[0],floor_y+2.63,room[1])
			var lamp := OmniLight3D.new()
			lamp.name = "SoftWhiteCeilingLight"
			lamp.position = pos-Vector3.UP*.09
			lamp.light_color = Color(1,.98,.94)
			lamp.light_energy = .48
			lamp.omni_range = room[2]
			lamp.shadow_enabled = true
			lamp.omni_attenuation = 1.0
			attach(lamp,light_group)
			var rim := cylinder(pos,.14,.04,"brass",-1,ground_floor if floor_y==0 else upper_floor)
			var diffuser := cylinder(pos-Vector3.UP*.025,.12,.012,"glow",-1,ground_floor if floor_y==0 else upper_floor)
			# The fixture surrounds its own point light: do not project a large disc onto the ceiling.
			rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			diffuser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var probe := ReflectionProbe.new()
		probe.name = "InteriorReflection_"+str(int(floor_y/3))
		probe.position = at(6,floor_y+1.40,6)
		probe.size = Vector3(11.8,2.75,11.8)
		probe.interior = true
		probe.box_projection = true
		probe.intensity = .65
		probe.max_distance = 16
		attach(probe,light_group)
	# Light the staircase separately so the landing remains legible from cat height.
	var landing_light := OmniLight3D.new()
	landing_light.position = at(10.6,4.8,4.5)
	landing_light.light_color = Color(1,.96,.87)
	landing_light.light_energy = .80
	landing_light.omni_range = 4.2
	landing_light.shadow_enabled = true
	attach(landing_light,light_group)
	var stair_light := OmniLight3D.new()
	stair_light.name = "StairWallLight"
	stair_light.position = at(9.36,1.85,6.35)
	stair_light.light_color = Color(1,.94,.83)
	stair_light.light_energy = .70
	stair_light.omni_range = 3.6
	stair_light.shadow_enabled = true
	attach(stair_light,light_group)
	box("StairSconce",at(9.31,1.85,6.35),Vector3(.065,.30,.17),"brass",false,stair_group)
	box("StairSconceGlow",at(9.35,1.85,6.35),Vector3(.02,.22,.12),"glow",false,stair_group)

func zone(name: String, floor_index: int, a: float, b: float, c: float, d: float) -> Dictionary:
	return {"name":name,"floor":floor_index,"bounds":Rect2(a,b,c-a,d-b)}

func register_plan() -> void:
	root.set_meta("plan_version","V1")
	root.set_meta("site_size",Vector2(22,28))
	root.set_meta("building_size",Vector2(12,12))
	root.set_meta("room_zones",[
		zone("客厅",0,0,4.4,5.2,12),zone("餐厅",0,0,0,5.2,4.4),zone("厨房",0,5.2,0,12,3.6),
		zone("卫生间",0,6.7,3.6,9.2,6.2),zone("洗衣间",0,6.7,6.2,9.2,7.5),zone("工作书房",0,6.7,8.9,12,12),
		zone("主卧",1,0,0,5.2,5.4),zone("次卧 A",1,5.2,0,12,3.6),zone("书房",1,0,5.4,5.2,9),
		zone("露台",1,0,9,4,12),zone("阅读角",1,4,9,6.7,12),
		zone("卫生间",1,6.7,3.6,9.2,6.2),zone("衣帽储物",1,6.7,6.2,9.2,7.5),zone("电脑房",1,6.7,8.9,12,12),
		zone("地下室平台",-1,9.4,2.4,11.82,4.0)
	])
