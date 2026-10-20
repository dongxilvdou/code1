extends "res://day2/puzzle_ui.gd"
## Puzzle state lives in the quest manager; closing a panel never discards it.
const WateringPreview = preload("res://act2/watering_preview.gd")
var watering: SubViewportContainer
var chapter
var board: Control
var tiles: Array = []
var rotations: Array = []
var arrows: Array = []
var selected: Array = []
var sequence: Array = []
var voice_tween: Tween
const PIPE_BASE := [[3,1],[3,1],[3,2],[1,2],[3,1],[0,3],[0,1],[3,1],[3,1]]
const DIRECTIONS := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const MED_COUNTS := [8,2,7,1,9,3,8]
const SLIDE_GOAL := [1,2,3,8,0,4,7,6,5]

func open(kind: String, text := "") -> void:
	if is_instance_valid(watering):watering.set_flow(false)
	watering = null
	super.open("story",text)
	mode = kind
	for n in detail.get_children():
		detail.remove_child(n)
		n.queue_free()
	match kind:
		"pipes":
			title.text = "水槽之下 / 接回水路"
			description.text = "点击管道旋转，让水从左上方入口流到右下方出口。\n亮蓝色表示已经接通的管段。柜门内的红点仍在闪烁。"
			rotations.clear()
			for i in range(9):rotations.append(chapter.val("pipe_%d"%i,(i+1)%4))
			make_board(Vector2(420,300))
			button("检查水路",detail,check_pipes)
		"slide":
			title.text = "猫用冰箱 / 八数码锁"
			description.text = "点击空格相邻的数字块移动。目标按顺时针排列，空格在中央：\n1  2  3    /    8  □  4    /    7  6  5"
			tiles.clear()
			for i in range(9):tiles.append(chapter.val("tile_%d"%i,-1))
			if not slide_reachable(tiles):
				var migrated := not tiles.has(-1)
				shuffle_tiles()
				if migrated:feedback.text = "目标排列已更新，旧机关已重新排列，其他任务进度保留。"
			make_board(Vector2(330,300))
			button("重新打乱（始终可解）",detail,shuffle_tiles)
		"yarn":
			title.text = "毛线里的秘密 / 顺着线头"
			description.text = "点击线头，让它沿箭头方向抽出。前方有其他线头就会卡住。\n全部解开，才能看见藏在里面的东西。"
			arrows.clear()
			for i in range(16):arrows.append(chapter.val("yarn_%d"%i,1 if i%3==0 else 0))
			make_board(Vector2(400,300))
		"medicine":
			title.text = "七只密封药瓶 / 听声音"
			description.text = "瓶盖无法打开，也看不见里面。点击瓶子摇晃，比较声音的响度和音色。\n药片越多，碰撞声越响、越密。反复试听，选出药片最少的三瓶。"
			selected.clear()
			for i in range(7):
				if chapter.val("med_selection_mask") & (1<<i):selected.append(i)
			make_board(Vector2(588,180))
			var choose_row := HBoxContainer.new()
			detail.add_child(choose_row)
			for i in range(7):
				var choose := button("选 / 取消 %d"%(i+1),choose_row,toggle_medicine.bind(i))
				choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				choose.add_theme_font_size_override("font_size",14)
			button("从选中的三瓶取药",detail,check_medicine)
		"voice":
			title.text = "再叫一次我的名字"
			description.text = "大狗嚼：我觉得你很熟悉……可我连自己的名字也忘记了。\n先试试四种猫语声调，正确时它会摇尾巴。"
			selected.clear()
			sequence.clear()
			var row := HBoxContainer.new()
			detail.add_child(row)
			for i in range(4):button(["一声 喵→","二声 喵↗","三声 喵∨","四声 喵↘"][i],row,try_tone.bind(i))
		"aim":
			title.text = "浇水 / 把水送进花盆"
			description.text = "移动鼠标瞄准花盆开口，按住左键浇水。\n离开开口时不会累计进度；松开可重新瞄准。"
			make_board(Vector2(580,300))
			watering = WateringPreview.new()
			board.add_child(watering)
			watering.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			watering.use_plant(chapter.world.items.plant.get_meta("bound_furniture"))
		"photo":
			title.text = "书页里掉落的合照"
			description.text = "白大褂、实验室，还有蹲在主人身旁的我。\n右下角：观察对象 C-031 · 照护训练 · 阶段 II。"
			var picture := TextureRect.new()
			picture.texture = load("res://act2/memory_photo.svg")
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.custom_minimum_size = Vector2(540,270)
			detail.add_child(picture)
			var serial := label("C-031 / PHASE II",14,picture)
			serial.add_theme_color_override("font_color",Color("334f4e"))
			serial.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			serial.position = Vector2(310,238)
			serial.size = Vector2(205,25)
			serial.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			button("收好照片",detail,close)
		_:
			title.text = "第二幕 / "+["","","","被观察的日常","只剩一条鱼","记得你的名字"][clampi(chapter.today(),3,5)]
			button("继续 · E / 空格",detail,close).grab_focus()

