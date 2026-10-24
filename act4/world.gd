extends "res://act3/world.gd"
const Art = preload("res://furniture_pack/quest_props/refined_props.gd")
const Rodent = preload("res://act4/rodent_actor.gd")
const Spray = preload("res://act4/shower_spray.gd")
var mouse_actor
var mole_actor
var valve_wheel: Node3D
var bed: Node3D
var wardrobe: Node3D
var shower: Node3D
var study_desk: Node3D
var hands: Array[Node3D] = []
var plants: Array = []
var plant_homes: Array = []
var plant_originals: Array = []
var plant_art: Array = []
var plant_pot_materials: Array = []
var terrace_bench: Node3D
var leaf: Node3D
var door_body: AnimatableBody3D
var bolts: Array = []
var tiles: Array = []
var holes: Array[Vector3] = []
var rat_path: Array[Vector3] = []
const PLANT_NAMES := ["蕨叶","白菊","迷迭香"]
func target4(id: String, pos: Vector3, title_: String, days_: Array) -> Node3D:
	var n := item(id,pos)
	Props.days(n,days_)
	n.set_meta("title",title_)
	sign_at(n,title_,Vector3(0,.15,0),20)
	return n
func textured(parent: Node3D, name_: String, pos: Vector3, size_: Vector2, path: String, vertical := false) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size_
	var m := mat(Color.WHITE)
	m.albedo_texture = load(path)
	m.roughness = .8
	var n := Art.mesh_node(parent,name_,plane,m,pos)
	if vertical:n.rotation.x = PI/2
	return n
func grain(key: String, color: Color) -> StandardMaterial3D:
	var m := Art.material(key,color,.86)
	var noise := FastNoiseLite.new()
	noise.frequency = .13
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.noise = noise
	var gradient := Gradient.new()
	gradient.set_color(0,color.darkened(.28))
	gradient.set_color(1,color.lightened(.17))
	tex.color_ramp = gradient
	m.albedo_color = Color.WHITE
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE*18
	return m
