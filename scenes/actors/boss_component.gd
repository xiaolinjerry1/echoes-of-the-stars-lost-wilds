class_name BossComponent
extends Node
## BossComponent（BOSS 抗控/失衡组件）
## 职责：BOSS 不接受无限控制（冻结/眩晕/击退），改为积累失衡值；
## 失衡值满 → 进入「破绽」：受到伤害 +30%、无法行动，持续数秒；
## 破绽结束清空失衡并进入短暂免疫期。由 BOSS 的 apply_effect / 攻击逻辑调用。

signal stagger_changed(current: float, maximum: float)
signal staggering_started
signal staggering_ended

@export_group("失衡")
## 失衡值上限
@export var stagger_max := 100.0
## 冻结一次积累的失衡值
@export var freeze_gain := 40.0
## 眩晕一次积累的失衡值
@export var stun_gain := 30.0
## 击退一次积累的失衡值
@export var knockback_gain := 30.0

@export_group("破绽与免疫")
## 破绽持续时间（秒）
@export var stagger_duration := 6.0
## 破绽结束后的控制免疫时间（秒）
@export var immunity_duration := 5.0
## 破绽期间承受伤害加成
@export var break_damage_taken_bonus := 0.3

## 当前失衡值
var stagger_value := 0.0

var _stagger_time_left := 0.0
var _immunity_time_left := 0.0


func _process(delta: float) -> void:
	if _stagger_time_left > 0.0:
		_stagger_time_left -= delta
		if _stagger_time_left <= 0.0:
			staggering_ended.emit()
			stagger_value = 0.0
			stagger_changed.emit(stagger_value, stagger_max)
			_immunity_time_left = immunity_duration
			_show_status_text("破绽结束", Color(0.7, 0.75, 0.85))
	if _immunity_time_left > 0.0:
		_immunity_time_left -= delta


## 控制效果入口：返回 true 表示已拦截（转为失衡积累，不施加控制）。
func intercept_control(effect_id: String, _source: Node = null) -> bool:
	if _stagger_time_left > 0.0 or _immunity_time_left > 0.0:
		return true  # 破绽中 / 免疫期：直接免疫控制
	var gain := 0.0
	match effect_id:
		StatusEffects.FROZEN:
			gain = freeze_gain
		StatusEffects.STUN:
			gain = stun_gain
		"knockback":
			gain = knockback_gain
		_:
			return false
	add_stagger(gain)
	return true


## 直接积累失衡值（供击退等非状态控制调用）。
func add_stagger(amount: float) -> void:
	if amount <= 0.0 or _stagger_time_left > 0.0 or _immunity_time_left > 0.0:
		return
	stagger_value = minf(stagger_value + amount, stagger_max)
	stagger_changed.emit(stagger_value, stagger_max)
	_show_status_text("失衡 +%d（%d/%d）" % [int(amount), int(stagger_value), int(stagger_max)], Color(0.9, 0.8, 0.5))
	if stagger_value >= stagger_max:
		_start_stagger()


## 是否处于破绽（无法行动，承受伤害增加）。
func is_staggered() -> bool:
	return _stagger_time_left > 0.0


## 破绽剩余时间（秒）。
func get_stagger_time_left() -> float:
	return maxf(_stagger_time_left, 0.0)


## 是否处于破绽后的控制免疫期。
func is_control_immune() -> bool:
	return _immunity_time_left > 0.0


## 破绽期间目标承受伤害倍率（正常 1.0，破绽 1.3）。
func get_incoming_damage_multiplier() -> float:
	if is_staggered():
		return 1.0 + break_damage_taken_bonus
	return 1.0


## ---- 内部实现 ----

func _start_stagger() -> void:
	_stagger_time_left = stagger_duration
	staggering_started.emit()
	_show_status_text("破绽！", Color(1.0, 0.6, 0.3))
	ComboNotifier.play_beep(_resolve_parent(), _effect_position(), 320.0)


func _show_status_text(text: String, color: Color) -> void:
	ComboNotifier.show_text(_resolve_parent(), _effect_position() + Vector3.UP * 0.8, text, color, 44)


func _resolve_parent() -> Node:
	var owner_node := get_parent()
	if owner_node == null:
		return null
	var parent := owner_node.get_parent()
	return parent if parent != null else owner_node


func _effect_position() -> Vector3:
	var owner_node := get_parent()
	if owner_node is Node3D:
		return (owner_node as Node3D).global_position + Vector3.UP * 2.2
	return Vector3.ZERO
