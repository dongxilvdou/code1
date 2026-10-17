extends RefCounted
## All coordinates are world metres. This additive set never rebuilds villa.tscn.
var root: Node3D
var items := {}
var gates: Array[Node3D] = []
var door: Node3D
const PAPER_SPOTS := [
	["living", "客厅", Vector3(-3.9,.025,.3)],
	["dining", "餐厅", Vector3(-2.6,.025,-2.6)],
	["kitchen", "厨房", Vector3(4.2,.032,-4.0)],
	["bath1", "一楼卫生间", Vector3(1.3,.035,-1.2)],
	["laundry", "洗衣间", Vector3(1.35,.035,.8)],
	["study1", "一楼工作书房", Vector3(2.6,.025,4.7)],
	["hall1", "一楼过厅", Vector3(-.05,.025,2.3)],
	["master", "主卧", Vector3(-2.2,3.025,-3.7)],
	["bedroom", "次卧", Vector3(1.1,3.025,-3.6)],
	["computer", "电脑房", Vector3(2.5,3.025,4.4)],
	["study2", "二楼书房", Vector3(-3.9,3.025,.1)],
	["bath2", "二楼卫生间", Vector3(1.3,3.035,-1.2)],
	["dressing", "衣帽间", Vector3(1.35,3.035,.8)],
	["reading", "阅读角", Vector3(-.6,3.025,4.35)],
	["terrace", "露台", Vector3(-3.5,3.035,3.6)],
	["hall2", "二楼过厅", Vector3(-.1,3.025,-.2)],
	["basement", "地下室", Vector3(4.1,-2.675,-2.8)]
]

