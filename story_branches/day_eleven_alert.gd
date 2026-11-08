extends Node
var chapter: Node
var activated := false
var viewport: SubViewport
var alarm: AudioStreamPlayer
var intro: Node
var focused := true
var fade_clock := 0.0

func setup(owner_: Node) -> void:
	chapter=owner_
	alarm=AudioStreamPlayer.new();alarm.stream=preload("res://assets/audio/day11_alarm.wav");alarm.volume_db=-18;alarm.bus="Master";add_child(alarm)
	var stream=alarm.stream.duplicate()
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=stream.data.size()/2;alarm.stream=stream

func _process(delta: float) -> void:
	if not is_instance_valid(chapter) or not chapter.ensure_bound():return
	var quests=chapter.game.get_node("QuestSystem")
	var eligible: bool=quests.session_started and chapter.game.started and chapter.day.initialized and chapter.value("current_day")==11 and chapter.flag("br_route_locked") and not chapter.flag("br_legacy_flow")
	if not eligible:
		if activated:reset()
		return
	if not activated:activate()
	var paused: bool=not focused or chapter.game.ui.pause_panel.visible or (is_instance_valid(intro) and intro.paused) or (is_instance_valid(chapter.film) and chapter.film.paused)
	alarm.stream_paused=paused
	if chapter.flag("a11_enter"):
		if not paused:fade_clock=minf(1,fade_clock+delta)
		alarm.volume_db=lerpf(-18,-70,fade_clock)
		if fade_clock>=1:alarm.stop()
	elif not paused and not alarm.playing and chapter.value("br_phase")==0:alarm.play()
	if not is_instance_valid(intro) and chapter.value("br_day11_intro_state")<2:
		if chapter.flag("a11_enter") or chapter.value("br_day11_intro_state")==1:
			chapter.state.patch({"br_day11_alert_received":true},{"br_day11_intro_state":2})
		elif chapter.day.active_play() and chapter.state.patch({}, {"br_day11_intro_state":1}):
			intro=preload("res://story_branches/day_eleven_intro.gd").new();intro.chapter=chapter;add_child(intro);chapter.state.busy=true;intro.play()

func activate() -> void:
	activated=true;fade_clock=0
	viewport=SubViewport.new();viewport.size=Vector2i(960,540);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
	var background:=ColorRect.new();background.color=Color("180d10");background.size=Vector2(960,540);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(background)
	var label:=Label.new();label.text="实验出错\n请前往地下室修复实验";label.theme=preload("res://quest_system/quest_theme.gd").resource();label.add_theme_font_size_override("font_size",56);label.add_theme_color_override("font_color",Color("ffcfac"));label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.size=Vector2(960,540);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(label)
	chapter.game.get_node("HouseMemes").set_story_tv_override(true,viewport.get_texture())
	if not chapter.flag("a11_enter"):alarm.play()

func reset() -> void:
	if is_instance_valid(intro):intro.cancel();intro.queue_free();intro=null;chapter.state.busy=false
	if is_instance_valid(alarm):alarm.stop();alarm.stream_paused=false;alarm.volume_db=-18
	var television=chapter.game.get_node_or_null("HouseMemes")
	if is_instance_valid(television):television.set_story_tv_override(false,null)
	if is_instance_valid(viewport):viewport.queue_free();viewport=null
	activated=false;fade_clock=0

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:focused=false
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:focused=true
