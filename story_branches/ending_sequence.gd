extends "res://story_branches/film_base.gd"
const Actors=preload("res://story_branches/actors.gd")
var kind := 3
var segment := ""
var local_time := 0.0
var old_film: Node3D
var bay: Node3D
var rescue: Node3D
var cat: Node3D
var guide: Node3D
var investigator: Node3D
var hands: Node3D
var exit_cat: Node3D
var original_lights: Array=[]
var researcher: Node3D
var default_route := false

func _begin() -> void:
	kind=chapter.value("br_ending")
	default_route=chapter.value("br_route")==1 and not chapter.flag("br_legacy_flow")
	choice_align_right=true
	if kind==2:
		bay=stage("recovery_bay",Vector3(64,-20,0));new_camera()
		aim(chapter.game.get_node("Ending").world.retrofit.get_node("DrawerCam"),1|4|16,chapter.game.player.camera.environment)
		cat=preload("res://scenes/calico.tscn").instantiate();chapter.game.add_child(cat);stages.append(cat);cat.scale=Vector3.ONE*.8;Actors.layers(cat,4)
		cat.global_position=chapter.game.get_node("Ending").world.retrofit.get_node("CareCatRest").global_position;cat.preview_pose="sit"
		segment="transfer"
	else:
		old_film=preload("res://ending/film.gd").new();add_child(old_film);old_film.build(chapter.game.get_node("Ending"));old_film.set_process(false);old_film.set_process_input(false)
		camera=old_film.camera;camera.make_current();old_film.duct.show();old_film.home.hide();segment="duct"
		if chapter.value("br_mouse")==2:
			guide=preload("res://furniture_pack/quest_props/house_mouse.glb").instantiate();old_film.duct.add_child(guide);guide.scale=Vector3.ONE*.48;Actors.layers(guide,64)
		build_exit()
	local_time=0

func build_exit() -> void:
	var Art=preload("res://furniture_pack/quest_props/refined_props.gd")
	var floor:=BoxMesh.new();floor.size=Vector3(5,.08,4)
	var outside: MeshInstance3D=Art.mesh_node(old_film.duct,"OutsideGround",floor,Art.material("branch_grass",Color("78866c"),.95),Vector3(0,-.05,-22))
	outside.layers=64
	exit_cat=preload("res://scenes/calico.tscn").instantiate();old_film.duct.add_child(exit_cat);exit_cat.scale=Vector3.ONE*.8;Actors.layers(exit_cat,64);exit_cat.hide()

