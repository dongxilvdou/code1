extends Node
## Day ten's involuntary action owns input only for this short, pausable scene.
const DURATION := 5.4
var chapter
var running := false
var paused := false
var elapsed := 0.0
var resistance := Vector2.ZERO
var voice_played := false
var swallowed := false
var snapshot: Dictionary = {}
var canvases: Array = []
var ui: CanvasLayer
var darkness: ColorRect
var caption: Label
var pause_card: CenterContainer
var resume_button: Button
var voice: AudioStreamPlayer
var swallow: AudioStreamPlayer

func _ready() -> void:
	set_physics_process(false)
	ui=CanvasLayer.new();ui.name="MouseControlScene";ui.layer=80;add_child(ui)
	var screen:=Control.new();ui.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
	darkness=ColorRect.new();screen.add_child(darkness)
	darkness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	darkness.color=Color(0,0,0,0);darkness.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var font:=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"])
	caption=Label.new();screen.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left=90;caption.offset_right=-90;caption.offset_top=-150;caption.offset_bottom=-65
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_override("font",font);caption.add_theme_font_size_override("font_size",27)
	caption.add_theme_color_override("font_color",Color("f0eadb"))
	caption.add_theme_color_override("font_outline_color",Color(0,0,0,.8))
	caption.add_theme_constant_override("outline_size",5)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x",2);caption.add_theme_constant_override("shadow_offset_y",2)
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var hint:=Label.new();screen.add_child(hint)
	hint.text="Esc  暂停";hint.position=Vector2(26,22)
	hint.add_theme_font_override("font",font);hint.add_theme_font_size_override("font_size",16)
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pause_card=CenterContainer.new();screen.add_child(pause_card)
	pause_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	resume_button=Button.new();pause_card.add_child(resume_button)
	resume_button.text="已暂停 · 继续";resume_button.custom_minimum_size=Vector2(260,64)
	resume_button.add_theme_font_override("font",font)
	resume_button.add_theme_font_size_override("font_size",23)
	resume_button.pressed.connect(toggle_pause)
	voice=AudioStreamPlayer.new();add_child(voice)
	voice.stream=load("res://act4/audio/eat_command.wav");voice.volume_db=-5
	swallow=AudioStreamPlayer.new();add_child(swallow)
	swallow.stream=load("res://act4/audio/involuntary_swallow.wav");swallow.volume_db=-12
	ui.hide();pause_card.hide()

func begin() -> bool:
	if running or chapter.today()!=10 or chapter.flag("a10_eat"):return false
	for key in ["a10_catch","a10_note","a10_asked","a10_refused"]:
		if not chapter.flag(key):return false
	var player=chapter.player
	snapshot={"control":player.active,"physics":player.is_physics_processing(),
		"input":player.is_processing_unhandled_input(),"mouse":Input.mouse_mode,
		"yaw":player.yaw,"pitch":player.pitch,"camera":player.camera.transform,"fov":player.camera.fov,
		"cinematic":chapter.game.cinematic_active,"paws":[]}
	for paw in player.paws:snapshot.paws.append([paw,paw.transform,paw.visible])
	if is_instance_valid(chapter.game.rain_audio):
		snapshot.ambience_db=chapter.game.rain_audio.volume_db
		snapshot.ambience_paused=chapter.game.rain_audio.stream_paused
		snapshot.ambience_process=chapter.game.rain_audio.is_processing()
		snapshot.ambience_children=[]
		for child in chapter.game.rain_audio.get_children():
			if child is AudioStreamPlayer:
				snapshot.ambience_children.append([child,child.stream_paused,child.volume_db])
		# The current ambience also switches basement tracks each frame.
		# This scene owns their pause and mix until control is restored.
		chapter.game.rain_audio.set_process(false)
	canvases.clear()
	for canvas in chapter.game.find_children("*","CanvasLayer",true,false):
		if canvas!=ui:
			canvases.append([canvas,canvas.visible]);canvas.hide()
	var toward_exit: Vector3=Vector3(.05,player.global_position.y,-2.75)-player.global_position
	snapshot.leave_yaw=atan2(-toward_exit.x,-toward_exit.z) if toward_exit.length()>.05 else player.yaw+.6
	running=true;paused=false;elapsed=0;resistance=Vector2.ZERO;voice_played=false;swallowed=false
	chapter.game.cinematic_active=true
	player.set_control(false);player.velocity=Vector3.ZERO
	player.set_physics_process(false);player.set_process_unhandled_input(false)
	player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	darkness.color.a=0;pause_card.hide();ui.show()
	set_physics_process(true)
	render_pose(0)
	return true

func _input(event: InputEvent) -> void:
	if not running:return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		toggle_pause();get_viewport().set_input_as_handled();return
	if paused:return
	if event is InputEventMouseMotion:
		resistance.x=clampf(resistance.x-event.relative.x*.0021,-.20,.20)
		resistance.y=clampf(resistance.y-event.relative.y*.0021,-.15,.15)
	if event is InputEventKey or event is InputEventMouse:
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if not running:return
	paused=not paused
	voice.stream_paused=paused;swallow.stream_paused=paused
	if is_instance_valid(chapter.game.rain_audio):
		chapter.game.rain_audio.stream_paused=paused or snapshot.get("ambience_paused",false)
		for entry in snapshot.get("ambience_children",[]):
			if is_instance_valid(entry[0]):entry[0].stream_paused=paused or entry[1]
	pause_card.visible=paused
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused:resume_button.grab_focus()

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not running or paused:return
	if not chapter.active() or chapter.today()!=10:
		cancel();return
	elapsed=minf(elapsed+delta,DURATION)
	if elapsed>=.85 and not voice_played:
		voice_played=true;voice.play()
	if elapsed>=3.6 and not swallowed:
		swallowed=true;swallow.play()
	render_pose(delta)
	if elapsed>=DURATION:chapter.eat_mouse()

