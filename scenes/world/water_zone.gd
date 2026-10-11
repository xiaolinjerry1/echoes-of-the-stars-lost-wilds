extends Area3D
## WaterZone（浅水潮湿触发区）
## 职责：玩家进入溪流/水塘时施加 wet 状态，停留期间持续刷新。

const REFRESH_INTERVAL := 2.0

var _refresh_timer := 0.0


func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = REFRESH_INTERVAL
	for body in get_overlapping_bodies():
		_apply_wet(body)


func _on_body_entered(body: Node3D) -> void:
	_apply_wet(body)


func _apply_wet(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("apply_effect"):
		body.call("apply_effect", StatusEffects.WET, 6.0, 1.0)
