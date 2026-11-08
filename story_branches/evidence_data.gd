extends RefCounted
## One source for the physical documents, desktop and journal.
const Copy=preload("res://story_branches/data.gd")
const IDS := ["d1","d2","d3","d4","d5","d6"]
const ENTRIES := {
	"d1":{"title":"C-031 照护交接单","location_hint":"二楼主卧 · 床头抽屉","body":"接收载体：C-031 / 米酥。\n夜间怕冷，旧毯不要更换。\n饭后先等它靠近，不要强行抱起。\n照护负责人：H-031。\n\n载体保留对照护者的感官熟悉感。它与转入者的个人经历不是同一份记忆。"},
	"d2":{"title":"H-031 人员登记与工作记录","location_hint":"电脑 · 人员档案 / H-031","body":"H-031 / 男性研究员。\n负责 C-031 的照护与观察记录。\n工作照、记录签名与照护交接单一致。\n近期有转化实验异议记录。\n\n原始资料编号对应二楼书房的“住宅分站 / 原始操作”档案。\n照护交接资料留在二楼主卧床头抽屉。\n\n驻点登记："+Copy.STATION_ADDRESS},
	"d3":{"title":"住宅分站意识转移日志·留存副本","location_hint":"二楼书房 · 桌沿档案夹","body":"最后一次操作：03:42:00。\n意识源端：H-031。\n接收载体：C-031 / 米酥。\n操作完成后限制源端个人记忆访问，另行写入强制指令通道。\nH-031 原身体转入独立维持回路。\n本记录为历史留存，不代表当前生命体征。\n\n载体原生意识保留于休眠状态，没有被清空。源端意识回迁后，载体原生意识可恢复活动。\n载体的感官熟悉感可能被转入者体验；不代表源端曾以猫的身份生活。\n\n附件：举报材料留存稿，位于一楼工作书房。"},
	"d4":{"title":"未寄出的举报材料·留存稿","location_hint":"一楼工作书房 · 资料夹","body":"02 号已经死了。01 号失踪以后，主任仍要继续。\n米酥的名字已经写进下一批名单。\n今晚我会把原始记录交出去。\n\n——以下为事后归档标签，并非举报正文——\n关联操作记录：03:42。\n现场会话备份：住宅分站电脑 / 封存记录。\n地下室留存的举报材料为另一份副本。"},
	"d5":{"title":"03:42 封存会话","location_hint":"电脑 · 住宅分站 / 封存记录","body":"本地离线副本。外部同步失败不影响已留存的记录。","pages":{"recording":"文件袋被扯走。\n主任：“既然这么心疼它们，你自己试试。”\n随后，装置启动。\n\n会话时间：03:42:00。签名：H-031。\n任务叙述“主人生病了，在这里学习照护”由实验系统提供，并非 H-031 的真实经历。它与载体的熟悉感混合，使转入者误认了自己的来历。","access":"个人经历访问限制与强制指令通道分别运行。\n对照源端身份、记录签名和操作时间，可执行本地只读一致性核对。\n核对用于恢复本人经历的访问，不写入他人的记忆，也不改变身体控制通道。\n\n“只读”指保留原始档案。两页与前序资料匹配后，个人经历访问自动恢复。"}},
	"d6":{"title":"反向转移维护规程","location_hint":"电脑 · H-031 归档 / 回迁方案","body":"先在地下室确认 H-031 的实际生命体征，不以旧巡检记录代替现场检查。\n保持维持回路接通，隔离转移执行回路，再接入维护桥。\n检查反向耦合模块和线路。若模块校验异常，备用件在检查台侧抽屉。\n读取 C-031，写入 H-031，以原始档案核验。\n启动前核对目标 H-031 与最后一次操作时间 03:42:00。\n钢印尚未解除时，另行关闭自动重写与强制通道并验证。\n若 K-2 已完成永久解除，只核验现有结果，禁止重新附加钢印。\n禁止断开 H-031 维持供电。\n\n反向转移只取回 H-031 的意识；米酥的原生意识从休眠恢复。两者分别观察、护理。\n\n回迁准备摘要：H-031 / 03:42:00 / 读 C-031、写 H-031 / 维持开、转移关、维护开。"}
}

static func data(id: String, page := "") -> Dictionary:
	var result: Dictionary=ENTRIES.get(id,{}).duplicate(true)
	if not page.is_empty() and result.get("pages",{}).has(page):
		result.body=result.pages[page]
		result.title+=" / "+("录音与字幕" if page=="recording" else "访问说明")
	return result

static func access_reason(id: String, facts: Dictionary) -> String:
	if id not in IDS:return "未找到这份资料。"
	if int(facts.get("current_day",1))<7:return "电脑恢复后，可以检查住宅内的留存资料。"
	if id=="d2":
		for key in ["a7_read_photo","a7_read_site","a7_read_chat","a7_read_news"]:
			if not facts.get(key,false):return "先完成工作照、站点、聊天和新闻四项调查。"
	if id=="d5" and not (facts.get("br_doc_d3_read",false) and facts.get("br_doc_d4_read",false)):return "本地索引缺失：检查二楼书房原始操作档案与一楼工作书房举报留存稿。"
	if id=="d6" and not facts.get("br_memory_verified",false):return "先核对封存会话的两个页签及前序身份资料。"
	return ""
