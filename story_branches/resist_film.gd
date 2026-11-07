extends "res://story_branches/film_base.gd"
var voice: AudioStreamPlayer
var ground_mouse: Node3D
var pressed := false
var spoken := false
var dog: Node3D
var dog_home: Transform3D
var close_camera: Camera3D
var dog_mode := Node.PROCESS_MODE_INHERIT
var lamp_discharged := false

func _begin() -> void:
	voice=audio("res://act4/audio/eat_command.wav",-7)
	var player=chapter.game.player;player.camera.make_current()
	ground_mouse=preload("res://furniture_pack/quest_props/house_mouse.glb").instantiate();chapter.game.add_child(ground_mouse);stages.append(ground_mouse);ground_mouse.scale=Vector3.ONE*.48;ground_mouse.hide()
	dog=chapter.game.get_node("ActThree").world.dog_actor;dog_home=dog.global_transform
	dog_mode=dog.process_mode
	preload("res://story_branches/actors.gd").layers(chapter.world.chest,8)
	close_camera=new_camera();player.camera.make_current()

func _tick(_delta: float) -> void:
	var player=chapter.game.player
	if clock>=1.4 and clock<2.75:
		close_camera.global_position=player.to_global(Vector3(.20,.32,-.54));close_camera.look_at(chapter.world.chest.global_position);close_camera.cull_mask=1|4|8|16;close_camera.fov=42;close_camera.make_current()
	else:player.camera.make_current()
	if clock>=.85 and not spoken:spoken=true;voice.play()
	if clock>=1.8 and not pressed:
		pressed=true;chapter.world.chest.play_action(&"k2_press");chapter.feedback.play_feedback("pulse")
		for i in range(3):chapter.world.chest.device.led("K2LED%d"%(i+1),true)
	if clock>=2.6 and not lamp_discharged:
		lamp_discharged=true
		for i in range(3):chapter.world.chest.device.led("K2LED%d"%(i+1),false)
	player.camera.rotation.z=sin(clock*24)*.008*(1-smoothstep(2.5,5,clock))
	player.pitch=lerpf(snapshot.pitch,-.45,smoothstep(.85,1.5,clock)*(1-smoothstep(3.8,6.6,clock)));player.head.rotation.x=player.pitch
	for entry in snapshot.paws:
		entry[0].show();entry[0].position=Vector3(0,-.13,-.22).lerp(Vector3(.03,-.22,-.12),smoothstep(1.45,2.5,clock));entry[0].rotation.x=deg_to_rad(114)
	var held=chapter.game.get_node("ActFour").held_mouse
	if is_instance_valid(held):held.visible=clock<2.75;held.position.y=lerpf(-.14,-.25,smoothstep(2.3,2.75,clock))
	if clock>=2.75:
		ground_mouse.show();ground_mouse.global_position=Vector3(1.43,.024,-3.48).lerp(Vector3(1.75,.024,-3.76),smoothstep(2.75,4.0,clock))
	if clock>=4:
		dog.global_position=dog_home.origin.lerp(Vector3(1.50,dog_home.origin.y,-3.05),smoothstep(4,4.6,clock))
		ground_mouse.global_position=Vector3(1.75,.024,-3.76).lerp(Vector3(1.15,.024,-4.12),smoothstep(4,5.7,clock))
	if clock<1.4:caption.text="我不吃。离开这里。\n「吃掉它。」"
	elif clock<2.6:caption.text="胸前的按钮……现在。"
	elif clock<4:caption.text="爪子……松开了。"
	elif clock<5.6:caption.text="阿嚼挡住了摄像头。"
	else:caption.text="阿嚼：它跑过去了。你没有吃掉它。"
	if clock>=7:resolve()

func resolve() -> void:
	if finished:return
	resume()
	if not chapter.state.resolve_mouse(2):ask("结果尚未保存。\n"+chapter.state.last_error,[["重试保存",resolve]]);return
	finished=true;release();chapter.mouse_finished();queue_free()

func skip() -> void:resolve()

func toggle_pause() -> void:
	super.toggle_pause()
	if is_instance_valid(dog):dog.process_mode=Node.PROCESS_MODE_DISABLED if paused else dog_mode
	var motion=chapter.world.chest.device.motion
	if motion and motion.is_valid():
		if paused:motion.pause()
		else:motion.play()

func release() -> void:
	if not running:return
	if is_instance_valid(dog):dog.global_transform=dog_home;dog.process_mode=dog_mode
	if is_instance_valid(chapter.world.chest):preload("res://story_branches/actors.gd").layers(chapter.world.chest,2)
	super.release()
