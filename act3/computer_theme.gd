extends RefCounted
## Desktop applications have their own native-looking controls, separate from paper dialogues.
const INK=Color("202124")
const MUTED=Color("687078")
const BLUE=Color("0067c0")
const LINE=Color("dedfe1")
static var shared: Theme
static func box(fill: Color,border: Color=Color.TRANSPARENT,padding: float=10,radius: int=4) -> StyleBoxFlat:
 var result=StyleBoxFlat.new();result.bg_color=fill;result.border_color=border
 result.set_border_width_all(1 if border.a>0 else 0);result.set_corner_radius_all(radius);result.set_content_margin_all(padding)
 return result
static func resource() -> Theme:
 if shared:return shared
 shared=Theme.new();shared.default_font=preload("res://quest_system/quest_theme.gd").font();shared.default_font_size=16
 for type_ in ["Label","Button","LineEdit","TextEdit","Tree","LinkButton"]:
  shared.set_color("font_color",type_,INK);shared.set_color("font_focus_color",type_,INK);shared.set_color("font_hover_color",type_,INK)
 for state in ["normal","hover","pressed","focus","disabled"]:
  var fill=Color("e5f0fa") if state=="pressed" else Color("ededee") if state=="hover" else Color.TRANSPARENT
  shared.set_stylebox(state,"Button",box(fill,BLUE if state=="focus" else Color.TRANSPARENT,8,4))
 shared.set_stylebox("panel","PanelContainer",box(Color.WHITE))
 for type_ in ["LineEdit","TextEdit"]:
  shared.set_stylebox("normal",type_,box(Color("fafafa"),LINE,10,4));shared.set_stylebox("focus",type_,box(Color.WHITE,BLUE,10,4))
  shared.set_stylebox("read_only",type_,box(Color("f7f7f7"),LINE,10,4))
  shared.set_color("font_placeholder_color",type_,MUTED);shared.set_color("font_uneditable_color",type_,INK);shared.set_color("font_readonly_color",type_,INK)
  shared.set_color("selection_color",type_,Color("cce8ff"));shared.set_color("caret_color",type_,INK)
 shared.set_stylebox("panel","Tree",box(Color.WHITE,Color.TRANSPARENT,4,0))
 shared.set_stylebox("selected","Tree",box(Color("cce8ff")));shared.set_stylebox("selected_focus","Tree",box(Color("cce8ff")))
 shared.set_color("font_selected_color","Tree",INK);shared.set_constant("v_separation","Tree",12)
 shared.set_stylebox("title_button_normal","Tree",box(Color("f9f9f9"),LINE,8,0))
 shared.set_stylebox("title_button_hover","Tree",box(Color("e9eef5"),LINE,8,0))
 for state in ["title_button_color","title_button_hover_color","title_button_pressed_color"]:shared.set_color(state,"Tree",INK)
 shared.set_stylebox("panel","TooltipPanel",box(Color("fffff2"),LINE,8,3));shared.set_color("font_color","TooltipLabel",INK)
 return shared
static func label(text: String,parent: Node,size_: int=16,color: Color=INK,wrap: bool=true) -> Label:
 var result=Label.new();result.text=text;result.add_theme_font_size_override("font_size",size_);result.add_theme_color_override("font_color",color)
 if wrap:result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;result.custom_minimum_size.x=100
 parent.add_child(result);return result
static func button(text: String,parent: Node,callback: Callable) -> Button:
 var result=Button.new();result.text=text;result.custom_minimum_size.y=34;result.pressed.connect(callback);parent.add_child(result);return result
static func icon(kind: String) -> Texture2D:
 var art='<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">'
 if kind=="photo":art+='<rect x="4" y="3" width="24" height="26" rx="2" fill="#e5f2fd" stroke="#5698c7"/><rect x="7" y="7" width="18" height="18" fill="#99c8e7"/><circle cx="20" cy="12" r="3" fill="#ffe7a5"/><path d="M7 25l7-11 6 8 5-5v8z" fill="#4b936d"/>'
 elif kind=="folder":art+='<path d="M3 7h11l3 3h12v18H3z" fill="#e7ac35"/><path d="M3 12h26v16H3z" fill="#ffd572"/>'
 else:art+='<rect x="3" y="4" width="26" height="19" rx="2" fill="#4496cb"/><path d="M10 28h12m-6-5v5" stroke="#526d81" stroke-width="3"/>'
 var image=Image.new();image.load_svg_from_string(art+'</svg>');return ImageTexture.create_from_image(image)
