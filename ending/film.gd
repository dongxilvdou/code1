extends Node3D
const Art = preload("res://furniture_pack/quest_props/refined_props.gd")
const Geometry = preload("res://ending/world.gd")
var chapter
var camera: Camera3D
var duct: Node3D
var home: Node3D
var friend_cat: Node3D
var home_dog: Node3D
var running := false
var time := 0.0
var home_time := 0.0
var home_started := false
var geometry: Geometry
var original_lights: Array = []
var daylight_opening: MeshInstance3D
var exit_light: OmniLight3D
const DUCT_ORIGIN := Vector3(32,-10,0)
const HOME_ORIGIN := Vector3(32,0,0)

func build(owner_: Node) -> void:
	chapter=owner_
	for light_ in chapter.game.get_node("Apartment").find_children("*","Light3D",true,false):
		original_lights.append([light_,light_.light_cull_mask])
		light_.light_cull_mask=light_.light_cull_mask & ~(32|64)
	geometry=Geometry.new()
	add_child(geometry)
	camera=Camera3D.new();camera.name="EndingCamera";camera.near=.025;camera.far=55;camera.fov=65;camera.cull_mask=1|2|4|16;add_child(camera)
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("071014")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("63797b");environment.ambient_light_energy=.24
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	camera.environment=environment
	duct=Node3D.new();duct.name="EscapeDuct";add_child(duct);duct.position=DUCT_ORIGIN
	var metal:=geometry.material("duct_steel",Color("394d50"),.20)
	metal.roughness=.78
	var noise:=FastNoiseLite.new();noise.frequency=.13
	var texture:=NoiseTexture2D.new();texture.width=128;texture.height=128;texture.noise=noise
	var ramp:=Gradient.new();ramp.set_color(0,Color("17272c"));ramp.set_color(1,Color("52686b"));texture.color_ramp=ramp
	metal.albedo_color=Color.WHITE;metal.albedo_texture=texture;metal.uv1_triplanar=true;metal.uv1_scale=Vector3(12,12,12)
	geometry.block(duct,"DuctFloor",Vector3(0,-.025,-10),Vector3(.90,.05,22),metal)
	geometry.block(duct,"DuctCeiling",Vector3(0,.68,-10),Vector3(.90,.04,22),metal)
	for x in [-.45,.45]:geometry.block(duct,"DuctWall",Vector3(x,.32,-10),Vector3(.03,.70,22),metal)
	for i in range(19):
		var z: float=-i*1.1
		for x in [-.432,.432]:
			geometry.block(duct,"FoldedPanelSeam",Vector3(x,.32,z),Vector3(.018,.65,.027),geometry.material("duct_seam",Color("6c7c79"),.7))
			for y in [.08,.56]:
				var rivet:=geometry.cylinder(duct,"DuctRivet",Vector3(x,y,z),.008,.012,metal);rivet.rotation.z=PI/2
		geometry.block(duct,"CrossSeam",Vector3(0,.006,z),Vector3(.86,.012,.025),metal)
		if i%2==0:
			geometry.paw(duct,Vector3(.055,.012,z-.4))
			for j in range(3):Art.rod(duct,"OldDuctScratches",Vector3(.16+j*.02,.013,z-.13),Vector3(.18+j*.02,.013,z-.38),.0018,geometry.material("duct_scratch",Color("929787")))
	var light:=SpotLight3D.new();light.name="FaintDuctLight";light.light_color=Color("86a6ae");light.light_energy=1.0;light.spot_range=4.5;light.spot_angle=62;light.shadow_enabled=false;light.light_cull_mask=64;camera.add_child(light)
	var exit_mat:=geometry.material("daylight",Color("e5eed7"));exit_mat.emission_enabled=true;exit_mat.emission=Color("e5eed7");exit_mat.emission_energy_multiplier=2.0
	daylight_opening=geometry.block(duct,"DaylightOpening",Vector3(0,.32,-21),Vector3(.85,.64,.025),exit_mat)
	exit_light=OmniLight3D.new();exit_light.position=Vector3(0,.36,-19.6);exit_light.light_color=Color("e8e5c8");exit_light.omni_range=5;exit_light.light_cull_mask=64;duct.add_child(exit_light)
	build_home()
	for mesh in duct.find_children("*","MeshInstance3D",true,false):mesh.layers=64
	for mesh in home.find_children("*","MeshInstance3D",true,false):mesh.layers=32
	duct.hide();home.hide();set_process(false);set_process_input(false)

