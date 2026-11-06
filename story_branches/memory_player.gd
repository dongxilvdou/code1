extends Node
## Brief care memory only. Leaves real cages, player transforms and saves intact.
signal finished
var game: Node
var stage: Node3D
var old_camera: Camera3D
var old_active := false
var old_cinematic := false
var clock := 0.0
var running := false
var paused := false
var ui: CanvasLayer
var pause_panel: PanelContainer

func play(owner_: Node) -> void:
	if running:return
	game=owner_;old_camera=get_viewport().get_camera_3d();old_active=game.player.active;old_cinematic=game.cinematic_active
	stage=preload("res://story_branches/scenes/memory_vignette.tscn").instantiate();game.add_child(stage);stage.position=Vector3(64,-35,0)
	var camera: Camera3D=stage.get_node("StageCamera");camera.global_transform=stage.get_node("CarePOV").global_transform;camera.fov=55;camera.make_current()
	game.cinematic_active=true;game.player.set_control(false);game.player.velocity=Vector3.ZERO
	stage.play_action(&"care");clock=0;running=true
	ui=CanvasLayer.new();ui.layer=80;add_child(ui)
	var caption:=Label.new();caption.text="米酥怕冷。把毯子留给它。\n空格跳过 · Esc 暂停回忆";caption.add_theme_font_override("font",preload("res://quest_system/quest_theme.gd").font());caption.add_theme_font_size_override("font_size",24);caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_top=-100;caption.offset_bottom=-30;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(caption)
	pause_panel=PanelContainer.new();pause_panel.theme=preload("res://quest_system/quest_theme.gd").resource();pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);pause_panel.offset_left=-170;pause_panel.offset_right=170;pause_panel.offset_top=-80;pause_panel.offset_bottom=80;ui.add_child(pause_panel)
	var col:=VBoxContainer.new();pause_panel.add_child(col)
	var title:=Label.new();title.text="回忆已暂停";col.add_child(title)
	for entry in [["继续回忆",resume],["退出回忆",finish]]:
		var b:=Button.new();b.text=entry[0];b.pressed.connect(entry[1]);col.add_child(b)
	pause_panel.hide()

func _process(delta: float) -> void:
	if not running or paused:return
	clock+=delta
	if clock>=1.9:finish()

func resume() -> void:
	paused=false;pause_panel.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if stage.motion and stage.motion.is_valid():stage.motion.play()

func finish() -> void:
	if not running:return
	running=false
	if is_instance_valid(old_camera):old_camera.make_current()
	if is_instance_valid(stage):stage.queue_free()
	if is_instance_valid(ui):ui.queue_free()
	game.cinematic_active=old_cinematic;game.player.set_control(old_active)
	finished.emit();queue_free()

func _input(event: InputEvent) -> void:
	if not running:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if paused:resume()
			else:
				paused=true;pause_panel.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
				if stage.motion and stage.motion.is_valid():stage.motion.pause()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_SPACE,KEY_ENTER]:finish();get_viewport().set_input_as_handled()
