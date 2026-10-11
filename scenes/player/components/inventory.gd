class_name Inventory
extends Node
## Inventory（背包组件，挂在 Player 下）
## 职责：30 格物品格（每格 1 件装备，含强化等级与锁定状态）、
## 材料与任务物品独立收纳（自动堆叠）、金币；提供增删查整/锁定/分解/出售。
## 物品条目结构：{ "item_data": ItemData, "quantity": int, "locked": bool, "enhance_level": int }

signal inventory_changed
signal gold_changed(amount: int)

## 背包格数量
@export var slot_count := 30

## 背包格（空位为 null）
var items: Array = []
## 材料：item_id → quantity（自动堆叠）
var materials: Dictionary = {}
## 任务物品：item_id → quantity（独立收纳，不占背包格）
var quest_items: Dictionary = {}
## 金币
var gold := 0


func _ready() -> void:
	items.resize(slot_count)


## 添加装备/消耗品（材料自动走堆叠）；背包满时返回 false（已放入的保留）。
func add_item(item_data: ItemData, quantity := 1, enhance_level := 0) -> bool:
	if item_data == null or quantity <= 0:
		return false
	if item_data.item_type == "material":
		add_material(item_data.id, quantity)
		return true
	var placed := 0
	while placed < quantity:
		var free := _find_free_slot()
		if free < 0:
			break
		items[free] = {
			"item_data": item_data,
			"quantity": 1,
			"locked": false,
			"enhance_level": enhance_level,
		}
		placed += 1
	if placed > 0:
		# 任务系统：收集事件
		var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
		if quest_manager != null:
			quest_manager.notify_event("collect", item_data.id, placed)
		_notify_changed()
	return placed >= quantity


## 直接放入一个完整条目（保留强化与锁定信息）。
func add_entry(entry: Dictionary) -> bool:
	var free := _find_free_slot()
	if free < 0:
		return false
	items[free] = entry.duplicate(true)
	_notify_changed()
	return true


## 取出并移除指定格子的条目。
func take_entry(index: int) -> Dictionary:
	if index < 0 or index >= items.size() or items[index] == null:
		return {}
	var entry: Dictionary = items[index]
	items[index] = null
	_notify_changed()
	return entry


## 移除指定 id 的装备（优先未锁定）；数量不足返回 false。
func remove_item(item_id: String, quantity := 1) -> bool:
	if quantity <= 0:
		return true
	var removed := 0
	for i in items.size():
		if removed >= quantity:
			break
		var entry: Variant = items[i]
		if entry == null or entry["locked"]:
			continue
		var data: ItemData = entry["item_data"]
		if data != null and data.id == item_id:
			items[i] = null
			removed += 1
	if removed > 0:
		_notify_changed()
	return removed >= quantity


func has_item(item_id: String, quantity := 1) -> bool:
	return get_item_count(item_id) >= quantity


## 统计数量（背包格 + 材料）。
func get_item_count(item_id: String) -> int:
	var count := 0
	for entry in items:
		if entry != null and entry["item_data"] != null and entry["item_data"].id == item_id:
			count += 1
	return count + get_material_count(item_id)


func get_entry(index: int) -> Dictionary:
	if index < 0 or index >= items.size() or items[index] == null:
		return {}
	return items[index]


func find_index(item_id: String) -> int:
	for i in items.size():
		var entry: Variant = items[i]
		if entry != null and entry["item_data"] != null and entry["item_data"].id == item_id:
			return i
	return -1


func get_free_slots() -> int:
	var count := 0
	for entry in items:
		if entry == null:
			count += 1
	return count


## ---- 材料 / 任务物品 / 金币 ----

func add_material(material_id: String, quantity := 1) -> void:
	if material_id.is_empty() or quantity <= 0:
		return
	materials[material_id] = get_material_count(material_id) + quantity
	# 任务系统：采集事件
	var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	if quest_manager != null:
		quest_manager.notify_event("collect", material_id, quantity)
	_notify_changed()


func remove_material(material_id: String, quantity := 1) -> bool:
	var have := get_material_count(material_id)
	if have < quantity:
		return false
	if have == quantity:
		materials.erase(material_id)
	else:
		materials[material_id] = have - quantity
	_notify_changed()
	return true


func get_material_count(material_id: String) -> int:
	return int(materials.get(material_id, 0))


func add_quest_item(item_id: String, quantity := 1) -> void:
	quest_items[item_id] = int(quest_items.get(item_id, 0)) + quantity
	# 任务系统：任务物品收集事件
	var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	if quest_manager != null:
		quest_manager.notify_event("collect", item_id, quantity)
	_notify_changed()


