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
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(13,14),Vector2(39,14),Vector2(35,46),Vector2(17,46)]),Color("a9c4c6"))
		for x in [21,26,31]:draw_line(Vector2(x,20),Vector2(x,39),Color("547b88"),2,true)
		draw_line(Vector2(11,12),Vector2(41,12),ink,4,true)
		draw_arc(Vector2(26,9),6,PI,TAU,16,ink,2,true)
