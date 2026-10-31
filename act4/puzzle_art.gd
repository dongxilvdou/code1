extends Control
var chapter
var kind := "clock"
var elapsed := 0.0
var running := false
var routes: Array = []
var coils: Array = []
var result := {}
var level := 0
var dragging := false
var last_angle := 0.0
const Circuit = preload("res://act4/circuit.gd")
func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
func _gui_input(event: InputEvent) -> void:
	if kind!="valve":return
	var center := Vector2(size.x*.5,size.y*.5)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		dragging = event.pressed and event.position.distance_to(center)<110
		last_angle = (event.position-center).angle()
		if dragging:grab_focus();accept_event()
	elif event is InputEventMouseMotion and dragging:
		var angle: float = (event.position-center).angle()
		var change := rad_to_deg(angle_difference(last_angle,angle))/2.8
		chapter.panel.adjust_valve(roundi(change))
		if absf(change)>=.5:last_angle=angle
		accept_event()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT,KEY_RIGHT]:
		chapter.panel.adjust_valve(-2 if event.keycode==KEY_LEFT else 2)
		accept_event()
func _process(delta: float) -> void:
	if running:
		elapsed += delta/.55
		if elapsed>=result.get("finish",0)+.7:
			running = false
			chapter.panel.finish_circuit(result)
	queue_redraw()
func _draw() -> void:
	if kind=="clock":draw_clock()
	elif kind=="valve":draw_valve()
	elif kind=="circuit":draw_circuit()
func draw_clock() -> void:
	var c := size*.5
	var r := minf(size.x,size.y)*.46
	draw_circle(c,r,Color("b7a477"))
	draw_circle(c,r-7,Color("e8e1cb"))
	for i in range(60):
		var v := Vector2(sin(i*TAU/60),-cos(i*TAU/60))
		draw_line(c+v*(r-14),c+v*(r-(26 if i%5==0 else 18)),Color("48544b"),3 if i%5==0 else 1,true)
	var values := [chapter.val("clock_h",8)*30.0+chapter.val("clock_m",11)*.5,chapter.val("clock_m",11)*6.0,chapter.val("clock_s",25)*6.0]
	for i in range(3):
		var a: float = deg_to_rad(values[i])
		draw_line(c,c+Vector2(sin(a),-cos(a))*r*[.49,.72,.83][i],[Color("394c4d"),Color("394c4d"),Color("a75e42")][i],5-i*2,true)
	draw_circle(c,6,Color("a88852"))
func draw_valve() -> void:
	var c := size*.5
	var r := 85.0
	draw_circle(c,r+23,Color("47534e"))
	draw_circle(c,r+19,Color("9ca396"))
	for i in range(29):
		var a := deg_to_rad(-140+i*10)
		var v := Vector2(sin(a),-cos(a))
		draw_line(c+v*(r+4),c+v*(r+15),Color("5b6256"),2,true)
	# Opaque mineral deposits cover the numeric temperature scale, not the pointer.
	for span in [Vector2(-145,-24),Vector2(40,145)]:
		var patch := PackedVector2Array()
		for j in range(25):
			var a := deg_to_rad(lerpf(span.x,span.y,j/24.0))
			patch.append(c+Vector2(sin(a),-cos(a))*(r+22+sin(j*2.3)*2))
		for j in range(24,-1,-1):
			var a := deg_to_rad(lerpf(span.x,span.y,j/24.0))
			patch.append(c+Vector2(sin(a),-cos(a))*(r+2+sin(j*1.8)*3))
		draw_colored_polygon(patch,Color("c9bea2"))
		for j in range(40):
			var a := deg_to_rad(lerpf(span.x,span.y,fposmod(j*.618,1)))
			draw_circle(c+Vector2(sin(a),-cos(a))*(r+5+fposmod(j*3.17,16)),.6+fposmod(j*.7,1.2),Color("e0d6bb"))
	draw_arc(c,r+4,deg_to_rad(-104),deg_to_rad(-56),32,Color(.92,.86,.67,.65),5,true)
	for i in range(12):draw_circle(c,r-i*.7,Color("a7afa6").lerp(Color("d0d3c7"),i/16.0))
	var a := deg_to_rad(lerpf(-140,140,chapter.valve_setting()/100.0))
	var v := Vector2(sin(a),-cos(a))
	draw_line(c+v*35,c+v*(r-12),Color("38564f"),7,true)
	draw_circle(c,14,Color("7a877c"))
	draw_line(c-Vector2(6,0),c+Vector2(6,0),Color("d2d3c3"),2,true)
	draw_circle(c+Vector2(-127,66),8,Color("74a6ba"))
	draw_circle(c+Vector2(127,66),8,Color("b8765e"))
	var flow_center:=Vector2(62,c.y)
	draw_circle(flow_center,29,Color("6a7771"))
	draw_circle(flow_center,24,Color("bac2b5"))
	var flow_angle:=deg_to_rad(lerpf(-120,120,chapter.pressure_setting()/100.0))
	draw_line(flow_center,flow_center+Vector2(sin(flow_angle),-cos(flow_angle))*20,Color("365c64"),4,true)
	draw_string(get_theme_default_font(),flow_center+Vector2(-16,47),"出水",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("344b48"))
