class_name CalicoQuestObjective
extends Resource
enum Kind { ENTER_ROOM, MEOW, OPEN_DOOR, CUSTOM }
## 在同一个任务内唯一；存档后不要更改。
@export var id: StringName
@export_multiline var text: String
@export var kind: Kind = Kind.ENTER_ROOM
## ENTER_ROOM 使用本字段。any 表示任意房间。
@export_enum("any", "floor_1/living", "floor_1/dining", "floor_1/kitchen", "floor_1/guest", "floor_1/bathroom", "floor_1/laundry", "floor_1/hall", "floor_2/master", "floor_2/bedroom_a", "floor_2/bedroom_b", "floor_2/study", "floor_2/bathroom", "floor_2/dressing", "floor_2/reading", "floor_2/terrace", "floor_2/hall", "stairs/any", "garden/any", "garden/north", "garden/south", "garden/west", "garden/east") var room_id := "any"
## OPEN_DOOR 可填门节点名，CUSTOM 填事件 ID；留空匹配该类型的任意对象。
@export var target_id: StringName
@export_range(1, 9999, 1) var target_count := 1
