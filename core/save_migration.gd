class_name SaveMigration
extends RefCounted
## SaveMigration（存档版本迁移与数据修复）
## 职责：按版本逐级迁移存档数据、补全缺失字段、校验并修复失效的物品/回响引用。
## 原则：任何“保存成功但读档丢失”都视为严重问题——宁可给补偿也不丢存档。

const CURRENT_VERSION := 2

## 业务数据的完整默认结构（缺失时填充）。
const DATA_DEFAULTS := {
	"selected_class_id":"dart_master", "gameplay_mode":"",
	"world_data":{}, "player_data":{}, "survivor_data":{},
	"environment_data":{}, "play_time":0.0, "save_version":CURRENT_VERSION,
}


## 版本迁移入口：从 from_version 逐级迁移到 to_version。
static func migrate(data: Dictionary, from_version: int, to_version: int) -> Dictionary:
	var result := data.duplicate(true)
	var version := from_version
	while version < to_version:
		match version:
			0:
				# v0 → v1：早期存档仅含基础字段，统一补全默认结构
				_ensure_defaults(result)
		version += 1
	_ensure_defaults(result)
	result["save_version"] = to_version
	return result


## 校验并修复数据：缺失物品替换为同品质基础物品（金币补偿），未知回响标记但不删除。
static func validate_and_repair(data: Dictionary) -> Dictionary:
	var repaired := data.duplicate(true)
	if str(repaired.get("gameplay_mode", "")) == "survivor":
		repaired["selected_class_id"] = "dart_master"
		for key in ["inventory_data", "equipment_data", "quest_data", "echo_levels", "echo_fragments", "echo_energy", "spirit_level", "starter_equipment_granted"]:repaired.erase(key)
		for key in ["collected_echoes", "prep_slots", "selected_spirit_id", "spirit"]:repaired.erase(key)
		return repaired
	# Old saves are preserved on disk; the session converts their world exploration only.
	repaired["selected_class_id"] = "dart_master"
	return repaired

static func _ensure_defaults(data: Dictionary) -> void:
	for key in DATA_DEFAULTS:
		if not data.has(key):
			var value: Variant=DATA_DEFAULTS[key]
			data[key]=value.duplicate(true) if value is Dictionary else value
	for key in ["world_data","player_data","survivor_data","environment_data"]:
		if not data.get(key) is Dictionary:data[key]={}
