class_name LootSystem
extends RefCounted
## LootSystem（掉落系统，纯静态）
## 职责：按掉落表生成掉落列表（必得 + 独立装备抽取 + 独立材料抽取 + 精英额外抽取），
## 并在世界位置生成可拾取掉落物。对当前职业可用的武器给予更高抽取权重。

const DROP_SCENE := preload("res://scenes/combat/loot_drop.tscn")


## 按怪物类型生成掉落列表（元素为 {type, ...} 的字典）。
static func generate_loot(enemy_type: String) -> Array:
	var result: Array = []
	var table: Dictionary = LootTables.LOOT_TABLES.get(enemy_type, {})
	if table.is_empty():
		return result
	# 必得部分
	for entry in table.get("guaranteed", []):
		if not (entry is Dictionary):
			continue
		match str(entry.get("type", "")):
			"gold":
				result.append({
					"type": "gold",
					"amount": randi_range(int(entry.get("min", 1)), int(entry.get("max", 1))),
				})
			"equipment":
				var pool: Array = entry.get("pool", [])
				if not pool.is_empty():
					result.append({"type": "item", "item_id": _weighted_pick(pool)})
			"echo_material":
				result.append({
					"type": "material",
					"item_id": "echo_dust",
					"quantity": int(entry.get("amount", 1)),
				})
			"echo":
				result.append({"type": "echo", "item_id": str(entry.get("echo_id", ""))})
	# 独立装备抽取（不与材料/必得互斥）
	var equip_chance := float(table.get("equipment_chance", 0.0))
	if equip_chance > 0.0 and randf() < equip_chance:
		var pool: Array = table.get("equipment_pool", [])
		if not pool.is_empty():
			result.append({"type": "item", "item_id": _weighted_pick(pool)})
	# 独立材料抽取
	var material_chance := float(table.get("material_chance", 0.0))
	if material_chance > 0.0 and randf() < material_chance:
		var pool: Array = table.get("material_pool", [])
		if not pool.is_empty():
			result.append({
				"type": "material",
				"item_id": str(pool[randi() % pool.size()]),
				"quantity": 1,
			})
	# 精英额外抽取
	var bonus_chance := float(table.get("bonus_chance", 0.0))
	if bonus_chance > 0.0 and randf() < bonus_chance:
		var pool: Array = table.get("bonus_pool", [])
		if not pool.is_empty():
			result.append({"type": "item", "item_id": str(pool[randi() % pool.size()])})
	return result


## 在指定位置生成掉落物（轻微散开，逐个抬高避免重叠）。
static func drop_loot_at_position(parent: Node, loot_list: Array, position: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var index := 0
	for entry in loot_list:
		if not (entry is Dictionary):
			continue
		var drop := DROP_SCENE.instantiate() as LootDrop
		if drop == null:
			continue
		parent.add_child(drop)
		var offset := Vector3(randf_range(-0.6, 0.6), 0.55, randf_range(-0.6, 0.6))
		drop.global_position = position + offset + Vector3(0.0, index * 0.15, 0.0)
		drop.setup(entry)
		index += 1


## 加权抽取：武器权重 ×2（当前职业可用武器掉率更高）。
static func _weighted_pick(pool: Array) -> String:
	var total := 0.0
	var weights: Array = []
	for item_id in pool:
		var weight := 1.0
		var data := DataRegistry.get_item(str(item_id))
		if data != null and data.item_type == "weapon":
			weight = 2.0
		weights.append(weight)
		total += weight
	var roll := randf() * total
	for i in pool.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return str(pool[i])
	return str(pool[pool.size() - 1])
