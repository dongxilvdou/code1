extends "res://scripts/house_builder.gd"
## Editor-visible, baked environment. All coordinates are metres, floor at -2.7m.
const LIB := "res://furniture_pack/basement/"

func finish(key: String, tint: Color, floor_: bool = false, ceiling_: bool = false) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/laboratory_surface.gdshader")
	m.set_shader_parameter("paint",tint)
	m.set_shader_parameter("detail_texture",load("res://furniture_pack/textures/plaster_detail.png"))
	m.set_shader_parameter("floor_surface",floor_)
	m.set_shader_parameter("ceiling_surface",ceiling_)
	mats[key] = m

func group(label: String, parent: Node = null) -> Node3D:
	var n := Node3D.new();n.name = label;attach(n,parent);return n

func shape(label: String, pos: Vector3, size: Vector3, parent: Node = null, moving: bool = false) -> CollisionShape3D:
	var body: PhysicsBody3D = AnimatableBody3D.new() if moving else StaticBody3D.new()
	body.name = label;attach(body,parent)
	var c := CollisionShape3D.new();c.name = "CollisionShape3D"
	var s := BoxShape3D.new();s.size = size;c.shape = s;c.position = pos
	attach(c,body);return c

func asset(id: String, name_: String, pos: Vector3, yaw: float = 0, parent: Node = null) -> Node3D:
	var n: Node3D = load(LIB+"models/"+id+".glb").instantiate()
	n.name = name_;n.position = pos;n.rotation.y = yaw;attach(n,parent)
	n.set_meta("asset_id",id);n.set_meta("placement_room","BasementLaboratory")
	n.add_to_group("placed_furniture",true)
	return n

func text3(text: String, pos: Vector3, yaw: float = 0, size_: int = 40, pixel: float = .0025, parent: Node = null) -> Label3D:
	var l := Label3D.new();l.text = text;l.name = "Sign"
	l.font_size = size_;l.pixel_size = pixel;l.position = pos;l.rotation.y = yaw
	l.modulate = Color(.13,.22,.21);l.outline_size = 0;l.no_depth_test = false
	attach(l,parent);return l

func cage_scene() -> Node3D:
	root = Node3D.new();root.name = "ObservationCage"
	root.set_script(load("res://scripts/basement/lab_cage.gd"))
	material("label",Color(.79,.80,.72),"",1,.12,.8)
	asset("cage_shell","CageShell",Vector3.ZERO)
	var c := shape("Leaf",Vector3(.517,.467,0),Vector3(1.06,.935,.042),null,true)
	var leaf: AnimatableBody3D = c.get_parent()
	leaf.position = Vector3(-.517,.045,-.802)
	leaf.sync_to_physics = false
	asset("cage_door","HingedDoor",Vector3.ZERO,0,leaf)
	shape("TrayFloor",Vector3(0,.024,0),Vector3(1.14,.05,1.62))
	shape("Roof",Vector3(0,1.01,0),Vector3(1.14,.055,1.62))
	shape("LeftBars",Vector3(-.553,.53,0),Vector3(.035,1.01,1.62))
	shape("RightBars",Vector3(.553,.53,0),Vector3(.035,1.01,1.62))
	shape("BackBars",Vector3(0,.53,.791),Vector3(1.10,1.01,.035))
	box("EnclosureTag",Vector3(.777,.815,-.022),Vector3(.30,.115,.012),"label",false,leaf)
	text3("OBSERVATION\nFELIS / 031",Vector3(.777,.815,-.030),PI,22,.0015,leaf)
	root.set_meta("dimensions_m",Vector3(1.14,1.05,1.62))
	return root

