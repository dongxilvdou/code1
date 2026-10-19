extends SubViewportContainer
## Live 3D view of the same house plant and watering-can model, with volumetric spray.
const Props = preload("res://furniture_pack/quest_props/props.gd")
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var can: Node3D
var water: StandardMaterial3D
var ring_material: StandardMaterial3D
var jets: Array[MeshInstance3D] = []
var drops: MultiMeshInstance3D
var wet: MeshInstance3D
var sound: AudioStreamPlayer
var elapsed := 0.0
var pouring := false
var on_target := false
var aim := Vector3(0,.283,0)
var progress := 0.0
var last_mouse := Vector2.ZERO
const SOIL_Y := .283
const TARGET_RADIUS := .145

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = Vector2i(580,300)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("253731")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d1dfd6")
	settings.ambient_light_energy = .65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-25,0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	stage.add_child(sun)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(.48,1.18,1.9)
	camera.look_at(Vector3(-.12,.42,0))
	camera.fov = 42
	camera.near = .02
	camera.current = true
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4,4)
	ground.mesh = plane
	ground.material_override = material(Color("69766a"),.95)
	stage.add_child(ground)
	can = Node3D.new()
	stage.add_child(can)
	can.position = Vector3(-.60,.76,.34)
	can.rotation.z = -.15
	Props.model(can,"watering_can")
	water = material(Color(.55,.86,.98,.82),.12)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	water.metallic = .12
	water.emission_enabled = true
	water.emission = Color(.08,.16,.18)
	water.emission_energy_multiplier = .2
	for i in range(5):
		var jet := MeshInstance3D.new()
		jet.material_override = water
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.add_child(jet)
		jets.append(jet)
	drops = MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = .5
	sphere.height = 1
	sphere.radial_segments = 8
	sphere.rings = 4
	multimesh.mesh = sphere
	multimesh.instance_count = 120
	drops.multimesh = multimesh
	drops.material_override = water
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(drops)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = .108
	torus.outer_radius = .116
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.position.y = SOIL_Y+.003
	ring_material = material(Color("d5c28d"),.65)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	stage.add_child(ring)
	wet = MeshInstance3D.new()
	var patch := CylinderMesh.new()
	patch.top_radius = .1
	patch.bottom_radius = .1
	patch.height = .002
	wet.mesh = patch
	wet.position.y = SOIL_Y+.001
	wet.material_override = material(Color("263728"),.35)
	stage.add_child(wet)
	sound = AudioStreamPlayer.new()
	add_child(sound)
	sound.stream = load("res://act2/water_pour.wav")
	if sound.stream is AudioStreamWAV:
		sound.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.stream.loop_begin = 0
		sound.stream.loop_end = sound.stream.data.size()/2
	sound.volume_db = -24
	set_flow(false)

func material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result

func use_plant(original: Node3D) -> void:
	var plant := Node3D.new()
	plant.name = "RealHousePlant"
	stage.add_child(plant)
	# Copy geometry only: no duplicate scripts, furniture groups, interactions or collisions.
	for source in original.find_children("*","MeshInstance3D",true,false):
		if not source.visible:continue
		var clone := MeshInstance3D.new()
		clone.mesh = source.mesh
		clone.material_override = source.material_override
		plant.add_child(clone)
		clone.transform = original.global_transform.affine_inverse()*source.global_transform

func aim_at(mouse: Vector2) -> bool:
	last_mouse = mouse
	var pixel := mouse/size*Vector2(viewport.size)
	var origin := camera.project_ray_origin(pixel)
	var direction := camera.project_ray_normal(pixel)
	if absf(direction.y)<.001:return false
	var t := (SOIL_Y-origin.y)/direction.y
	aim = origin+direction*t
	on_target = Rect2(Vector2.ZERO,size).has_point(mouse) and Vector2(aim.x,aim.z).length()<TARGET_RADIUS
	if not on_target:
		var floor_t := -origin.y/direction.y
		aim = origin+direction*floor_t
	ring_material.albedo_color = Color("9de0bc") if on_target else Color("d5c28d")
	queue_redraw()
	return on_target

func soil_screen_position() -> Vector2:
	return camera.unproject_position(Vector3(0,SOIL_Y,0))/Vector2(viewport.size)*size

func set_flow(enabled: bool) -> void:
	pouring = enabled
	for jet in jets:jet.visible = enabled
	drops.visible = enabled
	if enabled and not sound.playing:sound.play()
	elif not enabled:sound.stop()

func sample(start: Vector3, end: Vector3, t: float) -> Vector3:
	var point := start.lerp(end,t)
	point.y = start.y-(start.y-end.y)*t*t
	return point

func jet_mesh(start: Vector3, end: Vector3, strand: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: Array[Vector3] = []
	for i in range(15):
		var t := float(i)/14
		var point := sample(start,end,t)
		var tangent := (sample(start,end,minf(1,t+.01))-sample(start,end,maxf(0,t-.01))).normalized()
		var u := tangent.cross(Vector3.FORWARD).normalized()
		var v := tangent.cross(u).normalized()
		for side in range(6):
			var angle := side*TAU/6
			vertices.append(point+(u*cos(angle)+v*sin(angle))*(.0028+strand*.0002))
	for i in range(14):
		for side in range(6):
			var a := i*6+side
			var b := i*6+(side+1)%6
			for index in [a,b,b+6,a,b+6,a+6]:surface.add_vertex(vertices[index])
	surface.generate_normals()
	return surface.commit()

func _process(delta: float) -> void:
	if not is_instance_valid(can):return
	if not is_visible_in_tree():
		if pouring:set_flow(false)
		return
	elapsed += delta
	can.rotation.z = lerpf(can.rotation.z,-1.10 if pouring else -.15,minf(1,delta*9))
	wet.scale = Vector3.ONE*lerpf(.08,1.0,clampf(progress,0,1))
	if not pouring:return
	var start := can.to_global(Vector3(.30,.273,0))
	for strand in range(5):
		var angle := strand*TAU/5
		var offset := Vector3(cos(angle)*.011,0,sin(angle)*.011)
		jets[strand].mesh = jet_mesh(start+offset,aim+offset*2,strand)
	for i in range(120):
		var point := Vector3.ZERO
		var scale_ := Vector3(.006,.012,.006)
		if i<80:
			var t := fmod(elapsed*(1.6+float(i%5)*.04)+float(i)/80.0,1.0)
			var angle := float(i%5)*TAU/5
			point = sample(start,aim,t)+Vector3(cos(angle),0,sin(angle))*.014
		else:
			var time := fmod(elapsed+float(i)*.037,.40)
			var angle := float(i)*2.4
			point = aim+Vector3(cos(angle)*time*.35,time*.65-time*time*2.5,sin(angle)*time*.35)
			scale_ = Vector3.ONE*.006 if point.y>aim.y else Vector3.ZERO
		drops.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(scale_),point))

func _draw() -> void:
	if not Rect2(Vector2.ZERO,size).has_point(last_mouse):return
	draw_arc(last_mouse,8,0,TAU,24,Color("cce9df") if on_target else Color("ece0bd"),1.5,true)
