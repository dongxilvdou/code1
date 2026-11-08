extends RefCounted
## Shared narrative copy. Visuals never own quest flags or write a second save.
const STATION_ADDRESS := "青柏路 17 号 / 住宅分站 C-031"
const REPORT_TITLE := "未寄出的举报材料"
const REPORT := "02 号已经死了。01 号失踪以后，主任还要继续。米酥的名字已经写进下一批名单。今晚我会把原始记录交出去。"
const PASSWORD_NOTE := "最爱的小猫的名字"
const PHOTO_BACK := "米酥怕冷。把毯子留给它。\nC-031 · 转移前观察"
const PHOTO_NAME := "米酥 / C-031"
const PHOTO_ASIDE := "米酥……这个名字，好像很熟悉。"
const LAB_PHOTO := "照护负责人 H-031"
const RECORD_INDEX := "住宅分站 C-031。完整转移记录未同步。H-031 维持回路独立供电，最近状态须到地下终端确认。维护附件 K-2 存放于本机下方维修盒。"
const SYNC_STATUS := "外部同步失败。站点无人应答。"
const BODY_FIELDS := ["研究员 / H-031", "生命维持稳定", "意识已迁出"]
const RECORD_TABS := ["身份记录", "护理档案", "转化日志"]
const RECORDS := [
	"H-031，男性研究员。\n转移前载体。\n\n与既有合照、工作照中的男性对应。",
	"C-031，米酥。\n照护负责人 H-031。",
	"03:42:00 · 意识转移完成\n转移前载体　H-031，男性研究员\n接收载体　C-031，米酥\n本次转移同步写入服从钢印，并封锁研究员的个人记忆。\nH-031 原身体已接入独立维持回路。"
]
const RECORDING_CAPTION := "文件袋被扯走。\n主任：“既然这么心疼它们，你自己试试。”\n随后，装置启动。"
const REPAIR := "反向耦合模块烧毁。替换件在检查台侧抽屉。维修期间保持 H-031 维持供电。记忆封印与强制指令通道分别处理。"
const CAGE_SIGNS := ["F-01 / 失踪", "F-02 / 终止", "F-03 / C-031"]
const PREVIEW_NOTICE := "模型与会话预览 · 不提交剧情进度，不读写正式存档"
const BOX_CODE := "031"
const K2_ANSWER := [1,1,0]
const MEMORY_ANSWER := [0,1,0]
const ROUTING_ANSWER := [0,1,2]
const VERIFY_TIME := [3,42,0]
const K2_MANUAL := "匹配当前载体后，可一次性停用自动重写并彻底解除强制指令钢印。\n解除结果永久保留，不需要持续佩戴维持。\n本机不能完整恢复被封存的个人记忆。\n使用最低可用输出。单次激活消耗后不能再次使用。"
const TIME_FOOTER := "最后一次操作"
const TIME_RECORD := "03:42:00\n最后一次操作。\n\n哪台机器的？地下终端也许还保留着日志。"
const MOUSE_HINT := "桌下的 K-2 能清除强制通道。先匹配当前猫载体，使用低输出。"
const REST_SAVED := "那道声音还在，但它已经不能再让身体替我执行了。\n明天，我要找到能离开这里的路。"
const REST_LOST := "我今天到底怎么了，为什么身体不受控制，为什么一定要吃了它，主人......到底是谁？"
const MOUSE_SAVED := "我：我停下来了。那道声音还在，但它已经不能再让身体替我执行了。\n\n阿嚼：我看见了。你松开了爪子。\n\n老鼠钻进柜下，把纸条推了回来。背面多了一句：明天，监控下面。\n纸条上的旧抓痕图，来自逃走的灰白猫；老鼠一直沿着管道替它送消息。"
const MOUSE_LOST := "阿嚼：我看见了，你刚才已经转身了。\n\n我：可我的身体又回来了。\n\n纸条留在地上。那只送来纸条的老鼠，已经不在了。"
const SEEK_TERMINAL := "阿嚼：那张纸条，指向监控下方。\n\n我：明天，我得亲眼看看地下室。"
const MEMORY_CAPTIONS := ["研究员：米酥，怕冷就靠近一点。\n那条毯子，是我留给它的。", "02号已经死了，01号失踪。\n我把老鼠藏起来，把原始记录装进文件袋。", "主任：既然这么心疼它们，你自己试试。\n装置启动。视线落到猫的高度。\n\n照片里的那个人是我。米酥……是我给它取的名字。\n原来不是今天才失控。从醒来的时候起，它就在。"]