func mat(color: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .72
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = .35
	return m

func box(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat(color)
	parent.add_child(mesh)
	mesh.position = pos
	if solid:collision(parent, pos, size)
	return mesh

func collision(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	parent.add_child(body)
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius*.87
	shape.height = height
	mesh.mesh = shape
	mesh.material_override = mat(color)
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

func item(id: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = id
	root.add_child(n)
	n.position = pos
	items[id] = n
	return n

func sign_at(parent: Node3D, text: String, pos: Vector3, size := 32) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = .0007
	label.modulate = Color("ffe4ac")
	label.outline_modulate = Color("242e29")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei"])
	label.font = font
	parent.add_child(label)
	label.position = pos
	return label

func build(parent: Node3D, game: Node) -> void:
	root = parent
	# South living arch becomes the tutorial door. Block the alternate north route.
	door = load("res://scripts/villa_door.gd").new()
	door.name = "DayOneLivingDoor"
	door.door_title = "客厅门把手"
	door.leaf_width = 1.315
	door.open_angle = -100
	door.position = Vector3(-.8,0,4.138)
	door.rotation.y = -PI/2
	var leaf := AnimatableBody3D.new()
	leaf.name = "Leaf"
	leaf.collision_layer = 1
	leaf.collision_mask = 2
	door.add_child(leaf)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.315,2.13,.055)
	col.shape = shape
	col.position = Vector3(.6575,1.1,0)
	leaf.add_child(col)
	box(leaf,"WoodPanel",col.position,shape.size,Color("b9a786"))
	for side in [-1,1]:
		box(leaf,"Handle",Vector3(1.12,.58,side*.065),Vector3(.2,.035,.07),Color("d6b16b"))
	root.add_child(door)
	# High visible temporary partitions also stop jumping around the tutorial.
	for data in [[Vector3(-.05,1.4,3.15),Vector3(1.48,2.8,.12)], [Vector3(-.8,1.4,.75),Vector3(.12,2.8,1.48)], [Vector3(-3.4,1.4,-1.58),Vector3(5.18,2.8,.12)]]:
		var gate := Node3D.new()
		root.add_child(gate)
		gate.position = data[0]
		box(gate,"ClosedPartition",Vector3.ZERO,data[1],Color("889789"),true)
		sign_at(gate,"先完成客厅的事情",Vector3(0,0,.09),26)
		gates.append(gate)
	var table := item("table", Vector3(-3,0,4.65))
	box(table,"Tabletop",Vector3(0,.76,0),Vector3(1.45,.08,.8),Color("a17851"),true)
	for x in [-.6,.6]:
		for z in [-.29,.29]:box(table,"Leg",Vector3(x,.36,z),Vector3(.065,.72,.065),Color("75543d"),true)
	var stool := item("stool",Vector3(-2.45,0,3.76))
	box(stool,"Seat",Vector3(0,.32,0),Vector3(.58,.08,.52),Color("d1b27f"),true)
	for x in [-.22,.22]:
		for z in [-.19,.19]:box(stool,"Leg",Vector3(x,.14,z),Vector3(.05,.28,.05),Color("876747"),true)
	var note := item("note",Vector3(-3,.806,4.65))
	box(note,"Paper",Vector3.ZERO,Vector3(.40,.007,.29),Color("fff0ca"))
	for i in range(5):box(note,"Ink",Vector3(-.03,.005,-.09+i*.035),Vector3(.25,.002,.006),Color("526159"))
	sign_at(note,"今日的小纸条",Vector3(0,.28,0),26)
	var cup := item("cup",Vector3(-3,.81,4.65))
	cylinder(cup,Vector3(0,.09,0),.075,.18,Color("f1dec4"))
	cylinder(cup,Vector3(0,.179,0),.065,.004,Color("73aeb5"))
	var tray := item("tray",Vector3(-3.48,.809,4.65))
	cylinder(tray,Vector3.ZERO,.13,.014,Color("80a395"))
	sign_at(tray,"杯垫",Vector3(0,.14,0),22)
	var ruler := item("ruler",Vector3(4.15,.802,3.78))
	box(ruler,"WoodRuler",Vector3.ZERO,Vector3(.6,.018,.05),Color("edbf65"))
	for i in range(20):box(ruler,"Tick",Vector3(-.28+i*.028,.010,.009),Vector3(.003,.002,.025 if i%5==0 else .014),Color("514330"))
	sign_at(ruler,"尺子 · E 叼起",Vector3(0,.18,0),24)
	var yarn := item("yarn",Vector3(-5.18,.10,2.15))
	var sphere := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = .095
	ball.height = .19
	sphere.mesh = ball
	sphere.material_override = mat(Color("b77c58"))
	yarn.add_child(sphere)
	for i in range(8):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = .088
		torus.outer_radius = .099
		ring.mesh = torus
		ring.material_override = mat(Color("e4b284"))
		yarn.add_child(ring)
		ring.rotation = Vector3(i*.41,i*.74,i*.21)
	for i in range(4):
		var hair := box(yarn,"UnfamiliarFur",Vector3(-.018+i*.012,.088,.008),Vector3(.052,.002,.002),Color("d9dedb"))
		hair.rotation.y = i*.48
	var nest := item("nest",Vector3(-5,.08,4.85))
	cylinder(nest,Vector3.ZERO,.43,.14,Color("8caa9a"))
	cylinder(nest,Vector3(0,.08,0),.34,.02,Color("e5d5b6"))
	sign_at(nest,"我的窝",Vector3(0,.34,0),28)
	var switch := item("switch",Vector3(-.985,1.91,3.13))
	box(switch,"Plate",Vector3.ZERO,Vector3(.055,.20,.16),Color("e8e4d7"))
	box(switch,"Rocker",Vector3(-.035,0,0),Vector3(.035,.11,.08),Color("acc69e"))
	sign_at(switch,"灯的开关",Vector3(-.08,.20,0),24)
	# A wider top rail makes the thin television a fair landing surface for the cat capsule.
	box(root,"TVTopRail",Vector3(-1.28,1.315,2.57),Vector3(.32,.07,1.18),Color("343c3b"),true)
	# Cabinet side extension leaves enough take-off distance to clear the top rail.
	box(root,"TVSideShelf",Vector3(-1.66,.50,3.30),Vector3(.95,.04,.50),Color("94734f"),true)
	for x in [-2.04,-1.28]:box(root,"ShelfLeg",Vector3(x,.24,3.43),Vector3(.055,.48,.055),Color("75543d"),true)
	for data in PAPER_SPOTS:
		var paper := item("paper_"+data[0],data[2])
		box(paper,"Scrap",Vector3.ZERO,Vector3(.17,.012,.12),Color("fff0ce"))
		paper.rotation.y = float(items.size())*.74
		box(paper,"Fold",Vector3(.03,.012,0),Vector3(.012,.012,.11),Color("dccba6"))
		sign_at(paper,"纸片",Vector3(0,.15,0),18)
	# Two reachable optional mess props, separate from the tutorial's protected cup.
	var loose_cup := item("mess_cup",Vector3(-3.85,.46,1.72))
	cylinder(loose_cup,Vector3(0,.075,0),.065,.15,Color("c9d9cb"))
	var pot := item("mess_pot",Vector3(-4.25,.01,3.5))
	cylinder(pot,Vector3(0,.14,0),.15,.28,Color("be825d"))
	for i in range(5):box(pot,"Leaf",Vector3(sin(i)*.10,.36,cos(i)*.10),Vector3(.09,.27,.04),Color("728954"))
	# Scene already includes a ground-floor Workshop (not the upstairs Study).
	for n in game.get_tree().get_nodes_in_group("placed_furniture"):
		if n.get_meta("asset_id","")=="armchair" and n.get_meta("placement_room","")=="Living":n.position = Vector3(-3.3,0,-.55)
		if n.get_meta("asset_id","")=="decor_wall_art" and n.get_meta("placement_room","")=="Living":
			n.position = Vector3(-4.3,1.65,5.80)
			n.rotation.y = PI
		if n.get_meta("asset_id","")=="decor_television" and n.global_position.y<1:items["television"] = n
