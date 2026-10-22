extends RefCounted
## A real 18-riser basement run alongside (not across) the upstairs entry.
const HOLE := Rect2(10.65,3.90,1.10,3.60)
const FOUNDATION := Rect2(-.125,-.125,12.25,12.25)

static func split_slab(builder, label: String, bounds: Rect2, top: float, thickness: float, key: String, parent: Node, solid: bool = true) -> void:
	split_rect(builder,label,bounds,HOLE,top,thickness,key,parent,solid)

static func split_site_slab(builder, label: String, bounds: Rect2, top: float, thickness: float, key: String, parent: Node, solid: bool = true) -> void:
	split_rect(builder,label,bounds,FOUNDATION,top,thickness,key,parent,solid)

static func split_rect(builder, label: String, bounds: Rect2, cutout: Rect2, top: float, thickness: float, key: String, parent: Node, solid: bool) -> void:
	# Four disjoint rectangles leave a true void through every ground layer.
	var x0 := bounds.position.x
	var z0 := bounds.position.y
	var x1 := bounds.end.x
	var z1 := bounds.end.y
	for rect in [Rect2(x0,z0,cutout.position.x-x0,z1-z0),Rect2(cutout.end.x,z0,x1-cutout.end.x,z1-z0),Rect2(cutout.position.x,z0,cutout.size.x,cutout.position.y-z0),Rect2(cutout.position.x,cutout.end.y,cutout.size.x,z1-cutout.end.y)]:
		if rect.size.x>.001 and rect.size.y>.001:
			builder.rect_floor(label,rect.position.x,rect.position.y,rect.end.x,rect.end.y,top,thickness,key,parent,solid)

static func build(builder) -> void:
	var root: Node3D = builder.folder("Basement")
	root.add_to_group("basement_geometry",true)
	var floor_key := "concrete"
	builder.finish_material("basement_wall","c9c7bc","plaster_detail",Vector3.ONE*2,.89,.0004)
	var wall_key := "basement_wall"
	# Preserve the original landing and stair collision; the west doorway opens
	# directly into the separate, editor-visible laboratory scene.
	var surfaces: Array = []
	builder.stair_collision("BasementLanding",builder.at(10.61,-2.78,3.20),Vector3(2.42,.16,1.60),root)
	surfaces.append(builder.volume(builder.at(10.61,-2.78,3.20),Vector3(2.42,.16,1.60)))
	builder.rect_floor("LandingCeiling",9.40,2.40,10.62,4.00,-.29,.04,"villa_ceiling",root,false)
	builder.rect_floor("LandingCeilingNorth",10.62,2.40,11.82,3.90,-.29,.04,"villa_ceiling",root,false)
	for i in range(18):
		var top := -(i+1)*.15
		var z := 7.50-(i+.5)*.20
		var bottom := -2.86
		builder.stair_collision("BasementStep%02d" % (i+1),builder.at(11.20,(top+bottom)*.5,z),Vector3(1.10,top-bottom,.202),root)
		surfaces.append(builder.volume(builder.at(11.20,(top+bottom)*.5,z),Vector3(1.10,top-bottom,.20)))
		builder.box("BasementNosing",builder.at(11.20,top-.016,z+.101),Vector3(1.12,.024,.016),"villa_trim",false,root)
	builder.union_mesh("BasementTreadsAndLanding",surfaces,[floor_key],root,-2.7)
	# Retaining walls, a white ceiling over the landing, and a safe lower end.
	for x in [10.60,11.80]:
		builder.box("ShaftRetainingWall",builder.at(x,-1.42,5.70),Vector3(.12,2.90,3.60),wall_key,true,root)
	builder.box("LandingNorthWall",builder.at(10.62,-1.40,2.35),Vector3(2.55,2.60,.12),wall_key,true,root)
	builder.box("LandingEastWall",builder.at(11.82,-1.40,3.2),Vector3(.12,2.60,1.60),wall_key,true,root)
	builder.box("BasementEntranceFascia",builder.at(11.20,-.14,7.50),Vector3(1.11,.28,.025),wall_key,false,root)
	# Finish the exposed NORTH slab edge, with 18mm of real relief from the
	# slab's cut plane. No collision is added to the existing stair route.
	builder.box("BasementNorthSoffit",builder.at(11.20,-.145,3.906),Vector3(1.11,.29,.024),wall_key,false,root)
	# At the bottom a short gallery remains walkable, not an open drop into the void.
	builder.box("LandingSouthGuard",builder.at(9.94,-1.40,4.06),Vector3(1.22,2.60,.12),wall_key,true,root)
	for x in [10.62,11.78]:
		builder.rail("BasementMouthGuard",builder.at(x,0,7.05),builder.at(x,0,7.48),.90,root)
		builder.rod(builder.at(x,.72,7.40),builder.at(x,-1.82,3.98),.024,"hardware",root)
	for z in [6.8,5.3,3.2]:
		var light := OmniLight3D.new()
		light.name = "BasementWarmLight"
		light.position = builder.at(11.19,-.30 if z>6 else -1.0 if z>4 else -1.55,z)
		light.light_color = Color(1,.88,.72)
		light.light_energy = .65
		light.omni_range = 3.2
		builder.attach(light,root)
		builder.box("BasementWallLight",light.position+Vector3(.52,.12,0),Vector3(.025,.12,.15),"glow",false,root)
	builder.room_sign("地下室",11.86,7.80,1.04,-90,builder.ground_floor)
	root.set_meta("floor_y",-2.7)
	root.set_meta("risers",18)
	var lab: Node3D = load("res://scenes/basement/medical_laboratory.tscn").instantiate()
	builder.attach(lab,root)
