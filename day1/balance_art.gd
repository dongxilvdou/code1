extends Control
var model
func _draw() -> void:
 if model==null:return
 var r=Rect2(Vector2(5,8),Vector2(size.x-10,25))
 draw_style_box(preload("res://quest_system/quest_theme.gd").panel(5),r)
 var center=r.get_center().x
 draw_rect(Rect2(Vector2(center-model.safe_half*r.size.x*.5,8),Vector2(model.safe_half*r.size.x,25)),Color("a0bc91"))
 draw_line(Vector2(center,5),Vector2(center,36),Color("6d795d"),1)
 draw_circle(Vector2(center+model.position*r.size.x*.5,20.5),8,Color("b97d4d"))
 draw_rect(Rect2(Vector2(5,48),Vector2(size.x-10,7)),Color("b7b39f"))
 draw_rect(Rect2(Vector2(5,48),Vector2((size.x-10)*model.progress,7)),Color("7e9677"))
func _process(_delta: float) -> void:queue_redraw()
