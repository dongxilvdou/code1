extends Node3D
## Colored motion comic. Owns input/UI temporarily; never moves the real actor.
signal started
signal finished(skipped: bool)
signal shot_changed(index: int)
const PanelArt = preload("res://scripts/cinematics/comic_panel.gd")
const BOOK_PATH := "res://assets/cinematics/comic/opening_book.json"
const PAGE_SIZE := Vector2(1920,1080)
@export_enum("无存档时播放", "每次从菜单开始播放", "关闭") var playback_policy := 0
@export var allow_skip := true
@export var allow_advance := true
@export var autoplay := true
@export var skip_action: StringName = &""
# Kept for the host's existing scene references. Comic never changes lighting.
@export var environment_source: WorldEnvironment
@export var sun_source: DirectionalLight3D
@export var film_time := 0.0
var active := false
var finishing := false
var finish_count := 0
var last_shot := -1
var meow_played := false
var meow_count := 0
var skip_elapsed := 0.0
var host: Node
var player: CharacterBody3D
var interface: CanvasLayer
var snapshot := {}
var book := {}
var pages: Array = []
var cues: Array = []
var panel_nodes: Array = []
var current_page := -1
var captions: Array = []
var caption_labels: Array = []
var valid_book := false
var error_message := ""
var transition: Tween
var finishing_skipped := false
@onready var timeline: AnimationPlayer = $AnimationPlayer
@onready var overlay: Control = $ComicUI/Overlay
@onready var board: Control = $ComicUI/Overlay/Board
@onready var fade: ColorRect = $ComicUI/Overlay/Fade
@onready var skip_hint: Button = $ComicUI/Overlay/Skip
@onready var next_hint: Button = $ComicUI/Overlay/Next
@onready var page_hint: Label = $ComicUI/Overlay/PageNumber
@onready var title: Label = $ComicUI/Overlay/Board/Title
@onready var score: AudioStreamPlayer = $Score
@onready var meow: AudioStreamPlayer = $Meow

func _ready() -> void:
	overlay.hide()
	set_process(false)
	set_process_input(false)
	timeline.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	timeline.animation_finished.connect(_on_animation_finished)
	skip_hint.pressed.connect(request_skip)
	next_hint.pressed.connect(advance_panel)
	get_viewport().size_changed.connect(_layout)
	_load_book()
	_layout()
	if score.stream is AudioStreamWAV:
		var loop: AudioStreamWAV = score.stream.duplicate()
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = loop.data.size()/(2 if loop.format==AudioStreamWAV.FORMAT_16_BITS else 1)/(2 if loop.stereo else 1)
		score.stream = loop

func _load_book() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOOK_PATH))
	if not parsed is Dictionary:
		error_message = "漫画分镜配置无法读取";return
	book = parsed
	pages = book.get("pages",[])
	cues = book.get("cues",[])
	if pages.is_empty() or cues.is_empty():
		error_message = "漫画分镜为空";return
	var previous := -1.0
	for cue in cues:
		if float(cue.get("time",-1))<=previous or int(cue.get("page",-1)) not in range(pages.size()):
			error_message = "漫画时间顺序或页码无效";return
		previous = float(cue.time)
	for page in pages:
		var texture := load(str(page.get("image",""))) as Texture2D
		if texture == null:
			error_message = "漫画图片缺失："+str(page.get("image",""));return
		var container := Control.new()
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(container)
		board.move_child(container,0)
		var nodes: Array = []
		for shape in page.get("panels",[]):
			var art := PanelArt.new()
			art.artwork = texture
			for point in shape:art.polygon.append(Vector2(float(point[0]),float(point[1])))
			if art.polygon.size()<3:
				error_message = "漫画面板边界无效";return
			art.focus = Vector2.ZERO
			for point in art.polygon:art.focus += point
			art.focus /= art.polygon.size()
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(art)
			nodes.append(art)
		container.hide()
		panel_nodes.append(nodes)
		var cap := PanelContainer.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ink := StyleBoxFlat.new()
		ink.bg_color = Color(.012,.014,.014,.96)
		ink.set_corner_radius_all(5)
		ink.content_margin_left = 23;ink.content_margin_right = 23
		ink.content_margin_top = 16;ink.content_margin_bottom = 18
		cap.add_theme_stylebox_override("panel",ink)
		var label := Label.new()
		label.theme = overlay.theme
		label.add_theme_font_size_override("font_size",43)
		label.add_theme_color_override("font_color",Color(.98,.975,.95))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.add_child(label)
		board.add_child(cap)
		cap.hide()
		captions.append(cap);caption_labels.append(label)
	for cue in cues:
		if int(cue.get("panel",-1)) not in range(panel_nodes[int(cue.page)].size()):
			error_message = "漫画面板索引无效";return
	board.move_child(title,board.get_child_count()-1)
	valid_book = true

