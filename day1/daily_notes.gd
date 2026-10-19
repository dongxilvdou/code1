extends RefCounted
## One persisted acknowledgement per day; merely opening/cancelling a note does not unlock tasks.
const FLAGS := ["","note_read","d2_note","a3_note","a4_note","a5_note"]
const CONTENT := ["",
	"① 先试试走路、跑步，打开客厅门。\n② 跳上单人沙发和茶几，把水杯放回杯垫。\n③ 关掉客厅的灯，收集一楼四张纸片。\n④ 解开喂食器，喂饱自己和大狗嚼。",
	"① 收集沙发前沿、单人沙发和玄关的三件衣服，放进洗衣机。\n② 用书房的尺子取回沙发底下的毛线球，送回猫窝。\n③ 叼起狗盘，到厨房对水龙头按 E 冲洗，再送回大狗身边。",
	"① 红色园艺书 → 第一层红色书列。\n② 蓝色日记 → 第二层蓝色书列；黄色图鉴 → 第三层黄色书列。\n③ 检查厨房水槽下的水管，再取水壶给沙发旁的花浇水。\n④ 别忘了给大狗嚼带饭。",
	"① 跳上客厅茶几，留意门铃，去门外取信。\n② 根据来信，解开冰箱侧面的机关。\n③ 将鲜鱼放入灶台烤箱，关门烤熟。\n④ 可以把剩下的半条鱼分享给大狗嚼，再帮它找找玩具。",
	"① 客厅茶几上有七只照护药瓶。先观察，选择剩余量最少的三瓶。\n② 去找大狗嚼；若它不肯直接吃药，再想办法混进狗粮盘。\n③ 盛好狗粮，把盘子送回大狗身边。\n④ 也可以陪它聊聊，旧玩具上的编号也许能唤回它的名字。"]

static func read(day: Node, number: int = 0) -> bool:
	var current: int = day.value("current_day",1) if number==0 else number
	return day.flag("daily_note_ack_%d"%clampi(current,1,5))

static func position_for(number: int, table: Vector3) -> Vector3:
	if number==1:return Vector3(-.35,.018,5.07) # Reachable before entering the locked tutorial room.
	if number==5:return Vector3(-4.30,.018,4.32) # Beside the cat bed, outside its rim.
	return table+Vector3(.12,.454,.12) # Near the front edge, fully supported by the tabletop.

static func guidance(number: int) -> String:
	return "先读完今天的小纸条，再开始任务。\n"+({1:"纸条在入户门内，地垫旁的地面。",5:"纸条在客厅南窗的猫窝旁，地面上。"}.get(number,"纸条在客厅茶几上。"))