func build(parent: Node3D, game: Node) -> void:
	root = parent
	bed = upstairs_furniture(game,"bed","MasterBedroom")
	wardrobe = upstairs_furniture(game,"wardrobe","MasterBedroom")
	shower = upstairs_furniture(game,"decor_shower","Bathroom")
	study_desk = upstairs_furniture(game,"desk","Study")
	for furniture_ in game.get_tree().get_nodes_in_group("placed_furniture"):
		if furniture_.get_meta("asset_id","")=="garden_bench" and furniture_.get_meta("placement_room","")=="Terrace" and furniture_.global_position.x> -5:terrace_bench=furniture_
	assert(bed and wardrobe and shower and study_desk)
	var bag := target4("food",wardrobe.to_global(Vector3(.50,2.172,.20)),"新封口的特制猫粮",[8])
	Props.bind(bag,wardrobe)
	foil_pouch(bag)
	for y in [.008,.158,.165]:Art.rod(bag,"SealedCrimp",Vector3(-.068,y,.004),Vector3(.068,y,.004),.0015,Art.material("crimp",Color("70604a"),.56))
	var tracks := target4("tracks",wardrobe.to_global(Vector3(0,2.171,0)),"柜顶的浮灰与猫爪印",[8])
	var dust := textured(tracks,"UndisturbedDust",Vector3.ZERO,Vector2(1.28,.52),"res://act4/textures/dust.svg")
	dust.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracks.rotation.y = -PI/2
	for i in range(5):
		var p := Vector3(-.4+i*.15,.002,.05+(.06 if i%2==0 else -.06))
		Art.ellipsoid(tracks,"PawPad",p,Vector3(.027,.001,.022),Art.material("dust_track",Color("766e5c"),.95))
		for j in range(3):Art.ellipsoid(tracks,"ToePrint",p+Vector3((j-1)*.012,0,-.019),Vector3(.009,.001,.012),Art.material("dust_track",Color("766e5c"),.95))
	var mattress := target4("bed",bed.to_global(Vector3(0,.592,0)),"床垫 · 连续跳三次蓄力",[8])
	Props.bind(mattress,bed)
	var valve := target4("valve",shower.to_global(Vector3(.12,.94,-.31)),"淋浴旋钮 · 调整水温",[8])
	Props.bind(valve,shower)
	valve.set_meta("hidden_temperature_scale",true)
	var wheel := cylinder(valve,Vector3.ZERO,.045,.018,Color("b6bcb4"))
	wheel.rotation.x = PI/2
	valve_wheel = Node3D.new();valve.add_child(valve_wheel)
	Art.rod(valve_wheel,"TemperaturePointer",Vector3(0,.018,.016),Vector3(0,.041,.016),.0022,Art.material("pointer",Color("3c544c"),.4))
	for i in range(23):
		var a := deg_to_rad(-140+i*280.0/22)
		Art.rod(valve,"CoveredTick",Vector3(sin(a)*.052,cos(a)*.052,.015),Vector3(sin(a)*.058,cos(a)*.058,.015),.0008,Art.material("covered_ticks",Color("69726a"),.8))
		if i%2==0:Art.ellipsoid(valve,"OpaqueCalcium",Vector3(sin(a)*.060,cos(a)*.060,.017),Vector3(.022,.013,.003),grain("chalk_limescale",Color("d0c6aa")))
	var wash := target4("wash",shower.to_global(Vector3(0,.057,.12)),"淋浴底盘 · E 试水并洗澡",[8])
	Props.bind(wash,shower)
	var limescale := target4("limescale",shower.to_global(Vector3(0,1.15,-.372)),"水垢 · 温度数字被遮住了",[8])
	for i in range(4):
		var ring := cylinder(limescale,Vector3(0,(i-1)*.035,0),.016,.002,Color("e1d6b5") if i==1 else Color("a5aba2"))
	var water := Spray.new()
	water.name = "ShowerSpray"
	root.add_child(water)
	water.global_transform = shower.global_transform
	items["water"] = water
	var clock := target4("clock",Vector3(-5.86,4.50,2.65),"书房时钟 · 三根指针",[8,9,10,11])
	clock.rotation.y = PI/2
	var rim := cylinder(clock,Vector3.ZERO,.22,.055,Color("a68a50"))
	rim.rotation.x = PI/2
	var dial:=textured(clock,"Dial",Vector3(0,0,.03),Vector2(.405,.405),"res://act4/textures/clock_face.svg",true)
	dial.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	dial.material_override.alpha_scissor_threshold=.5
	for i in range(3):
		var pivot := Node3D.new()
		clock.add_child(pivot)
		Art.rod(pivot,"ClockHand",Vector3(0,0,.035+i*.003),Vector3(0,[.105,.16,.18][i],.035+i*.003),[.004,.003,.0015][i],Art.material("hand%d"%i,Color("aa543b") if i==2 else Color("263f3c")))
		hands.append(pivot)
	var study_case := upstairs_furniture(game,"bookcase","Study")
	var side_table := upstairs_furniture(game,"decor_side_table","Study")
	var clue_positions := [study_desk.to_global(Vector3(-.38,.790,.19)),study_case.to_global(Vector3(.22,.018,.42)),side_table.to_global(Vector3(.12,.540,.14))]
	for i in range(3):
		var clue := target4(["clock_clue","clock_minute_clue","clock_second_clue"][i],clue_positions[i],["时针纸条 · 书桌","分针纸条 · 书柜脚边","秒针纸条 · 阅读小桌"][i],[8])
		textured(clue,"SeparateTimeClue",Vector3(0,.001,0),Vector2(.17,.12),"res://furniture_pack/quest_props/clock_%s_note.svg"%["hour","minute","second"][i])
	var painting := target4("painting",Vector3(-5.43,4.32,3.08),"墙上的植物画",[9])
	var frame := box(painting,"OakFrame",Vector3.ZERO,Vector3(.68,.43,.025),Color("8b7049"))
	frame.material_override = load("res://furniture_pack/materials/oak.tres")
	textured(painting,"BotanicalPrint",Vector3(0,0,.016),Vector2(.62,.375),"res://act4/textures/botanical_order.png",true)
	for i in range(3):
		var source := upstairs_furniture(game,"decor_plant",["Terrace","Reading","MasterBedroom"][i])
		plants.append(source)
		plant_homes.append(source.global_transform)
		plant_pot_materials.append(source.get_node("Terracotta_pot").material_override)
		var originals: Array = []
		for child in source.get_children():
			if child is MeshInstance3D and (str(child.name).begins_with("Leaf") or str(child.name).begins_with("Stem")):originals.append(child)
		plant_originals.append(originals)
		var botanical := Node3D.new()
		source.add_child(botanical)
		botanical.position.y = .279
		plant_art.append(botanical)
		botanical.hide()
		plant_species(botanical,i)
		var proxy := target4("plant%d"%i,Vector3.ZERO,"盆栽 · "+PLANT_NAMES[i],[9])
		Props.bind(proxy,source)
	var board := target4("jigsaw",study_desk.to_global(Vector3(-.07,.783,.19)),"书房桌上的拼图",[9])
	var tray := box(board,"WoodenPuzzleTray",Vector3(0,.004,0),Vector3(.32,.012,.225),Color("826640"))
	tray.material_override = load("res://furniture_pack/materials/walnut.tres")
	for i in range(9):
		var piece := textured(board,"CardboardPiece%d"%i,Vector3((i%3-1)*.101,.011,(i/3-1)*.068),Vector2(.10,.067),"res://act4/textures/laboratory_cats.png")
		tiles.append(piece)
	# Keep the entire 3x3 field on lawn, clear of the terrace's north edge at z=-8.
	var burrows := target4("burrows",Vector3(-.9,-.035,-10.0),"九个地鼠洞",[9])
	for i in range(9):
		var pos := Vector3((i%3-1)*1.1,0,(i/3-1)*1.1)
		holes.append(burrows.position+pos)
		earth_mound(burrows,pos)
		Art.ellipsoid(burrows,"DarkBurrow",pos+Vector3(0,.006,0),Vector3(.225,.012,.225),Art.material("hole",Color("151b17"),1))
		for k in range(9):Art.ellipsoid(burrows,"SoilClod",pos+Vector3(sin(k*2.3)*.18,.024,cos(k*2.3)*.18),Vector3(.035,.026,.025),grain("soil_clods",Color("80674b")))
	var mole := target4("mole",holes[0],"地鼠 · E 猫扑",[9])
	mole_actor = Rodent.new();mole.add_child(mole_actor);mole_actor.build(true)
	var mouse := target4("mouse",Vector3(.05,.02,2.1),"老鼠 · 靠近按 E 抓取",[10])
	mouse_actor = Rodent.new();mouse.add_child(mouse_actor);mouse_actor.build(false)
	var carried_note := textured(mouse_actor.visual,"CarriedNote",Vector3(0,.042,-.159),Vector2(.035,.018),"res://act4/textures/escape_note.svg")
	carried_note.rotation.x = .18
	var plan := target4("escape_note",Vector3(1.60,.010,-3.52),"老鼠掉下的纸条",[10,11])
	# Keep the actual folded surface above the non-colliding kitchen finish.
	for floor_mesh in game.get_node("Apartment/GroundFloor").get_children():
		if floor_mesh is MeshInstance3D and str(floor_mesh.name).begins_with("KitchenFinish"):
			var aabb: AABB = floor_mesh.global_transform*floor_mesh.get_aabb()
			plan.global_position.y = maxf(plan.global_position.y,aabb.end.y+.004)
	var paper_mesh := SurfaceTool.new();paper_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(8):
		for z in range(6):
			for uv in [Vector2(x,z),Vector2(x+1,z+1),Vector2(x+1,z),Vector2(x,z),Vector2(x,z+1),Vector2(x+1,z+1)]:
				uv /= Vector2(8,6)
				paper_mesh.set_uv(uv)
				paper_mesh.add_vertex(Vector3((uv.x-.5)*.18,.001+pow(absf(uv.x-.5)*2,5)*.003,(uv.y-.5)*.12))
	paper_mesh.generate_normals()
	var paper_mat := mat(Color.WHITE);paper_mat.albedo_texture = load("res://act4/textures/escape_note.svg")
	paper_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	Art.mesh_node(plan,"DampFoldedPaper",paper_mesh.commit(),paper_mat)
	build_door()
	root.hide()
