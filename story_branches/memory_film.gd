extends "res://story_branches/film_base.gd"
const Copy=preload("res://story_branches/data.gd")
const Actors=preload("res://story_branches/actors.gd")
var memory: Node3D
var level := 1
var readonly := true
var return_view := ""
var director: Node3D
var recording: AudioStreamPlayer

func _begin() -> void:
	memory=stage("memory_vignette",Vector3(64,-35,0));new_camera();memory.play_action(&"care")
	aim(memory.get_node("CarePOV"),512,memory.get_node("StageCamera").environment)
	if level==3:
		director=Actors.person(memory,"X主任",512);director.position=Vector3(.65,0,.25)
		recording=audio("res://story_branches/audio/transfer_log.wav",-14);recording.play()
	caption.text=Copy.memory_caption(level)

func _tick(_delta: float) -> void:
	if level==3:camera.global_position=memory.get_node("CarePOV").global_position+Vector3(0,-1.15*smoothstep(2,7,clock),0)
	if clock>=9:done()

func done() -> void:
	if finished:return
	resume()
	if not readonly and not chapter.state.patch({}, {"br_memory_seen_mask":chapter.value("br_memory_seen_mask")|(1<<(level-1))}):
		ask("记忆核对已保留，观看记录保存失败。",[["重试",done]]);return
	finished=true;release();chapter.state.busy=false;chapter.state.replay=false
	if not return_view.is_empty():chapter.open_panel(return_view)
	queue_free()

func skip() -> void:done()

func cancel() -> void:
	super.cancel();chapter.state.busy=false;chapter.state.replay=false
