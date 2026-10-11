extends StaticBody3D
## QuestPickup（任务物品拾取物）
## 职责：固定位置的可交互任务物品（如猎人日记）；拾取后放入「任务物品」
## 独立收纳并消失；同时通知任务系统（collect 事件）。

## 任务物品 id
@export var item_id := "hunter_diary"
## 显示名
@export var display_name := "猎人的日记"

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)


func _on_interacted(player: Node) -> void:
	var player_controller := player as PlayerController
	if player_controller == null:
		return
	player_controller.survivor.add_experience(16)
	player_controller.show_combat_feedback("发现 %s · 获得16经验" % display_name, Color(1.0, 0.9, 0.6))
	queue_free()
