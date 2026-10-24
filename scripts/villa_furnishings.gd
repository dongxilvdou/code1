extends RefCounted
## Placement in reviewed plan coordinates (NW corner = 0,0), metres.
## Keep asset scenes referenced so later asset edits propagate to all rooms.
var builder
var parent: Node3D
var room := ""
var placed: Array = []
var groups: Dictionary = {}
var floor_y := 0.0

func select_room(name: String, floor_index: int, outside: bool = false) -> void:
	room = name
	floor_y = floor_index*3.0
	var section: Node3D = builder.garden if outside else builder.ground_floor if floor_index==0 else builder.upper_floor
	var key := str(floor_index)+"_"+name
	if not groups.has(key):
		var furnishing_root: Node3D = section.get_node_or_null("Furnishings")
		if furnishing_root == null:
			furnishing_root = Node3D.new()
			furnishing_root.name = "Furnishings"
			builder.attach(furnishing_root,section)
		parent = Node3D.new()
		parent.name = name
		builder.attach(parent,furnishing_root)
		groups[key] = parent
	else:parent = groups[key]

func put(id: String, x: float, z: float, yaw: float = 0, height: float = 0, scaling: Vector3 = Vector3.ONE) -> Node3D:
	var path := "res://furniture_pack/scenes/"+id+".tscn"
	var n: Node3D = load(path).instantiate()
	n.name = id.to_pascal_case()+"_%03d" % placed.size()
	n.position = builder.at(x,floor_y+height,z)
	n.rotation.y = deg_to_rad(yaw)
	n.scale = scaling
	n.set_meta("placement_room",room)
	n.set_meta("asset_id",id)
	n.set_script(load("res://furniture_pack/room_finish.gd"))
	n.set("room_style",room)
	n.add_to_group("placed_furniture",true)
	builder.attach(n,parent)
	placed.append({"asset":id,"room":room,"floor_y":floor_y,"plan_xz":[x,z],"height_m":height,"yaw_degrees":yaw,"scale":[scaling.x,scaling.y,scaling.z],"node":str(parent.get_parent().get_parent().name)+"/Furnishings/"+room+"/"+str(n.name)})
	return n

func curtains(x: float, z: float, yaw: float, width: float) -> void:
	put("decor_curtains",x,z,yaw,.18,Vector3(width/2.44,1,1))

func bedside(x: float, z: float, yaw: float) -> void:
	put("nightstand",x,z,yaw)
	put("decor_table_lamp",x,z,yaw,.55)

func bedroom() -> void:
	# Guest bedroom and second upstairs bedroom share a practical, reusable layout.
	put("bed",9.70,10.10)
	bedside(8.45,9.30,0)
	bedside(10.95,9.30,0)
	put("wardrobe",7.22,11.14,90)
	put("armchair",11.20,11.20,-125)
	put("decor_plant",11.50,9.48)
	put("decor_wall_art",9.7,9.02,0,1.48)
	put("decor_rug",9.65,10.64,90,.002,Vector3(.70,1,.87))
	curtains(9.4,11.78,180,3.15)
	curtains(11.78,10.5,-90,1.92)

func workshop() -> void:
	put("work_desk",10.15,9.55)
	put("drafting_kit",10.04,9.58,0,.778)
	put("decor_table_lamp",10.88,9.44,0,.778)
	put("dining_chair",10.15,10.42,180)
	put("bookcase",8.70,9.18)
	put("bookcase",7.02,10.88,90)
	put("armchair",11.13,11.13,-135)
	put("decor_side_table",10.18,11.21)
	put("decor_books_vase",10.18,11.21,0,.53)
	put("decor_plant",11.48,9.48)
	put("decor_wall_art",9.80,9.02,0,1.55)
	put("decor_rug",9.45,10.65,90,.002,Vector3(.70,1,.75))
	curtains(9.4,11.78,180,3.15)
	curtains(11.78,10.5,-90,1.92)

