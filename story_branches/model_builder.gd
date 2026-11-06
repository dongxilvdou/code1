extends RefCounted
## Native metre-scale assets. Only the seven new subscenes are generated.
const Art = preload("res://furniture_pack/quest_props/refined_props.gd")
const Copy = preload("res://story_branches/data.gd")
const Visual = preload("res://story_branches/visual_state.gd")
var enamel := mat("enamel","cbd2c7",.18,.62)
var steel := mat("steel","899b97",.75,.48)
var rubber := mat("rubber","253c3a",0,.84)
var paper := mat("paper","d0c8ae",0,.90)
var red := mat("red","b94032",.10,.50)
var cloth := mat("cloth","929d91",0,.93)
var skin := mat("skin","c89e82",0,.8)
var hair := mat("hair","242925",0,.92)

func mat(key: String, hex: String, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new();m.resource_name="Branch_"+key;m.resource_local_to_scene=true;m.albedo_color=Color(hex);m.metallic=metal;m.roughness=rough
	return m

func root_(title: String, kind_: String) -> Node3D:
	var n := Node3D.new();n.name=title;n.set_script(Visual);n.kind=kind_;return n

func node(parent: Node3D, title: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new();n.name=title;parent.add_child(n);n.position=pos;return n

func box(parent: Node3D, title: String, pos: Vector3, size_: Vector3, m: Material, bevel := 0.0) -> MeshInstance3D:
	var mesh: Mesh
	if bevel>0:mesh=rounded(size_,minf(bevel,minf(size_.x,minf(size_.y,size_.z))*.35))
	else:
		var b := BoxMesh.new();b.size=size_;mesh=b
	return Art.mesh_node(parent,title,mesh,m,pos)

func rounded(size_: Vector3, r: float) -> ArrayMesh:
	# Four rounded corners and bevelled end rings, no extra colliders or scales.
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for edge in [Vector2(-size_.z*.5,r),Vector2(-size_.z*.5+r,0),Vector2(size_.z*.5-r,0),Vector2(size_.z*.5,r)]:
		var ring: Array[Vector3] = []
		for corner in range(4):
			var cx: float=(size_.x*.5-r)*(1 if corner in [0,3] else -1)
			var cy: float=(size_.y*.5-r)*(1 if corner<2 else -1)
			for i in range(4):
				var a: float=(corner*90+i*30)*PI/180
				ring.append(Vector3(cx+(r-edge.y)*cos(a),cy+(r-edge.y)*sin(a),edge.x))
		ring.reverse();rings.append(ring)
	for k in range(3):
		for i in range(16):
			var j := (i+1)%16
			for v in [rings[k][i],rings[k+1][j],rings[k+1][i],rings[k][i],rings[k][j],rings[k+1][j]]:st.add_vertex(v)
	for i in range(16):
		var j := (i+1)%16
		for v in [Vector3(0,0,-size_.z*.5),rings[0][j],rings[0][i],Vector3(0,0,size_.z*.5),rings[3][i],rings[3][j]]:st.add_vertex(v)
	st.generate_normals();return st.commit()

func cyl(parent: Node3D, title: String, pos: Vector3, radius: float, height: float, m: Material, axis_z := true) -> MeshInstance3D:
	var mesh := CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=16;mesh.rings=1
	var n := Art.mesh_node(parent,title,mesh,m,pos)
	if axis_z:n.rotation.x=PI/2
	return n

func label(parent: Node3D, title: String, text_: String, pos: Vector3, width: float, color := Color("d0c8ae")) -> Label3D:
	var longest := 1
	for line in text_.split("\n"):longest=maxi(longest,line.length())
	var l := Label3D.new();l.name=title;l.text=text_;l.position=pos;l.font=preload("res://quest_system/quest_theme.gd").font();l.font_size=48;l.pixel_size=width/longest/48
	l.modulate=color;l.outline_size=0;l.no_depth_test=false;parent.add_child(l);return l

func marker(parent: Node3D, title: String, pos: Vector3, aim := Vector3.INF, fov := 50.0) -> Marker3D:
	var n := Marker3D.new();n.name=title;parent.add_child(n);n.position=pos;n.set_meta("fov",fov)
	if aim!=Vector3.INF:n.transform=n.transform.looking_at(aim,Vector3.UP)
	return n

func screw(parent: Node3D, pos: Vector3) -> void:
	cyl(parent,"Screw",pos,.005,.003,steel)
	Art.rod(parent,"Slot",pos+Vector3(-.003,0,.002),pos+Vector3(.003,0,.002),.0007,rubber)

func module(parent: Node3D, title: String, pos: Vector3, burnt: bool) -> Node3D:
	var n := node(parent,title,pos)
	box(n,"Case",Vector3.ZERO,Vector3(.16,.042,.098),rubber,.008)
	box(n,"Seal",Vector3(0,.022,.006),Vector3(.115,.002,.058),paper)
	var l := label(n,"PartLabel","损坏 / 反向耦合" if burnt else "反向耦合",Vector3(0,.024,.006),.10,Color("3d4842"));l.rotation.x=-PI/2
	for i in range(6):box(n,"Contact",Vector3(-.055+i*.022,0,-.049),Vector3(.009,.018,.005),steel)
	if burnt:
		for i in range(4):box(n,"BurnMark",Vector3(-.068+i*.029,.022,-.02),Vector3(.020,.002,.022),mat("char","67513f",0,.98))
	return n

func retrofit() -> Node3D:
	var n := root_("Retrofit","retrofit")
	box(n,"ConsoleHousing",Vector3(.41,.48,.255),Vector3(.28,.29,.16),enamel,.008)
	box(n,"ConsoleFace",Vector3(.41,.48,.342),Vector3(.265,.265,.014),rubber,.004)
	for z in [.21,.30]:box(n,"ConsoleBracket",Vector3(.30,.738,z),Vector3(.04,.24,.03),steel,.002)
	box(n,"ObservationDisplay",Vector3(.395,.563,.354),Vector3(.188,.073,.010),mat("display","9fc8b9",.1,.6),.003)
	label(n,"ObservationText","H-031 / 维持舱",Vector3(.395,.563,.362),.173,Color("203e35"))
	cyl(n,"EmergencyRedButton",Vector3(.485,.401,.369),.028,.017,red)
	cyl(n,"EmergencyBezel",Vector3(.485,.401,.357),.037,.007,steel)
	box(n,"ServicePlate",Vector3(.369,.405,.355),Vector3(.10,.045,.006),paper)
	label(n,"ServiceText","检修 / 隔离",Vector3(.369,.405,.360),.087,Color("33483d"))
	for i in range(3):
		var pos := Vector3(.322+i*.068,.496,.360)
		cyl(n,["LifeLED","TransferLED","ServiceLED"][i],pos,.010,.008,mat("led%d"%i,"9fc8b9",.1,.6))
		label(n,"CircuitName",["L","T","M"][i],pos+Vector3(0,-.022,.005),.012)
	box(n,"ServiceBack",Vector3(.41,.48,.170),Vector3(.254,.226,.010),enamel,.003)
	var cables := node(n,"RoutingCables")
	for i in range(3):
		var x: float=.335+i*.075
		var toggle := node(n,["LifeToggle","TransferToggle","ServiceToggle"][i],Vector3(x,.515,.158))
		box(toggle,"Lever",Vector3(0,0,-.018),Vector3(.022,.034,.034),rubber,.002)
		box(toggle,"Tick",Vector3(0,.012,-.037),Vector3(.003,.008,.002),paper)
		var port := cyl(n,["PortRead","PortWrite","PortVerify"][i],Vector3(x,.422,.156),.018,.012,steel)
		cyl(port,"Socket",Vector3(0,-.008,0),.010,.014,rubber,false)
		var text_ := label(n,"PortLabel",["C-031","H-031","原始档案"][i],Vector3(x,.381,.152),.057,Color("263e38"));text_.rotation.y=PI
		Art.line(cables,"PatchLead",[Vector3(x,.422,.142),Vector3(x,.36,.10),Vector3(.47-i*.04,.32,.06)],.004,rubber)
	for i in range(2):
		var d := Vector3(i*.025,0,0)
		Art.line(n,"Loom",[Vector3(.47,.50,.19)+d,Vector3(.47,.39,.05)+d,Vector3(.17,.21,-.36)+d,Vector3(.11,.15,-.52)+d],.009,rubber)
	box(n,"Junction",Vector3(.11,.15,-.52),Vector3(.13,.09,.08),steel,.006)
	for x in [.295,.525]:
		for y in [.36,.60]:screw(n,Vector3(x,y,.353))
	# Open shell with a real interior, not a solid box surrounding a drawer.
	for x in [-.184,.144]:box(n,"DrawerSide",Vector3(x,.735,.415),Vector3(.012,.115,.24),enamel)
	box(n,"DrawerTop",Vector3(-.02,.7865,.415),Vector3(.34,.012,.24),enamel)
	box(n,"DrawerBack",Vector3(-.02,.735,.301),Vector3(.34,.115,.012),enamel)
	for x in [-.15,.11]:box(n,"DrawerHanger",Vector3(x,.825,.415),Vector3(.016,.065,.045),steel)
	var slide := node(n,"DrawerSlide",Vector3(-.02,.71,.415))
	box(slide,"DrawerTray",Vector3.ZERO,Vector3(.30,.020,.20),steel,.003)
	box(slide,"DrawerFront",Vector3(0,.024,.105),Vector3(.32,.068,.020),enamel,.004)
	box(slide,"DrawerHandle",Vector3(0,.028,.125),Vector3(.10,.020,.023),rubber,.003)
	module(slide,"SpareModule",Vector3(0,.031,.001),false)
	marker(slide,"SpareSocket",Vector3(0,.014,0))
	var slot := node(n,"ModuleSocket",Vector3(.27,.712,.452))
	box(slot,"RailLeft",Vector3(-.091,0,0),Vector3(.010,.062,.104),steel)
	box(slot,"RailRight",Vector3(.091,0,0),Vector3(.010,.062,.104),steel)
	box(slot,"Floor",Vector3(0,-.026,0),Vector3(.192,.010,.104),steel)
	module(n,"ModuleBurnt",slot.position,true);module(n,"ModuleInstalled",slot.position,false)
	marker(n,"DeviceAim",Vector3(.35,.40,.46))
	marker(n,"ServiceCam",Vector3(.77,.54,-.37),Vector3(.41,.48,.16),40)
	marker(n,"DrawerCam",Vector3(.25,.83,.94),Vector3(.08,.73,.52),49)
	marker(n,"CareCatRest",Vector3(0,.923,.01));marker(n,"CareHandStop",Vector3(.27,1.02,.35))
	return n

func vent() -> Node3D:
	var n := root_("VentService","vent")
	box(n,"Recess",Vector3(0,0,-.026),Vector3(.68,.46,.035),rubber)
	for x in [-.36,.36]:box(n,"FrameSide",Vector3(x,0,0),Vector3(.04,.52,.07),steel,.004)
	for y in [-.25,.25]:box(n,"FrameEnd",Vector3(0,y,0),Vector3(.76,.04,.07),steel,.004)
	var pivot := node(n,"GrillePivot",Vector3(-.34,0,.045))
	for i in range(8):box(pivot,"Louver%02d"%i,Vector3(.34,-.195+i*.055,0),Vector3(.65,.025,.026),steel,.002).rotation.x=deg_to_rad(-20)
	for x in [0,.68]:box(pivot,"EdgeRail",Vector3(x,0,0),Vector3(.018,.43,.028),steel,.002)
	box(pivot,"BentEdge",Vector3(.62,-.18,.038),Vector3(.085,.03,.012),steel,.002)
	var catch_ := node(n,"LeftCatchPivot",Vector3(-.30,.14,.081))
	box(catch_,"Catch",Vector3(0,-.025,0),Vector3(.022,.072,.010),steel,.002)
	box(n,"RightRustedCatch",Vector3(.32,.15,.061),Vector3(.023,.028,.012),mat("rust","75624d",.1,.9))
	box(n,"BrokenCatchEnd",Vector3(.32,.100,.061),Vector3(.023,.023,.012),steel)
	for x in [-.32,.32]:
		for y in [-.215,.215]:screw(n,Vector3(x,y,.045))
	marker(n,"VentCam",Vector3(.65,.13,.555),Vector3.ZERO,62)
	return n

func stage(root: Node3D, mask: int) -> void:
	root.set_meta("render_mask",mask)
	for child in root.find_children("*","GeometryInstance3D",true,false):child.layers=mask
	for child in root.find_children("*","Light3D",true,false):child.light_cull_mask=mask;child.layers=mask
	var key := DirectionalLight3D.new();key.name="StageSoftKey";key.rotation_degrees=Vector3(-55,-35,0);key.light_color=Color("d7e4da");key.light_energy=.22;key.light_cull_mask=mask;key.layers=mask;root.add_child(key)
	var cam := Camera3D.new();cam.name="StageCamera";cam.current=false;cam.cull_mask=mask;cam.near=.015;cam.far=18
	var env := Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("101a1c");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("a4b4ae");env.ambient_light_energy=.24;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;cam.environment=env;root.add_child(cam)

func light_(parent: Node3D, pos: Vector3, energy: float) -> void:
	var l := OmniLight3D.new();l.position=pos;l.light_color=Color("d7e4da");l.light_energy=energy;l.omni_range=6;l.shadow_enabled=false;parent.add_child(l)

func recovery() -> Node3D:
	var n := root_("RecoveryBay","recovery")
	box(n,"Floor",Vector3(0,-.06,0),Vector3(5,.12,4),cloth)
	for x in [-2.56,2.56]:box(n,"WallSide",Vector3(x,1.25,0),Vector3(.12,2.5,4.24),enamel)
	for z in [-2.06,2.06]:box(n,"WallEnd",Vector3(0,1.25,z),Vector3(5,2.5,.12),enamel)
	box(n,"Ceiling",Vector3(0,2.56,0),Vector3(5.24,.12,4.24),enamel)
	box(n,"PodBase",Vector3(0,.35,0),Vector3(.95,.70,2.30),enamel,.05)
	box(n,"BedPad",Vector3(0,.745,0),Vector3(.76,.12,2.04),rubber,.025)
	for x in [-.40,.40]:Art.rod(n,"BedRail",Vector3(x,.71,-1.10),Vector3(x,.71,1.10),.018,steel)
	var hatch := node(n,"HatchPivot",Vector3(.44,.84,0))
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		for pair in [Vector2(i,-1),Vector2(i+1,-1),Vector2(i+1,1),Vector2(i,-1),Vector2(i+1,1),Vector2(i,1)]:
			var a: float=pair.x*PI/16
			st.add_vertex(Vector3(.44*cos(a),.84+.44*sin(a),pair.y*1.02)-hatch.position)
	st.generate_normals()
	var glass := mat("pod_glass","7eaaa1",0,.23);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color.a=.27;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	Art.mesh_node(hatch,"HatchGlass",st.commit(),glass)
	for z in [-1.02,1.02]:
		for i in range(16):
			var a: float=i*PI/16;var b: float=(i+1)*PI/16
			Art.rod(hatch,"HatchFrame",Vector3(.44*cos(a),.84+.44*sin(a),z)-hatch.position,Vector3(.44*cos(b),.84+.44*sin(b),z)-hatch.position,.012,steel)
	box(n,"Pillow",Vector3(0,.84,-.78),Vector3(.46,.07,.32),cloth,.018)
	# Low-detail covered male, with face orientation +Y and short swept hair.
	var human := node(n,"ResearcherH031")
	cyl(human,"Neck",Vector3(0,.923,-.579),.042,.15,skin)
	make_face(human)
	for x in [-.092,.092]:Art.ellipsoid(human,"Ear",Vector3(x,.936,-.754),Vector3(.023,.033,.048),skin)
	var chest := node(n,"BreathingChest",Vector3(0,.91,.16))
	Art.ellipsoid(chest,"CoveredBody",Vector3.ZERO,Vector3(.55,.21,1.44),cloth)
	Art.ellipsoid(chest,"Shoulders",Vector3(0,-.01,-.54),Vector3(.48,.16,.24),cloth)
	for i in range(6):Art.rod(chest,"BlanketFold",Vector3(-.21,.07,-.45+i*.18),Vector3(.18,.065,-.40+i*.18),.003,mat("fold","7e8a80",0,.98))
	box(n,"MonitorHead",Vector3(-.64,1.12,-.77),Vector3(.28,.22,.09),enamel,.015)
	box(n,"MonitorScreen",Vector3(-.64,1.12,-.718),Vector3(.25,.19,.012),rubber,.004)
	label(n,"Identity","研究员 / H-031\n生命维持稳定\n意识已迁出",Vector3(-.64,1.12,-.708),.21)
	Art.rod(n,"MonitorStand",Vector3(-.64,0,-.77),Vector3(-.64,1.02,-.77),.022,steel)
	box(n,"JunctionBox",Vector3(.63,1.04,-1.86),Vector3(.29,.35,.16),enamel,.012)
	Art.line(n,"IndependentLifeLine",[Vector3(.63,1.04,-1.77),Vector3(.63,.22,-1.4),Vector3(.36,.2,-1.0)],.012,rubber)
	label(n,"LifeCircuit","H-031 · 独立维持",Vector3(.63,1.05,-1.774),.25,Color("263f38"))
	marker(n,"BodyInspectCam",Vector3(1.63,1.47,1.18),Vector3(0,.96,-.44),49)
	marker(n,"BodyDetailCam",Vector3(.35,1.18,-.39),Vector3(0,.96,-.75),46)
	marker(n,"HumanWakeCam",Vector3(0,1.04,-.74),Vector3(0,1.11,.48),62)
	light_(n,Vector3(-.9,2.28,-.35),1.15);light_(n,Vector3(1.3,1.55,.75),.38)
	stage(n,128);return n

func face_y(x: float, z: float) -> float:
	var h := .94+.085*sqrt(maxf(0,1-pow(x/.09,2)-pow((z+.75)/.1175,2)))
	h+=.019*exp(-pow(x/.016,2)-pow((z+.752)/.036,2))
	for side in [-1,1]:
		h-=.005*exp(-pow((x-side*.040)/.019,2)-pow((z+.781)/.017,2))
		h+=.004*exp(-pow((x-side*.050)/.023,2)-pow((z+.729)/.024,2))
	return h

func make_face(parent: Node3D) -> void:
	var sphere:=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=48;sphere.rings=24
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var scalp:=SurfaceTool.new();scalp.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices:=sphere.get_faces()
	for start in range(0,vertices.size(),3):
		var center: Vector3=(vertices[start]+vertices[start+1]+vertices[start+2])/3
		var hairy := center.z<-.24 or absf(center.x)>.405 or center.y<-.1
		for i in range(3):
			var v: Vector3=vertices[start+i]*Vector3(.18,.17,.235)+Vector3(0,.94,-.75)
			if vertices[start+i].y>0:v.y=face_y(v.x,v.z)
			st.add_vertex(v)
			if hairy:scalp.add_vertex(v+(v-Vector3(0,.94,-.75)).normalized()*.002)
	st.generate_normals();scalp.generate_normals()
	Art.mesh_node(parent,"Head",st.commit(),skin);Art.mesh_node(parent,"ShortHair",scalp.commit(),hair)
	for side in [-1,1]:
		var eye: Array[Vector3]=[];var brow: Array[Vector3]=[]
		for i in range(7):
			var x: float=side*.040+(i-3)*.0045
			var z: float=-.782+sin(i*PI/6)*.003
			eye.append(Vector3(x,face_y(x,z)+.0015,z))
			var zb: float=z-.013
			brow.append(Vector3(x,face_y(x,zb)+.0014,zb))
		Art.line(parent,"ClosedEye",eye,.0011,hair);Art.line(parent,"Brow",brow,.0017,hair)
	var mouth: Array[Vector3]=[]
	for i in range(9):
		var x: float=(i-4)*.0045;var z: float=-.695+sin(i*PI/8)*.002
		mouth.append(Vector3(x,face_y(x,z)+.001,z))
	Art.line(parent,"Mouth",mouth,.001,mat("lips","996e60",0,.85))
	for i in range(6):
		var x: float=-.055+i*.015
		var p:=Vector3(x,face_y(x,-.83)+.002,-.83)
		Art.rod(parent,"SweptFringe",p,p+Vector3(.023,-.002,.023),.004,hair)

func rescue() -> Node3D:
	var n := root_("RescueStage","rescue")
	box(n,"OutsideFloor",Vector3(0,-.06,1),Vector3(6,.12,4),cloth)
	for x in [-1.5625,1.5625]:box(n,"StationWall",Vector3(x,1.25,0),Vector3(1.875,2.5,.12),enamel)
	box(n,"Lintel",Vector3(0,2.275,0),Vector3(1.25,.45,.12),enamel)
	for x in [-.665,.665]:box(n,"DoorFrame",Vector3(x,1.05,.02),Vector3(.08,2.10,.14),rubber,.005)
	label(n,"StationSign","住宅分站 / 医疗转运",Vector3(1.5,1.7,.07),1.1,Color("394f46"))
	for spec in [["DogInside",Vector3(0,0,-.70)],["DogOutside",Vector3(0,0,1.30)],["CatWait",Vector3(-.75,0,1)],["RescuerMark",Vector3(.92,0,.67)],["StretcherMark",Vector3(1.28,0,1.5)]]:marker(n,spec[0],spec[1])
	var dog := load("res://furniture_pack/scenes/dog_nest.tscn").instantiate() as Node3D;dog.name="AjaoVisual";dog.pose_mode="stand";dog.position=Vector3(0,0,1.30);dog.rotation.y=-PI/2;n.add_child(dog);dog.get_node("Bed").hide()
	for body in dog.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0
	var cat := load("res://scenes/calico.tscn").instantiate() as Node3D;cat.name="MisoVisual";cat.scale=Vector3.ONE*.8;cat.position=Vector3(-.75,0,1);cat.preview_pose="idle";cat.rotation.y=-PI/2;n.add_child(cat)
	var stretcher := node(n,"RescueStretcher",Vector3(1.28,0,1.5))
	box(stretcher,"TrolleyPad",Vector3(0,.67,0),Vector3(.64,.10,1.85),enamel,.03)
	Art.ellipsoid(stretcher,"CoveredPatient",Vector3(0,.79,0),Vector3(.53,.25,1.73),cloth)
	for x in [-.27,.27]:
		for z in [-.7,.7]:
			Art.rod(stretcher,"Leg",Vector3(x,.15,z),Vector3(x,.65,z),.018,steel)
			cyl(stretcher,"Wheel",Vector3(x,.09,z),.09,.035,rubber).rotation.y=PI/2
	box(stretcher,"Monitor",Vector3(.27,1.03,-.64),Vector3(.22,.18,.10),rubber,.01)
	label(stretcher,"PatientTag","H-031 / 转运中",Vector3(0,.70,.94),.44,Color("30483c"))
	var carrier := node(n,"MouseTransport",Vector3(-1.23,.13,1.30))
	box(carrier,"CarrierFloor",Vector3(0,-.125,0),Vector3(.30,.010,.19),enamel,.003)
	box(carrier,"CarrierRoof",Vector3(0,.125,0),Vector3(.30,.010,.19),enamel,.003)
	for x in [-.145,.145]:box(carrier,"CarrierSide",Vector3(x,0,0),Vector3(.010,.26,.19),enamel,.003)
	box(carrier,"CarrierBack",Vector3(0,0,-.09),Vector3(.30,.26,.010),enamel)
	for i in range(7):box(carrier,"AirGrille",Vector3(-.12+i*.04,0,.097),Vector3(.004,.25,.004),steel)
	var mouse := load("res://furniture_pack/quest_props/house_mouse.glb").instantiate() as Node3D;mouse.name="RescuedMouse";mouse.scale=Vector3.ONE*.48;mouse.position=Vector3(0,-.12,0);carrier.add_child(mouse)
	marker(n,"RescueCam",Vector3(-2.80,1.35,3.40),Vector3(.25,.55,.95),62)
	light_(n,Vector3(-1,2,2),1.2);stage(n,256);return n

func memory() -> Node3D:
	var n := root_("MemoryVignette","memory")
	var cage := load("res://furniture_pack/basement/observation_cage.tscn").instantiate() as Node3D
	cage.name="CageVisual";cage.set_script(null);n.add_child(cage)
	for body in cage.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0
	box(n,"Blanket",Vector3(0,.10,-.20),Vector3(.52,.018,.62),cloth,.005)
	var cat := load("res://scenes/calico.tscn").instantiate() as Node3D
	cat.name="MemoryMiso";cat.scale=Vector3.ONE*.8;cat.position=Vector3(0,.055,.15);cat.preview_pose="sit";n.add_child(cat)
	cage.get_node("Leaf/Sign").text="F-03\nC-031"
	var arm := node(n,"CareArm")
	Art.rod(arm,"LabSleeve",Vector3(.38,.65,-.80),Vector3(.22,.40,-.56),.048,enamel)
	Art.ellipsoid(arm,"Hand",Vector3(.16,.32,-.48),Vector3(.075,.04,.14),skin)
	for i in range(4):Art.rod(arm,"Finger",Vector3(.14+i*.015,.32,-.49),Vector3(.13+i*.015,.32,-.40),.006,skin)
	box(n,"Floor",Vector3(0,-.02,0),Vector3(3,.04,4),cloth)
	marker(n,"CarePOV",Vector3(0,1.52,-1.65),Vector3(0,.30,-.30),55)
	light_(n,Vector3(-.8,2,-1),1.0);stage(n,512);return n

func k2() -> Node3D:
	var n := root_("K2Visual","k2")
	box(n,"Case",Vector3.ZERO,Vector3(.065,.045,.024),rubber,.007)
	box(n,"MetalRim",Vector3(0,0,.010),Vector3(.061,.041,.006),steel,.002)
	box(n,"Face",Vector3(0,0,.014),Vector3(.056,.036,.003),rubber,.001)
	cyl(n,"K2Button",Vector3(0,-.008,.014),.008,.004,steel)
	marker(n,"ButtonContact",Vector3(0,-.008,.019))
	label(n,"K2Name","K-2",Vector3(0,.004,.018),.016)
	label(n,"StateLabel","未校准",Vector3(0,-.032,.015),.050)
	for i in range(3):cyl(n,"K2LED%d"%(i+1),Vector3(-.018+i*.018,.012,.014),.0025,.003,mat("k2led%d"%i,"344a46",0,.6))
	for x in [-.025,.025]:marker(n,"StrapLeft" if x<0 else "StrapRight",Vector3(x,.018,0))
	return n

func maintenance() -> Node3D:
	var n := root_("MaintenanceBox","box")
	# Hollow five-sided body; the front door rotates about the left edge.
	for x in [-.136,.136]:box(n,"BoxSide",Vector3(x,0,0),Vector3(.008,.16,.20),enamel,.002)
	for y in [-.076,.076]:box(n,"BoxLid",Vector3(0,y,0),Vector3(.28,.008,.20),enamel,.002)
	box(n,"BoxBack",Vector3(0,0,-.096),Vector3(.28,.16,.008),enamel)
	for x in [-.10,.10]:box(n,"MountingStrip",Vector3(x,.183,.04),Vector3(.02,.206,.02),steel,.002)
	Art.line(n,"DeskCable",[Vector3(0,.03,-.104),Vector3(0,.24,-.104),Vector3(-.15,.27,-.104)],.004,rubber)
	var pivot := node(n,"BoxDoorPivot",Vector3(-.14,0,.108))
	box(pivot,"BoxDoor",Vector3(.14,0,0),Vector3(.28,.16,.012),enamel,.003)
	for i in range(3):
		box(pivot,"DigitWindow%d"%(i+1),Vector3(.095+i*.045,.025,.008),Vector3(.032,.036,.004),rubber,.001)
		label(pivot,"Digit%d"%(i+1),"031"[i],Vector3(.095+i*.045,.025,.012),.020)
	label(pivot,"BoxInstructions","维护盒使用接收载体尾号",Vector3(.14,-.043,.009),.242,Color("314e40"))
	box(n,"K2Cradle",Vector3(0,-.020,.015),Vector3(.080,.020,.065),rubber,.004)
	var device := k2();device.name="K2InBox";device.position=Vector3(0,.014,.015);n.add_child(device)
	marker(n,"BoxAim",Vector3(0,0,.23))
	marker(n,"BoxInspectCam",Vector3(.28,.17,.66),Vector3(0,0,0),45)
	return n

func create(kind: String) -> Node3D:
	match kind:
		"conversion_retrofit":return retrofit()
		"vent_service":return vent()
		"recovery_bay":return recovery()
		"rescue_stage":return rescue()
		"memory_vignette":return memory()
		"maintenance_box":return maintenance()
		"k2_device":return k2()
	return null