func setup_materials() -> void:
	finish("tile",Color("c2cbc7"),true)
	finish("wall",Color("dce2d9"))
	finish("ceiling",Color("aeb8b1"),false,true)
	material("steel",Color("737f7c"),"",1,.7,.43)
	material("enamel",Color("cbd2c7"),"",1,.18,.62)
	material("dark",Color("293e39"),"",1,.3,.65)
	material("rubber",Color("252d2b"),"",1,0,.95)
	material("paper",Color("d0c8ae"),"",1,0,.94)
	material("amber",Color("71552d"),"",1,.15,.36)
	material("glass",Color("718f89"),"",1,.4,.28)
	var glow := material("tube",Color("d9eee7"))
	glow.emission_enabled = true;glow.emission = Color("d1e6dd");glow.emission_energy_multiplier = .9
	var red := material("indicator",Color("bc6748"))
	red.emission_enabled = true;red.emission = Color("cf6d45");red.emission_energy_multiplier = .4

func wall(label: String, pos: Vector3, size_: Vector3) -> void:
	box(label,pos,size_,"wall",true)
	var skirt := size_;skirt.y = .11
	# Separate shapes, with a real offset, avoid coplanar surfaces at the corners.
	if size_.x>size_.z:skirt.z += .018
	else:skirt.x += .018
	box("CovedSkirting",Vector3(pos.x,.055,pos.z),skirt,"dark",false)

func fixture(pos: Vector3, live: bool = true) -> void:
	box("FluorescentHousing",pos,Vector3(1.25,.075,.30),"enamel",false)
	for z in [-.078,.078]:box("Diffuser",pos+Vector3(0,-.044,z),Vector3(1.12,.026,.055),"tube" if live else "rubber",false)
	if not live:return
	var light := OmniLight3D.new();light.name = "ColdFluorescent"
	light.position = pos-Vector3(0,.18,0);light.light_color = Color(.75,.87,.86)
	light.light_energy = 1.05;light.omni_range = 5.1;light.omni_attenuation = 1.45
	light.shadow_enabled = true;light.light_size = .18
	attach(light)

func bottle(pos: Vector3, r: float, h: float, key: String, parent: Node = null) -> void:
	cylinder(pos+Vector3(0,h*.46,0),r,h*.83,key,-1,parent)
	cylinder(pos+Vector3(0,h*.93,0),r*.43,h*.16,"rubber",-1,parent)
	box("BottleLabel",pos+Vector3(0,h*.48,-r-.001),Vector3(r*1.5,h*.32,.003),"paper",false,parent)