func computer_room() -> void:
	put("work_desk",10.12,9.55)
	put("dual_monitor",10.12,9.31,0,.778)
	put("keyboard_mouse",10.08,9.73,0,.778)
	put("audio_accessories",10.12,9.34,0,.778)
	put("computer_tower",11.39,9.60)
	put("office_chair",10.10,10.47,180)
	put("tv_console",7.12,10.85,90)
	put("router_power",7.12,10.85,90,.52)
	put("bookcase",8.70,9.18)
	put("armchair",11.17,11.16,-135)
	put("decor_side_table",10.15,11.28)
	put("decor_plant",8.20,11.35)
	put("decor_rug",9.65,10.65,90,.002,Vector3(.70,1,.75))
	put("decor_wall_art",9.8,9.02,0,1.80)
	curtains(9.4,11.78,180,3.15)
	curtains(11.78,10.5,-90,1.92)

func bathroom(floor_index: int) -> void:
	select_room("Bathroom",floor_index)
	put("bath_vanity",8.58,3.99,0,.007)
	put("toilet",7.35,5.72,180,.007)
	put("decor_shower",8.55,5.56,180,.007)
	put("decor_bath_mat",7.91,4.96,0,.008)
	put("decor_wall_shelf",7.38,6.03,180,1.32)
	put("decor_towels",7.38,6.00,180,1.357)
	put("decor_herb_pot",8.91,3.97,0,.817)
	put("decor_wall_art",8.56,3.70,0,1.41,Vector3(.75,.75,1))

