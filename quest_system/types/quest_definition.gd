class_name CalicoQuest
extends Resource
enum MatchMode { ALL, ANY }
## 全部任务中唯一；资源文件可改名，但发布存档后不要更改此 ID。
@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var main_quest := true
@export var priority := 0
@export var auto_accept := true
@export_group("前置条件")
@export var prerequisite_mode: MatchMode = MatchMode.ALL
## 将已有任务 .tres 拖入数组。禁止自引用或循环依赖。
@export var prerequisite_quests: Array[CalicoQuest] = []
@export var extra_conditions: Array[CalicoQuestCondition] = []
@export_group("任务内容")
@export var objectives: Array[CalicoQuestObjective] = []
@export_group("任务结果")
@export_multiline var result_text: String
@export var success_results: Array[CalicoQuestResult] = []
@export var failure_results: Array[CalicoQuestResult] = []
