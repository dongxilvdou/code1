extends RefCounted
## One persisted acknowledgement per day; merely opening/cancelling a note does not unlock tasks.
const FLAGS := ["","note_read","d2_note","a3_note","a4_note","a5_note","a6_note","a7_note","a8_note","a9_note","a10_note_read","a11_note"]
const CONTENT := ["",
	"① 先试试走路、跑步，打开客厅门。\n② 跳上单人沙发和茶几，把水杯放回杯垫。\n③ 关掉客厅的灯，收集一楼四张纸片。\n④ 解开喂食器，喂饱自己和大狗嚼。",
	"① 收集沙发前沿、单人沙发和玄关的三件衣服，放进洗衣机。\n② 用书房的尺子取回沙发底下的毛线球，送回猫窝。\n③ 叼起狗盘，到厨房对水龙头按 E 冲洗，再送回大狗身边。",
	"① 红色园艺书 → 第一层红色书列。\n② 蓝色日记 → 第二层蓝色书列；黄色图鉴 → 第三层黄色书列。\n③ 检查厨房水槽下的水管，再取水壶给沙发旁的花浇水。\n④ 别忘了给大狗嚼带饭。",
	"① 跳上冰箱旁的柜台，解开侧面的八数码机关。\n② 冰箱里只有一条鱼，叼到灶台烤箱，放好后关门。\n③ 吃完可以把剩下的半条鱼分享给大狗嚼。\n④ 和它聊聊，也许它需要你帮忙找玩具。",
	"① 七只药瓶不能开盖。摇晃听声音，选出药片最少的三瓶。\n② 去找大狗嚼；若它不肯直接吃药，再想办法混进狗粮盘。\n③ 盛好狗粮，把盘子送回大狗身边。",
	"今天，二楼每个房间都放了小鱼干。\n去找到它们，并吃掉吧。\n\n上楼前，先给阿嚼带一份饭，再和它聊聊。",
	"① 全屋停电了，先到二楼走廊检查电路。\n② 恢复供电后，研究电脑房的座椅感应垫。\n③ 电脑桌上的便签，也许能帮你想起密码。",
	"① 二楼主卧柜顶有一袋特制猫粮，想办法拿到并吃掉。\n② 好久没有洗澡了，去二楼熟悉的淋浴间洗个澡。\n③ 二楼书房的时钟停了，找到小时、分钟、秒三张纸条，把三根指针调到正确时间。",
	"① 二楼露台的花盆有点不美观，按照旁边的画调整一下。\n② 花园里有一只地鼠，请抓住它。\n③ 完成二楼书房桌上的拼图。",
	"家里进了一只老鼠。\n\n捉住它，然后吃了它。",
	"来地下室。"]

static func read(day: Node, number: int = 0) -> bool:
	var current: int = day.value("current_day",1) if number==0 else number
	if current==5:return day.flag("a5_letter")
	return day.flag("daily_note_ack_%d"%clampi(current,1,11))

static func position_for(number: int, table: Vector3) -> Vector3:
	if number==1:return Vector3(-.35,.018,5.07) # Reachable before entering the locked tutorial room.
	return table+Vector3(.12,.454,.12) # Near the front edge, fully supported by the tabletop.

static func guidance(number: int) -> String:
	if number==5:return "今天的任务清单不见了。\n跳上客厅茶几看看，再留意门外的动静。"
	return "先读完今天的小纸条，再开始任务。\n"+({1:"纸条在入户门内，地垫旁的地面。",5:"纸条在客厅南窗的猫窝旁，地面上。"}.get(number,"纸条在客厅茶几上。"))
