class_name LootTables
extends RefCounted
## LootTables（掉落表定义）
## 掉落结构：「必得 + 独立装备抽取 + 独立材料抽取 + 精英额外抽取」，互不挤占，
## 不做把所有奖励塞进一次互斥抽奖的设计。

const LOOT_TABLES := {
	"boss_wyvern": {
		"guaranteed": [
			{"type": "gold", "min": 60, "max": 90},
			{"type": "echo_material", "amount": 4},
			{"type": "equipment", "pool": ["frost_edge", "guardian_gloves", "iron_chest"]},
		],
	},
	"normal_forest_enemy": {
		"guaranteed": [{"type": "gold", "min": 3, "max": 8}],
		"equipment_chance": 0.20,
		"equipment_pool": ["rusty_sword", "leather_helmet", "vigor_pendant"],
		"material_chance": 0.5,
		"material_pool": ["forest_herb", "monster_bone"],
	},
	"elite_enemy": {
		"guaranteed": [
			{"type": "equipment", "pool": ["iron_sword", "iron_chest"]},
			{"type": "echo_material", "amount": 2},
		],
		"bonus_chance": 0.3,
		"bonus_pool": ["frost_edge", "guardian_gloves"],
	},
	"chest_normal": {
		"guaranteed": [{"type": "gold", "min": 15, "max": 30}],
		"equipment_chance": 0.65,
		"equipment_pool": ["rusty_sword", "leather_helmet", "vigor_pendant", "iron_sword"],
		"material_chance": 0.5,
		"material_pool": ["forest_herb", "monster_bone", "echo_dust"],
	},
	"chest_rare": {
		"guaranteed": [
			{"type": "echo_material", "amount": 2},
			{"type": "equipment", "pool": ["frost_edge", "guardian_gloves", "iron_chest"]},
		],
		"bonus_chance": 0.4,
		"bonus_pool": ["iron_sword", "vigor_pendant"],
	},
	"dungeon_chest": {
		"guaranteed": [
			{"type": "gold", "min": 25, "max": 40},
			{"type": "echo_material", "amount": 2},
			{"type": "equipment", "pool": ["frost_edge", "guardian_gloves", "iron_chest"]},
		],
		"bonus_chance": 0.4,
		"bonus_pool": ["iron_sword", "vigor_pendant"],
	},
	"boss_moss_crown": {
		"guaranteed": [
			{"type": "echo_material", "amount": 3},
			{"type": "equipment", "pool": ["iron_sword", "iron_chest", "guardian_gloves"]},
		],
		"bonus_chance": 0.35,
		"bonus_pool": ["frost_edge"],
	},
	"sprout": {},
	"boss_first_clear": {
		"guaranteed": [
			{"type": "equipment", "quality": "rare"},
			{"type": "echo", "echo_id": "frost_lamp_scholar"},
		],
	},
}
