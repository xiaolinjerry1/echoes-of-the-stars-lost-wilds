class_name DamageNumber
extends Label3D
## DamageNumber（伤害飘字）
## 职责：在受击位置生成伤害数字，向上漂浮并淡出后自动释放。

const LIFETIME := 0.9
const RISE := 1.2


## 在 parent 下生成飘字（world_position 为世界坐标）。
## kind: "damage" 白 / "crit" 黄大 / "heal" 绿 / "combo" 青
static func spawn(parent: Node, world_position: Vector3, amount: float, is_crit := false, color := Color(1.0, 0.95, 0.8), kind := "damage") -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var label := DamageNumber.new()
	var font := 48
	var text_color := color
	match kind:
		"heal":
			label.text = "+%.0f" % roundf(amount)
			text_color = Color(0.45, 1.0, 0.5)
			font = 44
		"combo":
			label.text = "%.0f" % roundf(amount)
			text_color = Color(0.45, 0.95, 1.0)
			font = 54
		_:
			if is_crit:
				label.text = "%.0f!" % roundf(amount)
				text_color = Color(1.0, 0.9, 0.25)
				font = 62
			else:
				label.text = "%.0f" % roundf(amount)
	label.modulate = text_color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = font
	label.pixel_size = 0.004
	label.outline_size = 16
	label.outline_modulate = Color(0, 0, 0, 0.75)
	parent.add_child(label)
	label.global_position = world_position
	var lifetime := 1.0 if kind != "damage" else LIFETIME
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", world_position + Vector3.UP * RISE, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, lifetime).set_delay(0.25)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)