func build_home() -> void:
	home=Node3D.new();home.name="OriginalHome";add_child(home);home.position=HOME_ORIGIN
	geometry.block(home,"HomeFloor",Vector3(0,-.09,-.6),Vector3(8,.18,9),load("res://furniture_pack/materials/oak.tres"))
	var plaster:=geometry.material("home_wall",Color("c7c7ab"))
	geometry.block(home,"HomeBackWall",Vector3(0,1.5,-4.2),Vector3(8,3,.12),plaster)
	geometry.block(home,"HomeSideWall",Vector3(-4,1.5,-.3),Vector3(.12,3,8),plaster)
	geometry.block(home,"HomeRightWall",Vector3(4,1.5,-.3),Vector3(.12,3,8),plaster)
	geometry.block(home,"HomeCeiling",Vector3(0,3.05,-.3),Vector3(8,.10,8),plaster)
	for x in [-3.94,3.94]:geometry.block(home,"HomeSkirting",Vector3(x,.09,-.4),Vector3(.03,.18,7.5),load("res://furniture_pack/materials/oak.tres"))
	for spec in [["sofa",Vector3(-2,0,-2.1),PI/2],["coffee_table",Vector3(-1.20,0,-.9),0],["decor_rug",Vector3(-.25,.004,-.3),0],["decor_plant",Vector3(-3.1,0,-3.5),0],["floor_lamp",Vector3(-3.1,0,-1.1),0],["decor_wall_art",Vector3(-1.4,1.65,-4.10),0],["decor_curtains",Vector3(1.2,0,-4.07),0]]:
		var piece:=load("res://furniture_pack/scenes/"+str(spec[0])+".tscn") as PackedScene
		var prop:=piece.instantiate() as Node3D;home.add_child(prop);prop.position=spec[1];prop.rotation.y=spec[2]
		for body in prop.find_children("*","CollisionObject3D",true,false):body.collision_layer=0
	var window:=geometry.material("home_window",Color("d0e0d6"));window.emission_enabled=true;window.emission=Color("bbd7d2");window.emission_energy_multiplier=.3
	geometry.block(home,"HomeWindow",Vector3(1.2,1.62,-4.10),Vector3(1.50,1.70,.025),window)
	for x in [.43,1.2,1.97]:geometry.block(home,"WindowMullion",Vector3(x,1.62,-4.075),Vector3(.045,1.78,.055),load("res://furniture_pack/materials/oak.tres"))
	for y in [.74,2.50]:geometry.block(home,"WindowFrame",Vector3(1.2,y,-4.075),Vector3(1.59,.045,.055),load("res://furniture_pack/materials/oak.tres"))
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-44,-27,0);sun.light_color=Color("ffe2ae");sun.light_energy=.65;sun.light_cull_mask=32;sun.shadow_enabled=false;home.add_child(sun)
	var fill:=OmniLight3D.new();fill.position=Vector3(1,2,-1);fill.light_color=Color("f8e7c7");fill.light_energy=.7;fill.omni_range=8;fill.light_cull_mask=32;home.add_child(fill)
	friend_cat=load("res://scenes/calico.tscn").instantiate();friend_cat.name="HomeFriendCat";home.add_child(friend_cat);friend_cat.scale=Vector3.ONE*.8
	# Reuse the authored pet rigs. The home animals are separate story characters.
	home_dog=load("res://furniture_pack/scenes/dog_nest.tscn").instantiate() as Node3D
	home_dog.name="HomeDog";home.add_child(home_dog);home_dog.position=Vector3(1.6,0,-1.45);home_dog.rotation=Vector3(0,-.35,0);home_dog.pose_mode="stand"
	home_dog.set_pose("stand",true)
	for body in home_dog.find_children("*","CollisionObject3D",true,false):body.collision_layer=0

