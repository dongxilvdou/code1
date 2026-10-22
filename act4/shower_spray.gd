extends Node3D
## Ballistic droplets originate at the existing rain head and stop at its tray.
const SOURCE := Vector3(0,1.954,-.12)
const FLOOR_Y := .057
const COUNT := 420
var elapsed := 0.0
var running := false
var stop_after := 0.0
var drops: MultiMeshInstance3D
var ripples: MultiMeshInstance3D
var drop_positions := PackedVector3Array()
var sound: AudioStreamPlayer3D

func _ready() -> void:
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(.66,.85,.90,.68)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = .14
	water.metallic = .12
	water.vertex_color_use_as_albedo = true
	var drop := SphereMesh.new()
	drop.radius = .5;drop.height = 1
	drop.radial_segments = 8;drop.rings = 4
	drops = multimesh(drop,COUNT,water)
	drop_positions.resize(COUNT)
	var ring := TorusMesh.new()
	ring.inner_radius = .86;ring.outer_radius = 1
	ring.rings = 20;ring.ring_segments = 4
	ripples = multimesh(ring,32,water)
	sound = AudioStreamPlayer3D.new()
	var audio := load("res://act2/water_pour.wav").duplicate() as AudioStreamWAV
	audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.loop_end = audio.data.size()/2
	sound.stream = audio;sound.volume_db = -20;sound.max_distance = 7
	add_child(sound)
	hide()

func multimesh(mesh: Mesh, amount: int, mat: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_colors = true
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = amount
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func start(duration := 0.0) -> void:
	running = true;stop_after = duration;elapsed = 0
	show()
	if not sound.playing:sound.play()
	update_drops()

func stop() -> void:
	running = false
	hide()
	if is_instance_valid(sound):sound.stop()

func _process(delta: float) -> void:
	if not running:return
	# Menus/dialogue pause the scene's effect and sound as well as task progress.
	var game := get_tree().current_scene
	if game and (not game.player.active or game.cinematic_active):
		sound.stream_paused = true
		return
	sound.stream_paused = false
	elapsed += delta
	if stop_after>0 and elapsed>=stop_after:stop();return
	update_drops()

func update_drops() -> void:
	for i in range(COUNT):
		var seed_ := fposmod(i*.61803399,1)
		var speed := 1.0+fposmod(i*.37,1)*1.4
		var flight := (-speed+sqrt(speed*speed+20*(SOURCE.y-FLOOR_Y)))/10
		var t := fposmod(elapsed+seed_*flight,flight)
		var angle := i*2.39996
		var radius := sqrt(fposmod(i*.754877,1))*.078
		var radial := Vector3(sin(angle),0,cos(angle))
		var pos := SOURCE+radial*(radius+t*.18)
		pos.y -= speed*t+5*t*t
		drop_positions[i] = pos
		var width := .0015+seed_*.0018
		var length_ := .005+(speed+10*t)*.0018
		drops.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(width,length_,width)),pos))
		drops.multimesh.set_instance_color(i,Color(1,1,1,.35+seed_*.55))
	for i in range(32):
		var t := fposmod(elapsed*2.7+i*.618,1)
		var angle := i*2.39996
		var pos := Vector3(sin(angle)*sqrt(fposmod(i*.37,1))*.18,FLOOR_Y+.001,cos(angle)*sqrt(fposmod(i*.37,1))*.18-.12)
		ripples.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(.006+t*.026,.001,.006+t*.026)),pos))
		ripples.multimesh.set_instance_color(i,Color(1,1,1,(1-t)*.5))
