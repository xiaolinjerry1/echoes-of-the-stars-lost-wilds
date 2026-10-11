extends Area3D
## QuestArea（任务区域触发器）
## 职责：玩家进入区域时自动推进「探索/抵达」类任务目标；同时作为任务标记点
## （group: quest_marker + meta quest_marker_id），供 HUD 方向指示使用。
## 注：本区域不属于 death_zone 组，不会触发死亡区回位。

## 区域 id（与任务目标 target_id 对应）
@export var area_id := "area"
## 推进的目标类型（默认 explore）
@export var quest_objective_type := "explore"


func _ready() -> void:
	collision_layer = 64  # environment_trigger
	collision_mask = 2    # 只感应玩家
	if not is_in_group("quest_marker"):
		add_to_group("quest_marker")
	set_meta("quest_marker_id", area_id)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	if quest_manager != null:
		quest_manager.notify_event(quest_objective_type, area_id, 1)
