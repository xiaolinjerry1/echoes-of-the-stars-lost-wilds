extends "res://dev/verify_boot.gd".Runner
## 独立重跑现有五任务回归，定位角色美术接入后的任务时序问题。
func _run() -> void:
	await get_tree().process_frame
	await _verify_quests()
	_finish()
