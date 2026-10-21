extends "res://day2/world.gd"
const Details = preload("res://furniture_pack/quest_props/refined_props.gd")
const Circuit = preload("res://act3/lights_out.gd")
const SNACKS := [
	["MasterBedroom","主卧","tv_console",Vector3(.35,.521,.18)],
	["BedroomA","次卧 A","nightstand",Vector3(.15,.551,.12)],
	["Study","书房","desk",Vector3(-.06,.781,.13)],
	["Terrace","露台","coffee_table",Vector3(-.24,.451,.07)],
	["Reading","阅读角","decor_side_table",Vector3(0,.531,.17)],
	["Bathroom","卫生间","decor_bath_mat",Vector3(-.12,.016,.04)],
	["Dressing","衣帽储物","decor_basket",Vector3(-.40,.001,0)],
	["ComputerRoom","电脑房","decor_side_table",Vector3(0,.531,.01)]
]
var desk: Node3D
var chair: Node3D
var monitor: Node3D
var house_plant: Node3D
var plant_home: Transform3D
var source_book: Node3D
var source_band: Node3D
var book_home := Transform3D.IDENTITY
var dog_actor: Node3D
var dog_home_transform: Transform3D
var moved_dog_position := Vector3(3.05,0,-3.90)
var original_plate_home := Vector3.ZERO
var stair_guard: StaticBody3D
var lamps: Array = []
var screens: Array = []
var panel_leds: Array[MeshInstance3D] = []
var pad: Node3D
var light_sources: Array = []
var emissive_surfaces: Array = []
var previous_power_mode := -1

func target(id: String, pos: Vector3, label_: String, days_: Array) -> Node3D:
	var n := item(id,pos)
	Props.days(n,days_)
	n.set_meta("title",label_)
	sign_at(n,label_,Vector3(0,.18,0),23)
	return n

