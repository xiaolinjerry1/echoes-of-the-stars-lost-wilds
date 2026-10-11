class_name DamageCalculator
extends RefCounted
## DamageCalculator（伤害结算工具，纯静态类）
## 职责：战斗伤害统一公式——基础伤害 + 攻击强度×系数，再经增伤乘区、
## 暴击、目标护甲减伤（护甲/(护甲+50)，递减收益）；最低 1 点伤害。

const ARMOR_CONSTANT := 50.0
const DEFAULT_CRIT_MULTIPLIER := 1.5


## 计算一次命中伤害。
static func calculate_damage(skill_data: SkillData, attacker_power: float, target_stats: Variant = null, is_crit := false, damage_multiplier := 1.0) -> float:
	var base := skill_data.damage_base + attacker_power * skill_data.damage_coefficient
	var crit_multiplier := DEFAULT_CRIT_MULTIPLIER if is_crit else 1.0
	var armor := get_armor(target_stats)
	var final := base * damage_multiplier * crit_multiplier * (1.0 - get_armor_reduction(armor))
	return maxf(1.0, final)


## 护甲减伤比例（递减收益）。
static func get_armor_reduction(armor: float) -> float:
	if armor <= 0.0:
		return 0.0
	return armor / (armor + ARMOR_CONSTANT)


## 对原始伤害应用护甲减伤（敌人攻击玩家的统一入口）。
static func apply_armor(amount: float, armor: float) -> float:
	return amount * (1.0 - get_armor_reduction(maxf(armor, 0.0)))


## 从目标对象上安全读取护甲值（无该属性则视为 0）。
static func get_armor(target_stats: Variant) -> float:
	if target_stats is Object:
		var value: Variant = (target_stats as Object).get("armor")
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			return maxf(float(value), 0.0)
	return 0.0