func foil_pouch(parent: Node3D) -> void:
	var profile: Array[Vector3]=[Vector3(0,.064,.003),Vector3(.010,.068,.010),Vector3(.027,.068,.025),Vector3(.060,.066,.032),Vector3(.105,.065,.030),Vector3(.14,.064,.018),Vector3(.159,.068,.003),Vector3(.17,.068,.002)]
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(profile.size()-1):
		for side in range(32):
			for corner in [Vector2i(row,side),Vector2i(row+1,side),Vector2i(row+1,side+1),Vector2i(row,side),Vector2i(row+1,side+1),Vector2i(row,side+1)]:
				var p:=profile[corner.x]
				var angle: float=corner.y*TAU/32
				body.set_uv(Vector2(corner.y/32.0,p.x/.17))
				body.add_vertex(Vector3(cos(angle)*p.y,p.x,sin(angle)*p.z+sin(angle*9+corner.x)*.0007))
	body.generate_normals()
	var wrapper:=grain("pouch_kraft",Color("baa77c"))
	wrapper.cull_mode=BaseMaterial3D.CULL_DISABLED
	Art.mesh_node(parent,"CrinkledSealedPouch",body.commit(),wrapper)
	var label_mesh:=SurfaceTool.new()
	label_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(10):
		for col in range(10):
			for corner in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var x: float=(corner.y/10.0-.5)*.105
				var y: float=.15-corner.x*.0125
				var depth:=.025
				for i in range(profile.size()-1):
					if y>=profile[i].x and y<=profile[i+1].x:depth=lerpf(profile[i].z,profile[i+1].z,inverse_lerp(profile[i].x,profile[i+1].x,y))
				label_mesh.set_uv(Vector2(corner.y/10.0,corner.x/10.0))
				label_mesh.add_vertex(Vector3(x,y,depth*sqrt(maxf(0.0,1-pow(x/.066,2)))+.001))
	label_mesh.generate_normals()
	var ink:=mat(Color.WHITE)
	ink.albedo_texture=load("res://act4/textures/food_label.svg")
	ink.cull_mode=BaseMaterial3D.CULL_DISABLED
	Art.mesh_node(parent,"WrappedPrintedLabel",label_mesh.commit(),ink)
