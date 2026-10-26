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
var feeder_audio: AudioStreamPlayer3D
const FEEDER_SOUNDS := {
	"button":preload("res://day2/audio/feeder_button.wav"),
	"unlock":preload("res://day2/audio/feeder_unlock.wav"),
	"dispense":preload("res://day2/audio/feeder_dispense.wav")
}

func play_feeder_sound(kind: String) -> void:
	if not is_instance_valid(feeder_audio) or not FEEDER_SOUNDS.has(kind):return
	# Repeated E presses never stack motors or interrupt a portion already dispensing.
	if feeder_audio.playing and feeder_audio.stream==FEEDER_SOUNDS.dispense:return
	feeder_audio.stream=FEEDER_SOUNDS[kind]
	feeder_audio.volume_db=-22.0 if kind=="button" else -20.0 if kind=="unlock" else -18.0
	feeder_audio.max_db=feeder_audio.volume_db
	feeder_audio.play()

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
			n.set_meta("clothing_support",sofa)
			n.position = sofa.to_global(Vector3(-.10,.516,.39))
			n.rotation.y = sofa.global_rotation.y
			Props.model(n,"shirt_draped")
		elif data[0]=="cloth_chair":
			# The former .465 m anchor buried the flat shirt below the .51 m cushion.
			# Drape over the back facing the living room, visible/reachable at cat height.
			var chair := Props.furniture(game,"armchair","Living")
			n.set_meta("clothing_support",chair)
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
			build_washer_interior(n)
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
	feeder_audio=AudioStreamPlayer3D.new();feeder_audio.name="FeederSound"
	feeder_audio.position=Vector3(0,.44,.18)
	feeder_audio.unit_size=1.4;feeder_audio.max_distance=7.0
	feeder_audio.volume_db=-18;feeder_audio.max_db=-18
	dispenser.add_child(feeder_audio)
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

func clothing_target(id: String, eye: Vector3) -> Vector3:
	var bounds:=AABB()
	var first:=true
	for mesh in items[id].find_children("*","MeshInstance3D",true,false):
		var part: AABB=mesh.global_transform*mesh.get_aabb()
		bounds=part if first else bounds.merge(part)
		first=false
	if first:return items[id].global_position
	bounds=bounds.grow(.025)
	return Vector3(clampf(eye.x,bounds.position.x,bounds.end.x),clampf(eye.y,bounds.position.y,bounds.end.y),clampf(eye.z,bounds.position.z,bounds.end.z))

func build_washer_interior(machine: Node3D) -> void:
	machine.get_node("Appliance").hide()
	var shell:=Node3D.new();shell.name="WasherCabinetAndDrum";machine.add_child(shell)
	var enamel:=load("res://furniture_pack/materials/ivory.tres")
	for data in [[Vector3(-.29,.425,0),Vector3(.02,.85,.59)],[Vector3(.29,.425,0),Vector3(.02,.85,.59)],[Vector3(0,.84,0),Vector3(.56,.02,.59)],[Vector3(0,.018,0),Vector3(.56,.036,.59)],[Vector3(0,.425,-.285),Vector3(.56,.81,.02)]]:
		box(shell,"EnamelPanel",data[0],data[1],Color.WHITE).material_override=enamel
	var face:=SurfaceTool.new();face.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drum:=SurfaceTool.new();drum.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		var edges: Array[Vector2]=[]
		for a in [i*TAU/96.0,(i+1)*TAU/96.0]:
			var direction:=Vector2(cos(a),sin(a))
			edges.append(direction*minf(.3/maxf(.0001,absf(direction.x)),.32/maxf(.0001,absf(direction.y))))
		var a:=Vector2(cos(i*TAU/96.0),sin(i*TAU/96.0))*.173
		var b:=Vector2(cos((i+1)*TAU/96.0),sin((i+1)*TAU/96.0))*.173
		for point in [a,edges[0],edges[1],a,edges[1],b]:face.add_vertex(Vector3(point.x,.4+point.y,.296))
		for point in [Vector3(a.x,.4+a.y,.29),Vector3(a.x,.4+a.y,-.21),Vector3(b.x,.4+b.y,-.21),Vector3(a.x,.4+a.y,.29),Vector3(b.x,.4+b.y,-.21),Vector3(b.x,.4+b.y,.29)]:drum.add_vertex(point)
	face.generate_normals();drum.generate_normals()
	var front_material:=mat(Color("e8e6dc"));front_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	Props.Details.mesh_node(shell,"FrontPanelWithOpening",face.commit(),front_material)
	var steel:=Props.Details.material("washer_brushed_steel",Color("7d8585"),.3,.85)
	steel.cull_mode=BaseMaterial3D.CULL_DISABLED
	Props.Details.mesh_node(shell,"HollowSteelDrum",drum.commit(),steel)
	var back:=cylinder(shell,Vector3(0,.4,-.213),.174,.012,Color("637071"));back.rotation.x=PI/2;back.material_override=steel
	var holes:=MultiMeshInstance3D.new();holes.name="DrumPerforations"
	holes.multimesh=MultiMesh.new();holes.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	var dot:=SphereMesh.new();dot.radius=.5;dot.height=1;dot.radial_segments=8;dot.rings=4
	holes.multimesh.mesh=dot;holes.multimesh.instance_count=240
	holes.material_override=Props.Details.material("washer_hole",Color("20292b"),.9)
	holes.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;shell.add_child(holes)
	for ring in range(8):
		for hole in range(30):
			var a: float=(hole+(ring%2)*.5)*TAU/30
			holes.multimesh.set_instance_transform(ring*30+hole,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.006),Vector3(cos(a)*.171,.4+sin(a)*.171,.25-ring*.057)))
	for i in range(3):
		var a:=i*TAU/3
		Props.Details.rod(shell,"RaisedDrumLifter",Vector3(cos(a)*.153,.4+sin(a)*.153,-.17),Vector3(cos(a)*.153,.4+sin(a)*.153,.24),.012,steel)
	var seal:=TorusMesh.new();seal.inner_radius=.172;seal.outer_radius=.190
	var gasket:=Props.Details.mesh_node(shell,"RubberDoorSeal",seal,Props.Details.material("washer_seal",Color("343b3c"),.95),Vector3(0,.4,.3));gasket.rotation.x=PI/2
	var lamp:=OmniLight3D.new();lamp.name="DrumInteriorLight";lamp.position=Vector3(0,.48,.18);lamp.light_color=Color("cbdde2");lamp.light_energy=.18;lamp.omni_range=.7;shell.add_child(lamp)
