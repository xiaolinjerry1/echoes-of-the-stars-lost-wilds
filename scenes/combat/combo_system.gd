class_name ComboSystem
extends RefCounted
## ComboSystem（连招组合系统，纯静态工具类）
## 职责：在伤害结算时检测「目标状态效果 + 技能标签」的四类组合规则，
## 并施加减益/扩散效果；组合反馈（世界文字+音效）由 ComboNotifier 统一播放。
## 规则：碎冰（冻结+重击）/ 电弧扩散（潮湿+雷电）/ 火势扩散（灼烧+风）/
## 弱点暴击（标记+精准）。组合伤害不会再次触发组合；每个目标有 1 秒内置冷却。

const COMBO_SHATTER := "shatter"
const COMBO_ARC_SPREAD := "arc_spread"
const COMBO_FIRE_SPREAD := "fire_spread"
const COMBO_WEAKPOINT := "weakpoint"

const DISPLAY_NAMES := {
	COMBO_SHATTER: "碎冰",
	COMBO_ARC_SPREAD: "电弧扩散",
	COMBO_FIRE_SPREAD: "火势扩散",
	COMBO_WEAKPOINT: "弱点暴击",
}

const COLORS := {
	COMBO_SHATTER: Color(0.5, 0.85, 1.0),
	COMBO_ARC_SPREAD: Color(0.75, 0.9, 1.0),
	COMBO_FIRE_SPREAD: Color(1.0, 0.6, 0.25),
	COMBO_WEAKPOINT: Color(1.0, 0.85, 0.4),
}

## 组合触发内置冷却（毫秒，按目标计）
const COMBO_COOLDOWN_MS := 1000
## 扩散类组合的搜索半径与最大目标数
const SPREAD_RADIUS := 6.0
const SPREAD_MAX_TARGETS := 2
## 电弧扩散：对附近目标的伤害比例
const SPREAD_DAMAGE_RATIO := 0.5
## 碎冰 / 弱点暴击的伤害加成
const SHATTER_BONUS := 0.5
const WEAKPOINT_BONUS := 0.3

## 目标实例 id → 上次组合触发时间（毫秒）
static var _last_combo_time: Dictionary = {}


## 在伤害落点检测并应用组合。
## 返回 { "damage": float, "combos": Array }；无组合时原样返回。
static func apply_on_hit(skill: SkillData, target: Node, damage: float, attacker: Node = null) -> Dictionary:
	var result := {"damage": damage, "combos": []}
	if skill == null or target == null or not is_instance_valid(target):
		return result
	if not _can_trigger(target):
		return result
	var combos: Array = []
	var tags: Array[String] = skill.combat_tags

	if tags.has("heavy") and _has(target, StatusEffects.FROZEN):
		# 碎冰：附加 50% 伤害并清除冻结
		result["damage"] = damage * (1.0 + SHATTER_BONUS)
		_remove(target, StatusEffects.FROZEN)
		combos.append(COMBO_SHATTER)
		_spawn_combo_burst(target, COMBO_SHATTER, 28, 3.5)
	elif tags.has("lightning") and _has(target, StatusEffects.WET):
		# 电弧扩散：伤害扩散到附近最多 2 个目标
		_spread_damage(target, damage * SPREAD_DAMAGE_RATIO, attacker)
		combos.append(COMBO_ARC_SPREAD)
		_spawn_combo_burst(target, COMBO_ARC_SPREAD, 20, 3.0)
	elif tags.has("wind") and _has(target, StatusEffects.BURNING):
		# 火势扩散：灼烧扩散到附近最多 2 个目标
		_spread_burning(target, attacker)
		combos.append(COMBO_FIRE_SPREAD)
		_spawn_combo_burst(target, COMBO_FIRE_SPREAD, 20, 3.0)
	elif tags.has("precise") and _has(target, StatusEffects.MARKED):
		# 弱点暴击：额外 30% 伤害
		result["damage"] = damage * (1.0 + WEAKPOINT_BONUS)
		combos.append(COMBO_WEAKPOINT)
		_spawn_combo_burst(target, COMBO_WEAKPOINT, 16, 2.6)

	if combos.is_empty():
		return result
	_last_combo_time[target.get_instance_id()] = Time.get_ticks_msec()
	_cleanup_stale()
	result["combos"] = combos
	var parent := _resolve_parent(target, attacker)
	var position := _effect_position(target)
	for combo_name in combos:
		ComboNotifier.trigger_combo(combo_name, position, parent)
	# 任务系统：连招事件
	var tree := target.get_tree()
	if tree != null:
		var quest_manager := tree.get_first_node_in_group("quest_manager") as QuestManager
		if quest_manager != null:
			for combo_name in combos:
				quest_manager.notify_event("combo", combo_name, 1)
	return result


