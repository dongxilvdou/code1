extends RefCounted
## Fixed, save-versioned layouts; no random board generation during play.
const DIRECTIONS=[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const BOOK_COUNT=7
const BOOK_GOAL=[2,4,0,6,3,1,5]
const BOOK_INITIAL=[0,5,2,1,6,4,3]
const BOOK_SCALES=[1.0,.74,1.22,.86,1.12,.65,.94]
const BOOK_NAMES=["园艺","日记","图鉴","气象","植物","随笔","诗集"]
const BOOK_COLORS=[Color("a55f51"),Color("4b7687"),Color("b29854"),Color("667959"),Color("92674e"),Color("576179"),Color("846a85")]
static func book_x(slot: int) -> float:return -.258+slot*.086
const PIPE_ENDS=[[3,1],[3,2],[2,1],[3,1],[3,2],[1,2],[0,3],[1,0],[2,3],[0,2],[0,2],[2,1],[3,2],[2,0],[0,2],[0,1],[3,0],[0,1],[3,0],[0,1]]
const FIXED=[1,7,12,18]
const CHECKPOINTS=[7,12]
static func initial_pipes() -> Array:
 var result=[]
 for i in range(20):result.append(0 if i in FIXED else (i+1)%4)
 return result
static func pipe_ends(i: int,rotations: Array) -> Array:
 var rotation=0 if i in FIXED else int(rotations[i])
 return [(PIPE_ENDS[i][0]+rotation)%4,(PIPE_ENDS[i][1]+rotation)%4]
static func water(rotations: Array) -> Dictionary:
 var wet=[];var leaks=[];var pending=[]
 if rotations.size()!=20:return {"wet":wet,"leaks":leaks,"passed":false}
 if pipe_ends(0,rotations).has(3):pending.append(0)
 while not pending.is_empty():
  var i: int=pending.pop_front()
  if i in wet:continue
  wet.append(i)
  for direction in pipe_ends(i,rotations):
   if (i==0 and direction==3) or (i==19 and direction==1):continue
   var point=Vector2i(i%5,i/5)+DIRECTIONS[direction]
   if point.x<0 or point.x>=5 or point.y<0 or point.y>=4:
    if i not in leaks:leaks.append(i)
    continue
   var other=point.y*5+point.x
   if not pipe_ends(other,rotations).has((direction+2)%4):
    if i not in leaks:leaks.append(i)
   elif other not in wet:pending.append(other)
 var passed=19 in wet and pipe_ends(19,rotations).has(1) and leaks.is_empty()
 for checkpoint in CHECKPOINTS:passed=passed and checkpoint in wet
 return {"wet":wet,"leaks":leaks,"passed":passed}