func apply(target) -> void:
	builder = target
	select_room("Living",0)
	put("sofa",.77,8.00,90)
	put("coffee_table",2.54,8.00,90)
	put("tv_console",4.77,8.57,-90)
	put("decor_television",4.72,8.57,-90,.52)
	put("armchair",3.55,9.70,-145)
	put("floor_lamp",1.32,6.63)
	put("cat_tree",.69,5.64,90)
	put("bookcase",4.91,4.86,-90)
	put("decor_rug",2.48,8.12,0,.002)
	put("decor_books_vase",2.53,8.05,90,.45)
	# Keep the pots clear of the cat bed, sofa end and the two adjoining walls.
	put("decor_plant",.60,11.53,0,0,Vector3.ONE*.92)
	put("decor_plant",.60,9.65,0,0,Vector3.ONE*.92)
	put("decor_pet_bowls",4.84,9.71,-90,.003)
	# Solid west-wall pier before the window; leave clear space around the curtains.
	put("decor_wall_art",.16,4.97,90,1.52,Vector3(.85,.85,1))
	curtains(.22,7.20,90,3.34)
	curtains(2.55,11.78,180,3.43)

	select_room("Dining",0)
	put("dining_table",2.60,2.80)
	for x in [2.10,3.10]:
		put("dining_chair",x,1.95)
		put("dining_chair",x,3.65,180)
	put("dining_chair",1.28,2.80,90)
	put("dining_chair",3.92,2.80,-90)
	put("decor_fruit_bowl",2.6,2.8,0,.762)
	put("tv_console",.50,4.12,90)
	put("decor_books_vase",.50,4.12,90,.52)
	put("decor_wall_art",.20,4.14,90,1.30)
	put("decor_plant",.66,.66)
	put("decor_pendant",2.6,2.8,0,2.12)
	curtains(.22,2.0,90,2.32)

	select_room("Kitchen",0)
	for x in [6.00,7.26,8.70,9.34,9.98]:put("kitchen_cabinet",x,.49,0,.007)
	put("cooker",6.63,.49,0,.007)
	put("sink_cabinet",7.98,.49,0,.007)
	put("fridge",11.13,.57,0,.007)
	put("decor_prep_board",6.00,.49,0,.907)
	put("decor_herb_pot",8.74,.43,0,.907)
	put("decor_herb_pot",7.28,.43,0,.907)
	for x in [8.39,9.03]:put("kitchen_cabinet",x,3.16,180,.007)
	put("decor_fruit_bowl",8.39,3.16,180,.907)
	put("decor_prep_board",9.03,3.16,180,.907)
	put("decor_wall_art",10.60,.19,0,1.35,Vector3(.65,.65,1))

	select_room("Entry",0)
	put("decor_entry_console",6.38,10.68,-90)
	put("decor_books_vase",6.37,10.70,-90,.84)
	put("decor_wall_art",6.58,10.70,-90,1.32)
	put("decor_runner",5.94,10.48,0,.002)
	bathroom(0)
	select_room("Laundry",0)
	put("decor_washing_machine",8.70,6.86,-90,.007)
	put("decor_basket",7.91,7.04,0,.007)
	put("decor_wall_shelf",8.99,6.85,-90,1.26)
	put("decor_towels",8.94,6.85,-90,1.297)
	select_room("Workshop",0)
	workshop()

	select_room("MasterBedroom",1)
	put("bed",2.35,4.00,180)
	bedside(1.10,4.87,180)
	bedside(3.60,4.87,180)
	put("wardrobe",4.72,1.88,-90)
	put("tv_console",2.15,.48)
	put("decor_books_vase",2.25,.50,0,.52)
	put("armchair",.76,1.42,55)
	put("floor_lamp",.50,2.57)
	put("decor_plant",3.68,.62)
	put("decor_rug",2.35,3.35,0,.002)
	put("decor_wall_art",2.35,5.25,180,1.48,Vector3(1.3,1.3,1))
	curtains(2.30,.22,0,3.14)
	curtains(.22,2.4,90,3.10)

	select_room("BedroomA",1)
	put("bed",9.0,2.29,180)
	bedside(7.77,3.11,180)
	put("wardrobe",10.99,3.10,180)
	put("desk",6.16,.61)
	put("dining_chair",6.16,1.42,180)
	put("decor_table_lamp",6.58,.59,0,.78)
	put("decor_books_vase",5.92,.60,0,.78)
	put("bookcase",11.30,.40)
	put("decor_plant",7.35,.56)
	put("decor_rug",9.0,1.95,90,.002,Vector3(.72,1,.85))
	put("decor_wall_art",9.0,3.47,180,1.48)
	curtains(8.55,.22,0,4.02)
	curtains(11.78,1.95,-90,2.03)
	select_room("ComputerRoom",1)
	computer_room()
	bathroom(1)
	select_room("Dressing",1)
	put("decor_closet_rack",8.87,6.85,-90,.007)
	put("decor_basket",7.83,7.04,0,.007)
	put("decor_towels",8.85,6.84,-90,.322)

	select_room("Study",1)
	put("desk",.66,7.20,90)
	put("dining_chair",1.48,7.20,-90)
	put("decor_table_lamp",.64,6.80,90,.78)
	put("decor_books_vase",.64,7.51,90,.78)
	for x in [2.2,3.18,4.16]:put("bookcase",x,5.68)
	put("armchair",3.35,7.84,-120)
	put("decor_side_table",2.48,7.80)
	put("decor_books_vase",2.48,7.80,0,.53)
	put("floor_lamp",4.35,8.35)
	put("decor_rug",2.1,7.3,90,.002,Vector3(.60,1,.82))
	put("decor_wall_art",5.08,8.15,-90,1.32)
	curtains(.22,7.15,90,2.62)
	select_room("Reading",1)
	put("bookcase",6.43,9.68,-90)
	put("armchair",5.78,11.10,-145)
	put("decor_side_table",4.78,11.45)
	put("decor_books_vase",4.78,11.45,0,.53)
	put("floor_lamp",4.34,11.46)
	put("decor_plant",4.58,9.47)
	curtains(5.15,11.78,180,1.96)

	select_room("Terrace",1)
	put("garden_bench",.45,10.33,90,.01)
	put("garden_bench",1.90,11.53,180,.01)
	put("coffee_table",1.60,10.75,0,.01)
	put("decor_fruit_bowl",1.6,10.75,0,.46)
	put("decor_plant",3.43,11.50,0,.01)
	select_room("Garden",0,true)
	for x in [6.1,8.3]:put("garden_bench",x,-.62,180,-.003)
	put("coffee_table",7.15,-1.43,0,-.003)
	put("decor_plant",4.50,-.70,0,-.003)
	put("decor_plant",10.20,-.70,0,-.003)
	put("garden_bench",1.0,14.4,180,-.04)
	put("decor_plant",2.1,14.45,0,-.04)
	builder.root.set_meta("furniture_count",placed.size())
	builder.root.set_meta("furnished_rooms",groups.size())
	var layout_file: FileAccess
	for attempt in range(5):
		layout_file = FileAccess.open("res://furniture_pack/villa_layout.json",FileAccess.WRITE)
		if layout_file:break
		OS.delay_msec(150)
	if layout_file:
		layout_file.store_string(JSON.stringify({"units":"metres","origin":"NW building corner","placements":placed},"\t"))
		layout_file.close()
	else:push_error("Could not write furniture layout: "+error_string(FileAccess.get_open_error()))