func add_gold(amount: int) -> void:
	if amount == 0:
		return
	gold = maxi(gold + amount, 0)
	gold_changed.emit(gold)
	_notify_changed()


## ---- 整理 / 锁定 / 分解 / 出售 ----

## 一键整理：类型 → 品质（高→低）→ id 排序，空格压到末尾。
func sort_items() -> void:
	var entries: Array = []
	for entry in items:
		if entry != null:
			entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: ItemData = a["item_data"]
		var db: ItemData = b["item_data"]
		if da.item_type != db.item_type:
			return da.item_type < db.item_type
		if da.quality != db.quality:
			return ItemQuality.rank_for(da.quality) > ItemQuality.rank_for(db.quality)
		return da.id < db.id)
	var new_items: Array = []
	for entry in entries:
		new_items.append(entry)
	while new_items.size() < slot_count:
		new_items.append(null)
	items = new_items
	_notify_changed()


func lock_item(index: int, locked := true) -> void:
	var entry := get_entry(index)
	if entry.is_empty():
		return
	entry["locked"] = locked
	_notify_changed()


## 分解装备，返还回响尘（普通 1 / 优秀 2 / 稀有 4 / 史诗 8）。
func dismantle(index: int) -> Dictionary:
	var entry := get_entry(index)
	if entry.is_empty() or entry["locked"]:
		return {}
	var data: ItemData = entry["item_data"]
	var dust := _dismantle_dust(data.quality)
	take_entry(index)
	add_material("echo_dust", dust)
	return {"echo_dust": dust}


## 出售装备（普通 5 / 优秀 15 / 稀有 40 / 史诗 100 金币）。
func sell(index: int) -> int:
	var entry := get_entry(index)
	if entry.is_empty() or entry["locked"]:
		return 0
	var data: ItemData = entry["item_data"]
	var prices := {ItemQuality.COMMON: 5, ItemQuality.UNCOMMON: 15, ItemQuality.RARE: 40, ItemQuality.EPIC: 100}
	var price := int(prices.get(data.quality, 5))
	take_entry(index)
	add_gold(price)
	return price


## 批量分解所有未锁定的低品质装备；返回分解数量。
func batch_dismantle_low_quality(max_rank := 1) -> int:
	var count := 0
	for i in items.size():
		var entry: Variant = items[i]
		if entry == null or entry["locked"]:
			continue
		var data: ItemData = entry["item_data"]
		if data.item_type == "material":
			continue
		if ItemQuality.rank_for(data.quality) <= max_rank:
			add_material("echo_dust", _dismantle_dust(data.quality))
			items[i] = null
			count += 1
	if count > 0:
		_notify_changed()
	return count


## ---- 存档序列化 ----

func serialize() -> Dictionary:
	return get_save_data()


## 存档接口（背包/材料/任务物品/金币）。
func get_save_data() -> Dictionary:
	var item_list: Array = []
	for entry in items:
		if entry == null:
			continue
		item_list.append({
			"id": entry["item_data"].id,
			"quantity": entry["quantity"],
			"locked": entry["locked"],
			"enhance_level": entry["enhance_level"],
		})
	return {"gold": gold, "items": item_list, "materials": materials.duplicate()}


## 读档恢复（物品 id 经 DataRegistry 还原）。
func apply_saved(data: Dictionary) -> void:
	gold = int(data.get("gold", 0))
	materials = (data.get("materials", {}) as Dictionary).duplicate()
	items.clear()
	items.resize(slot_count)
	for entry_data in data.get("items", []):
		if not (entry_data is Dictionary):
			continue
		var item_data := DataRegistry.get_item(str(entry_data.get("id", "")))
		if item_data == null:
			continue
		var free := _find_free_slot()
		if free < 0:
			break
		items[free] = {
			"item_data": item_data,
			"quantity": int(entry_data.get("quantity", 1)),
			"locked": bool(entry_data.get("locked", false)),
			"enhance_level": int(entry_data.get("enhance_level", 0)),
		}
	_notify_changed()


## ---- 内部 ----

func _find_free_slot() -> int:
	for i in items.size():
		if items[i] == null:
			return i
	return -1


func _dismantle_dust(quality: String) -> int:
	var amounts := {ItemQuality.COMMON: 1, ItemQuality.UNCOMMON: 2, ItemQuality.RARE: 4, ItemQuality.EPIC: 8}
	return int(amounts.get(quality, 1))


func _notify_changed() -> void:
	inventory_changed.emit()
	_sync_session()


func _sync_session() -> void:
	var session := AppFlow.game_session
	if session == null or not is_instance_valid(session):
		return
	session.inventory_data = serialize()
