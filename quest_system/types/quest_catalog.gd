class_name CalicoQuestCatalog
extends Resource
## 所有可用任务必须加入这里；显式引用也保证导出包包含任务资源。
@export var quests: Array[CalicoQuest] = []
