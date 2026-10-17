extends "res://scripts/game.gd"
var zone_records: Array = []
var inspection_camera: Camera3D
var inspecting := false
var inspection_section := 3
var orbit_yaw := -.72
var orbit_pitch := .60
var orbit_distance := 23.0
var nearest_door: Node3D
var menu_camera: Camera3D

func _ready() -> void:
	zone_records = $Apartment.get_meta("room_zones",[])
	super._ready()
	inspection_camera = Camera3D.new()
	inspection_camera.name = "VillaOverviewCamera"
	inspection_camera.near = .08
	inspection_camera.far = 150
	inspection_camera.fov = 54
	inspection_camera.cull_mask = 1|2|4|16
	add_child(inspection_camera)
	update_overview_camera()
	menu_camera = Camera3D.new()
	menu_camera.name = "MenuCamera"
	menu_camera.fov = 62
	menu_camera.cull_mask = 1|2|4|16
	add_child(menu_camera)
	menu_camera.position = Vector3(-1.7,1.55,-1.6)
	menu_camera.look_at(Vector3(-4.0,.75,2.4))
	if not started and not cinematic_active:menu_camera.make_current()
	if "--overview" in OS.get_cmdline_user_args():
		start_game()
		toggle_overview()

func room_at(p: Vector3) -> String:
	var q := Vector2(p.x+6,p.z+6)
	if p.y<-.20:return "地下层 · 楼梯与平台"
	if q.x<0 or q.x>12 or q.y<0 or q.y>12:
		return "北侧花园" if q.y<0 else "入户庭院" if q.y>12 else "侧花园"
	if Rect2(9.2,3.6,2.8,3.9).has_point(q):return "楼梯"
	var floor_index := 1 if p.y>2.6 else 0
	var prefix := "二层 · " if floor_index==1 else "一层 · "
	for record in zone_records:
		if record.floor==floor_index and (record.bounds as Rect2).has_point(q):return prefix+record.name
	return prefix+"过厅"

func update_room() -> void:
	var current := room_at(player.global_position)
	if current!=room_name:
		room_name = current
		rooms[current] = true

func update_target() -> void:
	nearest_door = null
	ui.hint_label.text = ""
	if inspecting or not player.active or photo:return
	var distance := 1.40
	var eye: Vector3 = player.camera.global_position
	var forward: Vector3 = -player.camera.global_basis.z
	for door in get_tree().get_nodes_in_group("villa_doors"):
		var target: Vector3 = door.interaction_position()
		var delta := target-eye
		if delta.length()>distance or forward.dot(delta.normalized())<.20:continue
		var ray := PhysicsRayQueryParameters3D.create(eye,target,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider!=door.leaf:continue
		distance = delta.length()
		nearest_door = door
	if nearest_door:
		ui.hint_label.text = "[ E ]  "+("关闭" if nearest_door.is_open else "打开")+nearest_door.door_title
		if nearest_door.locked:ui.hint_label.text = "门暂时打不开 · 先完成客厅里的事情"
		if nearest_door.blocked:ui.hint_label.text = "让开一点，门会继续移动  ·  E 改变方向"
	var day := get_node_or_null("DayOne")
	if day and day.has_method("target_hint"):
		var hint: String = day.target_hint()
		if not hint.is_empty():ui.hint_label.text = hint

func interact() -> void:
	var day := get_node_or_null("DayOne")
	if day and day.has_method("try_interact") and day.try_interact():return
	update_target()
	if nearest_door:nearest_door.toggle()

func _unhandled_input(event: InputEvent) -> void:
	if cinematic_active or not started or ui.pause_panel.visible or ui.settings_panel.visible:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_B:toggle_overview()
		elif inspecting and event.keycode in [KEY_1,KEY_2,KEY_3]:set_section(event.keycode-KEY_0)
	if not inspecting:return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		orbit_yaw -= event.relative.x*.006
		orbit_pitch = clampf(orbit_pitch+event.relative.y*.004,.12,1.35)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:orbit_distance = maxf(10,orbit_distance-1.5)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:orbit_distance = minf(40,orbit_distance+1.5)

func toggle_overview() -> void:
	if cinematic_active:return
	inspecting = not inspecting
	if inspecting:
		photo = false
		player.set_control(false)
		inspection_camera.make_current()
		set_section(3)
	else:
		set_section(3)
		player.camera.make_current()
		room_name = ""
		ui.toast_time = 0
		player.set_control(true)

func set_section(value: int) -> void:
	inspection_section = value
	if $Apartment.has_node("Basement"):$Apartment/Basement.visible = value!=2
	$Apartment/GroundFloor.visible = value!=2
	$Apartment/UpperFloor.visible = value!=1
	$Apartment/Roof.visible = value==3
	update_overview_camera()

func update_overview_camera() -> void:
	if not is_instance_valid(inspection_camera):return
	var target := Vector3(0,2.4,-.2) if inspection_section==3 else Vector3(0,1.0 if inspection_section==1 else 3.2,0)
	var offset := Vector3(sin(orbit_yaw)*cos(orbit_pitch),sin(orbit_pitch),cos(orbit_yaw)*cos(orbit_pitch))*orbit_distance
	inspection_camera.global_position = target+offset
	inspection_camera.look_at(target)

func _process(delta: float) -> void:
	super._process(delta)
	if inspecting:
		update_overview_camera()
		ui.navigation_label.text = "1 / 2 / 3  楼层     拖动旋转 · 滚轮缩放     B  返回"
	elif photo:ui.navigation_label.text = "V  返回猫视角     Esc  暂停"
	else:ui.navigation_label.text = "M  地图     B  总览     Esc  暂停"

func toggle_pause() -> void:
	if inspecting:toggle_overview()
	super.toggle_pause()

func toggle_photo() -> void:
	if inspecting:return
	super.toggle_photo()

func verify_game() -> void:
	await get_tree().physics_frame
	print("VILLA_VERIFY ",JSON.stringify({"zones":zone_records.size(),"doors":get_tree().get_nodes_in_group("villa_doors").size(),"cat_scale":player.cat_scale,"eye_height_m":player.head.position.y,"mirror_removed":not $Apartment.has_node("StandingMirror"),"stairs":$Apartment/Staircase.get_child_count()}))
	get_tree().quit()
