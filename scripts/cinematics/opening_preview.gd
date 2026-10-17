extends Node
## F6 preview uses the actual map and player, with task saving disabled.
func _ready() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	game.opening_preview_on_ready = true
	add_child(game)
