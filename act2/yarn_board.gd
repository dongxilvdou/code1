extends Control
## Draw and hit-test the same polyline geometry, at any zoom level.
signal selected(id: int)
signal zoom_changed
const Rules=preload("res://act2/yarn_rules.gd")
const CELL=24.0
const INK=Color("27394d")
const HOVER=Color("287a83")
var rules=Rules.new()
var removed: Dictionary={}
var paths: Array[PackedVector2Array]=[]
var lengths: Array[float]=[]
var bounds: Array[Rect2]=[]
var zoom=1.0
var pan=Vector2.ZERO
var hovered=-1
var dragging=false
var blocked=-1
var attempted=-1
var blocked_cell=-1
var flash_left=0.0
var animations: Dictionary={}

func _ready() -> void:
 clip_contents=true;mouse_filter=Control.MOUSE_FILTER_STOP
 custom_minimum_size=Vector2(360,300)
 size_flags_horizontal=Control.SIZE_EXPAND_FILL;size_flags_vertical=Control.SIZE_EXPAND_FILL
 for thread in Rules.THREADS:
  var points=PackedVector2Array()
  for cell in thread.cells:points.append(cell_point(cell))
  paths.append(points)
  var length=0.0
  var rect=Rect2(points[0],Vector2.ZERO)
  for i in range(points.size()):
   rect=rect.expand(points[i])
   if i>0:length+=points[i].distance_to(points[i-1])
  lengths.append(length);bounds.append(rect.grow(CELL*.4))
 resized.connect(func():clamp_pan();queue_redraw())
 mouse_exited.connect(func():hovered=-1;queue_redraw())
 set_process(false)
func cell_point(cell: int) -> Vector2:return Vector2(cell%Rules.WIDTH+.5,floori(float(cell)/Rules.WIDTH)+.5)*CELL
func extent() -> Vector2:return Vector2(Rules.WIDTH,Rules.HEIGHT)*CELL
func draw_scale() -> float:return maxf(.01,minf((size.x-48)/extent().x,(size.y-48)/extent().y))*zoom
func origin() -> Vector2:return (size-extent()*draw_scale())*.5+pan
func screen_cell(cell: int) -> Vector2:return origin()+cell_point(cell)*draw_scale()
func fit_view() -> void:
 zoom=1.0;pan=Vector2.ZERO;hovered=-1;queue_redraw();zoom_changed.emit()
func clamp_pan() -> void:
 var limit=(extent()*draw_scale()-size)*.5+Vector2(32,32)
 pan.x=clampf(pan.x,-maxf(0,limit.x),maxf(0,limit.x))
 pan.y=clampf(pan.y,-maxf(0,limit.y),maxf(0,limit.y))
func zoom_at(factor: float,anchor: Vector2) -> void:
 var point=(anchor-origin())/draw_scale()
 zoom=clampf(zoom*factor,1.0,3.5)
 pan=anchor-(size-extent()*draw_scale())*.5-point*draw_scale()
 clamp_pan();hovered=-1;queue_redraw();zoom_changed.emit()
func pick(point: Vector2) -> int:
 var local=(point-origin())/draw_scale()
 var radius=minf(CELL*.38,9.0/draw_scale())
 var nearest=radius*radius;var chosen=-1
 for i in range(paths.size()):
  if removed.has(i) or not bounds[i].has_point(local):continue
  for j in range(1,paths[i].size()):
   var closest=Geometry2D.get_closest_point_to_segment(local,paths[i][j-1],paths[i][j])
   var distance=local.distance_squared_to(closest)
   if distance<nearest:nearest=distance;chosen=i
 return chosen
func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton:
  if event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
   dragging=event.pressed;hovered=-1;queue_redraw();accept_event()
  elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   zoom_at(1.18 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.18,event.position);accept_event()
  elif event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
   var id=pick(event.position)
   if id>=0:selected.emit(id)
   accept_event()
 elif event is InputEventMouseMotion:
  if dragging:
   pan+=event.relative;clamp_pan();queue_redraw();accept_event()
  else:
   var id=pick(event.position)
   if id!=hovered:hovered=id;queue_redraw()