func render_pose(delta: float) -> void:
	var player=chapter.player
	var turn:=smoothstep(0.0,.65,elapsed)
	var pull:=smoothstep(.85,1.6,elapsed)
	var recover:=smoothstep(4.55,DURATION,elapsed)
	var resist:=1.0-smoothstep(1.6,2.65,elapsed)
	var yaw: float=lerp_angle(snapshot.yaw,snapshot.leave_yaw,turn)
	yaw=lerp_angle(yaw,snapshot.yaw,pull)
	player.yaw=lerp_angle(yaw+resistance.x*resist,snapshot.yaw,recover)
	player.pitch=lerpf(lerpf(snapshot.pitch,-.65,pull)+resistance.y*resist,snapshot.pitch,recover)
	player.rotation.y=player.yaw;player.head.rotation.x=player.pitch
	player.camera.rotation.z=sin(elapsed*24)*.012*pull*(1.0-recover)
	player.camera.fov=lerpf(snapshot.fov,69.0,pull*(1.0-recover))
	var axis: Vector2=Input.get_vector("move_left","move_right","move_forward","move_back")
	var attempt: Vector3=player.basis*Vector3(axis.x,0,axis.y)*.30*resist
	var direction: Vector3=-player.basis.z
	var speed:=.42 if elapsed<.8 else .22 if elapsed>1.65 and elapsed<2.2 else 0.0
	player.velocity.x=direction.x*speed+attempt.x
	player.velocity.z=direction.z*speed+attempt.z
	player.velocity.y=-.1 if player.is_on_floor() else player.velocity.y-12.0*delta
	if delta>0:player.move_and_slide()
	player.model.speed=Vector2(player.velocity.x,player.velocity.z).length()/player.cat_scale
	for entry in snapshot.paws:
		var paw: Node3D=entry[0]
		paw.visible=elapsed<3.8
		paw.position=Vector3(0,lerpf(-.16,-.13,pull),lerpf(-.17,-.19,pull))
		paw.rotation.x=lerpf(deg_to_rad(112),deg_to_rad(118),pull)
		paw.rotation.z=sin(elapsed*20)*.015*pull
	if is_instance_valid(chapter.held_mouse):
		chapter.held_mouse.visible=elapsed<3.7
		chapter.held_mouse.position=Vector3(.07,-.14,-.30).lerp(Vector3(0,-.08,-.20),pull)
		chapter.held_mouse.rotation.z=.08+sin(elapsed*29)*.018*pull
	darkness.color.a=smoothstep(3.2,3.65,elapsed)*.94*(1.0-smoothstep(4.2,DURATION,elapsed))
	if elapsed<.85:caption.text="我不吃。离开这里。"
	elif elapsed<1.8:caption.text="「吃掉它。」"
	elif elapsed<2.7:caption.text="我说了……我不吃。"
	elif elapsed<3.5:caption.text="为什么还在动？"
	elif elapsed<4.25:caption.text="停下来。"
	else:caption.text="我明明想走……"
	caption.modulate=Color("dfb8a7") if elapsed>=.85 and elapsed<1.8 else Color("f0eadb")
	if snapshot.has("ambience_db"):
		chapter.game.rain_audio.volume_db=lerpf(snapshot.ambience_db,snapshot.ambience_db-17.0,pull*(1.0-recover))
		for entry in snapshot.get("ambience_children",[]):
			if is_instance_valid(entry[0]):entry[0].volume_db=lerpf(entry[2],entry[2]-17.0,pull*(1.0-recover))

func finish() -> void:
	if not running:return
	running=false;paused=false;set_physics_process(false)
	voice.stop();swallow.stop();voice.stream_paused=false;swallow.stream_paused=false
	ui.hide();pause_card.hide()
	var player=chapter.player
	player.velocity=Vector3.ZERO
	player.yaw=snapshot.yaw;player.rotation.y=player.yaw
	player.pitch=snapshot.pitch;player.head.rotation.x=player.pitch
	player.camera.transform=snapshot.camera;player.camera.fov=snapshot.fov
	for entry in snapshot.paws:
		if is_instance_valid(entry[0]):entry[0].transform=entry[1];entry[0].visible=entry[2]
	for entry in canvases:
		if is_instance_valid(entry[0]):entry[0].visible=entry[1]
	canvases.clear()
	if snapshot.has("ambience_db") and is_instance_valid(chapter.game.rain_audio):
		chapter.game.rain_audio.volume_db=snapshot.ambience_db
		chapter.game.rain_audio.stream_paused=snapshot.ambience_paused
		for entry in snapshot.get("ambience_children",[]):
			if is_instance_valid(entry[0]):entry[0].stream_paused=entry[1];entry[0].volume_db=entry[2]
		chapter.game.rain_audio.set_process(snapshot.ambience_process)
	chapter.game.cinematic_active=snapshot.cinematic
	player.set_physics_process(snapshot.physics);player.set_process_unhandled_input(snapshot.input)
	player.model.speed=0
	player.set_control(snapshot.control);Input.mouse_mode=snapshot.mouse

func cancel() -> void:
	if running:finish()

func _exit_tree() -> void:
	cancel()