func circuit_point(p: Vector2) -> Vector2:return Vector2(24+p.x*56,44+p.y*40)

func draw_circuit() -> void:
	draw_style_box(chapter.panel.QuestTheme.panel(8),Rect2(Vector2.ZERO,size))
	var font: Font=chapter.panel.font
	var ink: Color=chapter.panel.QuestTheme.TEXT
	var has_run:=not result.is_empty()
	draw_string(font,Vector2(14,19),"起点 0拍  ·  每枚线圈停1拍  ·  当前 %.1f拍"%elapsed,HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
	if level==1:
		var entry:=circuit_point(Vector2(6,1.5))
		var exit:=circuit_point(Vector2(8,1.5))
		draw_rect(Rect2(entry-Vector2(10,17),Vector2(exit.x-entry.x+20,34)),Color("d9c39c"))
		draw_line(entry,exit,Color("8e7553"),13,true)
		draw_string(font,entry+Vector2(-18,-27),"窄桥：4拍红 / 7拍蓝",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
		draw_string(font,entry+Vector2(-5,40),"过桥2拍 + 散热1拍",HORIZONTAL_ALIGNMENT_LEFT,-1,11,ink)
	for lane in range(Circuit.count_(level)):
		var path:=Circuit.path(level,lane,routes[lane])
		var wire:=PackedVector2Array()
		for p in path:wire.append(circuit_point(p))
		draw_polyline(wire,Color("8c9689"),8,true)
		draw_polyline(wire,Circuit.COLORS[lane].darkened(.32),3,true)
		for p in wire:
			draw_circle(p,3,Color("f5efdf"));draw_arc(p,3,0,TAU,12,Color("746b54"),1,true)
		var coil_point: Vector2=wire[Circuit.speed_(level,lane,0)]+Vector2(0,14)
		for j in range(Circuit.coil_limit(level)):
			var center:=coil_point+Vector2((j-(Circuit.coil_limit(level)-1)*.5)*16,0)
			draw_arc(center,7,-PI/2,PI*1.5,20,Color("bcb4a1"),1,true)
			if j<coils[lane]:draw_arc(center,7,-PI/2,PI*1.5,20,Color("8d622d"),3,true)
		var junction: Vector2=wire[2]
		draw_colored_polygon(PackedVector2Array([junction+Vector2(-5,-7),junction+Vector2(7,0),junction+Vector2(-5,7)]),Color("876f42"))
		if level==2 and lane==1:
			for j in range(3):draw_line(wire[2]+Vector2(j*5,-12),wire[2]+Vector2(j*5+5,-3),Color("85553e"),2,true)
			draw_string(font,wire[2]+Vector2(-12,-19),"2 → 4",HORIZONTAL_ALIGNMENT_LEFT,-1,11,ink)
		var end: Vector2=wire[-1]+Vector2(25,0)
		var blocked: bool=level==1 and has_run and result.blocked_lanes[lane]
		var lit: bool=has_run and elapsed>=result.times[lane] and not blocked
		draw_circle(end,11,Circuit.COLORS[lane].darkened(.1) if lit else Color("ccc6b6"))
		draw_arc(end,14,0,TAU,24,Color("78654a"),2,true)
		if level==2:draw_string(font,end+Vector2(-15,-21),"%d拍"%Circuit.CLOCK_WINDOWS[lane],HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
		if level==1:
			var gate:=wire[Circuit.approach_length(lane,routes[lane])]
			draw_line(gate+Vector2(-5,-12),gate+Vector2(-5,12),Color("85553e") if blocked else Color("9b8a66"),3,true)
		if has_run:
			var distance_:=Circuit.distance_at(level,lane,routes[lane],coils[lane],elapsed)
			if blocked:distance_=minf(distance_,Circuit.approach_length(lane,routes[lane]))
			var d:=minf(distance_,wire.size()-1.001)
			var pos: Vector2=wire[int(d)].lerp(wire[mini(int(d)+1,wire.size()-1)],fposmod(d,1))
			draw_circle(pos,12,Color(Circuit.COLORS[lane],.25))
			draw_circle(pos,6,Circuit.COLORS[lane].darkened(.18))
			draw_circle(pos-Vector2(2,2),2,Color.WHITE)
