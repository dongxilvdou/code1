extends Node3D
## Shared controls, sound and cat inspection for the current villa.
var player: CharacterBody3D
var ui: CanvasLayer
var cat_camera: Camera3D
var photo := false
var started := false
var room_name := ""
var rooms := {}
var rain_audio: AudioStreamPlayer
var meow_audio: AudioStreamPlayer
var paw_audio: AudioStreamPlayer
var reaction_time := 0.0
var cinematic_active := false
var opening: Node3D
@export var opening_preview_on_ready := false

func _ready() -> void:
	player = $Miso
	ui = CanvasLayer.new()
	ui.name = "Interface"
	ui.set_script(load("res://scripts/interface.gd"))
	add_child(ui)
	ui.started.connect(request_new_game)
	ui.continued.connect(request_continue_game)
	ui.save_requested.connect(save_current_game)
	ui.resumed.connect(resume_game)
	ui.reset_requested.connect(func(): player.reset_position())
	ui.volume_changed.connect(set_volume)
	player.meowed.connect(meow)
	player.stepped.connect(footstep)
	player.interacted.connect(interact)
	player.pause_requested.connect(toggle_pause)
	player.photo_requested.connect(toggle_photo)
	setup_audio()
	cat_camera = Camera3D.new()
	cat_camera.name = "CatInspectionCamera"
	cat_camera.near = .04
	cat_camera.fov = 61
	cat_camera.cull_mask = 1|2|4|16
	add_child(cat_camera)
	opening = get_node_or_null("OpeningCutscene")
	if opening:
		opening.bind_game(self,player,ui)
		opening.finished.connect(_on_opening_finished)
	if opening_preview_on_ready or "--intro-preview" in OS.get_cmdline_user_args():
		call_deferred("request_start_game",true)
	if "--autoplay" in OS.get_cmdline_user_args(): start_game()
	if "--verify" in OS.get_cmdline_user_args(): call_deferred("verify_game")

func setup_audio() -> void:
	rain_audio = sound("rain",-13)
	var rain: AudioStreamWAV = rain_audio.stream.duplicate()
	rain.loop_mode = AudioStreamWAV.LOOP_FORWARD
	rain.loop_end = rain.data.size()/2
	rain_audio.stream = rain
	rain_audio.play()
	meow_audio = sound("meow",-6)
	paw_audio = sound("paw",-7)
	set_volume(.65)

func sound(key: String, volume: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/"+key+".wav")
	p.volume_db = volume
	add_child(p)
	return p

func set_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.001,value)))

func start_game() -> void:
	if cinematic_active:return
	started = true
	player.set_control(true)
	player.camera.make_current()
	ui.welcome.hide()
	ui.hud.show()

func refresh_save_menu() -> void:
	var quest := get_node_or_null("QuestSystem")
	if quest == null:
		ui.update_save_menu(false,false,"当前场景不支持存档")
		ui.save_button.disabled = true
		return
	if not quest.initialized:return
	var info: Dictionary = quest.inspect_save()
	var summary := "暂无存档 · 选择新游戏开始"
	if info.exists:summary = "存档：第 %d 天" % info.day if info.valid else "存档无法读取 · 可选择新游戏重新开始"
	ui.update_save_menu(info.exists,info.valid,summary)
	ui.save_button.disabled = not quest.save_enabled

func request_new_game() -> void:
	if cinematic_active or started:return
	var quest := get_node_or_null("QuestSystem")
	if quest != null and not quest.prepare_session(true):
		ui.save_summary.text = quest.menu_error
		return
	request_start_game(true)

func request_continue_game() -> void:
	if cinematic_active or started:return
	var quest := get_node_or_null("QuestSystem")
	if quest == null:return
	if not quest.prepare_session(false):
		refresh_save_menu()
		ui.save_summary.text = quest.menu_error
		return
	# Continue resumes saved progress directly, without replaying the opening.
	start_game()

func save_current_game() -> void:
	if not started or cinematic_active or not ui.pause_panel.visible:return
	var quest := get_node_or_null("QuestSystem")
	if quest == null:return
	if quest.save_current_progress():
		ui.save_feedback.text = "已保存 · 第 %d 天 · %s" % [int(quest.manager.values.get("current_day",1)),Time.get_time_string_from_system()]
	else:ui.save_feedback.text = "保存失败："+quest.menu_error

func request_start_game(force_intro: bool = false) -> void:
	if cinematic_active or started:return
	var quest := get_node_or_null("QuestSystem")
	var has_save: bool = quest!=null and quest.save_enabled and FileAccess.file_exists(quest.save_file)
	var no_intro := "--skip-intro" in OS.get_cmdline_user_args()
	if opening and not no_intro and opening.should_play(has_save,force_intro):
		cinematic_active = true
		if opening.play():return
		cinematic_active = false
	start_game()

func _on_opening_finished(_skipped: bool) -> void:
	cinematic_active = false
	start_game()

func update_room() -> void:
	pass

func update_target() -> void:
	pass

func interact() -> void:
	pass

func verify_game() -> void:
	get_tree().quit()

func resume_game() -> void:
	player.set_control(true)
	ui.hud.show()

func toggle_pause() -> void:
	if cinematic_active or not started or ui.settings_panel.visible:return
	if ui.pause_panel.visible:
		ui.pause_panel.hide()
		resume_game()
	else:
		player.set_control(false)
		ui.hud.hide()
		ui.pause_panel.show()

func toggle_photo() -> void:
	if cinematic_active:return
	photo = not photo
	if photo:
		cat_camera.make_current()
		ui.toast("查看米酥  ·  再按 V 回到猫的眼睛",3)
	else:player.camera.make_current()

func _process(delta: float) -> void:
	if not is_instance_valid(player.camera):return
	if photo:
		var target := player.global_position+Vector3(0,.25,0)
		var offset: Vector3 = player.transform.basis*Vector3(.90,1.05,1.4)
		var ray := PhysicsRayQueryParameters3D.create(target,target+offset,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		cat_camera.global_position = (hit.position+(target-hit.position).normalized()*.12) if not hit.is_empty() else target+offset
		cat_camera.look_at(target)
	if not started:return
	update_room()
	update_target()
	reaction_time -= delta
	if reaction_time>0:
		player.camera.rotation.z = sin(reaction_time*22)*.022

func meow() -> void:
	player.model.meow()
	meow_audio.pitch_scale = randf_range(.95,1.08)
	meow_audio.play()
	ui.toast("喵。",1.4)
	reaction_time = .28

func footstep() -> void:
	paw_audio.pitch_scale = randf_range(.83,1.20)
	paw_audio.play()

func stop_audio() -> void:
	for sound_player in [rain_audio,meow_audio,paw_audio]:
		if is_instance_valid(sound_player):sound_player.stop()

func _exit_tree() -> void:
	stop_audio()