func bind_game(game: Node, actor: CharacterBody3D, ui: CanvasLayer) -> void:
	host = game;player = actor;interface = ui

func should_play(has_save: bool, force := false) -> bool:
	return not active and (force or (playback_policy!=2 and (playback_policy==1 or not has_save)))

func play() -> bool:
	if active or finishing or not is_instance_valid(player) or not valid_book:
		if not valid_book:push_error(error_message)
		return false
	snapshot = {"active":player.active,"physics":player.is_physics_processing(),
		"input":player.is_processing_unhandled_input(),"mouse":Input.mouse_mode,
		"hud":interface.hud.visible,"welcome":interface.welcome.visible,
		"velocity":player.velocity,"camera":get_viewport().get_camera_3d()}
	if is_instance_valid(host.rain_audio):snapshot.rain_db = host.rain_audio.volume_db
	active = true;finishing = false;finish_count = 0;last_shot = -1
	meow_played = false;meow_count = 0;film_time = 0;current_page = -1
	player.set_control(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	interface.welcome.hide();interface.hud.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for cap in captions:cap.hide()
	for group in panel_nodes:group[0].get_parent().hide()
	overlay.modulate.a = 1
	overlay.show()
	skip_hint.visible = allow_skip
	next_hint.visible = allow_advance
	page_hint.show();board.show()
	title.modulate.a = 0
	fade.color.a = 1
	score.volume_db = -70
	score.play()
	timeline.play("opening")
	timeline.advance(0)
	_update_comic()
	set_process(true);set_process_input(true)
	started.emit()
	return true

func _process(delta: float) -> void:
	if not active:return
	if finishing:
		skip_elapsed += delta
		fade.color.a = smoothstep(0,.25,skip_elapsed)
		score.volume_db = lerpf(-21,-70,clampf(skip_elapsed/.25,0,1))
		if skip_elapsed>=.25:_finish(finishing_skipped)
		return
	if not timeline.is_playing():
		_begin_finish(true);return
	if autoplay:timeline.advance(delta)
	if active and not finishing:_update_comic()

func _update_comic() -> void:
	var index := 0
	for i in range(cues.size()):
		if film_time+.0001>=float(cues[i].time):index = i
	var cue: Dictionary = cues[index]
	var page := int(cue.page)
	if current_page!=page:
		if current_page>=0:panel_nodes[current_page][0].get_parent().hide()
		current_page = page
		panel_nodes[page][0].get_parent().show()
	if index!=last_shot:
		last_shot = index
		shot_changed.emit(index)
		if cue.get("meow",false) and not meow_played:
			meow_played = true;meow_count += 1
			meow.play()
	var local := maxf(0,film_time-float(cue.time))
	for j in range(panel_nodes[page].size()):
		var first_time := 999.0
		for beat in cues:
			if int(beat.page)==page and int(beat.panel)==j:first_time = minf(first_time,float(beat.time))
		var art: Control = panel_nodes[page][j]
		var reveal := smoothstep(first_time,first_time+.65,film_time)
		var brightness := 1.0 if j==int(cue.panel) else .66
		art.modulate = Color(brightness,brightness,brightness,reveal)
		art.progress = clampf((film_time-first_time)/9,0,1)
		art.queue_redraw()
	for p in range(captions.size()):captions[p].visible = p==page
	var cap: PanelContainer = captions[page]
	var label: Label = caption_labels[page]
	label.text = str(cue.text)
	label.custom_minimum_size.x = float(cue.width)*PAGE_SIZE.x-46
	cap.position = Vector2(float(cue.position[0]),float(cue.position[1]))*PAGE_SIZE
	cap.size = Vector2(float(cue.width)*PAGE_SIZE.x,0)
	cap.reset_size()
	var next_time := float(cues[index+1].time) if index+1<cues.size() else 55.0
	cap.modulate.a = smoothstep(.12,.65,local)*(1-smoothstep(next_time-.22,next_time,film_time))
	var page_start := float(pages[page].start)
	var page_end := float(pages[page].end)
	board.modulate.a = smoothstep(page_start,page_start+.45,film_time)*(1-smoothstep(page_end-.30,page_end,film_time))
	fade.color.a = maxf(1-smoothstep(.4,2.5,film_time),smoothstep(54.3,55,film_time))
	title.modulate.a = smoothstep(51.3,52.5,film_time)
	score.volume_db = linear_to_db(maxf(.0001,.12*smoothstep(0,4,film_time)*(1-smoothstep(51,55,film_time))))
	if snapshot.has("rain_db"):host.rain_audio.volume_db = -36
	page_hint.text = "%02d / %02d"%[page+1,pages.size()]

func _layout() -> void:
	if not is_instance_valid(board):return
	var area := get_viewport().get_visible_rect().size
	var factor := minf(area.x/PAGE_SIZE.x,area.y/PAGE_SIZE.y)
	board.scale = Vector2.ONE*factor
	board.position = (area-PAGE_SIZE*factor)*.5
	board.size = PAGE_SIZE

func advance_panel() -> void:
	if not active or finishing or not allow_advance:return
	for cue in cues:
		if float(cue.time)>film_time+.2:
			timeline.seek(float(cue.time)+.001,true)
			_update_comic()
			return
	_begin_finish(false)

func _input(event: InputEvent) -> void:
	if not active:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE or (skip_action!=&"" and InputMap.has_action(skip_action) and event.is_action_pressed(skip_action)):
			request_skip()
		elif event.keycode in [KEY_SPACE,KEY_ENTER,KEY_E]:advance_panel()
	if event is InputEventMouseButton:
		# GUI buttons need BOTH press and release; swallowing release cancels clicks.
		if skip_hint.visible and skip_hint.get_global_rect().has_point(event.position):return
		if next_hint.visible and next_hint.get_global_rect().has_point(event.position):return
		if event.pressed and event.button_index==MOUSE_BUTTON_LEFT:advance_panel()
	if event is InputEventKey or event is InputEventMouseMotion or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func request_skip() -> void:
	if active and not finishing and allow_skip:_begin_finish(true)

func _on_animation_finished(animation: StringName) -> void:
	if animation==&"opening" and active and not finishing:_begin_finish(false)

func _begin_finish(skipped: bool) -> void:
	if not active or finishing:return
	finishing = true;finishing_skipped = skipped;skip_elapsed = 0
	timeline.stop(true)
	meow.stop()

func _restore() -> void:
	if snapshot.is_empty():return
	if is_instance_valid(player):
		player.velocity = snapshot.velocity
		player.set_physics_process(snapshot.physics)
		player.set_process_unhandled_input(snapshot.input)
		player.set_control(snapshot.active)
		if is_instance_valid(snapshot.camera):snapshot.camera.make_current()
	if is_instance_valid(interface):
		interface.hud.visible = snapshot.hud
		interface.welcome.visible = snapshot.welcome
	if is_instance_valid(host) and snapshot.has("rain_db"):host.rain_audio.volume_db = snapshot.rain_db
	Input.mouse_mode = snapshot.mouse

func _finish(skipped: bool) -> void:
	if not active:return
	active = false;finish_count += 1
	timeline.stop(true);score.stop();meow.stop()
	fade.color.a = 1
	board.hide();skip_hint.hide();next_hint.hide();page_hint.hide()
	_restore()
	set_process(false);set_process_input(false)
	finished.emit(skipped)
	_release_overlay()

func _release_overlay() -> void:
	# DayOne restores its true spawn under black before exposing the 3D room.
	await get_tree().physics_frame
	await get_tree().physics_frame
	transition = create_tween()
	transition.tween_property(fade,"color:a",0.0,.35)
	await transition.finished
	overlay.hide();board.show();page_hint.show()
	finishing = false

func _exit_tree() -> void:
	if active:
		active = false
		_restore()
