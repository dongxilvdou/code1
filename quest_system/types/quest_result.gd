class_name CalicoQuestResult
extends Resource
enum Kind { SET_FLAG, ADD_VALUE, EMIT_EVENT }
@export var kind: Kind = Kind.SET_FLAG
@export var key: StringName
@export var flag_value := true
@export var amount := 1
