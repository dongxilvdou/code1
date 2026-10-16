@tool
extends Node3D
## Small reusable room sign; +Z is the readable side and the origin is its base.
@export var room_title := "书房":
	set(value):
		room_title = value
		if is_node_ready():$Title.text = value

func _ready() -> void:
	$Title.text = room_title