func build(parent: Node3D, game: Node) -> void:
	root = parent
	dog_actor = game.get_node("Apartment/Staircase/DogNest")
	dog_home_transform = dog_actor.global_transform
	original_plate_home = game.get_node("DayTwo").world.dog_home
	# A story gate occupies the upper-flight entrance while the companion is guarding.
	stair_guard = collision(root,Vector3(5.20,2.45,-1.13),Vector3(1.15,1.90,.16))
	stair_guard.name = "CompanionStairGuard"
	stair_guard.set_meta("quest_gate",true)
	for i in range(SNACKS.size()):
		var data: Array = SNACKS[i]
		var furniture_ := upstairs_furniture(game,data[2],data[0])
		assert(furniture_!=null,"Missing upstairs furniture: "+data[0])
		var snack := target("snack%d"%i,furniture_.to_global(data[3]),data[1]+"的小鱼干",[6])
		Props.bind(snack,furniture_)
		var dried := preload("res://act3/dried_anchovy.glb").instantiate() as Node3D
		snack.add_child(dried)
		dried.rotation.y = 0.0 if i==4 else .24+i*.57
		# Whole dried anchovies have a thin, curved body, sunken eye and papery fins.
		# Their mesh and skin are distinct from the fresh fish used on day four.
	desk = Props.furniture(game,"work_desk","ComputerRoom")
	chair = Props.furniture(game,"office_chair","ComputerRoom")
	monitor = Props.furniture(game,"dual_monitor","ComputerRoom")
	house_plant = Props.furniture(game,"decor_plant","ComputerRoom")
	assert(desk!=null and chair!=null and monitor!=null and house_plant!=null)
	plant_home = house_plant.global_transform
	var shelf := Props.furniture(game,"bookcase","ComputerRoom")
	source_book = shelf.get_node("Book")
	source_band = shelf.get_node_or_null("Spine_band")
	book_home = Transform3D(Basis.IDENTITY,desk.to_global(Vector3(.61,.783,.18)))
	var book := target("weight_book",book_home.origin,"厚书 · 2.0 kg",[7])
	Props.bind(book,source_book)
	var volume := Props.model(book,"book_blue")
	volume.scale = Vector3(1.25,2.0,1.15)
	var plant := target("weight_plant",desk.to_global(Vector3(-.65,.783,.17)),"桌上的花盆 · 3.2 kg",[7])
	Props.bind(plant,house_plant)
	pad = target("seat",chair.to_global(Vector3(0,.530,.035)),"座椅感应垫 · 放置 / 取回配重",[7])
	Props.bind(pad,chair)
	var soft := box(pad,"WovenSensorMat",Vector3.ZERO,Vector3(.46,.024,.36),Color("6b8582"))
	Props.fit_mesh(soft,Props.furniture(game,"coffee_table","Living").get_node("Rounded_tabletop").mesh,Vector3(.46,.024,.36))
	soft.material_override = load("res://furniture_pack/materials/sage_fabric.tres")
	for edge in [-1,1]:
		Details.rod(pad,"PipedEdge",Vector3(edge*.215,.014,-.15),Vector3(edge*.215,.014,.15),.0025,Details.material("pad_seam",Color("c4c9ba"),.86))
	var cable: Array[Vector3] = [Vector3(.23,0,.06),Vector3(.30,-.06,.08),Vector3(.31,-.38,.09),Vector3(.20,-.50,.14)]
	Details.line(pad,"SensorCable",cable,.003,Details.material("pad_cable",Color("344641"),.78))
	var computer := target("computer",monitor.to_global(Vector3(-.31,.34,.10)),"电脑屏幕 · E 进入 / 鼠标点击",[7])
	Props.bind(computer,monitor)
	var note := target("computer_note",desk.to_global(Vector3(-.12,.784,.20)),"电脑桌上的便签",[7])
	var paper := Props.model(note,"memo")
	paper.scale = Vector3(.62,1,.42)
	replace_print(paper,"memo","res://act3/textures/password_note.png")
	# Reuse the collected album on the ground-floor living-room table.
	items["clues"] = game.get_node("ActTwo").world.items.clues
	var panel := target("circuit",Vector3(3.05,3.80,2.80),"走廊配电板 · E 检查",[7])
	panel.rotation.y = PI
	build_panel(panel,game)
	for n in game.get_node("Apartment").find_children("*","Light3D",true,false):
		if not n is DirectionalLight3D:light_sources.append([n,n.light_energy])
	for mesh in game.get_node("Apartment").find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_surface_count()):
			var material_: Material = mesh.get_active_material(i)
			if material_ is StandardMaterial3D and material_.emission_enabled:
				emissive_surfaces.append([mesh,i,mesh.get_surface_override_material(i),material_,mesh.material_override])
	for device_id in ["dual_monitor","computer_tower","keyboard_mouse","audio_accessories"]:
		var device := Props.furniture(game,device_id,"ComputerRoom")
		if device==null:continue
		for mesh in device.find_children("*","MeshInstance3D",true,false):
			for i in range(mesh.mesh.get_surface_count()):
				var material_: Material = mesh.get_active_material(i)
				if material_ is StandardMaterial3D and material_.resource_name in ["screen","cyan"]:screens.append([mesh,i,material_])
	root.visible = false
	stair_guard.collision_layer = 0

func upstairs_furniture(game: Node, id: String, room: String) -> Node3D:
	for n in game.get_tree().get_nodes_in_group("placed_furniture"):
		if n.get_meta("asset_id","")==id and n.get_meta("placement_room","")==room and n.global_position.y>2.8:return n
	return null

func replace_print(n: Node3D, key: String, path: String) -> void:
	for mesh in n.find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_surface_count()):
			var original: Material = mesh.get_active_material(i)
			if original is StandardMaterial3D and original.resource_name==key:
				var printed := original.duplicate() as StandardMaterial3D
				printed.albedo_texture = load(path)
				mesh.set_surface_override_material(i,printed)