func equipment() -> void:
	var exam := asset("examination_table","ExaminationTable",Vector3(.25,0,-3.92))
	shape("ExamTop",Vector3(0,.885,0),Vector3(.63,.06,1.17),exam)
	shape("ExamColumn",Vector3(0,.45,0),Vector3(.13,.86,.16),exam)
	shape("ExamFeet",Vector3(0,.075,0),Vector3(.55,.12,1.0),exam)
	var table := asset("instrument_table","InstrumentTable",Vector3(-3.67,0,-4.40))
	shape("InstrumentSurface",Vector3(0,.81,0),Vector3(2.48,.085,1.20),table)
	shape("InstrumentLowerShelf",Vector3(0,.20,0),Vector3(2.3,.06,1.12),table)
	for x in [-1.15,1.15]:
		for z in [-.52,.52]:shape("TableLeg",Vector3(x,.42,z),Vector3(.05,.82,.05),table)
	for p in [Vector3(1.94,0,-4.43),Vector3(-4.69,0,-2.86)]:
		var cart := asset("medical_cart","MedicalCart",p)
		# Shelf-level collision preserves the open space underneath this cart.
		for y in [.12,.44,.73]:shape("CartShelf",Vector3(.08,y,0),Vector3(.70,.075,.47),cart)
		for x in [-.29,.40]:
			for z in [-.21,.21]:shape("CartLeg",Vector3(x,.42,z),Vector3(.04,.8,.04),cart)
	var screen := asset("privacy_screen","MedicalPrivacyScreen",Vector3(-1.16,0,-3.91),PI/2)
	shape("ScreenPanel",Vector3(0,1.05,0),Vector3(1.1,1.60,.055),screen)
	shape("ScreenFeet",Vector3(0,.055,0),Vector3(1.1,.11,.35),screen)
	# Examination lamp: articulated arm, shallow reflector and lit centre.
	rod(Vector3(.25,2.32,-3.92),Vector3(.85,1.89,-3.91),.035,"steel")
	rod(Vector3(.85,1.89,-3.91),Vector3(.32,1.65,-3.81),.028,"enamel")
	cylinder(Vector3(.32,1.60,-3.81),.24,.10,"enamel",.13)
	cylinder(Vector3(.32,1.544,-3.81),.19,.012,"tube")
	var lamp := SpotLight3D.new();lamp.name = "ExaminationLamp"
	lamp.position = Vector3(.32,1.53,-3.81);lamp.rotation_degrees.x = -90
	lamp.light_color = Color(.84,.91,.83);lamp.light_energy = 1.7;lamp.spot_range = 2.8
	lamp.spot_angle = 43;lamp.spot_attenuation = 1;lamp.shadow_enabled = true;attach(lamp)
	# Old records, a lined observation chart and closed reagent bottles.
	for i in range(4):
		bottle(Vector3(-4.45+i*.17,.86,-4.62),.045,.18+(i%2)*.045,"amber" if i%2==0 else "enamel")
	box("SteelKidneyTray",Vector3(-3.48,.873,-4.35),Vector3(.38,.024,.25),"steel",false)
	for i in range(3):rod(Vector3(-3.58+i*.045,.894,-4.40),Vector3(-3.56+i*.045,.894,-4.22),.004,"steel")
	box("ObservationClipboard",Vector3(-2.90,.873,-4.34),Vector3(.22,.025,.31),"dark",false)
	box("ChartPaper",Vector3(-2.90,.888,-4.34),Vector3(.197,.003,.28),"paper",false)
	for i in range(8):box("ChartRuling",Vector3(-2.90,.890,-4.43+i*.027),Vector3(.16,.001,.0015),"dark",false)
	for i in range(3):box("ArchiveFolder",Vector3(-2.57,.89+i*.025,-4.68),Vector3(.21,.022,.27),"paper",false)
	# East wall: a modest open supply cabinet, not a featureless solid block.
	var cabinet := group("SupplyCabinet")
	box("Back",Vector3(3.10,.92,.10),Vector3(.045,1.74,1.30),"enamel",false,cabinet)
	for z in [-.58,.78]:box("CabinetSide",Vector3(2.84,.92,z),Vector3(.55,1.74,.035),"enamel",true,cabinet)
	for y in [.12,.58,1.05,1.75]:box("CabinetShelf",Vector3(2.83,y,.10),Vector3(.55,.035,1.38),"enamel",true,cabinet)
	for i in range(5):bottle(Vector3(2.76,1.07,-.43+i*.24),.065,.30,"amber" if i%2 else "enamel",cabinet)
	for i in range(3):
		box("FoldedLinen",Vector3(2.82,.61+i*.035,.0),Vector3(.40,.031,.62),"enamel",false,cabinet)
	box("CabinetBase",Vector3(2.83,.065,.10),Vector3(.55,.13,1.4),"rubber",true,cabinet)
	# Utility bin with separate lid, foot pedal and a printed medical cross.
	cylinder(Vector3(2.46,.23,-1.08),.19,.45,"enamel")
	cylinder(Vector3(2.46,.468,-1.08),.202,.028,"steel")
	box("BinPedal",Vector3(2.46,.035,-1.30),Vector3(.13,.035,.10),"rubber",false)
	box("MedicalCross",Vector3(2.46,.28,-1.273),Vector3(.022,.12,.005),"dark",false)
	box("MedicalCross",Vector3(2.46,.28,-1.274),Vector3(.10,.023,.005),"dark",false)

