extends "res://story_branches/film_base.gd"

func _begin() -> void:
	caption.text="实验出错\n请前往地下室修复实验\n\n夜间自动复核发现转移装置异常。生命维持回路独立。"

func _tick(_delta: float) -> void:
	if clock>=3:complete()

func complete() -> void:
	if finished:return
	resume()
	if not chapter.state.patch({"br_day11_alert_received":true},{"br_day11_intro_state":2}):
		ask("警报目标尚未保存。\n"+chapter.state.last_error,[["重试",complete]]);return
	finished=true;release();chapter.state.busy=false;chapter.alert.intro=null;queue_free()

func skip() -> void:complete()