func build_panel(panel: Node3D, game: Node) -> void:
	var shell := box(panel,"EnamelCabinet",Vector3.ZERO,Vector3(.55,.64,.06),Color("c8cbbd"))
	Props.fit_mesh(shell,Props.furniture(game,"coffee_table","Living").get_node("Rounded_tabletop").mesh,Vector3(.55,.64,.06))
	shell.material_override = Details.material("panel_enamel",Color("c8cbbd"),.37,.15)
	box(panel,"InsetFrame",Vector3(0,0,.036),Vector3(.47,.49,.018),Color("283b3a"))
	for x in [-.245,.245]:
		for y in [-.285,.285]:
			var screw := cylinder(panel,Vector3(x,y,.04),.008,.007,Color("8f9e99"))
			screw.rotation.x = PI/2
			Details.rod(panel,"ScrewSlot",Vector3(x-.004,y,.045),Vector3(x+.004,y,.045),.001,Details.material("screw_slot",Color("3d4a49")))
	for i in range(16):
		var pos := Vector3((i%4-1.5)*.105,(1.5-i/4)*.108,.065)
		var socket := cylinder(panel,pos,.034,.015,Color("566861"))
		socket.rotation.x = PI/2
		var glass := ball(panel,pos+Vector3(0,.015,.012),Vector3(.035,.025,.012),Color("334238"))
		panel_leds.append(glass)
		var toggle := box(panel,"Rocker",pos+Vector3(0,-.023,.008),Vector3(.038,.016,.015),Color("e0ddcc"))
		var number := sign_at(panel,"%02d"%(i+1),pos+Vector3(.036,-.018,.009),14)
		number.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		number.pixel_size = .00045
		number.modulate = Color("c5c7ae")
		lamps.append(toggle)
	var marking := sign_at(panel,"照明 / 供电",Vector3(0,.274,.047),21)
	marking.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	marking.modulate = Color("31483f")
	marking.outline_size = 0

func refresh_circuit(bits: int) -> void:
	for i in range(panel_leds.size()):
		var on: bool = bits & (1<<i)!=0
		panel_leds[i].material_override = Details.material("panel_lit" if on else "panel_unlit",Color("e8d79b") if on else Color("2b3c35"),.27)
		if on:
			panel_leds[i].material_override.emission_enabled = true
			panel_leds[i].material_override.emission = Color("d3b16f")
		lamps[i].rotation.x = -.2 if on else .2

func set_power(blackout: bool, booted: bool) -> void:
	var mode := 0 if blackout else 2 if booted else 1
	if mode==previous_power_mode:return
	previous_power_mode = mode
	for entry in light_sources:
		entry[0].light_energy = 0.0 if blackout else entry[1]
	for entry in emissive_surfaces:
		if blackout:
			var unlit := entry[3].duplicate() as StandardMaterial3D
			unlit.emission_enabled = false
			if unlit.resource_name in ["cyan","screen","glow","decor_lamp"]:unlit.albedo_color = Color("293532")
			if entry[4]!=null:entry[0].material_override = unlit
			else:entry[0].set_surface_override_material(entry[1],unlit)
		else:
			entry[0].material_override = entry[4]
			entry[0].set_surface_override_material(entry[1],entry[2])
	for entry in screens:
		if not booted:
			entry[0].set_surface_override_material(entry[1],Details.material("unpowered_screen",Color("0e171d"),.32))
		else:
			var screen := entry[2].duplicate() as StandardMaterial3D
			screen.emission_enabled = true
			screen.emission = Color("6e9fae")
			screen.emission_energy_multiplier = .22
			entry[0].set_surface_override_material(entry[1],screen)

func reset_power() -> void:
	previous_power_mode = -1
	for entry in light_sources:entry[0].light_energy = entry[1]
	for entry in emissive_surfaces:
		entry[0].material_override = entry[4]
		entry[0].set_surface_override_material(entry[1],entry[2])
	for entry in screens:entry[0].set_surface_override_material(entry[1],entry[2])

func move_companion(released: bool, second) -> void:
	dog_actor.global_transform = Transform3D(Basis.IDENTITY,moved_dog_position) if released else dog_home_transform
	dog_actor.set_meta("free_to_roam",released)
	second.world.items.dog.global_position = dog_actor.global_position
	second.world.dog_home = moved_dog_position+Vector3(-.87,.012,.10) if released else original_plate_home
	second.world.items.dog_spot.global_position = second.world.dog_home
	stair_guard.collision_layer = 0 if released else 1

func place_weights(book_placed: bool, plant_placed: bool, holding: int, finished: bool) -> void:
	items.weight_book.global_transform = Transform3D(Basis.IDENTITY,chair.to_global(Vector3(-.14,.548,-.065))) if book_placed else book_home
	items.weight_book.visible = not finished and holding!=1
	source_book.visible = finished
	if source_band:source_band.visible = finished
	var plant_position := chair.to_global(Vector3(.13,.548,-.06)) if plant_placed else desk.to_global(Vector3(-.65,.783,.17))
	house_plant.global_transform = plant_home if finished else Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.48),plant_position)
	Props.activate(house_plant,holding!=2)
	items.weight_plant.global_position = house_plant.global_position
	items.weight_plant.visible = not finished and holding!=2
