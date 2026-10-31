extends RefCounted
const NAMES := ["把路走齐", "窄桥分时通行", "变速与时钟窗口"]
const COLORS := [Color("e19b89"),Color("80c4df"),Color("afd097")]
const BRIDGE_WINDOWS := [4,7]
const BRIDGE_TRAVEL := 2
const BRIDGE_COOLDOWN := 1
const CLOCK_WINDOWS := [8,10,12]
const HIGH_SCORE_COILS := 5

static func count_(level: int) -> int:return 3 if level==2 else 2
static func coil_limit(level: int) -> int:return [4,1,3][clampi(level,0,2)]
static func budget(level: int) -> int:return [4,2,3][clampi(level,0,2)]
static func approach_length(lane: int, route: int) -> int:return [3,2][lane]+route*2
static func length_(level: int, lane: int, route: int) -> int:
	if level==1:return approach_length(lane,route)+BRIDGE_TRAVEL+1
	if level==2:return [8,4,12][lane]+([0,8,20][route] if lane==1 else route*2)
	return [7,3][lane]+route*2
static func speed_(level: int, lane: int, distance_: int) -> int:
	return (2 if distance_<2 else 4) if level==2 and lane==1 else 1
static func arrival(level: int, lane: int, route: int, coils: int) -> int:
	var distance_:=0
	var beats:=coils
	while distance_<length_(level,lane,route):
		distance_+=speed_(level,lane,distance_)
		beats+=1
	return beats

static func distance_at(level: int, lane: int, route: int, coils: int, time: float) -> float:
	var total:=length_(level,lane,route)
	var first:=mini(total,speed_(level,lane,0))
	if time<=1.0:return maxf(0,time)*first
	if time<=1.0+coils:return float(first)
	var remaining:=time-1.0-coils
	var distance_:=float(first)
	while remaining>0 and distance_<total:
		# Even a partial final segment occupies one whole beat, as the rule states.
		var step:=mini(speed_(level,lane,int(distance_)),total-int(distance_))
		distance_+=step*minf(1.0,remaining)
		remaining-=1.0
	return minf(distance_,total)

static func rules(level: int) -> String:
	return [
		"两球从第0拍同时出发，每拍走到下一个节点；每枚线圈在首节点停1拍。让两盏终点灯同时点亮。每路最多4枚，全关最多4枚。",
		"两球共用窄桥，桥只在第4、7拍准入：红先蓝后。过桥用2拍，再空出1拍散热，禁止等待和抢行。每拍走1节点；每路仅1个线圈插槽，全关最多2枚。",
		"红、绿每拍走1节点；蓝先走2节点/拍，到第2节点后变为4节点/拍。末段不足4节点也占1整拍。线圈在首拍末端生效，每枚停1拍。红、蓝、绿必须恰在第8、10、12拍亮灯；每路最多3枚，全关最多3枚。"
	][level]

static func evaluate(level: int, routes: Array, coils: Array, limit := -1) -> Dictionary:
	var invalid:={"ok":false,"valid_input":false,"times":[],"gate_times":[],"blocked_lanes":[],"used":0,"finish":0,"message":"线路配置无效，请复位后重试。"}
	if level<0 or level>2 or routes.size()!=count_(level) or coils.size()!=count_(level):return invalid
	for i in range(count_(level)):
		if not routes[i] is int or routes[i]<0 or routes[i]>2:return invalid
		if not coils[i] is int or coils[i]<0 or coils[i]>coil_limit(level):return invalid
	var times: Array[int]=[]
	var gates: Array[int]=[]
	var blocked: Array[bool]=[]
	var used:=0
	for i in range(count_(level)):
		used+=coils[i]
		times.append(arrival(level,i,routes[i],coils[i]))
		if level==1:
			gates.append(approach_length(i,routes[i])+coils[i])
			blocked.append(gates[i]!=BRIDGE_WINDOWS[i])
	var cap:=budget(level) if limit<0 else mini(budget(level),maxi(0,limit))
	var ok:=used<=cap
	var message:=""
	if used>cap:message="线圈超过预算：%d / %d。"%[used,cap]
	elif level==0:
		ok=times[0]==times[1]
		message="两盏终点灯同步点亮。" if ok else "到达时间不同：红%d拍，蓝%d拍。调整绕路或线圈。"%[times[0],times[1]]
	elif level==1:
		var clear:=gates[1]>=gates[0]+BRIDGE_TRAVEL+BRIDGE_COOLDOWN
		ok=gates==BRIDGE_WINDOWS and clear
		if not clear:
			blocked[1]=true
			message="窄桥冲突：过桥用2拍，还要空出1拍。蓝球过早进入。"
		elif not ok:message="准入窗口不符：红在%d拍、蓝在%d拍到桥；应分别在4拍、7拍，桥口不能等待。"%[gates[0],gates[1]]
		else:message="红球4拍入桥、6拍出桥；7拍蓝球入桥，完成分时通行。"
	else:
		ok=times==CLOCK_WINDOWS
		if ok:message="三盏灯恰在8、10、12拍依次响应主时钟。"
		else:message="时钟窗口未对齐：当前红%d、蓝%d、绿%d拍；要求8、10、12拍。蓝球最后不足4节点也要走满1拍。"%[times[0],times[1],times[2]]
	return {"ok":ok,"valid_input":true,"times":times,"gate_times":gates,"blocked_lanes":blocked,"used":used,"message":message,"finish":times.max()}

static func all_solutions(level: int, limit := -1) -> Array:
	var found: Array=[]
	if level<0 or level>2:return found
	var n:=count_(level)
	var base:=coil_limit(level)+1
	for code in range(int(pow(3,n))):
		var routes: Array=[]
		var route_code:=code
		for i in range(n):
			routes.append(route_code%3);route_code=int(route_code/3)
		for delays in range(int(pow(base,n))):
			var coils: Array=[]
			var delay_code:=delays
			for i in range(n):
				coils.append(delay_code%base);delay_code=int(delay_code/base)
			var result:=evaluate(level,routes,coils,limit)
			if result.ok:found.append({"routes":routes.duplicate(),"coils":coils.duplicate()})
	return found

static func solution(level: int, limit := -1) -> Dictionary:
	var best: Dictionary={}
	var score:=2147483647
	for answer in all_solutions(level,limit):
		var cost: int=answer.coils.reduce(func(a,b):return a+b,0)*100+answer.routes.reduce(func(a,b):return a+b,0)
		if cost<score:best=answer;score=cost
	return best

static func path(level: int, lane: int, route: int) -> PackedVector2Array:
	var result:=PackedVector2Array()
	var row:=lane*3.0
	if level==1:
		var count:=approach_length(lane,route)
		for i in range(count+1):
			var u:=float(i)/count
			result.append(Vector2(.4+5.6*u,lerpf(row,1.5,u)+sin(u*PI)*route*(-.65 if lane==0 else .65)))
		result.append(Vector2(7,1.5));result.append(Vector2(8,1.5));result.append(Vector2(9,row))
		return result
	for i in range(length_(level,lane,route)+1):
		var x: float=i if i<3 else 3+(i-3)%6 if int((i-3)/6)%2==0 else 8-(i-3)%6
		var y: float=row if i<3 else row+floorf((i-3)/6.0)*.55
		result.append(Vector2(x,y))
	return result
