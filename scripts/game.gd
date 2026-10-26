extends Node3D
## Shared controls, sound and cat inspection for the current villa.
var player: CharacterBody3D
var ui: CanvasLayer
var cat_camera: Camera3D
var photo := false
var started := false
var room_name := ""
var rooms := {}
# Retain this handle for existing cutscene fades; its source is now summer ambience.
var rain_audio: AudioStreamPlayer
var meow_audio: AudioStreamPlayer
var paw_audio: AudioStreamPlayer
var reaction_time := 0.0
var cinematic_active := false
var comic_intro_completed := false
const DEMO_CONTEXT := "calico_demo_session"
var demo_mode := false
var _demo_reloading := false
var opening: Node3D
@export var opening_preview_on_ready := false

func _ready() -> void:
	demo_mode=bool(get_tree().root.get_meta(DEMO_CONTEXT,{}).get("active",false))
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
	ui.demo_toggled.connect(set_demo_mode)
	ui.demo_day_requested.connect(enter_demo_day)
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
	if get_tree().root.has_meta(DEMO_CONTEXT):
		_demo_reloading=true
		call_deferred("_restore_demo_context")
		return
	if opening_preview_on_ready or "--intro-preview" in OS.get_cmdline_user_args():
		call_deferred("request_start_game",true)
	if "--autoplay" in OS.get_cmdline_user_args(): start_game()
	if "--verify" in OS.get_cmdline_user_args(): call_deferred("verify_game")

func setup_audio() -> void:
	var ambience = load("res://scripts/environment_ambience.gd").new()
	ambience.configure(player,self,get_node_or_null("Apartment"))
	rain_audio = ambience
	add_child(ambience)
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
	if demo_mode:
		ui.update_save_menu(false,false,"演示模式 · 可在设置中选择天数")
		ui.save_button.disabled=true
		ui.save_feedback.text="演示进度不保存，不会覆盖正常存档。"
		return
	var info: Dictionary = quest.inspect_save()
	var summary := "暂无存档 · 选择新游戏开始"
	if info.exists:summary = "存档：第 %d 天" % info.day if info.valid else "存档无法读取 · 可选择新游戏重新开始"
	ui.update_save_menu(info.exists,info.valid,summary)
	ui.save_button.disabled = not quest.save_enabled

func request_new_game() -> void:
	if _demo_reloading:return
	if demo_mode:
		enter_demo_day(1)
		return
	if cinematic_active or started:return
	var quest := get_node_or_null("QuestSystem")
	if quest != null and not quest.prepare_session(true):
		ui.save_summary.text = quest.menu_error
		return
	request_start_game(true)

func request_continue_game() -> void:
	if demo_mode or _demo_reloading:return
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
	if demo_mode or _demo_reloading:return
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
	comic_intro_completed = true
	cinematic_active = false
	start_game()

func set_demo_mode(enabled: bool) -> void:
	if _demo_reloading:return
	var quest:=get_node("QuestSystem")
	if not quest.initialized:
		ui.set_demo_state(demo_mode)
		return
	if enabled==demo_mode:return
	if enabled:
		var doors: Dictionary={}
		for door in get_tree().get_nodes_in_group("villa_doors")+get_tree().get_nodes_in_group("laboratory_lock_doors"):
			doors[str(get_path_to(door))]=door.is_open
		var context: Dictionary={"active":true,"launch_day":0,"normal_started":started,"normal_save":quest.manager.make_save_data() if started else {},"normal_save_enabled":quest.save_enabled,"normal_autosave":quest.manager.autosave,"normal_save_file":quest.save_file,"normal_position":player.global_position,"normal_spawn":player.spawn,"normal_yaw":player.yaw,"normal_pitch":player.pitch,"normal_photo":photo,"normal_doors":doors,"volume":ui.volume_value}
		get_tree().root.set_meta(DEMO_CONTEXT,context)
		demo_mode=true
		quest.save_enabled=false;quest.manager.autosave=false
		ui.set_demo_state(true,int(quest.manager.values.get("current_day",1)))
		refresh_save_menu()
	else:
		var context: Dictionary=get_tree().root.get_meta(DEMO_CONTEXT,{})
		context["active"]=false;context["volume"]=ui.volume_value
		get_tree().root.set_meta(DEMO_CONTEXT,context)
		_reload_demo_scene()

func enter_demo_day(number: int) -> void:
	if _demo_reloading or not demo_mode or number<1 or number>11:return
	var context: Dictionary=get_tree().root.get_meta(DEMO_CONTEXT,{})
	context["launch_day"]=number;context["volume"]=ui.volume_value
	get_tree().root.set_meta(DEMO_CONTEXT,context)
	_reload_demo_scene()

func _reload_demo_scene() -> void:
	_demo_reloading=true
	ui.demo_jump_button.disabled=true
	get_tree().call_deferred("reload_current_scene")

