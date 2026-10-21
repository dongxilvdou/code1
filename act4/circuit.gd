extends RefCounted
const NAMES := ["把路走齐", "中途汇流", "快慢球按序"]
const COLORS := [Color("e19b89"),Color("80c4df"),Color("afd097")]
static func count_(level: int) -> int:return 3 if level==2 else 2
static func budget(level: int) -> int:return 3 if level==2 else 4
static func length_(level: int, lane: int, route: int) -> int:
	if level==2:return [8,4,12][lane]+([0,8,20][route] if lane==1 else route*2)
	return [7,3][lane]+route*2
static func speed_(level: int, lane: int, distance_: int) -> int:
	return (2 if distance_<2 else 4) if level==2 and lane==1 else 1
static func arrival(level: int, lane: int, route: int, coils: int) -> int:
	var distance_ := 0
	var beats := coils
	while distance_<length_(level,lane,route):
		distance_ += speed_(level,lane,distance_)
		beats += 1
	return beats
static func evaluate(level: int, routes: Array, coils: Array, limit := -1) -> Dictionary:
	var times: Array[int] = []
	var used := 0
	for i in range(count_(level)):
		used += coils[i]
		times.append(arrival(level,i,routes[i],coils[i]))
	var cap := budget(level) if limit<0 else limit
	var ok: bool = used<=cap
	if level<2:ok = ok and times[0]==times[1]
	else:ok = ok and times[1]==times[0]+2 and times[2]==times[1]+2
	var text := ""
	if used>cap:text = "线圈超过预算：%d / %d。转动转向器，用绕路增加路程。"%[used,cap]
	elif level==1 and times[0]!=times[1]:text = "先到的小球停在汇流门等待区，另一球晚到；门已卡死。必须同一拍到门。"
	elif not ok:text = "小球没有踩准时刻。"+("让两球同时点亮终点灯。" if level==0 else "红 → 蓝 → 绿，每次间隔 2 拍。")
	else:text = "同步成功，两球共同前进两格。" if level==1 else "灯泡按要求点亮。"
	return {"ok":ok,"times":times,"used":used,"message":text,"finish":times.max()+(2 if level==1 else 0)}
static func solution(level: int, limit := -1) -> Dictionary:
	var best := {}
	var score := 999
	var n := count_(level)
	for code in range(27 if n==3 else 9):
		var routes: Array = [code%3,(code/3)%3,code/9]
		for delays in range(64 if n==3 else 25):
			var base := 4 if n==3 else 5
			var coils: Array = [delays%base,(delays/base)%base,delays/(base*base)]
			var result := evaluate(level,routes,coils,limit)
			var cost: int = result.used+routes.slice(0,n).reduce(func(a,b):return a+b,0)*2
			if result.ok and cost<score:
				best = {"routes":routes.slice(0,n),"coils":coils.slice(0,n)}
				score = cost
	return best
static func path(level: int, lane: int, route: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var length := length_(level,lane,route)
	var row := lane*3.0
	# A continuous serpentine wire makes the added detour cells visible.
	for i in range(length+1):
		var x: float = i if i<3 else 3+(i-3)%6 if ((i-3)/6)%2==0 else 8-(i-3)%6
		var y: float = row if i<3 else row+floorf((i-3)/6.0)*.55
		result.append(Vector2(x,y))
	return result