static func paper_memory(mouse: int, cleared := true) -> String:
	var lead := "纸条指向监控下方。"
	if mouse==2:lead="我用 K-2 永久解除了强制通道。老鼠把纸条留给了我。" if cleared else "我用过 K-2，放走了老鼠。旧记录没有保存永久解除结果，还要到终端核验通道状态。"
	elif mouse==1:lead="昨天，我明明想离开，身体却还是执行了命令。但那张纸条上的内容，我记住了。"
	return lead+"\n\n「地下室逃跑计划」\n「监控底下。沿着旧抓痕走。」\n\n这里也许有答案，也许有能出去的路。"

static func ending_text(kind: int, mouse: int, memory: bool, cleared: bool) -> String:
	var text_ := ""
	if kind==2:
		text_="他带走了米酥、阿嚼和剩下的实验记录。失去的时间不会回来，记忆也还需要慢慢整理。但这一次，他可以决定先照顾谁。"
	else:
		text_="米酥离开了那套仍在运转的日程。阿嚼也被带了出来。它还保留着猫的身体，关于过去和以后的问题，终于可以在安全的地方继续寻找答案。"
		text_+="\n\n我知道自己是谁。现在我想先离开。" if memory else "\n\n还没想明白的事，出去以后再说。"
		text_+="\n强制通道已经永久关闭。" if cleared else "\n那道控制仍需要处理，但分站已经无法继续把命令送到它面前。"
	if mouse==1:text_+="\n\n送来纸条的那只老鼠没有等到这一天。"
	elif mouse==2:text_+="\n\n那只冒险回来的老鼠，也被一起带走。"
	return text_

static func rest_text(mouse: int, level: int) -> String:
	if mouse==2:return REST_SAVED+("\n我知道自己原本是谁。剩下的事，要去地下室确认。" if level==3 else "")
	if level>=2:return "我记得自己是 H-031，却还是没能让爪子松开。\n知道真相，没有让身体自由。"
	return REST_LOST

static func memory_caption(level: int) -> String:
	match level:
		1:return "这条毯子……是我留下的。\n那个俯身照顾米酥的人，为什么像是我？"
		2:return "照片里的那个人，是我。\n米酥……是我给它取的名字。\n那些被照顾的熟悉感，来自它；我记得的，是照顾它的那双手。"
		_:return "我原本要把记录带出去……\n主任：既然这么心疼它们，你自己试试。\n\n装置启动，视线落到猫的高度。\n“来这里学习照顾主人”是他们给我的说法，不是我的经历。记忆封存和身体控制，是两道不同的锁。"

static func route_ending_text(route: int, mouse: int, level: int, cleared: bool) -> String:
	if route==1:
		var result:="回到了原来的家。另一只猫向我跑来，原住的狗还守在熟悉的位置。\n\n实验失败。观察对象离开监测范围。\n\n我仍在猫的身体里。强制通道尚未解除，离开分站只让它暂时收不到命令。"
		if level>=2:result+="\n我没有忘记：照片中的 H-031 是我。"
		if level==3:result+="\n举报和转移的经过，我也记得；昨晚还没有准备好安全回迁的方法。"
		return result+"\n送来纸条的老鼠已经死了。阿嚼仍在分站，去向尚未确认。"
	return ending_text(2 if route==3 else 3,mouse,level==3,cleared)
