class_name CalicoQuestCondition
extends Resource
## 接取任务时检查的额外条件；所有额外条件必须满足。
enum Kind { FLAG_EQUALS, VALUE_AT_LEAST }
@export var kind: Kind = Kind.FLAG_EQUALS
## 标记或数值的固定 ID，例如 garden_unlocked、exploration_points。
@export var key: StringName
@export var expected_flag := true
@export var required_value := 1
