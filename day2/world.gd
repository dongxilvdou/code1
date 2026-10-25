extends "res://day1/world.gd"
var washer_hinge: Node3D
var washer_selector: Node3D
var stream
var basin_position := Vector3.ZERO
var dog_home := Vector3.ZERO
var sink_cabinet: Node3D
var dog_tail: Node3D
var stains: Node3D
var food := {}
var original_bowls: Node3D

func ball(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = .5
	s.height = 1
	n.mesh = s
	n.material_override = mat(color)
	parent.add_child(n)
	n.position = pos
	n.scale = size
	return n

func bowl(id: String, pos: Vector3, color: Color) -> void:
	var n := item(id,pos)
	# Use the actual ceramic bowls already furnished in this house.
	var ceramic: MeshInstance3D = original_bowls.get_node("Bowl2" if id=="dog_bowl" else "Bowl")
	ceramic.reparent(n,false)
	ceramic.position = Vector3.ZERO
	ceramic.scale = Vector3(1.65,1.65,1.65)
	Props.bind(n,ceramic)
	var kibble := Node3D.new()
	n.add_child(kibble)
	for i in range(14):
		ball(kibble,Vector3(sin(i*2.4)*.085,.066,cos(i*2.4)*.085),Vector3(.025,.018,.025),Color("aa7745"))
	food[id] = kibble
	sign_at(n,"猫碗" if id=="cat_bowl" else "大狗嚼的盘子",Vector3(0,.20,0),24)

func build(parent: Node3D, game: Node) -> void:
	root = parent
	original_bowls = Props.furniture(game,"decor_pet_bowls","Living")
	if original_bowls==null:original_bowls = Props.furniture(game,"decor_pet_bowls")
	assert(original_bowls!=null)
	# Keep its mat as the feeding station, remove only the baked-in fake food discs.
	original_bowls.global_position = Vector3(4.00,0,-2.88)
	for part in ["Water_or_food","Water_or_food2"]:original_bowls.get_node(part).hide()
	for data in [["cloth_sofa",Vector3(-5.03,.53,2.15),Color("8ba8bc")],["cloth_chair",Vector3(-3.3,.465,-.55),Color("bca0b2")],["cloth_entry",Vector3(.03,.035,4.10),Color("d9c5a2")]]:
		var n := item(data[0],data[1])
		if data[0]=="cloth_sofa":
			var sofa := Props.furniture(game,"sofa","Living")
			n.position = sofa.to_global(Vector3(-.10,.516,.39))
			n.rotation.y = sofa.global_rotation.y
			Props.model(n,"shirt_draped")
		elif data[0]=="cloth_chair":
			# The former .465 m anchor buried the flat shirt below the .51 m cushion.
			# Drape over the back facing the living room, visible/reachable at cat height.
			var chair := Props.furniture(game,"armchair","Living")
			var back := chair.get_node("Back_shell") as MeshInstance3D
			var bounds := back.transform*back.get_aabb()
			n.position = chair.to_global(Vector3(0,bounds.end.y+.008,bounds.position.z+.015))
			n.rotation.y = chair.global_rotation.y+PI
			var shirt := Props.model(n,"shirt_draped")
			for mesh in shirt.find_children("*","MeshInstance3D",true,false):
				for surface in range(mesh.mesh.get_surface_count()):
					var material_: Material = mesh.get_active_material(surface)
					if material_ is StandardMaterial3D and material_.resource_name=="blue":
						# This packed fabric map needs its R/G/B-aware furniture shader.
						var warm := load("res://furniture_pack/materials/sage_fabric.tres").duplicate() as ShaderMaterial
						warm.set_shader_parameter("tint",Color("c48a73"))
						mesh.set_surface_override_material(surface,warm)
		else:Props.model(n,["shirt_blue","shirt_red","shirt_gold"][["cloth_sofa","cloth_chair","cloth_entry"].find(data[0])])
		Props.days(n,[2])
		sign_at(n,"待洗衣服",Vector3(0,.16,0),23)
	# Use the existing washing machine; its door is now a real rotating hinge.
	for n in game.get_tree().get_nodes_in_group("placed_furniture"):
		if n.get_meta("asset_id","")=="sink_cabinet" and n.global_position.y<1:
			sink_cabinet = n
		if n.get_meta("asset_id","")=="decor_washing_machine":
			washer_hinge = Node3D.new()
			n.add_child(washer_hinge)
			washer_hinge.position = Vector3(-.18,.4,.32)
			for part in ["Door_ring","Door_glass","Handle","Handle_mount","Handle_mount2"]:
				var mesh := n.get_node_or_null(part)
				if mesh:mesh.reparent(washer_hinge,true)
			washer_selector = n.get_node("Selector")
	var loading := item("washer_door",Vector3(2.33,.40,.86))
	Props.bind(loading,washer_hinge.get_parent())
	sign_at(loading,"洗衣机门 · E",Vector3(-.03,.16,0),23)
	var dial := item("washer_dial",washer_selector.global_position+Vector3(0,.02,.025))
	Props.bind(dial,washer_selector)
	dial.set_meta("dial_base",washer_selector.rotation)
	box(washer_selector,"Indicator",Vector3(0,.022,-.020),Vector3(.006,.003,.024),Color("3b5149"))
	# The original rotary selector is the only visible knob.
	Props.days(loading,[2])
	Props.days(dial,[2])
	sign_at(dial,"洗衣旋钮",Vector3(0,.17,0),23)
	var dispenser := item("feeder",Vector3(4.75,0,-2.77))
	# Face the central kitchen aisle, like the adjacent preparation cabinets.
	dispenser.rotation.y = PI
	Props.model(dispenser,"feeder")
	collision(dispenser,Vector3(0,.37,0),Vector3(.63,.74,.44))
	sign_at(dispenser,"食物给予器",Vector3(0,1.18,0),28)
	bowl("cat_bowl",Vector3(4.00,.01,-2.88),Color("9ab9ad"))
	var actor: Node3D = game.get_node("Apartment/Staircase/DogNest")
	# West side of the landing, clear of the south crossing between flights.
	dog_home = actor.global_position+Vector3(-.91,.012,0)
	bowl("dog_bowl",dog_home,Color("cbb17e"))
	var home := item("dog_spot",dog_home)
	sign_at(home,"大狗嚼的餐位",Vector3(0,.22,0),22)
	stains = Node3D.new()
	items.dog_bowl.add_child(stains)
	for i in range(7):ball(stains,Vector3(sin(i*2.1)*.08,.069,cos(i*2.1)*.08),Vector3(.025,.004,.017),Color("78543b"))
	# Keep the existing feeding quest ID, referring to the real landing companion.
	# The proxy has no duplicate visual/collider; the dog remains present on day 1.
	var dog := item("dog",actor.global_position)
	dog.set_meta("actor",actor)
	sign_at(dog,"大狗嚼",Vector3(0,.72,0),30)
	# Interact with the actual faucet, without a separate floating button/bottle.
	var spout := sink_cabinet.get_node("Tap_spout") as MeshInstance3D
	spout.rotation.x = deg_to_rad(135)
	# Also repair merged older villas whose cabinet shelf crosses the basin.
	sink_cabinet.get_node("Cabinet_shelf2").position.y = .61
	sink_cabinet.get_node("Collision/Solid_005").position.y = .61
	var nozzle := spout.to_global(Vector3(0,(spout.mesh as CylinderMesh).height*.5,0))
	basin_position = sink_cabinet.to_global(Vector3(0,.72,-.035))
	var tap := item("tap",nozzle)
	Props.bind(tap,sink_cabinet)
	Props.days(tap,[2])
	sign_at(tap,"水龙头 · E 冲洗狗盘",Vector3(0,.15,0),22)
	stream = preload("res://day2/water_stream.gd").new()
	stream.name = "RinseWater"
	root.add_child(stream)
	stream.configure(nozzle,basin_position.y+.072)
	# A small step beside the washer and sink supports ordinary cat jumps.
	for data in [["WashStep",Vector3(1.65,0,1.14),[2]],["SinkStep",Vector3(1.23,0,-4.71),[2,4]]]:
		var step := Node3D.new()
		step.name = data[0]
		root.add_child(step)
		step.position = data[1]
		Props.model(step,"step_stool")
		collision(step,Vector3(0,.305,0),Vector3(.43,.035,.42))
		Props.days(step,data[2])
