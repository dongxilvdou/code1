extends Node2D

const FROST = preload("res://ui/paper/frosted_paper.gdshader")
const LINE := Color("cbb797")
const INK := Color("9b7653")
const FAINT := Color("deceb5")
var ornaments := false:
	set(value):
		ornaments=value
		queue_redraw()
var frost: ColorRect

func _ready() -> void:
	# Node2D ornaments do not participate in Container layout or intercept input.
	frost=ColorRect.new();frost.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frost.show_behind_parent=true
	var shader_material:=ShaderMaterial.new();shader_material.shader=FROST
	frost.material=shader_material;add_child(frost)
	get_parent().resized.connect(_resize)
	_resize()

func _resize() -> void:
	var extent: Vector2=get_parent().size
	frost.size=extent
	(frost.material as ShaderMaterial).set_shader_parameter("panel_size",extent)
	queue_redraw()

func _draw() -> void:
	if not ornaments:return
	var extent: Vector2=get_parent().size
	if extent.x<120 or extent.y<64:return
	var middle:=extent.x*.5
	for x in [9.0,extent.x-9.0]:draw_line(Vector2(x,31),Vector2(x,extent.y-31),FAINT,1,true)
	for y in [9.0,extent.y-9.0]:
		draw_line(Vector2(36,y),Vector2(middle-24,y),LINE,1,true)
		draw_line(Vector2(middle+24,y),Vector2(extent.x-36,y),LINE,1,true)
	for right in [false,true]:
		for bottom in [false,true]:
			_sprig(Vector2(extent.x if right else 0,extent.y if bottom else 0),Vector2(-1 if right else 1,-1 if bottom else 1))
	_cat(Vector2(middle,9))
	_paw(Vector2(middle-10,extent.y-10),-.25)
	_paw(Vector2(middle+10,extent.y-9),.23)

func _path(points: Array[Vector2], origin: Vector2, direction: Vector2, color: Color, width := 1.1) -> void:
	var stroke:=PackedVector2Array()
	for point in points:stroke.append(origin+point*direction)
	draw_polyline(stroke,color,width,true)

func _sprig(origin: Vector2, direction: Vector2) -> void:
	var turn:=direction*.75
	_path([Vector2(12,36),Vector2(14,27),Vector2(20,19),Vector2(30,13),Vector2(43,11)],origin,turn,INK)
	_leaf(Vector2(18,22),Vector2(15,12),2.5,origin,turn)
	_leaf(Vector2(25,16),Vector2(25,7),2.4,origin,turn)
	_leaf(Vector2(31,13),Vector2(38,6),2.4,origin,turn)
	_leaf(Vector2(36,12),Vector2(44,19),2.5,origin,turn)

func _leaf(start: Vector2, tip: Vector2, breadth: float, origin: Vector2, direction: Vector2) -> void:
	var normal: Vector2=(tip-start).orthogonal().normalized()
	var points: Array[Vector2]=[]
	for side in [1.0,-1.0]:
		for i in range(9):
			var t:=float(i)/8 if side>0 else 1-float(i)/8
			points.append(start.lerp(tip,t)+normal*sin(t*PI)*breadth*side)
	_path(points,origin,direction,INK,1)

func _cat(origin: Vector2) -> void:
	var small:=Vector2.ONE*.72
	_path([Vector2(-14,7),Vector2(-14,-7),Vector2(-6,-2),Vector2(6,-2),Vector2(14,-7),Vector2(14,7),Vector2(10,11),Vector2(-10,11),Vector2(-14,7)],origin,small,INK)
	for side in [-1,1]:
		draw_line(origin+Vector2(5*side,3)*small,origin+Vector2(8*side,3)*small,INK,1,true)
		draw_line(origin+Vector2(16*side,3)*small,origin+Vector2(21*side,1)*small,LINE,1,true)
	_path([Vector2(-2,6),Vector2(0,8),Vector2(2,6)],origin,small,INK,1)

func _paw(origin: Vector2, angle: float) -> void:
	draw_set_transform(origin,angle,Vector2.ONE*.72)
	var pad:=PackedVector2Array()
	for i in range(25):
		var t:=TAU*i/24.0
		pad.append(Vector2(cos(t)*4.2,sin(t)*3.1+2))
	draw_polyline(pad,INK,1,true)
	for toe in [Vector2(-5,-3),Vector2(-1.6,-5.3),Vector2(2.4,-5),Vector2(5.5,-2.5)]:draw_circle(toe,1.5,INK,false,1,true)
	draw_set_transform(Vector2.ZERO)
