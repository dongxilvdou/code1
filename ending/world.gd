extends Node3D
const Art = preload("res://furniture_pack/quest_props/refined_props.gd")
const Props = preload("res://furniture_pack/quest_props/props.gd")
var items := {}
var equipment: Node3D
var cage: Node3D
var grille: Node3D
var path: Node3D
var chamber: Node3D

func material(key: String, tint: Color, metal := 0.0) -> StandardMaterial3D:
	return Art.material("ending_"+key,tint,.58,metal)

func block(parent: Node3D, title: String, pos: Vector3, size_: Vector3, m: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new();mesh.size=size_
	return Art.mesh_node(parent,title,mesh,m,pos)

func cylinder(parent: Node3D, title: String, pos: Vector3, radius: float, height: float, m: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=48
	return Art.mesh_node(parent,title,mesh,m,pos)

func sign_(parent: Node3D, text_: String, pos: Vector3, size_ := 24) -> Label3D:
	var label := Label3D.new();label.text=text_;label.position=pos;label.font_size=size_;label.pixel_size=.0015
	label.modulate=Color("dfdfc8");label.outline_size=3;label.no_depth_test=false
	parent.add_child(label)
	return label

func target(id: String, pos: Vector3, title: String, source: Node3D = null) -> Node3D:
	var n := Node3D.new();n.name=id;add_child(n);n.global_position=pos
	Props.days(n,[11]);n.set_meta("title",title);items[id]=n
	if source:Props.bind(n,source)
	return n

func build(game: Node) -> void:
	equipment=Props.furniture(game,"examination_table","BasementLaboratory")
	assert(equipment!=null,"Ending requires the furnished laboratory examination table")
	cage=game.get_node("Apartment/Basement/MedicalLaboratory/ObservationCage_01")
	# The existing examination table supplies the base, lifting column and mattress.
	# Only its conversion module and controls are added, never another table or cage.
	chamber=Node3D.new();chamber.name="ConversionModule";add_child(chamber)
	chamber.global_transform=equipment.global_transform
	var steel:=material("brushed_steel",Color("899b97"),.75)
	var dark:=material("rubber",Color("253c3a"))
	for y in [.95,1.47]:
		var ring:=TorusMesh.new();ring.inner_radius=.31;ring.outer_radius=.345;ring.rings=48;ring.ring_segments=12
		Art.mesh_node(chamber,"ChamberRim",ring,steel,Vector3(0,y,0))
	for x in [-.24,.24]:
		Art.rod(chamber,"ChamberSpine",Vector3(x,.95,-.23),Vector3(x,1.47,-.23),.014,steel)
	var glass:=material("chamber_glass",Color(.39,.67,.65,.17),.1)
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	# Curved back panel leaves the front open and the old padded table visible.
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(40):
		for corner in [Vector2(i,0),Vector2(i+1,1),Vector2(i+1,0),Vector2(i,0),Vector2(i,1),Vector2(i+1,1)]:
			var a: float=PI*.05+corner.x/40.0*PI*.90
			surface.add_vertex(Vector3(cos(a)*.326,.97+corner.y*.48,-sin(a)*.326))
	surface.generate_normals();Art.mesh_node(chamber,"CurvedGlassShield",surface.commit(),glass)
	for x in [-.24,.24]:
		for y in [1.02,1.41]:cylinder(chamber,"SpineFastener",Vector3(x,y,-.23),.026,.018,steel)
	block(chamber,"ControlHousing",Vector3(.40,.45,.23),Vector3(.20,.24,.10),dark)
	var button:=cylinder(chamber,"EmergencyRedButton",Vector3(.40,.47,.296),.045,.025,material("red_button",Color("b94032"),.1))
	button.rotation.x=PI/2
	var bezel:=TorusMesh.new();bezel.inner_radius=.043;bezel.outer_radius=.054
	var collar:=Art.mesh_node(chamber,"ButtonBezel",bezel,steel,Vector3(.40,.47,.297));collar.rotation.x=PI/2
	for i in range(3):block(chamber,"ReadoutBar",Vector3(.36+i*.036,.53,.287),Vector3(.022,.008,.004),material("readout",Color("85ad9e")))
	Art.line(chamber,"ControlCable",[Vector3(.43,.35,.20),Vector3(.44,.14,.2),Vector3(.06,.08,.2)],.012,dark)
	sign_(chamber,"CONVERSION / C-031",Vector3(0,1.51,.30),20)
	sign_(chamber,"转化装置",Vector3(0,.71,.59),25)
	target("device",equipment.to_global(Vector3(.35,.40,.46)),"检查转化装置",equipment)
	var traces:=target("cage",cage.to_global(Vector3(.02,.062,-.55)),"观察笼里的旧抓痕与猫毛",cage)
	fur(traces,Vector3(-.12,.004,.04),22)
	for i in range(4):
		Art.line(traces,"OldClawScratch",[Vector3(-.12+i*.024,.002,-.08),Vector3(-.10+i*.024,.002,-.22),Vector3(-.08+i*.024,.002,-.29)],.0018,material("scratch",Color("514d3f")))
	path=Node3D.new();path.name="OldEscapeTrail";add_child(path)
	for i in range(12):
		var pos:=Vector3(-4.2-i*.082,-2.694,-.69-i*.078)
		paw(path,pos+Vector3(.028 if i%2==0 else -.028,0,0))
	var vent:=target("vent",Vector3(-5.255,-2.43,-1.73),"监控底下的通风口")
	vent.rotation.y=PI/2
	block(vent,"VentRecess",Vector3(0,0,-.026),Vector3(.68,.46,.035),material("vent_shadow",Color("101c1d")))
	for x in [-.36,.36]:block(vent,"VentSideFrame",Vector3(x,0,0),Vector3(.04,.52,.07),steel)
	for y in [-.25,.25]:block(vent,"VentFrame",Vector3(0,y,0),Vector3(.76,.04,.07),steel)
	grille=Node3D.new();grille.name="LooseVentGrille";vent.add_child(grille);grille.position=Vector3(-.34,0,.045)
	for i in range(8):
		var slat:=block(grille,"Louver",Vector3(.34,-.195+i*.055,0),Vector3(.65,.025,.026),steel)
		slat.rotation.x=-.35
	for x in [0,.68]:block(grille,"LouverRail",Vector3(x,0,0),Vector3(.018,.43,.028),steel)
	for x in [-.32,.32]:
		for y in [-.215,.215]:
			var screw:=cylinder(vent,"SlottedScrew",Vector3(x,y,.045),.009,.005,steel);screw.rotation.x=PI/2
			Art.rod(vent,"ScrewSlot",Vector3(x-.005,y,.049),Vector3(x+.005,y,.049),.001,dark)
	fur(vent,Vector3(.23,-.23,.047),18,true)
	for i in range(3):Art.rod(vent,"VentClawMark",Vector3(-.17+i*.026,-.20,.047),Vector3(-.13+i*.026,-.09,.047),.002,material("scratch",Color("514d3f")))
	var camera:=target("camera",Vector3(-5.23,-.92,-1.73),"监控摄像头")
	camera.rotation.y=PI/2
	block(camera,"CameraMount",Vector3.ZERO,Vector3(.12,.18,.035),steel)
	Art.rod(camera,"CameraBracket",Vector3(0,0,.02),Vector3(0,-.09,.18),.018,steel)
	var body:=cylinder(camera,"CameraHousing",Vector3(0,-.08,.26),.073,.22,material("camera_enamel",Color("c6d0c5"),.2));body.rotation.x=PI/2
	var lens:=cylinder(camera,"BlackLensBarrel",Vector3(0,-.08,.38),.051,.06,dark);lens.rotation.x=PI/2
	var optic:=cylinder(camera,"CoatedGlassLens",Vector3(0,-.08,.413),.037,.006,material("optic",Color("385d67"),.8));optic.rotation.x=PI/2
	Art.ellipsoid(camera,"LensReflection",Vector3(-.011,-.065,.418),Vector3(.010,.007,.003),material("lens_glint",Color("a0c0bc")))
	Art.ellipsoid(camera,"RecordingLED",Vector3(.058,-.08,.359),Vector3(.012,.012,.012),material("recording_led",Color("b4593d")))
	for i in range(4):block(camera,"CoolingFin",Vector3(.071,-.08+i*.015,.24),Vector3(.004,.004,.09),dark)
	hide()

func paw(parent: Node3D, pos: Vector3) -> void:
	var m:=material("dusty_pawprint",Color("696955"))
	Art.ellipsoid(parent,"OldPawPad",pos,Vector3(.032,.0015,.027),m)
	for j in range(3):Art.ellipsoid(parent,"OldToePrint",pos+Vector3((j-1)*.013,0,-.021),Vector3(.012,.0015,.015),m)

func fur(parent: Node3D, pos: Vector3, count: int, vertical := false) -> void:
	for i in range(count):
		var a:=i*2.399
		var radius:=.2+fmod(i*.618,1.0)*.8
		var start:=pos+Vector3(sin(a)*.045*radius,cos(a)*.003,cos(a)*.028*radius)
		var end:=start+Vector3(.018+sin(i)*.01,.004,-.012)
		if vertical:end=start+Vector3(sin(a)*.018,.020,0)
		Art.line(parent,"CaughtCatHair",[start,start.lerp(end,.5)+Vector3(0,.003,.002),end],.00065,material("old_fur_pale" if i%3 else "old_fur_dark",Color("d9cfb4") if i%3 else Color("746859")))

func restore(enabled: bool, discovered: bool) -> void:
	visible=enabled
	for n in items.values():Props.activate(n,enabled)
	grille.rotation.y=-1.05 if discovered else -.12
	path.visible=enabled
