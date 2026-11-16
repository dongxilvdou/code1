extends Control
var kind := 0
func _draw() -> void:
	var ink := Color("e3e9e3")
	var blue := Color("79afbd")
	if kind==0:
		var bezel := StyleBoxFlat.new()
		bezel.bg_color = Color("c7d3d1")
		bezel.set_corner_radius_all(4)
		draw_style_box(bezel,Rect2(4,4,44,32))
		draw_rect(Rect2(8,8,36,24),Color("385e72"))
		draw_line(Vector2(26,36),Vector2(26,43),ink,4,true)
		draw_line(Vector2(17,44),Vector2(35,44),ink,3,true)
	elif kind==1:
		var sheet := StyleBoxFlat.new()
		sheet.bg_color = ink
		sheet.set_corner_radius_all(3)
		draw_style_box(sheet,Rect2(11,3,30,43))
		for y in [16,23,30,37]:draw_line(Vector2(16,y),Vector2(35,y),blue,2,true)
	elif kind==2:
		draw_rect(Rect2(4,7,44,35),ink)
		draw_rect(Rect2(8,11,36,27),Color("6998aa"))
		draw_circle(Vector2(34,18),4,Color("e7d69f"))
		draw_colored_polygon(PackedVector2Array([Vector2(8,38),Vector2(20,24),Vector2(30,34),Vector2(38,25),Vector2(44,38)]),Color("d8e5d6"))
	elif kind==3:
		draw_colored_polygon(PackedVector2Array([Vector2(12,13),Vector2(40,13),Vector2(36,47),Vector2(16,47)]),Color("d5eaf1"))
		draw_polyline(PackedVector2Array([Vector2(12,13),Vector2(16,47),Vector2(36,47),Vector2(40,13)]),Color("9bbdcc"),1.5,true)
		draw_line(Vector2(10,11),Vector2(42,11),Color("f2f9fc"),4,true)
		for angle in [0,TAU/3,TAU*2/3]:
			var point=Vector2(26,29)+Vector2(sin(angle),-cos(angle))*9
			var direction=Vector2(cos(angle),sin(angle))
			draw_line(point-direction*5,point+direction*5,Color("238bba"),3,true)
			draw_colored_polygon(PackedVector2Array([point+direction*7,point+direction*1+direction.orthogonal()*4,point+direction*1-direction.orthogonal()*4]),Color("238bba"))

	elif kind==4:
		draw_circle(Vector2(26,26),22,blue);draw_arc(Vector2(26,26),21,0,TAU,48,ink,2,true)
		draw_line(Vector2(5,26),Vector2(47,26),ink,2,true)
		for x in [-9,9]:draw_arc(Vector2(26+x,26),16,-PI/2,PI/2,24,ink,2,true)
	else:
		draw_circle(Vector2(22,22),18,Color("08b35b"));draw_circle(Vector2(33,32),16,Color("f0f6f2"))
		draw_colored_polygon(PackedVector2Array([Vector2(11,31),Vector2(10,42),Vector2(22,34)]),Color("08b35b"))
		draw_colored_polygon(PackedVector2Array([Vector2(35,42),Vector2(44,49),Vector2(42,36)]),Color("f0f6f2"))
		for x in [17,27]:draw_circle(Vector2(x,20),2,Color("eefff2"))
		for x in [28,37]:draw_circle(Vector2(x,31),2,Color("3f6e54"))
