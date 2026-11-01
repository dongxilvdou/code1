extends Control
const GROUPS=["鱼骨","月亮","太阳"]
const COUNTS=[4,1,2]
const ORDER=[2,0,1]
var font: Font
static func password() -> String:
 var result=""
 for index in ORDER:result+=str(COUNTS[index])
 return result
func _ready() -> void:
 font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
 mouse_filter=Control.MOUSE_FILTER_IGNORE
func symbol(center: Vector2,index: int) -> void:
 var ink=Color("725b40")
 if index==0:
  draw_line(center-Vector2(25,0),center+Vector2(25,0),ink,3,true)
  for x in [-12,0,12]:
   draw_line(center+Vector2(x,0),center+Vector2(x-7,-10),ink,2,true)
   draw_line(center+Vector2(x,0),center+Vector2(x-7,10),ink,2,true)
  draw_circle(center+Vector2(28,0),7,ink)
 elif index==1:
  draw_circle(center,18,ink);draw_circle(center+Vector2(9,-5),16,Color("e9dfc6"))
 else:
  draw_arc(center,12,0,TAU,40,ink,2,true)
  for i in range(8):
   var d=Vector2.from_angle(i*TAU/8);draw_line(center+d*17,center+d*24,ink,2,true)
func paw(center: Vector2,dog: bool=false,partial: bool=false,scale_: float=1.0) -> void:
 var ink=Color("6b6350") if not dog else Color("897564")
 var s=scale_*(1.27 if dog else 1.0)
 draw_set_transform(center,0,Vector2.ONE*s)
 draw_circle(Vector2(0,5),9,ink)
 for p in [Vector2(-13,-6),Vector2(-5,-13),Vector2(5,-13),Vector2(13,-6)]:
  if partial and p.x>0:continue
  draw_circle(p,4.5,ink)
  if dog:draw_line(p+Vector2(0,-6),p+Vector2(1,-10),ink,2,true)
 if partial:draw_rect(Rect2(0,-22,24,42),Color("e9dfc6"))
 draw_set_transform(Vector2.ZERO)
func _draw() -> void:
 if font==null:return
 draw_style_box(preload("res://quest_system/quest_theme.gd").panel(12),Rect2(Vector2.ZERO,size))
 draw_rect(Rect2(Vector2(10,10),size-Vector2(20,20)),Color("e9dfc6"))
 for col in range(3):
  var x=(col+.5)*size.x/3
  symbol(Vector2(x,38),col)
  draw_string(font,Vector2(x-17,77),GROUPS[col],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("725b40"))
  if col>0:draw_line(Vector2(col*size.x/3,22),Vector2(col*size.x/3,size.y-18),Color("b5a88b"),1)
  for i in range(COUNTS[col]):paw(Vector2(x+(i%2-.5)*55,115+int(i/2)*63))
  paw(Vector2(x-29,248),true,false,.87)
  paw(Vector2(x+32,248),false,true,.92)
