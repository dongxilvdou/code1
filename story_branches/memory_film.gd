extends "res://story_branches/film_base.gd"
const Copy=preload("res://story_branches/data.gd")
const Actors=preload("res://story_branches/actors.gd")
var memory: Node3D
var previous_part := -1
var director: Node3D
var recording: AudioStreamPlayer

func _begin() -> void:
	memory=stage("memory_vignette",Vector3(64,-35,0));new_camera();memory.play_action(&"care")
	aim(memory.get_node("CarePOV"),512,memory.get_node("StageCamera").environment)
	director=Actors.person(memory,"X主任",512);director.position=Vector3(.65,0,.25);director.hide()
	recording=audio("res://story_branches/audio/transfer_log.wav",-14)

func _tick(_delta: float) -> void:
	var part:=mini(2,int(clock/4))
	caption.text=Copy.MEMORY_CAPTIONS[part]
	if part!=previous_part:
		previous_part=part
		if part==1:
			memory.get_node("MemoryMiso").hide()
			var mouse: Node3D=preload("res://furniture_pack/quest_props/house_mouse.glb").instantiate();memory.add_child(mouse);mouse.scale=Vector3.ONE*.48;mouse.position=Vector3(.2,.12,-.1);Actors.layers(mouse,512)
		elif part==2:director.show();recording.play()
	if part==2:camera.global_position=memory.get_node("CarePOV").global_position+Vector3(0,-1.15*smoothstep(8,11.5,clock),0)
	if clock>=12:done()

func done() -> void:
	if finished:return
	finished=true;release();chapter.state.busy=false;chapter.open_panel("repair");queue_free()

func skip() -> void:done()
