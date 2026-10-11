class_name StatusEffects
extends RefCounted
## StatusEffects（状态效果常量表）
## 职责：集中定义所有状态效果 id、中文名与简要说明，供技能/战斗系统引用。

const FROZEN := "frozen"
const CHILLED := "chilled"
const BURNING := "burning"
const WET := "wet"
const MARKED := "marked"
const STUN := "stun"
const ROOTED := "rooted"

## id → 中文名
const DISPLAY_NAMES := {
	FROZEN: "冻结",
	CHILLED: "寒意",
	BURNING: "灼烧",
	WET: "潮湿",
	MARKED: "标记",
	STUN: "眩晕",
	ROOTED: "根须束缚",
}

## id → 效果说明
const DESCRIPTIONS := {
	FROZEN: "无法移动和攻击，受到重击触发碎冰",
	CHILLED: "移动速度 -30%，攻击速度 -20%",
	BURNING: "每秒受到伤害",
	WET: "受到雷电伤害时触发电弧扩散",
	MARKED: "受到精准命中伤害 +30%",
	STUN: "无法移动和攻击",
	ROOTED: "短暂无法移动，仍可攻击和格挡",
}


## 是否为合法的状态效果 id。
static func is_valid(effect_id: String) -> bool:
	return DISPLAY_NAMES.has(effect_id)
