class_name PlayerStats
extends Node
## PlayerStats（玩家状态组件）
## 职责：保存玩家的生命、护盾、专注（职业技能资源）、护甲、等级与经验数据，
## 并通过信号通知 UI 更新。只处理数据，不处理表现与战斗判定。

signal health_changed(current: float, maximum: float)
signal focus_changed(current: float, maximum: float)
signal died
signal level_up(new_level: int)

@export var max_health := 100.0
@export var max_focus := 100.0
## 专注值每秒恢复量
@export var focus_regen := 5.0
## 护甲（减伤公式：护甲/(护甲+50)，递减收益）
@export var armor := 0.0
@export var level := 1
@export var exp := 0
## 升到下一级所需基础经验
@export var exp_base := 100
## 每级经验需求增长倍率
@export var exp_growth := 1.5

var current_health := 0.0
var current_focus := 0.0
## 护盾值（先于生命被伤害消耗，由精灵等效果给予）
var shield := 0.0


func _ready() -> void:
	current_health = max_health
	current_focus = max_focus


func _process(delta: float) -> void:
	if current_focus >= max_focus:
		return
	current_focus = minf(current_focus + focus_regen * delta, max_focus)
	focus_changed.emit(current_focus, max_focus)


## 应用职业基础属性并回满生命/专注（开新局或战斗初始化时调用）。
func apply_class_data(class_data: ClassData) -> void:
	max_health = class_data.max_health
	max_focus = class_data.max_focus
	focus_regen = class_data.focus_regen
	armor = class_data.armor
	current_health = max_health
	current_focus = max_focus
	shield = 0.0
	health_changed.emit(current_health, max_health)
	focus_changed.emit(current_focus, max_focus)


## 受到伤害；生命归零时发出 died 信号。
func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()


## 恢复生命（不超过上限）。
func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


## 消耗专注值；不足时返回 false 且不消耗。
func use_focus(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_focus < amount:
		return false
	current_focus -= amount
	focus_changed.emit(current_focus, max_focus)
	return true


## 增加护盾（同一时间只保留一层，取较大值）。
func add_shield(amount: float) -> void:
	shield = maxf(shield, amount)


## 清除护盾。
func clear_shield() -> void:
	shield = 0.0


## 用护盾吸收伤害，返回剩余未被吸收的伤害。
func absorb_with_shield(amount: float) -> float:
	if shield <= 0.0 or amount <= 0.0:
		return amount
	var absorbed := minf(shield, amount)
	shield -= absorbed
	return amount - absorbed


## 增加经验；满足需求时自动升级（可连续升级）。
func add_exp(amount: int) -> void:
	if amount <= 0:
		return
	exp += amount
	while exp >= get_exp_to_next_level():
		exp -= get_exp_to_next_level()
		level += 1
		level_up.emit(level)


## 当前等级升到下一级所需经验。
func get_exp_to_next_level() -> int:
	return int(round(exp_base * pow(exp_growth, level - 1)))
