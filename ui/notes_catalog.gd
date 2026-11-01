extends RefCounted
const Daily=preload("res://day1/daily_notes.gd")
const PAPER_KEYS=["living","dining","kitchen","study1"]
const PAPERS=[
 {"title":"纸片一 · 图案的先后","text":"太阳在鱼骨之前。\n\n机器上的位置，并不是开锁的顺序。"},
 {"title":"纸片二 · 最后的位置","text":"月亮排在最后。\n\n把看见的图案，重新排好。"},
 {"title":"纸片三 · 留下的脚印","text":"只数这种完整的猫脚印。\n\n圆圆的掌垫，四枚趾垫。\n把同一图案下的完整脚印数清楚。"},
 {"title":"纸片四 · 别数错了","text":"半个掌印，不算。\n带爪尖的大脚印，也不算。\n\n想一想，它们是谁留下的。"}
]
static var textures: Dictionary={}
static func data(id: String) -> Dictionary:
 if id.begins_with("day"):
  var number=clampi(int(id.trim_prefix("day")),1,11)
  return {"title":"第 %d 天的小纸条"%number,"text":Daily.CONTENT[number]+("\n\n我：又是没有署名的命令。\n昨天的逃跑计划也指向地下室。\n那里也许有答案，也许有能出去的路。" if number==11 else "")}
 if id.begins_with("paper"):
  return PAPERS[clampi(int(id.trim_prefix("paper")),0,3)].duplicate()
 match id:
  "escape":return {"title":"被折过的小纸条","text":"地下室逃跑计划。\n\n监控底下。\n沿着旧抓痕走。\n\nD-017 / C-031"}
  "letter":return {"title":"今天的照料清单","text":"大狗嚼今天需要吃药。\n七只药瓶无法开盖，只能摇晃听声音。\n药片越多，碰撞声越响、越密。\n请从药片最少的三瓶里取药，\n照顾它吃下去。\n\n没有署名，也没有写它为什么需要吃药。"}
  "photo":return {"title":"收好的照片","text":"主人穿着白大褂，身旁蹲着我。\n照片背面：C-031 / 阶段 II。"}
  "pipes":return {"title":"柜门里的镜头","text":"红点正对着我修水管的位置。\n它一直在看着这里吗？"}
  "bone":return {"title":"阿嚼的玩具骨头","text":"骨头上刻着：D-017。\n\n→ 短，↘ 长。\n这是阿嚼留下的线索。"}
 return {"title":"线索册","text":"找到值得记住的纸片和照片后，可以收在这里。"}
static func load_image(path: String) -> Texture2D:
 if textures.has(path):return textures[path]
 if ResourceLoader.exists(path):
  var imported=load(path) as Texture2D
  if imported:textures[path]=imported;return imported
 if not FileAccess.file_exists(path):return null
 var image=Image.load_from_file(ProjectSettings.globalize_path(path))
 if image==null or image.is_empty():return null
 var texture=ImageTexture.create_from_image(image);textures[path]=texture;return texture
static func texture(id: String) -> Texture2D:
 return load_image("res://act2/memory_photo.png" if id=="photo" else "res://assets/notes/%s.png"%id)
static func collected(day: Node) -> Array[String]:
 var result: Array[String]=[]
 for number in range(1,12):
  if day.flag("daily_note_ack_%d"%number):result.append("day%d"%number)
 for i in range(4):
  if day.flag("paper_"+PAPER_KEYS[i]) or day.flag("papers_done"):result.append("paper%d"%i)
 for entry in [["a3_photo","photo"],["a3_pipes","pipes"],["yarn_solved","bone"],["a5_letter","letter"],["a10_note","escape"]]:
  if day.flag(entry[0]):result.append(entry[1])
 return result
static func all_ids() -> Array[String]:
 var ids: Array[String]=[]
 for number in range(1,12):ids.append("day%d"%number)
 ids.append_array(["paper0","paper1","paper2","paper3","escape","letter","pipes","bone"])
 return ids