func plant_species(parent: Node3D, species: int) -> void:
	var green := grain("botanical_leaf",Color("507044"))
	for i in range(16 if species==0 else 7 if species==1 else 14):
		var angle := i*2.4
		var tip := Vector3(sin(angle)*.18,.24+cos(i)*.06,cos(angle)*.18)
		Art.rod(parent,"Stem",Vector3.ZERO,tip,.003,Art.material("woody_stem",Color("667048"),.88))
		if species==1:
			Art.ellipsoid(parent,"GoldFlowerCenter",tip,Vector3(.025,.013,.025),grain("pollen",Color("c0a04b")))
			for j in range(11):
				var petal := Art.ellipsoid(parent,"WhiteDaisyPetal",tip+Vector3(sin(j*TAU/11)*.026,0,cos(j*TAU/11)*.026),Vector3(.014,.004,.041),Art.material("white_petals",Color("e7e4d3"),.8))
				petal.rotation.y = j*TAU/11
		else:
			for j in range(1,9):
				var base := tip*j/10.0
				for side in [-1,1]:
					var leaflet := Art.ellipsoid(parent,"FernLeaflet" if species==0 else "RosemaryNeedle",base+Vector3(side*.02,0,0),Vector3(.065 if species==0 else .028,.005,.014 if species==0 else .004),green)
					leaflet.rotation.y = angle+side*.4
func earth_mound(parent: Node3D, origin: Vector3) -> void:
	var mesh:=SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2]=[Vector2(.100,.002),Vector2(.119,.031),Vector2(.148,.040),Vector2(.177,.018),Vector2(.205,.001)]
	for a in range(48):
		for row in range(4):
			for corner in [Vector2i(a,row),Vector2i(a+1,row),Vector2i(a+1,row+1),Vector2i(a,row),Vector2i(a+1,row+1),Vector2i(a,row+1)]:
				var angle: float=corner.x*TAU/48
				var p:=profile[corner.y]
				var rough:=sin(angle*7)*.008+sin(angle*13)*.004
				mesh.set_uv(Vector2(corner.x/12.0,corner.y/4.0))
				mesh.add_vertex(origin+Vector3(sin(angle)*(p.x+rough),p.y+absf(rough)*.7,cos(angle)*(p.x+rough)))
	mesh.generate_normals()
	var soil:=grain("fresh_soil",Color("80674b"))
	soil.cull_mode=BaseMaterial3D.CULL_DISABLED
	Art.mesh_node(parent,"UnevenExcavatedSoil",mesh.commit(),soil)