func _tick(delta: float) -> void:
	local_time+=delta
	match segment:
		"transfer":
			if local_time<3:caption.text="C-031 → H-031\n维持稳定。目标校验通过。"
			elif local_time<7:
				fade.color=Color(.8,.9,.86,sin((local_time-3)/4*PI)*.65);caption.text="反向传输开始。"
			elif local_time<12:
				fade.color.a=0
				aim(bay.get_node("HumanWakeCam"),128,bay.get_node("StageCamera").environment)
				bay.get_node("ResearcherH031").hide()
				if hands==null:hands=Actors.hands(camera,128)
				hands.visible=true;caption.text="我……回来了。"
			else:
				if hands:hands.hide()
				cat.curious=1
				aim(chapter.game.get_node("Ending").world.retrofit.get_node("DrawerCam"),1|4|16,chapter.game.player.camera.environment)
				caption.text="米酥的原生意识已从休眠恢复，生命体征稳定。\n研究员：米酥，是我。别怕。"
				ask("它抬起头，随后又缩了回去。",[["蹲下，等它靠近",begin_care]])
		"care":
			cat.global_position=chapter.game.get_node("Ending").world.retrofit.get_node("CareCatRest").global_position+Vector3(.10,0,.10)*smoothstep(0,3,local_time)
			caption.text="研究员：这次，你不想过来，也可以。"
			if local_time>4:start_rescue()
		"duct":
			old_film.time=local_time;old_film.update_duct();caption.text=chapter.game.get_node("Ending").ui.caption.text;fade.color=chapter.game.get_node("Ending").ui.blackout.color
			if not default_route and not chapter.flag("br_legacy_flow") and chapter.value("br_route")==2:
				# This route has permanent control freedom; retain the duct, without the old collapse cues.
				chapter.game.get_node("Ending").ui.shade_lids(0)
				camera.global_position.y=old_film.DUCT_ORIGIN.y+.23+sin(local_time*2.1)*.007
				camera.rotation=Vector3(-.05,0,sin(local_time*.9)*.008)
				if local_time<5:caption.text="老鼠在前面带路。跟上它。"
				elif local_time<10:caption.text="通道很窄。可这一次，我的爪子听从自己的意思。"
				elif local_time<15:caption.text="它停下来等我。再往前一点。"
				else:caption.text="出口就在前面。"
			if guide:
				var ahead: float=clampf(-camera.global_position.z-10+2,1,20)
				guide.position=Vector3(.10,.02,-ahead)
			if local_time>=22:segment="outside";local_time=0;fade.color.a=0;old_film.daylight_opening.hide();exit_cat.show()
		"outside":
			camera.cull_mask=64;camera.global_position=old_film.DUCT_ORIGIN+Vector3(1.1,.6,-23.2);camera.look_at(old_film.DUCT_ORIGIN+Vector3(0,.25,-21.3))
			exit_cat.position=Vector3(0,0,-20.8-1.1*smoothstep(0,3,local_time));exit_cat.preview_pose="walk";exit_cat.speed=.6
			caption.text="爬出外墙了。\n"+("我得把纸条带到能求助的人面前。" if not default_route else "身体仍不舒服。先离开这里。")
			if local_time>3.5:old_film.start_home();segment="home";local_time=0
		"home":
			old_film.home_time=local_time;old_film.update_home();fade.color=chapter.game.get_node("Ending").ui.blackout.color
			caption.text="离开分站后\n这是……原来的家。" if local_time<3 else "它看见我了。原住的狗也还在这里。"
			if guide:
				if guide.get_parent()!=old_film.home:guide.reparent(old_film.home);Actors.layers(guide,32)
				guide.position=Vector3(-1.5+smoothstep(2,6,local_time),.02,.6)
			if local_time>=8:
				if default_route:default_summary();return
				old_film.home.hide();segment="terminal";local_time=0
				aim(chapter.game.get_node("Ending").world.retrofit.get_node("ServiceCam"),1|4|16,chapter.game.player.camera.environment)
		"terminal":
			fade.color=Color(0,0,0,.15);caption.text="实验失败\n对象离开监测范围，观察中断。"
			if local_time>3:
				if default_route:default_summary()
				else:start_rescue()
		"rescue":update_rescue()

func begin_care() -> void:
	clear_choice();segment="care";local_time=0
	if hands:hands.hide()
	var marker: Node3D=chapter.game.get_node("Ending").world.retrofit.get_node("CareHandStop")
	camera.global_position=marker.global_position+Vector3(.40,.40,.40);camera.look_at(cat.global_position+Vector3(0,.13,0));camera.cull_mask=1|4|16
	if hands:hands.queue_free()
	hands=Actors.hands(camera,4)

