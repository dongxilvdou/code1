extends "res://day2/world.gd"
## Quest adapters bind to the furnished villa. Only missing portable props are created.
var cabinet_hinges: Array = []
var fridge_hinge: Node3D
var oven_hinge: Node3D
var oven_glow: OmniLight3D
var camera_led: MeshInstance3D
var water_surface: MeshInstance3D
var books: Array = []
var original_bookcase: Node3D
var colors := [Color("be6c59"),Color("6f9daa"),Color("d4b163")]
var shelves: Array[Vector3] = []
var book_returns: Array[Transform3D] = []
var titles := {}
var fish_home := Vector3.ZERO
var fish_in_oven := Vector3.ZERO
var shared_yarn: Node3D
var shared_yarn_home := Vector3.ZERO
var medicine_models: Array[Node3D] = []

func target(id: String, pos: Vector3, title: String, available: Array = [3,4,5]) -> Node3D:
	var n := item(id,pos)
	titles[id] = title
	Props.days(n,available)
	sign_at(n,title,Vector3(0,.16,0),23)
	return n

func build(parent: Node3D, game: Node) -> void:
	root = parent
	original_bookcase = Props.furniture(game,"bookcase","Living")
	assert(original_bookcase != null)
	# Keep the actual cabinet and wood shelving. Replace its old unmarked book blocks.
	for child in original_bookcase.get_children():
		if str(child.name).begins_with("Book") or str(child.name).begins_with("Spine_band"):child.hide()
	for row in range(4):
		var height: float = [.146,.495,.925,1.355][row]
		for col in range(8 if row==0 else 6):
			var book := Props.model(original_bookcase,["book_red","book_blue","book_gold"][(row+col)%3])
			var x: float = -.29+col*.075 if row==0 else (-.35+col*.056 if row==2 else .03+col*.056)
			book.position = Vector3(x,height+.123*(.9+float(col%3)*.07)+.002,.02)
			book.basis = Basis(Vector3.UP,PI/2)*Basis(Vector3.RIGHT,-PI/2)
			book.scale = Vector3(.9,.9,.9+float(col%3)*.07)
	# Shallow pull-out reading ledges are PARTS of this bookcase, not a second bookcase.
	for i in range(3):
		var height: float = [.495,.925,1.355][i]
		var x: float = [-.30,.30,-.30][i]
		var depth: float = [.64,.56,.24][i]
		var center_z := .17+depth*.5
		var stand_z: float = [.69,.61,.32][i]
		var ledge := Node3D.new()
		ledge.name = "ReadingLedge%d"%i
		original_bookcase.add_child(ledge)
		var board := box(ledge,"OakTray",Vector3(x,height-.018,center_z),Vector3(.30,.036,depth),Color("937755"),true)
		Props.fit_mesh(board,Props.furniture(game,"coffee_table","Living").get_node("Rounded_tabletop").mesh,Vector3(.30,.036,depth))
		board.material_override = load("res://furniture_pack/materials/oak.tres")
		for side in [-1,1]:
			box(ledge,"SlideRail",Vector3(x+side*.12,height-.041,center_z),Vector3(.012,.018,depth-.04),Color("899490"))
		var anchor := original_bookcase.to_global(Vector3(x,height,stand_z))
		shelves.append(anchor)
		var shelf := target("shelf%d"%i,anchor,["红色书签 · 第一层","蓝色书签 · 第二层","金色书签 · 第三层"][i],[3])
		Props.bind(shelf,original_bookcase)
		var marker := box(shelf,"ClothBookmark",Vector3(0,-.006,.09),Vector3(.08,.003,.10),colors[i])
		marker.rotation.y = original_bookcase.rotation.y
		var book := target("book%d"%i,Vector3(-2.5+i*.47,.023,.15),["红色园艺书","蓝色日记","金色植物图鉴"][i])
		Props.model(book,["book_red","book_blue","book_gold"][i])
		book.set_meta("interaction_days",[3])
		books.append(book)
		var transform := original_bookcase.global_transform*Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(x,height+.125,.02))
		book_returns.append(transform)
	var photo := target("photo",Vector3(-2.25,.025,.40),"从书里掉下的照片",[3])
	var photo_mesh := box(photo,"Photograph",Vector3.ZERO,Vector3(.26,.004,.17),Color.WHITE)
	var photo_material := mat(Color.WHITE)
	photo_material.albedo_texture = load("res://act2/memory_photo.svg")
	photo_mesh.material_override = photo_material
	var sink: Node3D = game.get_node("DayTwo").world.sink_cabinet
	# Correct pivots at the true door edges; the old full-width front collider is removed.
	for side in [-1,1]:
		var hinge := Node3D.new()
		hinge.name = "QuestCabinetDoorLeft" if side<0 else "QuestCabinetDoorRight"
		sink.add_child(hinge)
		hinge.position = Vector3(side*.395,.49,.31)
		cabinet_hinges.append(hinge)
		for part in sink.get_children():
			if part is MeshInstance3D and (str(part.name).begins_with("Door_") or str(part.name).begins_with("Handle")) and signf(part.position.x)==side:part.reparent(hinge,true)
		collision(hinge,Vector3(-side*.197,0,-.016),Vector3(.375,.70,.035))
	var door_shape := sink.get_node_or_null("Collision/Solid_011") as CollisionShape3D
	if door_shape:door_shape.disabled = true
	# Leave a proper plumbing cutout under the sink instead of a solid board through the drain.
	sink.get_node("Cabinet_shelf2").hide()
	sink.get_node("Collision/Solid_005").disabled = true
	for side in [-1,1]:box(sink,"SplitInnerShelf",Vector3(side*.235,.61,0),Vector3(.33,.036,.52),Color("d4d8cc"),true)
	var cabinet := target("cabinet",sink.to_global(Vector3(0,.30,.40)),"水槽柜门 · E 开关",[3])
	Props.bind(cabinet,sink)
	var plumbing := target("pipes",sink.to_global(Vector3(0,.35,.24)),"水槽排水管 · 接回水路",[3])
	Props.bind(plumbing,sink)
	# Continuous P-trap, drain tailpiece, collars and wall connection.
	var points := [Vector3(0,.35,-.24),Vector3(0,.05,-.24),Vector3(.035,-.07,-.24),Vector3(.14,-.07,-.24),Vector3(.18,.03,-.24),Vector3(.18,.08,-.33),Vector3(.18,.08,-.50)]
	for i in range(points.size()-1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		var pipe := cylinder(plumbing,(a+b)/2,.025,a.distance_to(b),Color("a9b6b1"))
		pipe.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
		ball(plumbing,a,Vector3(.056,.056,.056),Color("a9b6b1"))
		var collar := cylinder(plumbing,a,.033,.026,Color("71847c"))
		collar.quaternion = pipe.quaternion
	var monitor := target("camera",sink.to_global(Vector3(.27,.53,.27)),"柜门里的微型镜头",[3])
	box(monitor,"Mount",Vector3(0,0,-.018),Vector3(.065,.065,.015),Color("3f4d48"))
	var lens := cylinder(monitor,Vector3.ZERO,.023,.028,Color("253336"))
	lens.rotation.x = PI/2
	var glass := cylinder(monitor,Vector3(0,0,.017),.016,.004,Color("344f57"))
	glass.rotation.x = PI/2
	camera_led = ball(monitor,Vector3(.025,.022,.014),Vector3(.006,.006,.006),Color("ff4a4a"))
	camera_led.material_override = mat(Color("ff2222"),true)
	# Reuse the existing climbing tree by the window, and an existing living-room plant.
	var tree := Props.furniture(game,"cat_tree","Living")
	var can := target("can",tree.to_global(Vector3(.13,.756,.04)),"猫爬架上的浇花壶",[3])
	Props.model(can,"watering_can")
	water_surface = cylinder(can,Vector3(0,.216,0),.103,.003,Color("84bec7"))
	var shower := Props.furniture(game,"decor_shower","Bath1")
	if shower==null:
		for n in game.get_tree().get_nodes_in_group("placed_furniture"):
			if n.get_meta("asset_id","")=="decor_shower" and n.global_position.y<1:shower = n
	assert(shower != null)
	var drain := target("drain",shower.get_node("Drain").global_position+Vector3(0,.01,0),"淋浴地漏 · 倒掉一半水",[3])
	Props.bind(drain,shower)
	var plant_furniture: Node3D
	for n in game.get_tree().get_nodes_in_group("placed_furniture"):
		if n.get_meta("asset_id","")=="decor_plant" and n.global_position.distance_to(Vector3(-4.65,0,-1.10))<.25:plant_furniture = n
	assert(plant_furniture != null)
	plant_furniture.global_position = Vector3(-5.35,0,3.12)
	var plant := target("plant",plant_furniture.global_position+Vector3(0,.24,0),"沙发旁的花盆",[3])
	Props.bind(plant,plant_furniture)
	var mailbox := target("mailbox",Vector3(-1.60,0,7.30),"门外信箱 · 摇晃",[1,2,3,4,5])
	mailbox.set_meta("interaction_days",[4])
	Props.model(mailbox,"mailbox")
	collision(mailbox,Vector3(0,.65,0),Vector3(.12,1.3,.12))
	collision(mailbox,Vector3(0,1.32,0),Vector3(.54,.40,.36))
	box(mailbox,"EnvelopeTip",Vector3(.08,1.39,.21),Vector3(.19,.014,.08),Color("eadfc4"))
	var letter := target("letter",Vector3(-1.60,.012,7.70),"掉落的信",[4])
	Props.model(letter,"letter")
	var fridge := Props.furniture(game,"fridge","Kitchen")
	fridge.get_node("Fridge_body").hide()
	for shape in fridge.get_node("Collision").get_children():shape.disabled = true
	for side in [-1,1]:box(fridge,"InnerSide",Vector3(side*.325,.9,0),Vector3(.05,1.8,.70),Color("d6d9c9"),true)
	box(fridge,"InnerBack",Vector3(0,.9,-.325),Vector3(.60,1.8,.05),Color("a4b6ac"),true)
	for height in [.035,.63,1.35,1.775]:box(fridge,"GlassShelf",Vector3(0,height,0),Vector3(.60,.025,.66),Color("c8d3c9"),true)
	fridge_hinge = Node3D.new()
	fridge_hinge.name = "QuestFridgeDoor"
	fridge.add_child(fridge_hinge)
	fridge_hinge.position = Vector3(-.365,0,.35)
	for part in fridge.get_children():
		if part is MeshInstance3D and (str(part.name) in ["Upper_door","Lower_freezer"] or "Handle" in str(part.name)):part.reparent(fridge_hinge,true)
	collision(fridge_hinge,Vector3(.365,.90,.01),Vector3(.70,1.74,.045))
	var lock := target("fridge_lock",fridge.to_global(Vector3(-.42,1.12,.27)),"冰箱侧面 · 猫爪机关",[3,4])
	Props.bind(lock,fridge)
	Props.model(lock,"fridge_lock")
	fish_home = fridge.to_global(Vector3(0,.65,.06))
	var fish := target("fish",fish_home,"冰箱里的鲜鱼",[4])
	Props.model(fish,"fish")
	# Reuse the existing range oven, keeping its burners, dials and manufactured trim.
	var cooker := Props.furniture(game,"cooker","Kitchen")
	cooker.get_node("Range_body").hide()
	cooker.get_node("Collision/Solid_000").disabled = true
	for side in [-1,1]:box(cooker,"OvenSide",Vector3(side*.28,.43,0),Vector3(.04,.86,.58),Color("c6cec2"),true)
	box(cooker,"OvenBack",Vector3(0,.43,-.27),Vector3(.52,.86,.04),Color("3d4b48"),true)
	for h in [.10,.73]:box(cooker,"OvenLiner",Vector3(0,h,0),Vector3(.52,.04,.54),Color("3f4a47"),true)
	for i in range(10):box(cooker,"RackBar",Vector3(-.23+i*.051,.30,0),Vector3(.006,.006,.46),Color("a4b3af"))
	for z in [-.20,.20]:box(cooker,"RackRail",Vector3(0,.30,z),Vector3(.49,.008,.008),Color("a4b3af"))
	oven_hinge = Node3D.new()
	oven_hinge.name = "QuestOvenDoor"
	cooker.add_child(oven_hinge)
	oven_hinge.position = Vector3(0,.17,.315)
	for part in ["Oven_frame","Oven_glass","Handle","Handle_mount","Handle_mount2"]:cooker.get_node(part).reparent(oven_hinge,true)
	oven_hinge.get_node("Oven_frame").hide()
	for side in [-1,1]:box(oven_hinge,"WindowSide",Vector3(side*.244,.23,-.013),Vector3(.042,.48,.025),Color("26332f"))
	for h in [.012,.448]:box(oven_hinge,"WindowRail",Vector3(0,h,-.013),Vector3(.45,.044,.025),Color("26332f"))
	var oven_glass := StandardMaterial3D.new()
	oven_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	oven_glass.albedo_color = Color(.15,.21,.18,.28)
	oven_glass.roughness = .16
	oven_glass.metallic = .2
	oven_hinge.get_node("Oven_glass").material_override = oven_glass
	collision(oven_hinge,Vector3(0,.23,.006),Vector3(.53,.47,.035))
	oven_glow = OmniLight3D.new()
	cooker.add_child(oven_glow)
	oven_glow.position = Vector3(.18,.55,.05)
	oven_glow.light_color = Color("ffc887")
	oven_glow.light_energy = 0
	oven_glow.omni_range = .65
	var oven := target("oven",cooker.to_global(Vector3(0,.32,.37)),"灶台烤箱 · 放鱼 / 关门",[4])
	Props.bind(oven,cooker)
	fish_in_oven = cooker.to_global(Vector3(0,.313,.02))
	var half := target("half_fish",Vector3(3.35,.915,-5.38),"餐盘里的半份烤鱼",[4,5])
	Props.model(half,"half_fish")
	# One yarn ball moves between its day-two home and the optional later clue.
	shared_yarn = game.get_node("DayOne").world.items.yarn
	shared_yarn.set_meta("interaction_days",[2,4,5])
	shared_yarn_home = Vector3(-4.64,.13,2.30)
	items["yarn"] = shared_yarn
	titles["yarn"] = "熟悉的毛线球"
	var bone := target("bone",Vector3(-4.48,.025,2.30),"编号 D-017 的磨牙玩具",[4,5])
	Props.model(bone,"bone")
	var table: Node3D = game.get_node("DayOne").world.items.table
	var medicines := target("medicine",table.position+Vector3(.12,.454,-.04),"七只药瓶 · 检查剩余量",[5])
	for i in range(7):
		var visual := Props.model(medicines,"medicine_%d"%i,Vector3((i%4)*.10-.15,0,(i/4)*.13))
		medicine_models.append(visual)
	var clues := target("clues",table.position+Vector3(-.29,.454,0),"线索手记 · 照片与编号")
	Props.model(clues,"clues")

func place_book(index: int, returned: bool) -> void:
	var book: Node3D = items["book%d"%index]
	book.global_transform = book_returns[index] if returned else Transform3D(Basis(Vector3.UP,index*.38),Vector3(-2.5+index*.47,.023,.15))

func medicine_selection(taken: bool) -> void:
	# Keep only the selected three bottles in the mouth. Unselected bottles are put away.
	for i in range(medicine_models.size()):medicine_models[i].visible = not taken or i in [1,3,5]
