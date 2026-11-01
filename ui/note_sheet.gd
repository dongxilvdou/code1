extends Control
const Catalog=preload("res://ui/notes_catalog.gd")
var note_id="day1"
var font: Font
var paper: Texture2D
func _ready() -> void:
 font=SystemFont.new();font.font_names=PackedStringArray(["KaiTi","Microsoft YaHei","SimHei"])
 paper=Catalog.load_image("res://assets/notes/paper_surface.png")
func _draw() -> void:
 if font==null:return
 if paper:draw_texture_rect(paper,Rect2(Vector2.ZERO,size),false)
 else:draw_rect(Rect2(Vector2.ZERO,size),Color("f3ead7"))
 var entry: Dictionary=Catalog.data(note_id)
 var margin=size.x*.11
 draw_string(font,Vector2(margin,margin+34),entry.title,HORIZONTAL_ALIGNMENT_LEFT,-1,36,Color("5f4c35"))
 var text:=TextParagraph.new();text.width=size.x-margin*2;text.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND
 text.add_string(entry.text,font,34);text.draw(get_canvas_item(),Vector2(margin,margin+102),Color("383729"))
 if note_id=="paper2" or note_id=="paper3":
  # Keep paw glyphs identical to the machine; no random generated counts.
  var center=Vector2(size.x*.38,size.y*.67)
  draw_paw(center,false)
  if note_id=="paper3":draw_paw(center+Vector2(210,0),true)
func draw_paw(center: Vector2,dog: bool) -> void:
 draw_set_transform(center,0,Vector2.ONE*2.4)
 var ink=Color("6b6350")
 draw_circle(Vector2(0,5),9,ink)
 for p in [Vector2(-13,-6),Vector2(-5,-13),Vector2(5,-13),Vector2(13,-6)]:
  draw_circle(p,4.5,ink)
  if dog:draw_line(p+Vector2(0,-6),p+Vector2(1,-10),ink,2,true)
 draw_set_transform(Vector2.ZERO)
