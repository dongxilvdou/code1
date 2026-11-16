extends RefCounted
const FULL := 65535

static func toggle_mask(cell: int) -> int:
	var mask := 1<<cell
	for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var p: Vector2i = Vector2i(cell%4,cell/4)+d
		if p.x>=0 and p.x<4 and p.y>=0 and p.y<4:mask |= 1<<(p.y*4+p.x)
	return mask

static func solution(state: int) -> Array[int]:
	# GF(2) elimination solves the actual current board, including repeated moves.
	var rows: Array[int] = []
	for i in range(16):rows.append(toggle_mask(i) | ((((FULL^state)>>i)&1)<<16))
	var pivots: Array[int] = []
	var rank := 0
	for col in range(16):
		var found := -1
		for r in range(rank,16):
			if rows[r] & (1<<col):
				found = r
				break
		if found<0:continue
		var saved := rows[rank]
		rows[rank] = rows[found]
		rows[found] = saved
		for r in range(16):
			if r!=rank and rows[r] & (1<<col):rows[r] ^= rows[rank]
		pivots.append(col)
		rank += 1
	for r in range(rank,16):
		if rows[r] & (1<<16):return []
	var free: Array[int] = []
	for i in range(16):
		if not pivots.has(i):free.append(i)
	var best: Array[int] = []
	var best_count := 17
	for option in range(1<<free.size()):
		var presses := 0
		for i in range(free.size()):
			if option & (1<<i):presses |= 1<<free[i]
		for r in range(rank):
			var parity := (rows[r]>>16)&1
			for col in free:
				if rows[r] & presses & (1<<col):parity ^= 1
			if parity:presses |= 1<<pivots[r]
		var candidate: Array[int] = []
		for i in range(16):
			if presses & (1<<i):candidate.append(i)
		if candidate.size()<best_count:
			best = candidate
			best_count = candidate.size()
	return best