func start_rescue() -> void:
	clear_choice();resume();fade.color.a=0;segment="rescue";local_time=0
	if cat:cat.hide()
	if hands:hands.hide()
	if old_film:old_film.duct.hide();old_film.home.hide()
	rescue=stage("rescue_stage",Vector3(64,0,0));rescue.apply_visual_state({"br_mouse":chapter.value("br_mouse"),"branch":kind})
	aim(rescue.get_node("RescueCam"),256,rescue.get_node("StageCamera").environment)
	rescue.get_node("AjaoVisual").position=rescue.get_node("DogInside").position
	investigator=Actors.person(rescue,"调查",256);investigator.position=Vector3(.8,0,1.35)
	if kind==2:
		researcher=Actors.person(rescue,"研究员",256);researcher.position=Vector3(-.15,0,-.65);researcher.carry(true)
		rescue.get_node("MisoVisual").position=researcher.position+Vector3(0,.94,.44);rescue.get_node("MisoVisual").rotation.y=PI/2
	var paper:=Label3D.new();paper.text="D-017 / C-031\n"+preload("res://story_branches/data.gd").STATION_ADDRESS;paper.font_size=25;paper.pixel_size=.0018;paper.position=Vector3(-.65,.07,1.2);paper.rotation.x=-PI/2;rescue.add_child(paper);paper.layers=256

func update_rescue() -> void:
	if investigator:investigator.gait(local_time,1.0 if local_time>3 and local_time<6 else 0.0)
	if researcher:researcher.gait(local_time,1.0 if local_time<5 else 0.0)
	var dog: Node3D=rescue.get_node("AjaoVisual")
	if researcher:
		researcher.position=Vector3(-.15,0,-.65).lerp(Vector3(-.45,0,1.10),smoothstep(0,5,local_time))
		rescue.get_node("MisoVisual").position=researcher.position+Vector3(0,.94,.44);rescue.get_node("MisoVisual").rotation.y=PI/2
	if local_time<3:
		caption.text="归家后，米酥把带有分站地址和编号的纸条推到照护者面前。照护者联系了救援人员。" if kind==3 else "他先联系救援人员，提供住宅分站地址与H-031原始记录；随后抱起米酥，将证据交接。"
	elif local_time<6:
		caption.text="救援人员根据纸条地址、H-031 的档案编号定位住宅分站；接应人员核对记录。"
		investigator.position=Vector3(.8,0,1.35).lerp(Vector3(.15,0,-.3),smoothstep(3,6,local_time))
	elif local_time<10:
		dog.position=rescue.get_node("DogInside").position.lerp(rescue.get_node("DogOutside").position,smoothstep(6,9.5,local_time));dog.rotation.y=0
		caption.text="救援人员从正常入口进屋。阿嚼跨出了分站的门槛。"
	elif local_time<13:
		caption.text="阿嚼：这次，我能自己走了。"
	else:
		caption.text="维持舱及记录一并移交，后续处理仍需等待。" if kind==3 else "米酥、阿嚼与证据，一起离开了分站。"
	if local_time>=16:summary()

func default_summary() -> void:
	resume();caption.text="实验失败。"
	if old_film:old_film.start_home();old_film.home_time=6.4;old_film.update_home();fade.color=Color(0,0,0,.20)
	ask("回到了原来的家。\n另一只猫向我跑来，原住的狗还在熟悉的位置。\n\n送纸条的老鼠已经死亡。阿嚼仍在分站。",[["确认本次经历",finish_ending]])

func summary() -> void:
	if default_route:default_summary();return
	resume()
	if rescue==null:start_rescue()
	rescue.get_node("AjaoVisual").position=rescue.get_node("DogOutside").position
	caption.text="善后确认"
	var text_:="米酥存活。\n阿嚼已从正常入口撤离。\n实验记录已经交给调查人员。"
	if kind==3:text_+="\nH-031 原身体与维持设备已交接转运。"
	if chapter.value("br_mouse")==2:text_+="\n获救的老鼠也在安全处。"
	elif chapter.value("br_mouse")==1:text_+="\n送来纸条的老鼠已经死亡。"
	if not chapter.state.replay and not chapter.state.patch({"br_rescue_performed":true},{}):
		ask("救援过程尚未保存。",[["重试",summary]]);return
	ask(text_,[["确认救援结果",finish_ending]])

func skip() -> void:
	if default_route:
		if old_film:old_film.start_home();old_film.home_time=6.3;old_film.update_home()
		default_summary()
	else:summary()

func release() -> void:
	if not running:return
	if old_film:old_film.restore_lights()
	super.release()
