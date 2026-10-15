extends "res://furniture_pack/build_pack.gd"
## Additional reusable household objects. Uses the original furniture palette.

func palette() -> void:
	for key in ["oak","walnut","linen","cream","sage_fabric","rust","sage","ivory","porcelain","stone","brass","steel","charcoal","shadow","glass_black","rope","book_green","book_red"]:
		materials[key] = load(BASE+"materials/"+key+".tres")
	material("decor_terra",Color("b47b5d"),0,.85)
	material("decor_leaf",Color("456b45"),0,.85)
	material("decor_leaf_light",Color("718c55"),0,.85)
	material("decor_soil",Color("42362b"),0,1)
	material("decor_gold",Color("c7a45a"),0,.75)
	material("decor_sky",Color("9eb5b4"),0,.95)
	material("decor_water",Color("467f88"),0,.2)
	material("decor_glass",Color(.69,.83,.83,.17),0,.12)
	materials.decor_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materials.decor_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	ResourceSaver.save(materials.decor_glass,BASE+"materials/decor_glass.tres")
	material("decor_lamp",Color("fff1d0"),0,.7)
	materials.decor_lamp.emission_enabled = true
	materials.decor_lamp.emission = Color("ffe2ac")
	materials.decor_lamp.emission_energy_multiplier = .55
	ResourceSaver.save(materials.decor_lamp,BASE+"materials/decor_lamp.tres")

func save_decor(id: String, title_text: String, note: String = "") -> void:
	finish("decor_"+id,title_text,"陈设与生活设备",note)

func rug(id: String, width: float, depth: float, key: String) -> void:
	begin("decor_"+id)
	block("Woven_base",Vector3(0,.006,0),Vector3(width,.012,depth),key,.005,false)
	for side in [-1,1]:
		block("Long_border",Vector3(side*(width*.5-.07),.013,0),Vector3(.045,.002,depth-.10),"cream",.0005,false)
		block("End_border",Vector3(0,.013,side*(depth*.5-.07)),Vector3(width-.10,.002,.045),"cream",.0005,false)
	for i in range(8):
		var x := (i-3.5)*width/10
		block("Woven_accent",Vector3(x,.014,0),Vector3(.022,.002,depth-.24),"linen",.0005,false)
	save_decor(id,"织边地毯" if id=="rug" else "玄关长毯" if id=="runner" else "浴室地垫","薄织物无阻挡碰撞，避免猫脚与地面接缝卡住。")

func plant(small: bool = false) -> void:
	var id := "herb_pot" if small else "plant"
	begin("decor_"+id)
	var s := .32 if small else 1.0
	lathe("Terracotta_pot",[Vector2(.001,0),Vector2(.14,0),Vector2(.17,.04),Vector2(.20,.30),Vector2(.205,.32),Vector2(.18,.32),Vector2(.16,.06),Vector2(.001,.04)],Vector3.ZERO,"decor_terra",Vector3.ONE*s)
	rod("Soil",Vector3(0,.275*s,0),Vector3(0,.28*s,0),.17*s,"decor_soil")
	if not small:collision(Vector3(0,.15,0),Vector3(.34,.30,.34))
	for k in range(9):
		var angle := k*2.399
		var h := (.55+(k%4)*.13)*s
		var tip := Vector3(cos(angle)*.18*s,h,sin(angle)*.18*s)
		rod("Stem",Vector3(0,.28*s,0),tip,.004*s,"decor_leaf")
		for j in range(3):
			var p: Vector3 = Vector3(0,.28*s,0).lerp(tip,.48+j*.21)
			var direction := Vector3(cos(angle+j*.8),.38,sin(angle+j*.8)).normalized()
			var leaf := mesh_node("Leaf",leaf_mesh(.25*s,.10*s),p,"decor_leaf_light" if (k+j)%3==0 else "decor_leaf")
			leaf.quaternion = Quaternion(Vector3.UP,direction)
	save_decor(id,"香草盆栽" if small else "陶盆绿植","枝叶为双面立体折叶，陶盆保留落地碰撞。")

