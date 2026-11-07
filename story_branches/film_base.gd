extends Node
## One cinematic owns cameras/input/audio, including every exit and retry path.
var chapter: Node
var running := false
var paused := false
var waiting := false
var clock := 0.0
var snapshot := {}
var canvases: Array=[]
var stages: Array[Node]=[]
var ui: CanvasLayer
var screen: Control
var caption: Label
var fade: ColorRect
var choices: PanelContainer
var choice_content: VBoxContainer
var pause_card: PanelContainer
var camera: Camera3D
var owned_camera := false
var sounds: Array[AudioStreamPlayer]=[]
var finished := false
var choice_align_right := false

func play() -> void:
	build_ui()
	var game=chapter.game;var player=game.player
	snapshot={"control":player.active,"physics":player.is_physics_processing(),"input":player.is_processing_unhandled_input(),"mouse":Input.mouse_mode,"cinematic":game.cinematic_active,"position":player.global_transform,"yaw":player.yaw,"pitch":player.pitch,"camera":get_viewport().get_camera_3d(),"camera_transform":player.camera.transform,"fov":player.camera.fov,"paws":[]}
	for paw in player.paws:snapshot.paws.append([paw,paw.transform,paw.visible])
	for canvas in game.find_children("*","CanvasLayer",true,false):
		if canvas!=ui:canvases.append([canvas,canvas.visible]);canvas.hide()
	var ambience=game.rain_audio
	snapshot.ambience=[ambience.volume_db,ambience.stream_paused,ambience.is_processing()];snapshot.ambience_children=[]
	for child in ambience.get_children():
		if child is AudioStreamPlayer:snapshot.ambience_children.append([child,child.stream_paused,child.volume_db])
	ambience.set_process(false);ambience.volume_db-=9
	for entry in snapshot.ambience_children:entry[0].volume_db-=9
	game.cinematic_active=true;player.set_control(false);player.velocity=Vector3.ZERO;player.set_physics_process(false);player.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	sounds.append(chapter.feedback.player)
	running=true;finished=false;clock=0;paused=false;waiting=false
	_begin()

func build_ui() -> void:
	ui=CanvasLayer.new();ui.layer=90;add_child(ui)
	screen=Control.new();screen.theme=preload("res://quest_system/quest_theme.gd").resource();screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);screen.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(screen)
	fade=ColorRect.new();fade.color=Color(0,0,0,0);fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);screen.add_child(fade)
	caption=Label.new();caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.add_theme_font_size_override("font_size",25);caption.add_theme_color_override("font_color",Color("f0eadb"));caption.add_theme_color_override("font_outline_color",Color.BLACK);caption.add_theme_constant_override("outline_size",5)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_left=80;caption.offset_right=-80;caption.offset_top=-150;caption.offset_bottom=-35;screen.add_child(caption)
	var hint:=Label.new();hint.text="Esc 暂停 · 空格 跳过演出";hint.position=Vector2(26,22);hint.add_theme_font_size_override("font_size",16);hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;screen.add_child(hint)
	choices=PanelContainer.new();choices.add_theme_stylebox_override("panel",preload("res://quest_system/quest_theme.gd").panel(24));screen.add_child(choices)
	choice_content=VBoxContainer.new();choice_content.add_theme_constant_override("separation",12);choices.add_child(choice_content);choices.hide()
	pause_card=PanelContainer.new();pause_card.add_theme_stylebox_override("panel",preload("res://quest_system/quest_theme.gd").panel(24));screen.add_child(pause_card)
	var col:=VBoxContainer.new();pause_card.add_child(col)
	for entry in [["继续演出",resume],["跳过演出",skip],["返回主菜单",chapter.return_menu]]:add_button(col,entry[0],entry[1])
	pause_card.hide()

func add_button(parent: Node, text_: String, callback: Callable) -> Button:
	var button:=Button.new();button.text=text_;button.custom_minimum_size.y=40;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.pressed.connect(callback);parent.add_child(button);return button

func ask(text_: String, options: Array) -> void:
	waiting=true
	for node in choice_content.get_children():choice_content.remove_child(node);node.queue_free()
	var label:=Label.new();label.text=text_;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",20);label.custom_minimum_size.x=550;choice_content.add_child(label)
	for entry in options:add_button(choice_content,entry[0],entry[1])
	choices.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if choice_content.get_child_count()>1:choice_content.get_child(1).grab_focus()

func clear_choice() -> void:waiting=false;choices.hide()

func new_camera() -> Camera3D:
	camera=Camera3D.new();camera.near=.012;camera.far=60;add_child(camera);owned_camera=true;camera.make_current();return camera

