extends RefCounted
## Shared narrative copy. Visuals never own quest flags or write a second save.
const REPORT_TITLE := "未寄出的举报材料"
const REPORT := "02 号已经死了。01 号失踪以后，主任还要继续。米酥的名字已经写进下一批名单。今晚我会把原始记录交出去。"
const PASSWORD_NOTE := "最爱的小猫的名字"
const PHOTO_BACK := "米酥怕冷。把毯子留给它。\nC-031 · 转移前观察"
const PHOTO_NAME := "米酥 / C-031"
const PHOTO_ASIDE := "我记得……这个名字是我取的。\n为什么会这样想？"
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
const K2_MANUAL := "仅用于短时校准。先完成载体匹配，强制通道受扰后可能暂缓执行。单次使用后需要实验室重新维护。\n\n匹配当前载体；本机不读取个人记忆；使用最低可用输出。"
const TIME_FOOTER := "最后一次操作"
const TIME_RECORD := "03:42:00\n最后一次操作。\n\n哪台机器的？地下终端也许还保留着日志。"
const MOUSE_HINT := "桌下那个发光的东西，也许能让声音停一会儿。"
const REST_SAVED := "我明明想停下来，身体却还是在听那个声音。刚才只是那个装置帮了我一下……主人，到底是谁？"
const REST_LOST := "我今天到底怎么了，为什么身体不受控制，为什么一定要吃了它，主人......到底是谁？"
const MOUSE_SAVED := "我：我明明已经想停下了。刚才那个声音，还是在把我往回拽。\n\n阿嚼：我看见了。是那个小东西让你停住了一会儿。\n\n我：它不是在叫我。它是在用我的身体。\n\n柜下传来两下轻响。老鼠把纸条推了回来，背面多了一句：明天，监控下面。"
const MOUSE_LOST := "阿嚼：我看见了，你刚才已经转身了。\n\n我：可我的身体又回来了。\n\n纸条留在地上。那只送来纸条的老鼠，已经不在了。"
const SEEK_TERMINAL := "阿嚼：我看见你想转身。那道声音却在拖着你。\n\n我：地下那个终端，也许能告诉我，它是从什么时候开始的。"
const MEMORY_CAPTIONS := ["研究员：米酥，怕冷就靠近一点。\n那条毯子，是我留给它的。", "02号已经死了，01号失踪。\n我把老鼠藏起来，把原始记录装进文件袋。", "主任：既然这么心疼它们，你自己试试。\n装置启动。视线落到猫的高度。\n\n照片里的那个人是我。米酥……是我给它取的名字。\n原来不是今天才失控。从醒来的时候起，它就在。"]

static func paper_memory(mouse: int) -> String:
	var lead := "纸条指向监控下方。"
	if mouse==2:lead="那一次，我借助校准器停住了。老鼠把纸条留给了我。"
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
