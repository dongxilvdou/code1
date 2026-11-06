extends RefCounted
## Shared narrative copy. Visuals never own quest flags or write a second save.
const REPORT_TITLE := "未寄出的举报材料"
const REPORT := "02 号已经死了。01 号失踪以后，主任还要继续。米酥的名字已经写进下一批名单。今晚我会把原始记录交出去。"
const PASSWORD_NOTE := "最爱的小猫的名字"
const PHOTO_BACK := "米酥怕冷。把毯子留给它。\nC-031 · 转移前观察"
const PHOTO_NAME := "米酥 / C-031"
const LAB_PHOTO := "照护负责人 H-031"
const RECORD_INDEX := "住宅分站 C-031。完整转移记录未同步。H-031 维持回路独立供电，最近状态须到地下终端确认。维护附件 K-2 存放于本机下方维修盒。"
const SYNC_STATUS := "外部同步失败。站点无人应答。"
const BODY_FIELDS := ["研究员 / H-031", "生命维持稳定", "意识已迁出"]
const RECORD_TABS := ["身份记录", "接收载体", "转化日志"]
const RECORDS := [
	"H-031，男性研究员。\n转移前载体。\n\n与既有合照、工作照中的男性对应。",
	"C-031，米酥。\n接收载体为 H-031 的意识。",
	"03:42:00 · 意识转移完成\n转移前载体　H-031，男性研究员\n接收载体　C-031，米酥\n本次转移同步写入服从钢印，并封锁研究员的个人记忆。\nH-031 原身体已接入独立维持回路。"
]
const RECORDING_CAPTION := "文件袋被扯走。\n主任：“既然这么心疼它们，你自己试试。”\n随后，装置启动。"
const REPAIR := "反向耦合模块烧毁。替换件在检查台侧抽屉。维修期间保持 H-031 维持供电。记忆封印与强制指令通道分别处理。"
const CAGE_SIGNS := ["F-01 / 失踪", "F-02 / 终止", "F-03 / C-031"]
const PREVIEW_NOTICE := "模型与会话预览 · 不提交剧情进度，不读写正式存档"