func _input(event: InputEvent) -> void:
 if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:dragging=false
func clear_effects() -> void:
 animations.clear();blocked=-1;attempted=-1;blocked_cell=-1;flash_left=0;hovered=-1;dragging=false
 set_process(false);queue_redraw()
func show_blocker(id: int,cell: int) -> void:
 attempted=id;blocked_cell=cell;blocked=rules.owners[cell];flash_left=1.1
 set_process(true);queue_redraw()
func animate_pull(id: int) -> void:
 blocked=-1;attempted=-1;flash_left=0;hovered=-1
 animations[id]=0.0;set_process(true);queue_redraw()
func _process(delta: float) -> void:
 for id in animations.keys():
  animations[id]+=delta/.42
  if animations[id]>=1.0:animations.erase(id)
 if flash_left>0:
  flash_left-=delta
  if flash_left<=0:blocked=-1;attempted=-1
 queue_redraw()
 if animations.is_empty() and flash_left<=0:set_process(false)
func moving_path(id: int,t: float) -> PackedVector2Array:
 var points=paths[id].duplicate();var head=points[-1]
 var direction=Vector2(Rules.DIRECTIONS[Rules.THREADS[id].direction])
 var edge=extent().y-head.y if direction.y>0 else head.y if direction.y<0 else extent().x-head.x if direction.x>0 else head.x
 var advance=(lengths[id]+edge+CELL)*t
 points.append(head+direction*(lengths[id]+edge+CELL*2))
 var result=PackedVector2Array();var traveled=0.0
 var begin=advance;var end=advance+lengths[id]
 for j in range(1,points.size()):
  var length=points[j].distance_to(points[j-1])
  var a=maxf(begin-traveled,0.0);var b=minf(end-traveled,length)
  if b>=a and a<=length and b>=0:
   var direction_=(points[j]-points[j-1]).normalized()
   if result.is_empty():result.append(points[j-1]+direction_*a)
   result.append(points[j-1]+direction_*b)
  traveled+=length
  if traveled>=end:break
 return result
func paint_thread(id: int,ink: Color,width: float,points: PackedVector2Array) -> void:
 if points.size()<2:return
 var screen=PackedVector2Array()
 for point in points:screen.append(origin()+point*draw_scale())
 draw_polyline(screen,ink,width,true)
 draw_circle(screen[0],width*.5,ink,true,-1,true)
 var direction=Vector2(Rules.DIRECTIONS[Rules.THREADS[id].direction])
 var head=screen[-1];var arrow=CELL*draw_scale()*.33
 var wing=Vector2(-direction.y,direction.x)*arrow*.52
 draw_polyline(PackedVector2Array([head-direction*arrow+wing,head,head-direction*arrow-wing]),ink,width,true)
func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("f8f4eb"))
 draw_rect(Rect2(Vector2.ZERO,size).grow(-1),Color("d8cdbb"),false,1,true)
 var width=maxf(1.8,2.6*draw_scale())
 if hovered>=0 and not removed.has(hovered):paint_thread(hovered,Color(.16,.48,.51,.18),width+6,paths[hovered])
 for i in range(paths.size()):
  if removed.has(i):continue
  var ink=Color("bd493b") if i==blocked else Color("ad6b28") if i==attempted else HOVER if i==hovered else INK
  paint_thread(i,ink,width,paths[i])
 if attempted>=0 and blocked_cell>=0:
  var start=screen_cell(Rules.THREADS[attempted].cells[-1]);var finish=screen_cell(blocked_cell)
  draw_dashed_line(start,finish,Color("bd493b"),1.4,5.0,true)
  draw_circle(finish,CELL*draw_scale()*.30,Color("bd493b"),false,2,true)
 for id in animations:paint_thread(id,HOVER,width,moving_path(id,animations[id]))
