extends RefCounted
## A fixed Arrow Out layout. Cells run from tail to head; the head ray must be clear.
## Removing a thread only removes obstacles, so every legal choice stays solvable.
const WIDTH=26
const HEIGHT=30
const VERSION=3
const DIRECTIONS=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
const THREADS=[
 {"cells":[45,46,20,21,47,48,22],"direction":0},
 {"cells":[430,456,482,508,534,535,509,510,536,562,588,614,613,612,638,639,640,641,615,616,617,643,669,670,671,672,673,674,648,622,623,597,571,545,519,493,467,441,415,389,363,337,311,285,259,233,207,181,155,129,103,102,101,100,74],"direction":0},
 {"cells":[336,362,361,360,386,387,388],"direction":1},
 {"cells":[325,351,352,353,354,355,356,357,331,332,333,359,358,384,385],"direction":1},
 {"cells":[278,277,276,275,274,273,272,298,324,323,349,350],"direction":1},
 {"cells":[318,319,345,346,347,348],"direction":1},
 {"cells":[131,157,183,182,208,234,260,286,287,313,339,340,341,342,343,344],"direction":1},
 {"cells":[5,6,7,8,9,35,36,10,11,12,13,14,15,16,17,43,69,95,96,70,71,97,123,149,148,147,173,199,200,226,252,253,254,255,229,203,177,178,179,180],"direction":1},
 {"cells":[80,79,105,106,132,158,184,210,209],"direction":3},
 {"cells":[262,261,235,236,237,211,212,213,187,186,185],"direction":3},
 {"cells":[239,238,264,265,291,292,293,267,241,215,214],"direction":3},
 {"cells":[194,193,219,218,217,216],"direction":3},
 {"cells":[322,321,295,296,270,244,245,246,247,221,220],"direction":3},
 {"cells":[377,376,375,374,373,372,398,424,450,476,502,501,475,474,500,526,527,528,529,503,504,530,556,555,554,553,552,551,577,603,602,628,627,601,600,626,625,624],"direction":3},
 {"cells":[163,164,165,166,192,191,190,189,188],"direction":3},
 {"cells":[225,251,250,249,248,222,196,195],"direction":3},
 {"cells":[120,146,172,198,224,223],"direction":3},
 {"cells":[124,98,72,73,99,125,151,150,176,202,228,227],"direction":3},
 {"cells":[204,205,231,230],"direction":3},
 {"cells":[159,160,161,162,136,110,84,83,109,135,134,133,107,81,55,56,57,58,59,60,61,62,63,64,65,66,67,93,94],"direction":1},
 {"cells":[114,88,89,90,91,92],"direction":1},
 {"cells":[141,140,139,138,137,111,85,86,87],"direction":1},
 {"cells":[451,477,478,452,426,400],"direction":0},
 {"cells":[712,686,685,659,633,607,608,582],"direction":0},
 {"cells":[770,769,743,742,716,690,664,663,662,661,660,634],"direction":0},
 {"cells":[637,611,585,586,587,561,560,559,533,532,558,584,610,636,635,609,583,557,531,505,506,507,481,480,454,428,402,403,404,378,379,405,431,457,483,484,485,459,458,432,406,380,381,382,383],"direction":1},
 {"cells":[777,751,725,724,698,697,696,722,721,695,694,693,692,691,717],"direction":2},
 {"cells":[759,760,761,762,763,764,738],"direction":0},
 {"cells":[728,702,676,650,651,652,653,654,655,656,682,708,709,710,711,737],"direction":2},
 {"cells":[678,679,680,681,707,706,732,758,757,756,730,729],"direction":3},
 {"cells":[498,472,446,420,419,445,471,497,523,524,550,576],"direction":2},
 {"cells":[621,647,646,620,594,595,596,570,569,568,567,541,515,514,540,539,565,591,590,589,563,564,538,537,511,512,486,460,461,462,463,464,490,516,542,543,544],"direction":1},
 {"cells":[417,391,392,393,367,368,394],"direction":2},
 {"cells":[750,776,775,774,748,747,773,772,746,720,719,718,744],"direction":2},
 {"cells":[439,465,466,440,414,413,412,438],"direction":2},
 {"cells":[411,410,409,408,407,433,434,435,436,437],"direction":1},
 {"cells":[335,309,283,257,256,282,308,334],"direction":2},
 {"cells":[153,154,128,127,126,152],"direction":2},
 {"cells":[167,168,142,143,144,145],"direction":1},
 {"cells":[677,703,704,705,731],"direction":2},
 {"cells":[468,469,495,521,547,546,572,598,599,573,574,548,549,575],"direction":2},
 {"cells":[581,580,606,632,658,684,683,657,631,605,604],"direction":3},
 {"cells":[768,767,766,740,714,688,687],"direction":3},
 {"cells":[306,307,281,280,279,305,304,330,329,303,302,301,300,326],"direction":2},
 {"cells":[642,668,667,666,665],"direction":3},
 {"cells":[644,645,619,618],"direction":3},
 {"cells":[327,328],"direction":1},
 {"cells":[37,38,39,40,41,42,68],"direction":2},
 {"cells":[169,170,171,197],"direction":2},
 {"cells":[418,444,470,496,522],"direction":2},
 {"cells":[399,425],"direction":2},
 {"cells":[320,294,268,242,243,269],"direction":2},
 {"cells":[689,715,741],"direction":2},
 {"cells":[649,675,701,700,699],"direction":3},
 {"cells":[518,492,491,517],"direction":2},
 {"cells":[50,76,77,51,25,24,23,49,75],"direction":2},
 {"cells":[52,26,0,1,27,53,54],"direction":1},
 {"cells":[34,33,32,31,30,29,28],"direction":3},
 {"cells":[525,499,473,447,421,395,396,422,448,449,423,397,371],"direction":0},
 {"cells":[369,370],"direction":1},
 {"cells":[443,442,416,390,364,365,366],"direction":1},
 {"cells":[310,284,258,232,206],"direction":0},
 {"cells":[727,753,779,778,752,726],"direction":0},
 {"cells":[263,289,288,314],"direction":2},
 {"cells":[513,487,488,489],"direction":1},
 {"cells":[266,240],"direction":0},
 {"cells":[174,175,201],"direction":2},
 {"cells":[593,592,566],"direction":0},
 {"cells":[578,579],"direction":1},
 {"cells":[156,130,104,78],"direction":0},
 {"cells":[749,723],"direction":0},
 {"cells":[338,312],"direction":0},
 {"cells":[520,494],"direction":0},
 {"cells":[290,316,315],"direction":3},
 {"cells":[82,108],"direction":2},
 {"cells":[113,112],"direction":3},
 {"cells":[119,118,117,116,115],"direction":3},
 {"cells":[122,121],"direction":3},
 {"cells":[19,18,44],"direction":2},
 {"cells":[2,3,4],"direction":1},
 {"cells":[771,745],"direction":0},
 {"cells":[297,271],"direction":0},
 {"cells":[479,453,427,401],"direction":0},
 {"cells":[765,739,713],"direction":0},
 {"cells":[733,734,735,736],"direction":1},
 {"cells":[754,755],"direction":1},
 {"cells":[629,630],"direction":1},
 {"cells":[429,455],"direction":2}]
