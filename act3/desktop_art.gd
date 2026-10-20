extends Control
## A quiet landscape wallpaper; every shape scales with the actual viewport.
func _ready() -> void:resized.connect(queue_redraw)
func _draw() -> void:
	var sky := Color("253c57")
	for i in range(64):draw_rect(Rect2(0,size.y*i/64.0,size.x,size.y/64.0+1),sky.lerp(Color("769ea5"),i/64.0))
	draw_circle(size*Vector2(.76,.26),size.y*.10,Color("d9dfc8"))
	draw_colored_polygon(PackedVector2Array([size*Vector2(0,.78),size*Vector2(.23,.40),size*Vector2(.43,.72),size*Vector2(.65,.46),size*Vector2(1,.82),size,Vector2(0,size.y)]),Color("3c6572"))
	draw_colored_polygon(PackedVector2Array([size*Vector2(0,.88),size*Vector2(.25,.70),size*Vector2(.55,.86),size*Vector2(.85,.56),size*Vector2(1,.68),size,Vector2(0,size.y)]),Color("2b555f"))
	draw_colored_polygon(PackedVector2Array([size*Vector2(0,.93),size*Vector2(.38,.85),size*Vector2(.64,.94),size*Vector2(1,.81),size,Vector2(0,size.y)]),Color("1b3c46"))