func build_door() -> void:
	var width := 1.28
	var gate = load("res://scripts/basement/laboratory_lock_door.gd").new()
	gate.name = "basement"
	gate.position = Vector3(3.34,-2.70,-2.80+width*.5)
	gate.rotation.y = PI/2
	gate.leaf_width = width
	gate.open_angle = 100
	gate.door_title = "实验室密码门"
	Props.days(gate,[8,9,10,11],[11])
	gate.set_meta("title","实验室密码门 · 三组电流锁")
	items["basement"] = gate
	# The gate origin is its hinge. The slab occupies the actual 1.3m portal,
	# and opens into the laboratory, away from the narrow lower stair landing.
	leaf = AnimatableBody3D.new()
	leaf.name = "Leaf"
	gate.add_child(leaf)
	var slab := box(leaf,"PaintedSteelDoor",Vector3(.52,1.0,0),Vector3(1.04,2,.055),Color("344c47"))
	(slab.mesh as BoxMesh).size.x = width
	(slab.mesh as BoxMesh).size.y = 2.04
	slab.position.x = width*.5
	slab.position.y = 1.02
	slab.material_override = grain("door_paint",Color("485852"))
	for x in [.07,width-.07]:
		for y in [.25,1.75]:cylinder(leaf,Vector3(x,y,.035),.014,.006,Color("afaa94")).rotation.x = PI/2
	door_body = leaf as AnimatableBody3D
	door_body.collision_layer = 1;door_body.collision_mask = 2
	var collider := CollisionShape3D.new();collider.name = "CollisionShape3D"
	var shape := BoxShape3D.new();shape.size = Vector3(width,2.04,.055)
	collider.shape = shape;collider.position = Vector3(width*.5,1.02,0)
	leaf.add_child(collider)
	for i in range(3):
		var body := box(leaf,"RelayLock%d"%i,Vector3(.52,.35+i*.25,.046),Vector3(.33,.17,.035),Color("8f8b76"))
		body.material_override = grain("relay_case",Color("8b9285"))
		Props.fit_mesh(body,Props.furniture(root.get_parent(),"coffee_table","Living").get_node("Rounded_tabletop").mesh,Vector3(.33,.17,.035))
		for x in [.38,.66]:
			for side in [-1,1]:
				var y: float=.35+i*.25+side*.055
				cylinder(leaf,Vector3(x,y,.069),.007,.004,Color("c0baa5")).rotation.x=PI/2
				Art.rod(leaf,"ScrewSlot",Vector3(x-.003,y,.073),Vector3(x+.003,y,.073),.0007,Art.material("screw_slot",Color("44504b")))
		var traces: Array[Vector3]=[]
		for j in range(7):traces.append(Vector3(.40+j*.036,.35+i*.25+(.035 if j%2 else -.035),.066))
		Art.line(leaf,"CopperCircuitTrace",traces,.0013,Art.material("etched_copper",Color("b2a16e"),.5,.3))
		for j in range(4):
			var lamp := ball(leaf,Vector3(.42+j*.065,.35+i*.25,.07),Vector3(.026,.026,.012),Color("9a694e"))
			bolts.append(lamp)
	Art.rod(leaf,"SteelPullHandle",Vector3(width-.17,.88,.10),Vector3(width-.17,1.12,.10),.013,Art.material("door_hardware",Color("b7b7a5"),.3,.7))
	root.add_child(gate)
	gate.apply_lock_state(false,false)
func arrange(order: Array, active_: bool) -> void:
	for slot in range(3):
		var i: int = order[slot]
		var source: Node3D = plants[i]
		var bench_pos := terrace_bench.to_global(Vector3((slot-1)*.50,.465,.015))
		source.global_transform = Transform3D(Basis.IDENTITY,bench_pos) if active_ else plant_homes[i]
		source.get_node("Terracotta_pot").material_override = grain("botanical_pot%d"%i,[Color("b77e53"),Color("d2cbb1"),Color("84937c")][i]) if active_ else plant_pot_materials[i]
		for original in plant_originals[i]:original.visible = not active_
		plant_art[i].visible = active_
		items["plant%d"%i].global_position = source.global_position+Vector3(0,.25,0)
func update_jigsaw(order: Array) -> void:
	for i in range(9):
		tiles[i].material_override.albedo_texture = load("res://act4/textures/laboratory_cats.png")
		tiles[i].material_override.uv1_scale = Vector3(1.0/3,1.0/3,1)
		tiles[i].material_override.uv1_offset = Vector3((order[i]%3)/3.0,(order[i]/3)/3.0,0)
func clock_pose(seconds: float) -> void:
	var angles := [seconds/43200.0*TAU,seconds/3600.0*TAU,seconds/60.0*TAU]
	for i in range(3):hands[i].rotation.z = -angles[i]
func door_state(opened: bool, level: int, enabled: bool) -> void:
	items.basement.apply_lock_state(opened,enabled)
	for i in range(bolts.size()):bolts[i].material_override = Art.material("lock_ready" if i/4<level else "lock_waiting",Color("adc99a") if i/4<level else Color("9c7355"),.3)