func build() -> Node3D:
	root = Node3D.new();root.name = "MedicalLaboratory";root.position.y = -2.7
	root.set_script(load("res://scripts/basement/laboratory.gd"))
	setup_materials()
	# Three disjoint surfaces meet exactly: lab ends at 3.27, bridge at 3.40,
	# original landing starts at 3.40. No coplanar overlap at the doorway.
	box("TiledFloor",Vector3(-1.04,-.08,-2.05),Vector3(8.62,.16,6.4),"tile",true)
	box("LandingConnection",Vector3(3.335,-.08,-2.80),Vector3(.13,.16,1.30),"tile",true)
	box("SealedCeiling",Vector3(-1.0,2.40,-2.05),Vector3(8.85,.12,6.55),"ceiling",true)
	wall("NorthTiledWall",Vector3(-1.0,1.2,-5.32),Vector3(8.85,2.40,.14))
	wall("SouthTiledWall",Vector3(-1.0,1.2,1.22),Vector3(8.85,2.40,.14))
	wall("WestTiledWall",Vector3(-5.42,1.2,-2.05),Vector3(.14,2.40,6.40))
	wall("EastWallNorthOfDoor",Vector3(3.34,1.2,-4.375),Vector3(.14,2.40,1.75))
	wall("EastWallSouthOfDoor",Vector3(3.34,1.2,-.52),Vector3(.14,2.40,3.34))
	box("EntranceLintel",Vector3(3.34,2.24,-2.80),Vector3(.17,.32,1.4),"enamel",true)
	for z in [-3.47,-2.13]:box("SteelDoorJamb",Vector3(3.34,1.03,z),Vector3(.20,2.06,.035),"steel",false)
	# Keep the plaque above the actual door, clear of both jambs and the landing.
	box("LandingLaboratorySign",Vector3(3.435,2.23,-2.80),Vector3(.018,.24,.58),"enamel",false)
	text3("B1 · 观察实验区",Vector3(3.448,2.23,-2.80),PI/2,30,.0019)
	text3("动物医学观察室 / B1\nFELINE OBSERVATION — ACCESS RESTRICTED",Vector3(-1.0,1.64,-5.236),0,42,.0020)
	text3("03  /  留观区",Vector3(-2.35,1.48,1.138),PI,38,.0024)
	text3("器械 · 归档",Vector3(-3.70,1.37,-5.235),0,32,.0020)
	# Ceiling services follow two continuous lines, without blocking the stair.
	for z in [-4.95,.91]:
		rod(Vector3(-5.25,2.15,z),Vector3(3.10,2.15,z),.036,"enamel")
		for x in [-4.5,-2.0,.5,2.6]:
			rod(Vector3(x,2.16,z),Vector3(x,2.35,z),.012,"steel")
			cylinder(Vector3(-5.1,2.15,z),.057,.08,"steel").rotation.z = PI/2
	fixture(Vector3(-3.55,2.30,-3.1))
	fixture(Vector3(.80,2.30,-1.65))
	fixture(Vector3(-2.2,2.30,.15),false)
	# A steady, weak exit marker; no rapid horror flicker.
	box("ExitLight",Vector3(3.20,1.85,-2.80),Vector3(.05,.14,.36),"tube",false)
	text3("出口  →",Vector3(3.166,1.85,-2.80),-PI/2,28,.0022)
	var exit_l := OmniLight3D.new();exit_l.position = Vector3(2.98,1.70,-2.8)
	exit_l.light_color = Color(.49,.70,.63);exit_l.light_energy = .22;exit_l.omni_range = 2.2;attach(exit_l)
	equipment()
	for i in range(3):
		var cage: Node3D = load(LIB+"observation_cage.tscn").instantiate()
		cage.name = "ObservationCage_%02d"%(i+1)
		cage.position = Vector3(-4.2+i*1.83,0,.22)
		cage.set("door_title","%02d 号观察笼门"%(i+1))
		cage.set("starts_open",i==0)
		cage.set("specimen_number",31+i)
		attach(cage)
		cage.set_meta("asset_id","observation_cage");cage.add_to_group("placed_furniture",true)
		text3("F-0%d"%(i+1),Vector3(cage.position.x,.13,-.68),PI,24,.0018)
	root.set_meta("floor_rect_xz",Rect2(-5.35,-5.25,8.70,6.40))
	root.set_meta("clear_height_m",2.34)
	return root