## 目标是否可触发组合（1 秒内置冷却）。
static func can_trigger_on(target: Node) -> bool:
	return _can_trigger(target)


## ---- 内部实现 ----

static func _can_trigger(target: Node) -> bool:
	var id := target.get_instance_id()
	if not _last_combo_time.has(id):
		return true
	return Time.get_ticks_msec() - int(_last_combo_time[id]) >= COMBO_COOLDOWN_MS


static func _cleanup_stale() -> void:
	if _last_combo_time.size() <= 64:
		return
	var now := Time.get_ticks_msec()
	for id in _last_combo_time.keys():
		if now - int(_last_combo_time[id]) > 10000:
			_last_combo_time.erase(id)


static func _has(target: Node, effect_id: String) -> bool:
	if not target.has_method("has_effect"):
		return false
	return bool(target.call("has_effect", effect_id))


static func _remove(target: Node, effect_id: String) -> void:
	if target.has_method("remove_effect"):
		target.call("remove_effect", effect_id)


## 电弧扩散：对目标附近最近的敌人造成部分伤害（不再触发组合）。
static func _spread_damage(target: Node, amount: float, attacker: Node) -> void:
	if not (target is Node3D):
		return
	var neighbors := _find_neighbors(target as Node3D)
	var parent := _resolve_parent(target, attacker)
	for neighbor in neighbors:
		if neighbor.has_method("take_damage"):
			neighbor.call("take_damage", amount)
		if neighbor is Node3D:
			var position: Vector3 = (neighbor as Node3D).global_position + Vector3.UP * 1.4
			DamageNumber.spawn(parent, position, amount, false, COLORS[COMBO_ARC_SPREAD])
			HitEffect.spawn_burst(parent, position - Vector3.UP * 0.4, COLORS[COMBO_ARC_SPREAD], 12, 2.6)


## 火势扩散：把目标身上的灼烧扩散给附近最近的敌人（沿用其 DPS）。
static func _spread_burning(target: Node, attacker: Node) -> void:
	if not (target is Node3D):
		return
	var power := 0.0
	if target.has_method("get_effect_power"):
		power = float(target.call("get_effect_power", StatusEffects.BURNING))
	var neighbors := _find_neighbors(target as Node3D)
	for neighbor in neighbors:
		if neighbor.has_method("apply_effect"):
			neighbor.call("apply_effect", StatusEffects.BURNING, 4.0, power, attacker)


## 目标附近最近的若干可战斗单位（不含目标自身）。
static func _find_neighbors(origin: Node3D) -> Array:
	var result: Array = []
	var found := TargetQuery.find_targets(origin, SPREAD_RADIUS)
	for candidate in found:
		if candidate == origin:
			continue
		result.append(candidate)
		if result.size() >= SPREAD_MAX_TARGETS:
			break
	return result


static func _resolve_parent(target: Node, attacker: Node) -> Node:
	if attacker != null and is_instance_valid(attacker) and attacker.is_inside_tree():
		var attacker_parent := attacker.get_parent()
		if attacker_parent != null:
			return attacker_parent
	if target.is_inside_tree():
		return target.get_parent()
	return target


static func _effect_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position + Vector3.UP * 1.2
	return Vector3.ZERO


static func _spawn_combo_burst(target: Node, combo_name: String, amount: int, speed: float) -> void:
	if not (target is Node3D) or not target.is_inside_tree():
		return
	var parent := target.get_parent()
	if parent == null:
		return
	var color: Color = COLORS.get(combo_name, Color.WHITE)
	HitEffect.spawn_burst(parent, (target as Node3D).global_position + Vector3.UP, color, amount, speed)
