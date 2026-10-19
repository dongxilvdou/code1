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
	Props.model(n,"pet_bowl")
	var kibble := Node3D.new()
	n.add_child(kibble)
	for i in range(14):
		ball(kibble,Vector3(sin(i*2.4)*.085,.066,cos(i*2.4)*.085),Vector3(.025,.018,.025),Color("aa7745"))
	food[id] = kibble
	sign_at(n,"猫碗" if id=="cat_bowl" else "大狗嚼的盘子",Vector3(0,.20,0),24)

func build(parent: Node3D, game: Node) -> void:
	root = parent
	for data in [["cloth_sofa",Vector3(-5.03,.53,2.15),Color("8ba8bc")],["cloth_chair",Vector3(-3.3,.465,-.55),Color("bca0b2")],["cloth_entry",Vector3(.03,.035,4.10),Color("d9c5a2")]]:
		var n := item(data[0],data[1])
		Props.model(n,["shirt_blue","shirt_red","shirt_gold"][["cloth_sofa","cloth_chair","cloth_entry"].find(data[0])])
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
	for data in [["WashStep",Vector3(1.65,0,1.14),[2]],["SinkStep",Vector3(1.23,0,-4.71),[1,2,3,4,5]]]:
		var step := Node3D.new()
		step.name = data[0]
		root.add_child(step)
		step.position = data[1]
		Props.model(step,"step_stool")
		collision(step,Vector3(0,.305,0),Vector3(.43,.035,.42))
		Props.days(step,data[2])
