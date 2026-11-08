extends Node3D
## Authored stylized silhouette with articulated shoulders, elbows and hands.
var role := "研究员"
var arms: Array[Node3D]=[]
var elbows: Array[Node3D]=[]
var palms: Array[Node3D]=[]
var legs: Array[Node3D]=[]
var carried := false
const Art=preload("res://furniture_pack/quest_props/refined_props.gd")

func mesh(parent: Node3D, name_: String, geometry: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	return Art.mesh_node(parent,name_,geometry,material,pos)

func profile(parent: Node3D, name_: String, rings: Array, material: Material, offset := Vector3.ZERO) -> MeshInstance3D:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments:=16
	for row in range(rings.size()-1):
		for j in range(segments):
			var vertices: Array[Vector3]=[]
			for point in [[row,j],[row,(j+1)%segments],[row+1,(j+1)%segments],[row+1,j]]:
				var ring: Vector3=rings[point[0]];var angle: float=TAU*point[1]/segments
				vertices.append(Vector3(sin(angle)*ring.x,ring.y,cos(angle)*ring.z))
			var order: Array=[0,1,2,0,2,3] if rings[row+1].y>=rings[row].y else [0,2,1,0,3,2]
			for index in order:surface.add_vertex(vertices[index])
	surface.generate_normals();return mesh(parent,name_,surface.commit(),material,offset)

func build(title: String) -> void:
	role=title
	var skin=Art.material("human_skin",Color("c69d80"),.86)
	var hair=Art.material("human_hair",Color("302c2a"),.92)
	var fabric=Art.material("human_cloth_"+role,Color("dadfd7") if role=="研究员" else Color("344c62") if role=="调查" else Color("59565c"),.94)
	var trousers=Art.material("human_trousers",Color("303b43"),.93)
	var dark=Art.material("human_shoes",Color("252d31"),.82)
	profile(self,"TailoredCoat",[Vector3(.19,.78,.12),Vector3(.20,.82,.13),Vector3(.15,1.05,.11),Vector3(.22,1.30,.13),Vector3(.22,1.36,.11),Vector3(.08,1.43,.06)],fabric)
	profile(self,"Neck",[Vector3(.07,1.38,.065),Vector3(.07,1.52,.065)],skin)
	profile(self,"Face",[Vector3(.015,1.49,.035),Vector3(.075,1.51,.08),Vector3(.105,1.57,.105),Vector3(.113,1.67,.10),Vector3(.10,1.75,.08),Vector3(.035,1.79,.03),Vector3(.001,1.80,.001)],skin,Vector3(0,0,.008))
	profile(self,"Hair",[Vector3(.106,1.68,.093),Vector3(.119,1.73,.097),Vector3(.102,1.79,.077),Vector3(.02,1.82,.025),Vector3(.001,1.825,.001)],hair,Vector3(0,0,-.018))
	for side in [-1,1]:
		Art.ellipsoid(self,"Ear",Vector3(side*.116,1.635,0),Vector3(.025,.041,.025),skin)
		Art.ellipsoid(self,"EyeWhite",Vector3(side*.046,1.66,.099),Vector3(.025,.012,.009),Art.material("human_eye",Color("deddd1")))
		Art.ellipsoid(self,"Iris",Vector3(side*.046,1.659,.107),Vector3(.010,.009,.004),dark)
		Art.rod(self,"Brow",Vector3(side*.025,1.683,.103),Vector3(side*.071,1.68,.095),.006,hair)
		var leg:=Node3D.new();leg.name="LegPivot";add_child(leg);leg.position=Vector3(side*.105,.83,0);legs.append(leg)
		profile(leg,"Trousers",[Vector3(.075,-.01,.087),Vector3(.068,-.37,.071),Vector3(.055,-.74,.055)],trousers)
		Art.ellipsoid(leg,"Shoe",Vector3(0,-.78,.043),Vector3(.073,.05,.138),dark)
		var shoulder:=Node3D.new();add_child(shoulder);shoulder.position=Vector3(side*.218,1.31,0);arms.append(shoulder)
		profile(shoulder,"UpperSleeve",[Vector3(.073,.02,.07),Vector3(.067,-.14,.063),Vector3(.055,-.30,.052)],fabric)
		var elbow:=Node3D.new();shoulder.add_child(elbow);elbow.position.y=-.30;elbows.append(elbow)
		profile(elbow,"ForeSleeve",[Vector3(.055,0,.052),Vector3(.045,-.22,.044),Vector3(.043,-.25,.039)],fabric)
		var palm:=Node3D.new();elbow.add_child(palm);palm.position=Vector3(0,-.27,.01);palms.append(palm)
		profile(palm,"Palm",[Vector3(.039,0,.025),Vector3(.04,-.07,.025),Vector3(.029,-.09,.023)],skin)
		for finger in range(4):Art.rod(palm,"Finger",Vector3(-.027+finger*.017,-.075,.005),Vector3(-.027+finger*.017,-.125+(absf(finger-1.5)*.006),.018),.008,skin)
		Art.rod(palm,"Thumb",Vector3(side*.035,-.025,.007),Vector3(side*.052,-.075,.026),.011,skin)
	Art.ellipsoid(self,"Nose",Vector3(0,1.627,.111),Vector3(.018,.026,.026),skin)
	Art.rod(self,"Mouth",Vector3(-.027,1.574,.105),Vector3(.027,1.574,.105),.0035,Art.material("human_lips",Color("845e50")))
	for i in range(4):Art.ellipsoid(self,"CoatButton",Vector3(0,1.24-i*.105,.126),Vector3(.008,.008,.004),dark)
	for side in [-1,1]:Art.rod(self,"Lapel",Vector3(side*.065,1.41,.065),Vector3(side*.12,1.23,.117),.018,fabric)
	var badge:=BoxMesh.new();badge.size=Vector3(.064,.082,.006);mesh(self,"IdentityCard",badge,Art.material("human_badge",Color("b4d6d0")),Vector3(-.105,1.20,.133))

func carry(enabled: bool) -> void:
	carried=enabled
	for i in range(arms.size()):
		arms[i].rotation=Vector3(-.50,0,.10 if i==0 else -.10) if enabled else Vector3.ZERO
		elbows[i].rotation.x=-1.12 if enabled else -.05
		palms[i].rotation.x=.22 if enabled else 0

func gait(time: float, amount: float) -> void:
	for i in range(legs.size()):legs[i].rotation.x=sin(time*6+i*PI)*.22*amount
	if not carried:
		for i in range(arms.size()):arms[i].rotation.x=-sin(time*6+i*PI)*.10*amount