func aim(marker: Node3D, mask_: int, environment: Environment=null) -> void:
	if camera==null:new_camera()
	camera.global_transform=marker.global_transform;camera.cull_mask=mask_;camera.fov=marker.get_meta("fov",55.0);camera.environment=environment;camera.make_current()

func stage(id: String, position_: Vector3) -> Node3D:
	var node: Node3D=load("res://story_branches/scenes/"+id+".tscn").instantiate();chapter.game.add_child(node);node.position=position_;stages.append(node);return node

func audio(path_: String, db := -12.0) -> AudioStreamPlayer:
	var player:=AudioStreamPlayer.new();player.stream=load(path_);player.volume_db=db;add_child(player);sounds.append(player);return player

func _process(delta: float) -> void:
	if not running:return
	var viewport:=get_viewport().get_visible_rect().size
	var width:=minf(520,viewport.x*.40) if choice_align_right else minf(650,viewport.x-80)
	if choice_content.get_child_count()>0:choice_content.get_child(0).custom_minimum_size.x=width-48
	choices.custom_minimum_size.x=width;choices.size=Vector2(width,0)
	choices.position=Vector2(viewport.x-width-24,viewport.y-choices.size.y-100) if choice_align_right else (viewport-choices.size)*.5
	pause_card.size=Vector2(minf(380,viewport.x-80),0);pause_card.position=(viewport-pause_card.size)*.5
	if paused or waiting:return
	clock+=delta
	_tick(delta)

func _begin() -> void:pass
func _tick(_delta: float) -> void:pass
func skip() -> void:pass

func toggle_pause() -> void:
	if not running:return
	paused=not paused;pause_card.visible=paused
	choices.visible=waiting and not paused
	if paused:pause_card.get_child(0).get_child(0).grab_focus()
	for sound in sounds:sound.stream_paused=paused
	chapter.game.rain_audio.stream_paused=paused or snapshot.ambience[1]
	for entry in snapshot.ambience_children:
		if is_instance_valid(entry[0]):entry[0].stream_paused=paused or entry[1]
	for node in stages:
		if not is_instance_valid(node):continue
		node.process_mode=Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
		var tween=node.get("motion") if node.has_method("play_action") else null
		if tween and tween.is_valid():
			if paused:tween.pause()
			else:tween.play()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func resume() -> void:
	if paused:toggle_pause()

func _input(event: InputEvent) -> void:
	if not running:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:toggle_pause();get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_SPACE,KEY_ENTER] and not waiting and not paused:skip();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_E and waiting:
			var focus:=get_viewport().gui_get_focus_owner()
			if focus is Button:focus.pressed.emit()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and running and not paused:toggle_pause()

func release() -> void:
	if not running:return
	running=false
	for sound in sounds:sound.stop()
	var player=chapter.game.player
	player.global_transform=snapshot.position;player.yaw=snapshot.yaw;player.pitch=snapshot.pitch;player.rotation.y=player.yaw;player.head.rotation.x=player.pitch;player.camera.transform=snapshot.camera_transform;player.camera.fov=snapshot.fov;player.velocity=Vector3.ZERO
	if is_instance_valid(snapshot.camera):snapshot.camera.make_current()
	for entry in snapshot.paws:
		if is_instance_valid(entry[0]):entry[0].transform=entry[1];entry[0].visible=entry[2]
	for entry in canvases:
		if is_instance_valid(entry[0]):entry[0].visible=entry[1]
	chapter.game.cinematic_active=snapshot.cinematic
	player.set_physics_process(snapshot.physics);player.set_process_unhandled_input(snapshot.input);player.set_control(snapshot.control);Input.mouse_mode=snapshot.mouse
	var ambience=chapter.game.rain_audio
	ambience.volume_db=snapshot.ambience[0];ambience.stream_paused=snapshot.ambience[1];ambience.set_process(snapshot.ambience[2])
	for entry in snapshot.ambience_children:
		if is_instance_valid(entry[0]):entry[0].stream_paused=entry[1];entry[0].volume_db=entry[2]
	for node in stages:
		if is_instance_valid(node):node.queue_free()
	stages.clear()
	if is_instance_valid(ui):ui.hide()

func finish_ending() -> void:
	if finished:return
	resume()
	if not chapter.ending_finished():ask("保存失败，原进度已保留。\n"+chapter.state.last_error,[["重试保存并确认",finish_ending]]);return
	finished=true;release();chapter.show_final();queue_free()

func cancel() -> void:release()
func _exit_tree() -> void:
	# Scene changes call cancel()/release() while peers are alive. Application
	# shutdown destroys the whole game tree and must not restore dying siblings.
	running=false