func _restore_demo_context() -> void:
	var quest:=get_node("QuestSystem")
	while not quest.initialized:await get_tree().process_frame
	var context: Dictionary=get_tree().root.get_meta(DEMO_CONTEXT,{})
	quest.manager.autosave=false
	ui.volume_slider.value=float(context.get("volume",.65))
	if context.get("active",false):
		demo_mode=true;quest.save_enabled=false
		var number:int=clampi(int(context.get("launch_day",1)),1,11)
		_seed_demo_day(number)
		ui.set_demo_state(true,number)
		context["launch_day"]=0
		get_tree().root.set_meta(DEMO_CONTEXT,context)
	else:
		demo_mode=false
		quest.save_enabled=bool(context.get("normal_save_enabled",true))
		if context.get("normal_started",false):
			if not quest.manager.restore_save_data(context.normal_save):
				ui.toast("进度恢复失败，原存档已保留。",5)
				_demo_reloading=false
				return
			var day:=get_node("DayOne")
			day.manager=quest.manager;day.initialized=true
			quest.session_started=true;quest.session_prepared=true
			comic_intro_completed=true;start_game()
			player.set_control(false);ui.hud.hide()
			_restore_story_world()
			for i in range(2):await get_tree().physics_frame
			player.global_position=context.normal_position;player.spawn=context.normal_spawn
			player.yaw=context.normal_yaw;player.rotation.y=player.yaw
			player.pitch=context.normal_pitch;player.head.rotation.x=player.pitch
			player.velocity=Vector3.ZERO;day.previous_position=player.global_position
			photo=context.normal_photo
			if photo:cat_camera.make_current()
			for path in context.normal_doors:
				var door:=get_node_or_null(NodePath(path))
				if door and not door.locked:door.set_open(context.normal_doors[path],true)
			ui.pause_panel.show()
		quest.manager.autosave=bool(context.get("normal_autosave",false))
		get_tree().root.remove_meta(DEMO_CONTEXT)
		ui.set_demo_state(false)
		ui.open_settings()
	_demo_reloading=false
	refresh_save_menu()

func _restore_story_world() -> void:
	var day:=get_node("DayOne")
	day.restore_world()
	var number:int=day.value("current_day",1)
	if number in [3,4,5]:get_node("ActTwo").restore()
	elif number in [6,7]:get_node("ActThree").restore()
	elif number>=8:get_node("ActFour").restore()
	get_node("ActTwo").update_clues_visibility()

func _seed_demo_day(number: int) -> void:
	var quest:=get_node("QuestSystem")
	var day:=get_node("DayOne")
	var manager: CalicoQuestManager=quest.manager
	manager.start_new_game()
	var data:=manager.make_save_data()
	data.values={"current_day":number,"cat_hunger":65,"dog_hunger":45,"act2_schedule_version":3,"dish_flow_version":2}
	data.flags={"intro_seen":true}
	var milestones: Dictionary={1:["walk","run","open_living","stool","table","cup_moved","note_read","light_off","papers_done","d2_unlocked","d2_cat_fed","d2_dog_fed","day_complete"],2:["d2_started","d2_note","d2_washed","ruler_found","yarn_freed","yarn_home","d2_dishes_done","d2_complete"],3:["a3_books","a3_photo","a3_pipes","a3_water","a3_feed","photo_dropped","book0","book1","book2"],4:["a4_fridge","a4_cook","a4_share","a4_toy","yarn_solved"],5:["a5_letter","a5_bell","a5_medicine","a5_name"],6:["a6_feed","a6_permission","a6_snacks"],7:["a7_power","a7_computer_power","a7_login","a7_complete"],8:["a8_food","a8_wash","a8_clock","a8_complete","a8_clue_hour","a8_clue_minute","a8_clue_second"],9:["a9_plants","a9_mole","a9_jigsaw","a9_complete"],10:["a10_catch","a10_eat","a10_note","a10_complete"]}
	for completed_day in range(1,number):
		for key in milestones[completed_day]:data.flags[key]=true
		data.flags["daily_note_ack_%d"%completed_day]=true
		data.flags[day.Notes.FLAGS[completed_day]]=true
	if number>2:
		for id in get_node("DayTwo").CLOTHES:data.flags["d2_"+id]=true
		data.values["dish_stage"]=9
	if number>4:data.values["cook_state"]=3
	if number>6:data.values["snack_mask"]=255
	if number>8:
		data.values.merge({"clock_h":3,"clock_m":42,"clock_s":0,"valve_setting":52,"pressure_setting":50})
	if number>9:
		for i in range(3):data.values["pot%d"%i]=i
		for i in range(9):data.values["piece%d"%i]=i
		data.values["mole_catches"]=2
	if number>10:data.values["mouse_stage"]=6
	var early_days: Dictionary={"day1_arrival":1,"day1_lights":1,"day1_papers":1,"day2_feed":1,"day2_note":2,"day2_laundry":2,"day1_yarn":2,"day2_dishes":2}
	for id in manager.definitions:
		var definition: CalicoQuest=manager.definitions[id]
		var quest_day:int=early_days.get(str(id),99)
		for condition in definition.extra_conditions:
			if condition.key==&"current_day":quest_day=condition.required_value
		if quest_day>=number:continue
		var progress: Dictionary={}
		for objective in definition.objectives:progress[str(objective.id)]=objective.target_count
		data.quests[str(id)]={"status":CalicoQuestManager.State.COMPLETED,"progress":progress}
	if not manager.restore_save_data(data):return
	quest.session_started=true;quest.session_prepared=true
	day.manager=manager;day.initialized=true
	day.reconcile_progress()
	comic_intro_completed=true;cinematic_active=false
	start_game()
	if number==1:day.restore_world();day.reset_spawn()
	elif number==2:get_node("DayTwo").begin_day()
	elif number<=5:get_node("ActTwo").begin_day(number)
	elif number<=7:get_node("ActThree").begin_day(number)
	else:get_node("ActFour").begin_day(number)
	get_node("ActTwo").update_clues_visibility()
	quest._messages.clear()

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