func play(finished := false) -> void:
	running=true;time=0;home_time=0;home_started=false
	chapter.ui.close();chapter.ui.film_root.show();chapter.ui.blackout.color=Color(0,0,0,1);chapter.ui.shade_lids(0)
	chapter.game.cinematic_active=true;chapter.player.set_control(false);chapter.player.velocity=Vector3.ZERO
	chapter.game.ui.hud.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	duct.show();home.hide();camera.make_current();set_process(true);set_process_input(true)
	camera.cull_mask=64;camera.environment.ambient_light_color=Color("63797b");camera.environment.ambient_light_energy=.42
	chapter.game.rain_audio.volume_db=-32
	if finished:
		start_home();home_time=7;update_home();finish()
	else:update_duct()

func _process(delta: float) -> void:
	if not running:return
	if not home_started:
		time+=delta
		update_duct()
		if time>=22:start_home()
	else:
		home_time+=delta;update_home()
		if home_time>=8:finish()

func update_duct() -> void:
	daylight_opening.visible=time>15
	exit_light.light_energy=smoothstep(15,20,time)
	var progress:=clampf(time/21,0,1)
	var travel:=20*(1-pow(1-progress,1.35))
	camera.global_position=DUCT_ORIGIN+Vector3(sin(time*1.4)*.014,.23-smoothstep(8,19,time)*.055+sin(time*2.1)*.007,-travel)
	camera.rotation=Vector3(-.05-smoothstep(8,18,time)*.10,0,sin(time*.9)*.028*smoothstep(5,15,time))
	chapter.ui.blackout.color=Color(0,0,0,1-smoothstep(0,1.2,time))
	if time>20.4:chapter.ui.blackout.color=Color(1,.99,.92,smoothstep(20.4,22,time))
	var tired:=smoothstep(4,18,time)
	chapter.ui.shade_lids(tired*(.14+pow(maxf(0,sin(time*.85)),8)*.30))
	if time<5:chapter.ui.caption.text="沿着旧抓痕，往前。\n\n空格 · 跳至归家"
	elif time<10:chapter.ui.caption.text="通道好长……身体，越来越难受。"
	elif time<15:chapter.ui.caption.text="眼皮好重。不能在这里睡着……"
	elif time<19:chapter.ui.caption.text="再往前一点……"
	else:chapter.ui.caption.text="光……"

func start_home() -> void:
	home_started=true;home_time=0;duct.hide();home.show();chapter.ui.shade_lids(0)
	camera.cull_mask=32;camera.environment.ambient_light_color=Color("b0a38b");camera.environment.ambient_light_energy=.65
	camera.fov=68;camera.global_position=HOME_ORIGIN+Vector3(.15,.28,2.1);camera.look_at(HOME_ORIGIN+Vector3(.05,.34,-1.6))
	friend_cat.position=Vector3(-.4,0,-2.25);friend_cat.rotation=Vector3(0,PI,0);friend_cat.preview_pose="idle";friend_cat.speed=0

func update_home() -> void:
	chapter.ui.blackout.color=Color(1,.99,.92,1-smoothstep(0,1.6,home_time))
	chapter.ui.caption.text="这是……原来的家。\n它们还在这里。" if home_time<3 else "它看见我了。"
	if home_time>2:
		friend_cat.preview_pose="run" if home_time<5.6 else "idle"
		friend_cat.speed=2.0 if home_time<5.6 else 0
		friend_cat.position=Vector3(-.4,0,-2.25).lerp(Vector3(.03,0,.95),smoothstep(2,5.6,home_time))
		if home_time>5.6:friend_cat.curious=1
	if home_time>6.6:chapter.ui.blackout.color=Color(0,0,0,smoothstep(6.6,8,home_time)*.65)

func finish() -> void:
	running=false;set_process(false);set_process_input(false)
	chapter.ui.caption.text="";chapter.ui.shade_lids(0)
	chapter.finish_ending()

func _input(event: InputEvent) -> void:
	if not running:return
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_SPACE,KEY_ENTER] and not home_started and time>1:start_home()
		get_viewport().set_input_as_handled()

func reset() -> void:
	running=false;set_process(false);set_process_input(false);duct.hide();home.hide()
	chapter.ui.film_root.hide();chapter.ui.shade_lids(0)
	chapter.game.rain_audio.volume_db=-13
	chapter.game.ui.hud.show()
	if camera.current:chapter.player.camera.make_current()
	restore_lights()

func restore_lights() -> void:
	for entry in original_lights:
		if is_instance_valid(entry[0]):entry[0].light_cull_mask=entry[1]
	original_lights.clear()

func _exit_tree() -> void:restore_lights()
