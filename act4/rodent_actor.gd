extends Node3D
## Shared game-scale assets; sound pauses with story panels and inactive quests.
var is_mole := false
var enabled := false
var moving := false
var elapsed := 0.0
var squeak_wait := 2.0
var squeak_count := 0
var visual: Node3D
var sound: AudioStreamPlayer3D
var paws: Array = []
var tail: Node3D
var rng := RandomNumberGenerator.new()

func build(mole: bool) -> void:
	is_mole = mole
	visual = load("res://furniture_pack/quest_props/"+("mole_upper_body.glb" if mole else "house_mouse.glb")).instantiate()
	add_child(visual)
	for node in visual.find_children("*","MeshInstance3D",true,false):
		if str(node.name).begins_with("ForePaw") or str(node.name).begins_with("HindPaw"):paws.append([node,node.position])
		if node.name==&"TaperedTail":tail=node
	for toe in visual.find_children("PawToe*","MeshInstance3D",true,false):
		var nearest: Node3D
		var best := INF
		for entry in paws:
			var distance_: float = entry[0].global_position.distance_to(toe.global_position)
			if distance_<best:best=distance_;nearest=entry[0]
		if nearest:toe.reparent(nearest,true)
	if not mole:
		sound = AudioStreamPlayer3D.new()
		sound.unit_size = 2.0
		sound.max_distance = 13
		sound.volume_db = -16
		add_child(sound)
		rng.randomize()
		squeak_wait = rng.randf_range(1.5,3.5)

func set_active(value: bool, running := false) -> void:
	enabled = value
	moving = running
	if not value and is_instance_valid(sound):sound.stop()

func _process(delta: float) -> void:
	if not enabled or not is_visible_in_tree():return
	elapsed += delta
	visual.position.y = (-.025 if not is_mole else 0.0)+sin(elapsed*2.1)*.0006
	if tail:tail.rotation.y = sin(elapsed*(17 if moving else 3))*(.10 if moving else .035)
	for i in range(paws.size()):
		paws[i][0].position = paws[i][1]+Vector3(0,maxf(0,sin(elapsed*30+i*PI))*.007 if moving else 0,0)
	if is_mole:return
	squeak_wait -= delta
	if squeak_wait<=0:
		sound.stream = load("res://act4/audio/mouse_squeak_%d.wav"%rng.randi_range(0,2))
		sound.pitch_scale = rng.randf_range(.92,1.08)
		sound.play()
		squeak_count += 1
		squeak_wait = rng.randf_range(3.2,6.8)
