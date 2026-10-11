class_name Interactable
extends Area3D
## Interactable（可交互组件）
## 职责：挂在 interact_area（物理第 5 层）的 Area3D 上，供玩家交互射线检测；
## 玩家按交互键时调用 interact(player)，并把事件转发为 interacted 信号。

signal interacted(player)

## 交互提示文本（显示为「按 E <interact_text>」）
@export var interact_text := "交互"


func _ready() -> void:
	add_to_group("interactable")
	# 自动配置到 interact_area 层，场景里无需手动设置
	collision_layer = 1 << 4
	collision_mask = 0


## 由玩家控制器调用。
func interact(player: Node) -> void:
	interacted.emit(player)
