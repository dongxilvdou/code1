extends "res://day2/world.gd"
var cabinet_hinges: Array = []
var fridge_hinge: Node3D
var oven_hinge: Node3D
var camera_led: MeshInstance3D
var water_surface: MeshInstance3D
var books: Array = []
var original_bookcase: Node3D
var colors := [Color("be6c59"),Color("6f9daa"),Color("d4b163")]
var shelves := [Vector3(-2.12,.38,-.86),Vector3(-1.65,.83,-.86),Vector3(-1.18,1.28,-.86)]
var titles := {}

func target(id: String, pos: Vector3, title: String) -> Node3D:
	var n := item(id,pos)
	titles[id] = title
	sign_at(n,title,Vector3(0,.16,0),23)
	return n

func build(parent: Node3D, game: Node) -> void:
	root = parent
	for n in game.get_tree().get_nodes_in_group("placed_furniture"):
		if n.get_meta("asset_id","")=="bookcase" and n.global_position.distance_to(Vector3(-1.09,0,-1.14))<.3:original_bookcase = n
	# A cat-accessible stepped bookcase at the living-room north wall.
	for i in range(3):
		var shelf := target("shelf%d"%i,shelves[i],["红色书格","蓝色书格","黄色书格"][i])
		box(shelf,"Shelf",Vector3(0,-.03,0),Vector3(.48,.06,.62),Color("896b4c"),true)
		box(shelf,"Back",Vector3(0,.15,-.28),Vector3(.48,.36,.035),colors[i])
		box(shelf,"Support",Vector3(0,-shelves[i].y*.5,0),Vector3(.08,shelves[i].y,.08),Color("896b4c"),true)
		var book := target("book%d"%i,Vector3(-2.5+i*.47,.04,.15),["红色的书","蓝色的书","黄色的书"][i])
		box(book,"Cover",Vector3.ZERO,Vector3(.24,.055,.18),colors[i])
		box(book,"Pages",Vector3(0,.005,.005),Vector3(.22,.037,.16),Color("e8ddc3"))
		books.append(book)
	var photo := target("photo",Vector3(-2.25,.045,.40),"从书里掉下的照片")
	var photo_mesh := box(photo,"Photograph",Vector3.ZERO,Vector3(.26,.004,.17),Color.WHITE)
	var photo_material := mat(Color.WHITE)
	photo_material.albedo_texture = load("res://act2/memory_photo.svg")
	photo_mesh.material_override = photo_material
	var sink = game.get_node("DayTwo").world.sink_cabinet
	for side in [-1,1]:
		var hinge := Node3D.new()
		sink.add_child(hinge)
		hinge.position = Vector3(side*.56,.10,.31)
		cabinet_hinges.append(hinge)
		for part in sink.get_children():
			if part is MeshInstance3D and (str(part.name).begins_with("Door_") or str(part.name).begins_with("Handle")) and signf(part.position.x)==side:part.reparent(hinge,true)
	target("cabinet",sink.to_global(Vector3(0,.30,.40)),"水槽下的柜门")
	var plumbing := target("pipes",sink.to_global(Vector3(0,.34,.27)),"接错的水管")
	for i in range(5):
		var pipe := cylinder(plumbing,Vector3(-.3+i*.15,0,-.02),.022,.26,Color("91aaa9"))
		pipe.rotation.z = PI/2 if i%2==0 else 0
	var monitor := target("camera",sink.to_global(Vector3(.47,.53,.31)),"柜门内的红点")
	box(monitor,"Monitor",Vector3.ZERO,Vector3(.055,.055,.025),Color("1c252b"))
	camera_led = ball(monitor,Vector3(0,0,.02),Vector3(.018,.018,.012),Color("ff4a4a"))
	camera_led.material_override = mat(Color("ff2222"),true)
	# Window ledge beside the living-room sofa. Full water locks jumping.
	var can := target("can",Vector3(-5.52,.96,3.35),"装满水的水壶")
	cylinder(can,Vector3(0,.12,0),.12,.24,Color("8aafa4"))
	var spout := cylinder(can,Vector3(.16,.16,0),.025,.24,Color("8aafa4"))
	spout.rotation.z = -.9
	var handle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = .12
	torus.outer_radius = .15
	handle.mesh = torus
	handle.material_override = mat(Color("8aafa4"))
	can.add_child(handle)
	handle.rotation.x = PI/2
	handle.position = Vector3(-.07,.17,0)
	water_surface = cylinder(can,Vector3(0,.232,0),.105,.007,Color("84bec7"))
	box(root,"WindowLedge",Vector3(-5.53,.92,3.35),Vector3(.46,.06,.70),Color("b29871"),true)
	box(root,"CanStep",Vector3(-4.93,.23,3.35),Vector3(.46,.46,.46),Color("b29871"),true)
	target("drain",Vector3(2.52,.07,-.38),"淋浴间地漏 · 倒掉一半水")
	var plant := target("plant",Vector3(-5.40,1.05,1.90),"需要浇水的花盆")
	cylinder(plant,Vector3(0,.10,0),.14,.20,Color("ae745b"))
	for i in range(5):
		var leaf := ball(plant,Vector3(sin(i)*.10,.28,cos(i)*.10),Vector3(.11,.26,.07),Color("78956b"))
		leaf.rotation.z = sin(i)*.5
	box(root,"PlantShelf",Vector3(-5.50,1.02,1.90),Vector3(.42,.05,.48),Color("b29871"),true)
	# Outdoor mailbox: unreachable letter comes down only after shaking.
	var mailbox := target("mailbox",Vector3(-1.60,0,7.30),"高信箱 · 摇晃")
	box(mailbox,"Post",Vector3(0,.65,0),Vector3(.12,1.3,.12),Color("666f69"),true)
	box(mailbox,"Box",Vector3(0,1.40,0),Vector3(.60,.38,.40),Color("5e8b82"),true)
	box(mailbox,"Opening",Vector3(0,1.40,.211),Vector3(.47,.16,.015),Color("253d39"))
	box(mailbox,"EnvelopeTip",Vector3(.08,1.40,.25),Vector3(.27,.10,.16),Color("eadfc4"))
	mailbox.get_child(0).position.y = .55
	var letter := target("letter",Vector3(-1.60,.035,7.70),"掉落的信")
	box(letter,"Envelope",Vector3.ZERO,Vector3(.30,.01,.18),Color("eadfc4"))
	# Side lock sits above the existing neighboring kitchen cabinet.
	var fridge: Node3D
	for n in game.get_tree().get_nodes_in_group("placed_furniture"):
		if n.get_meta("asset_id","")=="fridge":fridge = n
	# Replace the closed furniture block with a real hollow compartment.
	fridge.get_node("Fridge_body").hide()
	for shape in fridge.get_node("Collision").get_children():shape.disabled = true
	for side in [-1,1]:box(fridge,"CaseSide",Vector3(side*.325,.9,0),Vector3(.05,1.8,.70),Color("d6d9c9"),true)
	box(fridge,"CaseBack",Vector3(0,.9,-.325),Vector3(.60,1.8,.05),Color("a4b6ac"),true)
	for height in [.035,.63,1.35,1.775]:box(fridge,"CaseShelf",Vector3(0,height,0),Vector3(.60,.05,.66),Color("d6d9c9"),true)
	fridge_hinge = Node3D.new()
	fridge.add_child(fridge_hinge)
	fridge_hinge.position = Vector3(-.38,.10,.37)
	for part in fridge.get_children():
		if part is MeshInstance3D and (str(part.name) in ["Upper_door","Lower_freezer"] or "Handle" in str(part.name)):part.reparent(fridge_hinge,true)
	var lock := target("fridge_lock",Vector3(4.71,1.12,-5.12),"冰箱侧面的猫爪机关")
	box(lock,"Lock",Vector3.ZERO,Vector3(.06,.24,.25),Color("c2b38a"))
	box(root,"FridgeStep",Vector3(3.88,.21,-4.91),Vector3(.48,.42,.52),Color("b29871"),true)
	var fish := target("fish",Vector3(5.13,.69,-5.16),"冰箱里唯一的一条鱼")
	ball(fish,Vector3.ZERO,Vector3(.34,.08,.12),Color("8daeb0"))
	var tail := box(fish,"Tail",Vector3(-.19,0,0),Vector3(.09,.02,.15),Color("76999e"))
	tail.rotation.y = .6
	ball(fish,Vector3(.12,.035,.04),Vector3(.018,.018,.018),Color("182b30"))
	var oven := target("oven",Vector3(3.45,.91,-5.45),"烤箱 · 放入鱼，再关门")
	box(root,"OvenStep",Vector3(3.15,.20,-4.93),Vector3(.46,.40,.48),Color("b29871"),true)
	box(oven,"Body",Vector3(0,.20,0),Vector3(.64,.40,.42),Color("d0c7b3"),true)
	box(oven,"Inside",Vector3(0,.19,.22),Vector3(.52,.28,.02),Color("293937"))
	oven_hinge = Node3D.new()
	oven.add_child(oven_hinge)
	oven_hinge.position = Vector3(0,.02,.24)
	box(oven_hinge,"Door",Vector3(0,.15,0),Vector3(.56,.29,.025),Color("60746b"))
	box(oven_hinge,"Handle",Vector3(0,.25,.04),Vector3(.28,.035,.04),Color("c8b18a"))
	cylinder(root,Vector3(3.96,.921,-5.38),.16,.018,Color("ddd6bc"))
	var half := target("half_fish",Vector3(3.96,.95,-5.38),"留下的半条熟鱼")
	ball(half,Vector3.ZERO,Vector3(.19,.065,.11),Color("c99559"))
	var yarn := target("yarn",Vector3(-4.64,.13,2.30),"沙发旁的毛线球")
	ball(yarn,Vector3.ZERO,Vector3(.19,.19,.19),Color("cb9670"))
	var bone := target("bone",Vector3(-4.48,.05,2.30),"刻着编号的玩具骨头")
	box(bone,"Bone",Vector3.ZERO,Vector3(.24,.05,.06),Color("dec99b"))
	for x in [-.12,.12]:
		for z in [-.04,.04]:ball(bone,Vector3(x,0,z),Vector3(.075,.07,.075),Color("dec99b"))
	var medicines := target("medicine",Vector3(-3.0,.82,4.65),"七只药瓶")
	for i in range(7):
		var offset := Vector3((i-3)*.135,0,0)
		cylinder(medicines,offset+Vector3(0,.08,0),.042,.16,Color("7da38e"))
		cylinder(medicines,offset+Vector3(0,.17,0),.045,.035,Color("e2d9be"))
		box(medicines,"Label",offset+Vector3(0,.09,.043),Vector3(.055,.075,.002),Color("f1e5c7"))
	target("clues",Vector3(-3.40,.82,4.65),"线索册 · 回看照片与编号")