func leaf_mesh(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ps := [Vector3.ZERO,Vector3(-width*.5,length*.48,0),Vector3(0,length*.55,width*.15),Vector3(width*.5,length*.48,0),Vector3(0,length,0)]
	for face in [[0,1,2],[0,2,3],[1,4,2],[2,4,3]]:
		var normal: Vector3 = (ps[face[1]]-ps[face[0]]).cross(ps[face[2]]-ps[face[0]]).normalized()
		triangle(st,[ps[face[0]],ps[face[1]],ps[face[2]]],[normal,normal,normal])
		triangle(st,[ps[face[0]],ps[face[1]],ps[face[2]]],[-normal,-normal,-normal])
	st.index()
	return st.commit()

func curtain() -> void:
	begin("decor_curtains")
	rod("Curtain_pole",Vector3(-1.18,2.37,0),Vector3(1.18,2.37,0),.017,"walnut")
	for side in [-1,1]:
		ball("Finial",Vector3(side*1.20,2.37,0),Vector3(.07,.07,.07),"brass")
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for x in range(24):
			for y in range(8):
				var points: Array = []
				var normals: Array = []
				for ij in [Vector2i(x,y),Vector2i(x+1,y),Vector2i(x+1,y+1),Vector2i(x,y+1)]:
					var u: float = ij.x/24.0
					var v: float = ij.y/8.0
					var p := Vector3(side*.91+(u-.5)*.48,v*2.28,.025+sin(u*TAU*4)*.035)
					points.append(p)
					normals.append(Vector3(-cos(u*TAU*4)*1.8,0,1).normalized())
				triangle(st,[points[0],points[1],points[2]],[normals[0],normals[1],normals[2]])
				triangle(st,[points[0],points[2],points[3]],[normals[0],normals[2],normals[3]])
				triangle(st,[points[0],points[1],points[2]],[-normals[0],-normals[1],-normals[2]])
				triangle(st,[points[0],points[2],points[3]],[-normals[0],-normals[2],-normals[3]])
		st.index()
		mesh_node("Pleated_linen",st.commit(),Vector3.ZERO,"linen")
		for k in range(7):
			var n := mesh_node("Curtain_ring",null,Vector3(side*.91+(k-3)*.066,2.33,0),"brass")
			var torus := TorusMesh.new()
			torus.inner_radius = .022
			torus.outer_radius = .026
			torus.rings = 16
			torus.ring_segments = 8
			n.mesh = torus
			n.rotation.x = PI*.5
	save_decor("curtains","开敞亚麻窗帘","基准杆宽 2.44 m；按窗宽沿 X 轴调整，中央保持敞开。")

func art(tv: bool = false) -> void:
	var id := "television" if tv else "wall_art"
	begin("decor_"+id)
	var w := 1.18 if tv else .80
	var h := .70 if tv else .64
	var bottom := .08 if tv else 0.0
	block("Frame",Vector3(0,bottom+h*.5,0),Vector3(w,h,.045),"charcoal" if tv else "oak",.014,false)
	block("Print_field",Vector3(0,bottom+h*.5,.025),Vector3(w-.065,h-.065,.006),"decor_sky" if tv else "cream",.002,false)
	ball("Sun",Vector3(w*.19,bottom+h*.68,.031),Vector3(h*.25,h*.25,.004),"decor_gold")
	for i in range(3):
		ball("Layered_hills",Vector3((i-1)*w*.22,bottom+h*.29,.034+i*.004),Vector3(w*.43,h*(.25+i*.06),.006),["sage","sage_fabric","decor_terra"][i])
	if tv:
		for x in [-.40,.40]:
			rod("Screen_foot",Vector3(x,.015,.07),Vector3(x,.12,0),.012,"charcoal")
			block("Foot_pad",Vector3(x,.004,.07),Vector3(.06,.008,.13),"charcoal",.003,false)
		collision(Vector3(0,.43,0),Vector3(w,.70,.045))
	save_decor(id,"风景电视" if tv else "暖色风景挂画","画面为原创几何风景，无外部图片依赖。")

func lamp(pendant: bool = false) -> void:
	var id := "pendant" if pendant else "table_lamp"
	begin("decor_"+id)
	if pendant:
		lathe("Pleated_shade",[Vector2(.30,0),Vector2(.24,.22),Vector2(.055,.27),Vector2(.05,.26),Vector2(.23,.21),Vector2(.295,0)],Vector3.ZERO,"linen")
		rod("Cable",Vector3(0,.27,0),Vector3(0,.62,0),.004,"charcoal")
		rod("Canopy",Vector3(0,.62,0),Vector3(0,.65,0),.07,"brass")
		rod("Diffuser",Vector3(0,.012,0),Vector3(0,.017,0),.27,"decor_lamp")
	else:
		lathe("Ceramic_base",[Vector2(.001,0),Vector2(.09,0),Vector2(.10,.04),Vector2(.075,.17),Vector2(.035,.20)],Vector3.ZERO,"decor_terra")
		rod("Lamp_neck",Vector3(0,.19,0),Vector3(0,.32,0),.012,"brass")
		lathe("Linen_shade",[Vector2(.15,.25),Vector2(.105,.45),Vector2(.10,.45),Vector2(.145,.25)],Vector3.ZERO,"cream")
		ball("Bulb",Vector3(0,.32,0),Vector3(.05,.06,.05),"decor_lamp")
	save_decor(id,"亚麻餐吊灯" if pendant else "陶瓷床头台灯","发光材质用于灯罩细节，照明由房间光源统一控制。")

func tabletop(id: String) -> void:
	begin("decor_"+id)
	if id=="place_setting":
		rod("Plate",Vector3(0,0,0),Vector3(0,.012,0),.12,"porcelain")
		ring("Plate_rim",Vector3(0,.014,0),.112,.006,"porcelain")
		lathe("Cup",[Vector2(.001,0),Vector2(.035,0),Vector2(.04,.08),Vector2(.033,.08),Vector2(.029,.008),Vector2(.001,.008)],Vector3(.18,0,-.10),"porcelain")
		for x in [-.15,.15]:block("Cutlery",Vector3(x,.005,0),Vector3(.012,.008,.19),"steel",.003,false)
	elif id=="fruit_bowl":
		lathe("Bowl",[Vector2(.02,0),Vector2(.08,0),Vector2(.16,.07),Vector2(.17,.10),Vector2(.16,.105),Vector2(.14,.07),Vector2(.06,.015),Vector2(.01,.015)],Vector3.ZERO,"stone")
		for i in range(5):
			var a := i*TAU/5
			ball("Fruit",Vector3(cos(a)*.08,.115,sin(a)*.08),Vector3(.09,.09,.09),"decor_gold" if i%2 else "decor_terra")
	elif id=="books_vase":
		for i in range(3):block("Book",Vector3(-.08,.018+i*.03,0),Vector3(.22,.03,.16),"book_red" if i%2 else "book_green",.003,false,Vector3(0,i*.1,0))
		lathe("Vase",[Vector2(.001,0),Vector2(.055,0),Vector2(.08,.07),Vector2(.04,.16),Vector2(.03,.21),Vector2(.024,.21),Vector2(.029,.16)],Vector3(.17,0,0),"porcelain")
		for i in range(3):
			var tip := Vector3(.17+(i-1)*.04,.34+i*.035,(i-1)*.03)
			rod("Dried_stem",Vector3(.17,.12,0),tip,.002,"walnut")
			ball("Dried_flower",tip,Vector3(.03,.045,.03),"decor_gold")
	elif id=="towels":
		for i in range(3):block("Folded_towel",Vector3(0,.025+i*.045,0),Vector3(.34,.05,.24),"cream" if i%2 else "sage_fabric",.022,false)
	elif id=="pet_bowls":
		block("Feeding_mat",Vector3(0,.004,0),Vector3(.48,.008,.28),"sage_fabric",.003,false)
		for x in [-.12,.12]:
			lathe("Bowl",[Vector2(.02,0),Vector2(.08,0),Vector2(.095,.06),Vector2(.083,.065),Vector2(.066,.012),Vector2(.01,.012)],Vector3(x,.008,0),"porcelain")
			rod("Water_or_food",Vector3(x,.033,0),Vector3(x,.035,0),.069,"decor_water" if x<0 else "walnut")
	elif id=="prep_board":
		block("Board",Vector3(0,.008,0),Vector3(.34,.016,.24),"oak",.008,false)
		for x in [-.08,.05]:
			rod("Jar",Vector3(x,.017,0),Vector3(x,.17,0),.048,"porcelain")
			rod("Jar_lid",Vector3(x,.17,0),Vector3(x,.183,0),.05,"oak")
	var names := {"place_setting":"瓷盘与茶杯餐具","fruit_bowl":"果盘","books_vase":"书册与花瓶","towels":"叠放毛巾","pet_bowls":"猫咪食水碗","prep_board":"砧板与储物罐"}
	save_decor(id,names[id],"以台面或地面为零点摆放的小型生活陈设。")

func basket() -> void:
	begin("decor_basket")
	lathe("Woven_basket",[Vector2(.001,0),Vector2(.18,0),Vector2(.20,.05),Vector2(.22,.40),Vector2(.205,.42),Vector2(.19,.05),Vector2(.001,.04)],Vector3.ZERO,"rope")
	for i in range(10):ring("Woven_band",Vector3(0,.035+i*.039,0),.19+i*.0025,.003,"linen")
	block("Laundry",Vector3(0,.38,0),Vector3(.30,.08,.26),"cream",.035,false)
	collision(Vector3(0,.20,0),Vector3(.39,.40,.39))
	save_decor("basket","藤编洗衣篮")

func washer() -> void:
	begin("decor_washing_machine")
	block("Appliance",Vector3(0,.425,0),Vector3(.60,.85,.59),"ivory",.025)
	block("Control_panel",Vector3(0,.74,.30),Vector3(.55,.12,.025),"porcelain",.008,false)
	rod("Selector",Vector3(.17,.75,.32),Vector3(.17,.75,.345),.028,"steel")
	block("Display",Vector3(-.04,.75,.32),Vector3(.14,.045,.006),"glass_black",.003,false)
	var n := mesh_node("Door_ring",null,Vector3(0,.40,.31),"steel")
	var torus := TorusMesh.new()
	torus.inner_radius = .17
	torus.outer_radius = .205
	torus.rings = 48
	torus.ring_segments = 12
	n.mesh = torus
	n.rotation.x = PI*.5
	ball("Door_glass",Vector3(0,.40,.315),Vector3(.35,.35,.055),"glass_black")
	handle(.16,.4,.35,true,.12)
	save_decor("washing_machine","滚筒洗衣机","标准 0.60 m 宽、0.85 m 高。")

func shower() -> void:
	begin("decor_shower")
	block("Shower_tray",Vector3(0,.025,0),Vector3(.94,.05,.94),"porcelain",.022)
	for x in [-.45,.45]:block("Tray_lip",Vector3(x,.045,0),Vector3(.025,.035,.90),"porcelain",.01,false)
	for z in [-.45,.45]:block("Tray_lip",Vector3(0,.045,z),Vector3(.90,.035,.025),"porcelain",.01,false)
	for x in [-.45,.45]:rod("Upright",Vector3(x,.04,-.45),Vector3(x,2.02,-.45),.012,"brass")
	block("Back_glass",Vector3(0,1.02,-.45),Vector3(.89,1.94,.008),"decor_glass",.003,false)
	block("Side_glass",Vector3(.45,1.02,0),Vector3(.008,1.94,.90),"decor_glass",.003,false)
	rod("Shower_riser",Vector3(0,.80,-.39),Vector3(0,1.98,-.39),.012,"steel")
	rod("Shower_arm",Vector3(0,1.98,-.39),Vector3(0,1.98,-.12),.012,"steel")
	rod("Rain_head",Vector3(0,1.96,-.12),Vector3(0,1.98,-.12),.10,"steel")
	rod("Mixer",Vector3(-.10,.94,-.36),Vector3(.10,.94,-.36),.022,"steel")
	rod("Drain",Vector3(.25,.051,.25),Vector3(.25,.054,.25),.025,"steel")
	save_decor("shower","玻璃淋浴角","0.94 m 方形淋浴底盘；入口敞开，猫可进入。")

func console() -> void:
	begin("decor_entry_console")
	legs(.92,.20,.80,"oak",.018,0)
	block("Console_top",Vector3(0,.82,0),Vector3(1.05,.04,.30),"oak",.015)
	block("Lower_shelf",Vector3(0,.18,0),Vector3(.96,.025,.26),"oak")
	block("Drawer",Vector3(0,.72,0),Vector3(.98,.15,.27),"sage",.009)
	handle(0,.74,.18)
	save_decor("entry_console","窄型玄关桌","深 0.30 m，适合过厅，保留通道宽度。")

func storage() -> void:
	begin("decor_closet_rack")
	case_shell(.95,2.15,.40,0,"oak")
	for y in [.30,1.78]:block("Shelf",Vector3(0,y,0),Vector3(.90,.03,.37),"oak")
	rod("Clothes_rail",Vector3(-.43,1.62,0),Vector3(.43,1.62,0),.013,"brass")
	for i in range(5):
		var x := (i-2)*.16
		rod("Hanger_left",Vector3(x,1.60,0),Vector3(x,1.46,-.12),.005,"walnut")
		rod("Hanger_right",Vector3(x,1.60,0),Vector3(x,1.46,.12),.005,"walnut")
		block("Hanging_linen",Vector3(x,1.12,0),Vector3(.07,.69,.26),"cream" if i%2 else "sage_fabric",.033,false)
	save_decor("closet_rack","开放挂衣收纳架","宽 0.95 m，专门适配窄衣帽间。")

func shelf() -> void:
	begin("decor_wall_shelf")
	block("Shelf",Vector3(0,.018,0),Vector3(.80,.036,.24),"oak",.008,false)
	for x in [-.27,.27]:block("Bracket",Vector3(x,.10,-.095),Vector3(.025,.20,.025),"brass",.005,false)
	save_decor("wall_shelf","浴室洗衣间壁架","零点位于层板底面，靠墙侧为 -Z。")

func side_table() -> void:
	begin("decor_side_table")
	rod("Foot",Vector3(0,0,0),Vector3(0,.03,0),.16,"walnut",.15,true)
	rod("Pedestal",Vector3(0,.03,0),Vector3(0,.49,0),.026,"walnut",-1,true)
	rod("Round_top",Vector3(0,.49,0),Vector3(0,.53,0),.23,"oak",-1,true)
	save_decor("side_table","圆形边几")

func build() -> void:
	palette()
	rug("rug",2.6,3.2,"sage_fabric")
	rug("runner",.7,2.4,"rust")
	rug("bath_mat",1.0,.55,"linen")
	plant()
	plant(true)
	curtain()
	art()
	art(true)
	lamp()
	lamp(true)
	for id in ["place_setting","fruit_bowl","books_vase","towels","pet_bowls","prep_board"]:tabletop(id)
	basket()
	washer()
	shower()
	console()
	storage()
	shelf()
	side_table()
	FileAccess.open(BASE+"decor_catalog.json",FileAccess.WRITE).store_string(JSON.stringify({"units":"metres","items":records},"\t"))
	print("DECOR_BUILD ",JSON.stringify({"assets":records.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