func make_board(dimensions: Vector2) -> void:
	var center := CenterContainer.new()
	detail.add_child(center)
	board = Control.new()
	board.custom_minimum_size = dimensions
	center.add_child(board)
	board.draw.connect(draw_board)
	board.gui_input.connect(board_input)

func cell_rect(i: int, columns: int, rows: int) -> Rect2:
	var s := board.size/Vector2(columns,rows)
	return Rect2(Vector2(i%columns,i/columns)*s+Vector2(5,5),s-Vector2(10,10))

func draw_board() -> void:
	var gold := Color("e1bd80")
	var sage := Color("8bbdb0")
	if mode=="pipes":
		var wet := connected_pipes()
		for i in range(9):
			var r := cell_rect(i,3,3)
			board.draw_style_box(QuestTheme.panel(8),r)
			for d in pipe_ends(i):board.draw_line(r.get_center(),r.get_center()+Vector2(DIRECTIONS[d])*Vector2(board.size.x/6,board.size.y/6),Color("7dcddc") if wet.has(i) else gold,13,true)
			board.draw_circle(r.get_center(),9,sage if wet.has(i) else gold)
		board.draw_string(font,Vector2(0,18),"入",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
		board.draw_string(font,board.size-Vector2(20,8),"出",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
	elif mode=="slide":
		for i in range(9):
			var r := cell_rect(i,3,3)
			if tiles[i]==0:continue
			board.draw_style_box(QuestTheme.panel(10),r)
			board.draw_string(font,r.get_center()+Vector2(-9,10),str(tiles[i]),HORIZONTAL_ALIGNMENT_LEFT,-1,30,gold)
	elif mode=="yarn":
		for i in range(16):
			if arrows[i]<0:continue
			var r := cell_rect(i,4,4)
			var direction := Vector2(DIRECTIONS[arrows[i]])
			var end := r.get_center()+direction*24
			board.draw_line(r.get_center()-direction*24,end,gold,5,true)
			board.draw_line(end,end-direction.rotated(.65)*13,sage,4,true)
			board.draw_line(end,end-direction.rotated(-.65)*13,sage,4,true)
	elif mode=="medicine":
		for i in range(7):
			var r := cell_rect(i,7,1)
			var body := QuestTheme.panel(13)
			body.bg_color = Color("73553d")
			body.border_color = sage if selected.has(i) else Color("a18a65")
			body.set_border_width_all(3 if selected.has(i) else 1)
			board.draw_style_box(body,Rect2(r.position+Vector2(9,32),r.size-Vector2(18,62)))
			var cap := QuestTheme.panel(5)
			cap.bg_color = Color("ded8bf")
			board.draw_style_box(cap,Rect2(r.position+Vector2(15,18),Vector2(r.size.x-30,22)))
			for x in range(5):board.draw_line(r.position+Vector2(20+x*7,21),r.position+Vector2(20+x*7,36),Color("a9a38d"),1)
			board.draw_rect(Rect2(r.position+Vector2(15,66),Vector2(r.size.x-30,45)),Color("e2dcc5"))
			board.draw_string(font,r.position+Vector2(24,96),"%02d"%(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("455950"))
			board.draw_string(font,r.position+Vector2(10,165),"已听" if chapter.val("med_heard_mask") & (1<<i) else "摇一摇",HORIZONTAL_ALIGNMENT_LEFT,-1,14,sage if selected.has(i) else gold)
	elif mode=="aim":pass # The live viewport renders the actual models and water volume.

func pipe_ends(i: int) -> Array:
	return [(PIPE_BASE[i][0]+rotations[i])%4,(PIPE_BASE[i][1]+rotations[i])%4]

func connected_pipes() -> Array:
	var wet: Array = []
	if not pipe_ends(0).has(3):return wet
	var pending: Array = [0]
	while not pending.is_empty():
		var i: int = pending.pop_front()
		if wet.has(i):continue
		wet.append(i)
		for d in pipe_ends(i):
			var p: Vector2i = Vector2i(i%3,i/3)+DIRECTIONS[d]
			if p.x<0 or p.x>2 or p.y<0 or p.y>2:continue
			var j: int = p.y*3+p.x
			if pipe_ends(j).has((d+2)%4) and not wet.has(j):pending.append(j)
	return wet

func check_pipes() -> void:
	if connected_pipes().has(8) and pipe_ends(8).has(1):solved.emit("pipes")
	else:feedback.text = "水还没到出口。看看蓝色水路在哪里断开了。"

func shuffle_tiles() -> void:
	tiles = SLIDE_GOAL.duplicate()
	var previous := -1
	for turn in range(60):
		var empty := tiles.find(0)
		var options: Array = []
		for i in range(9):
			if abs(i%3-empty%3)+abs(i/3-empty/3)==1 and i!=previous:options.append(i)
		var target: int = options.pick_random()
		tiles[empty] = tiles[target]
		tiles[target] = 0
		previous = empty
	if tiles==SLIDE_GOAL:tiles = [1,2,3,8,6,4,7,0,5]
	save_array("tile",tiles)
	if is_instance_valid(board):board.queue_redraw()

func move_tile(i: int) -> void:
	var empty := tiles.find(0)
	if abs(i%3-empty%3)+abs(i/3-empty/3)!=1:return
	tiles[empty] = tiles[i]
	tiles[i] = 0
	save_array("tile",tiles)
	if tiles==SLIDE_GOAL:solved.emit("slide")

func slide_reachable(values: Array) -> bool:
	if values.size()!=9:return false
	var sorted := values.duplicate()
	sorted.sort()
	if sorted!=[0,1,2,3,4,5,6,7,8]:return false
	# An odd-width board preserves inversion parity under every legal move.
	var inversions := 0
	for i in range(9):
		for j in range(i+1,9):
			if values[i]!=0 and values[j]!=0 and values[i]>values[j]:inversions += 1
	return inversions%2==1

func pull_thread(i: int) -> void:
	if arrows[i]<0:return
	var p: Vector2i = Vector2i(i%4,i/4)+DIRECTIONS[arrows[i]]
	while p.x>=0 and p.x<4 and p.y>=0 and p.y<4:
		if arrows[p.y*4+p.x]>=0:
			feedback.text = "线头卡住了，先抽掉箭头前面的线。"
			return
		p += DIRECTIONS[arrows[i]]
	arrows[i] = -1
	save_array("yarn",arrows)
	feedback.text = "解开了 %d / 16 个线头" % arrows.count(-1)
	if arrows.count(-1)==16:solved.emit("yarn")

func check_medicine() -> void:
	selected.sort()
	for i in selected:
		if not chapter.val("med_heard_mask") & (1<<i):
			feedback.text = "先摇晃选中的药瓶，听一听里面的声音。"
			return
	if selected==[1,3,5]:
		chapter.set_value("med_selection_mask",0)
		solved.emit("medicine")
	else:feedback.text = "还不对。再摇一摇，比较响度和音色，只选最少的三瓶。"

func shake_medicine(i: int) -> void:
	chapter.set_value("med_heard_mask",chapter.val("med_heard_mask") | (1<<i))
	audio.stream = load("res://act3/audio/bottle_%d.wav"%i)
	audio.volume_db = 0
	audio.pitch_scale = 1.0
	audio.play()
	feedback.text = "正在摇晃 %d 号药瓶。听完后，可以再次点击比较。"%(i+1)
	board.queue_redraw()

func toggle_medicine(i: int) -> void:
	if selected.has(i):selected.erase(i)
	elif selected.size()<3:selected.append(i)
	else:
		feedback.text = "最多选择三瓶，先取消一瓶再重新选择。"
		return
	var mask := 0
	for entry in selected:mask |= 1<<entry
	chapter.set_value("med_selection_mask",mask)
	feedback.text = "已选择 %d / 3 瓶。"%selected.size()
	board.queue_redraw()

func try_tone(i: int) -> void:
	play_voice(i,false)
	if i in [0,3]:
		chapter.dog_react()
		if not selected.has(i):selected.append(i)
		feedback.text = "它摇了摇尾巴，似乎认出了这个声调。"
	else:feedback.text = "它抬起头，但没有认出这个声音。"
	if selected.size()==2 and detail.get_child_count()==1:
		description.text = "找到了两种声调。把它们分别配上长音或短音，按顺序叫两声。\n骨头刻字：阿嚼 · → 短，↘ 长。选错可以重新叫。"
		var row := HBoxContainer.new()
		detail.add_child(row)
		for tone in [0,3]:
			for long_note in [false,true]:button(("一声" if tone==0 else "四声")+(" · 长" if long_note else " · 短"),row,add_voice.bind(tone,long_note))

func add_voice(tone: int, long_note: bool) -> void:
	play_voice(tone,long_note)
	sequence.append(tone*2+int(long_note))
	feedback.text = "已经叫了 %d / 2 声"%sequence.size()
	if sequence.size()==2:
		if sequence==[0,7]:solved.emit("voice")
		else:
			sequence.clear()
			feedback.text = "它歪了歪头。再想想两声的顺序与长短。"

func play_voice(tone: int, long_note: bool) -> void:
	if voice_tween and voice_tween.is_valid():voice_tween.kill()
	var duration := .85 if long_note else .38
	audio.stream = load("res://assets/meow.wav")
	audio.pitch_scale = [.95,.75,1.05,1.35][tone]
	audio.play()
	voice_tween = create_tween()
	if tone==2:
		voice_tween.tween_property(audio,"pitch_scale",.65,duration*.5)
		voice_tween.tween_property(audio,"pitch_scale",1.05,duration*.5)
	else:voice_tween.tween_property(audio,"pitch_scale",[.95,1.3,1.05,.70][tone],duration)
	voice_tween.tween_callback(audio.stop)

func save_array(prefix: String, values: Array) -> void:
	for i in range(values.size()):chapter.set_value("%s_%d"%[prefix,i],values[i])

func board_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
	var columns := 7 if mode=="medicine" else 4 if mode=="yarn" else 3
	var rows := 1 if mode=="medicine" else 4 if mode=="yarn" else 3
	var p: Vector2 = event.position/board.size*Vector2(columns,rows)
	var i := int(p.y)*columns+int(p.x)
	match mode:
		"pipes":
			rotations[i] = (rotations[i]+1)%4
			save_array("pipe",rotations)
		"slide":move_tile(i)
		"yarn":pull_thread(i)
		"medicine":
			if i in range(7):shake_medicine(i)
	board.queue_redraw()

func close() -> void:
	if is_instance_valid(watering):watering.set_flow(false)
	super.close()

func pour_at(mouse: Vector2, pressed: bool, delta: float) -> void:
	if mode!="aim" or not shell.visible or not is_instance_valid(watering):return
	var hit: bool = watering.aim_at(mouse)
	watering.set_flow(pressed and Rect2(Vector2.ZERO,watering.size).has_point(mouse))
	if pressed and hit:chapter.aim_progress += delta
	watering.progress = clampf(chapter.aim_progress/2.5,0,1)
	feedback.text = "清水正在浇进花盆  %d%%"%int(watering.progress*100) if pressed and hit else "把光圈移到盆口，按住左键浇水 · %d%%"%int(watering.progress*100)
	if chapter.aim_progress>=2.5:solved.emit("aim")

func _process(delta: float) -> void:
	if mode!="aim" or not shell.visible or not is_instance_valid(watering):return
	pour_at(watering.get_local_mouse_position(),Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),delta)