var owners: PackedInt32Array=[]
var rays: Array=[]
func _init() -> void:
 owners.resize(WIDTH*HEIGHT);owners.fill(-1)
 for i in range(THREADS.size()):
  for cell in THREADS[i].cells:owners[cell]=i
  var cells: Array=[]
  var head: int=THREADS[i].cells[-1]
  var p=Vector2i(head%WIDTH,head/WIDTH)+DIRECTIONS[THREADS[i].direction]
  while p.x>=0 and p.x<WIDTH and p.y>=0 and p.y<HEIGHT:
   cells.append(p.y*WIDTH+p.x);p+=DIRECTIONS[THREADS[i].direction]
  rays.append(cells)
func thread_at(cell: int,removed: Dictionary) -> int:
 if cell<0 or cell>=owners.size():return -1
 var id=owners[cell]
 return -1 if removed.has(id) else id
func blocking_cell(id: int,removed: Dictionary) -> int:
 if id<0 or id>=THREADS.size() or removed.has(id):return -1
 for cell in rays[id]:
  if owners[cell]>=0 and not removed.has(owners[cell]):return cell
 return -1
func blocker(id: int,removed: Dictionary) -> int:
 var cell=blocking_cell(id,removed)
 return owners[cell] if cell>=0 else -1
func legal_moves(removed: Dictionary) -> Array[int]:
 var result: Array[int]=[]
 for i in range(THREADS.size()):
  if not removed.has(i) and blocker(i,removed)<0:result.append(i)
 return result
