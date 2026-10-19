extends RefCounted
## All coordinates are world metres. This additive set never rebuilds villa.tscn.
const Props = preload("res://furniture_pack/quest_props/props.gd")
var root: Node3D
var items := {}
var gates: Array[Node3D] = []
var door: Node3D
const TV_STEP_POSITION := Vector3(-1.89,.50,3.20)
const TV_STEP_SIZE := Vector3(.60,.04,.50)
const TV_RETRY_POSITION := TV_STEP_POSITION+Vector3(0,.04,0)
const PAPER_SPOTS := [
	["living", "客厅", Vector3(-3.9,.025,.3)],
	["dining", "餐厅", Vector3(-2.6,.025,-2.6)],
	["kitchen", "厨房", Vector3(4.2,.032,-4.0)],
	["study1", "一楼书房", Vector3(2.6,.025,4.7)]
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
		collision(gate,Vector3.ZERO,data[1])
		var curtain := MeshInstance3D.new()
		curtain.name = "StripedPartition"
		var plane := QuadMesh.new()
		plane.size = Vector2(maxf(data[1].x,data[1].z),data[1].y)
		curtain.mesh = plane
		curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var stripes := ShaderMaterial.new()
		stripes.shader = preload("res://day1/restriction_stripes.gdshader")
		stripes.set_shader_parameter("width_m",plane.size.x)
		stripes.set_shader_parameter("height_m",plane.size.y)
		curtain.material_override = stripes
		if data[1].x < data[1].z:curtain.rotation.y = PI/2
		gate.add_child(curtain)
		# Original 26 px label enlarged exactly fivefold, at cat-readable height.
		sign_at(gate,"先完成客厅\n的事情",Vector3(0,-.80,0),130)
		gates.append(gate)
	# Reuse the furnished living room: no extra teaching table or chair.
	var existing_table := Props.furniture(game,"coffee_table","Living")
	existing_table.rotation.y = 0
	var table := item("table",existing_table.global_position)
	Props.bind(table,existing_table)
	table.set_meta("surface_top",.45)
	table.set_meta("surface_half",Vector2(.52,.32))
	var chair := Props.furniture(game,"armchair","Living")
	var stool := item("stool",Vector3(-3.3,0,-.55))
	Props.bind(stool,chair)
	stool.set_meta("surface_top",.46)
	stool.set_meta("surface_half",Vector2(.43,.40))
	var top := existing_table.global_position+Vector3(0,.454,0)
	var note := item("note",top+Vector3(.12,0,0))
	Props.model(note,"memo")
	Props.days(note,[1,2,3,4,5])
	sign_at(note,"今日的小纸条",Vector3(0,.20,0),23)
	var cup := item("cup",note.position+Vector3(0,.006,0))
	Props.model(cup,"mug")
	Props.days(cup,[1])
	var tray := item("tray",top+Vector3(-.28,0,0))
	Props.model(tray,"coaster")
	Props.days(tray,[1])
	sign_at(tray,"杯垫",Vector3(0,.14,0),22)
	var ruler := item("ruler",Vector3(4.065,.794,3.725))
	Props.model(ruler,"ruler")
	Props.days(ruler,[2])
	sign_at(ruler,"书房桌上的尺子 · E 叼起",Vector3(0,.14,0),23)
	var yarn := item("yarn",Vector3(-5.18,.10,2.15))
	Props.model(yarn,"yarn")
	Props.days(yarn,[2,4,5],[2])
	var nest := item("nest",Vector3(-5,0,4.85))
	Props.model(nest,"cat_bed")
	sign_at(nest,"我的窝",Vector3(0,.34,0),28)
	var switch := item("switch",Vector3(-.985,1.91,3.13))
	box(switch,"Plate",Vector3.ZERO,Vector3(.055,.20,.16),Color("e8e4d7"))
	box(switch,"Rocker",Vector3(-.035,0,0),Vector3(.035,.11,.08),Color("acc69e"))
	sign_at(switch,"灯的开关",Vector3(-.08,.20,0),24)
	# A wider top rail makes the thin television a fair landing surface for the cat capsule.
	box(root,"TVTopRail",Vector3(-1.28,1.315,2.57),Vector3(.32,.07,1.18),Color("343c3b"),true)
	# A freestanding step stool clears even the cabinet handles by 10 cm.
	# The former extension shared its .52 m top surface with the cabinet.
	var tv_stool := box(root,"TVSideShelf",TV_STEP_POSITION,TV_STEP_SIZE,Color("94734f"),true)
	Props.fit_mesh(tv_stool,existing_table.get_node("Rounded_tabletop").mesh,TV_STEP_SIZE)
	tv_stool.material_override = load("res://furniture_pack/materials/oak.tres")
	var leg_index := 0
	for x in [-.23,.23]:
		for z in [-.18,.18]:
			var leg := box(root,"ShelfLeg%d" % leg_index,Vector3(TV_STEP_POSITION.x+x,.24,TV_STEP_POSITION.z+z),Vector3(.055,.48,.055),Color("75543d"),true)
			Props.fit_mesh(leg,existing_table.get_node("Tapered_leg").mesh,Vector3(.055,.48,.055))
			leg.material_override = load("res://furniture_pack/materials/walnut.tres")
			leg_index += 1
	for data in PAPER_SPOTS:
		var paper := item("paper_"+data[0],data[2])
		var visual := Props.model(paper,"memo")
		visual.scale = Vector3(.62,1,.43)
		paper.rotation.y = float(items.size())*.74
		Props.days(paper,[1])
		sign_at(paper,"纸片",Vector3(0,.15,0),18)
	# Two reachable optional mess props, separate from the tutorial's protected cup.
	var loose_cup := item("mess_cup",Vector3(-3.85,.46,1.72))
	Props.model(loose_cup,"mug")
	Props.days(loose_cup,[1,2])
	# This optional interaction belongs to a real house plant, not another blocky pot.
	var plant := Props.furniture(game,"decor_plant","Living")
	var pot := item("mess_pot",plant.global_position)
	Props.bind(pot,plant)
	Props.days(pot,[1,2])
	# Tabletop decor is set at the rear, leaving the note and mug accessible.
	var decor := Props.furniture(game,"decor_books_vase","Living")
	decor.global_position = Vector3(-1.24,.52,3.05)
	decor.rotation.y = -PI/2
	# Scene already includes a ground-floor Workshop (not the upstairs Study).
	for n in game.get_tree().get_nodes_in_group("placed_furniture"):
		if n.get_meta("asset_id","")=="armchair" and n.get_meta("placement_room","")=="Living":n.position = Vector3(-3.3,0,-.55)
		if n.get_meta("asset_id","")=="decor_wall_art" and n.get_meta("placement_room","")=="Living":
			n.position = Vector3(-4.3,1.65,5.80)
			n.rotation.y = PI
		if n.get_meta("asset_id","")=="decor_television" and n.global_position.y<1:items["television"] = n
