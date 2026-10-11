class_name EquipmentSystem
extends Node
## EquipmentSystem（装备系统组件，挂在 Player 下）
## 职责：五槽装备（头盔/胸甲/手套/武器/饰品）的穿脱与属性汇总；
## 装备变化时实时重算玩家属性（攻击强度/护甲/生命上限/暴击/技能急速/专注恢复），
## 并更新第一人称武器模型（稀有发光）与手套颜色；处理回响护符的特殊效果。

signal equipment_changed

const SLOTS := ["helmet", "chest", "gloves", "weapon", "accessory"]
const SLOT_NAMES := {
	"helmet": "头盔",
	"chest": "胸甲",
	"gloves": "手套",
	"weapon": "武器",
	"accessory": "饰品",
}

## slot → ItemData（未装备为 null）
var equipped_items: Dictionary = {}
## slot → 强化等级（+0..+5）
var equipped_enhance: Dictionary = {}

var _player: PlayerController = null
var _class_data: ClassData = null
var _charm_shield_timer := 0.0


## 由 PlayerController 在 _ready 时调用。
func setup(player: PlayerController) -> void:
	_player = player
	if player.combat != null:
		_class_data = player.combat.class_data
	for slot in SLOTS:
		equipped_items[slot] = null
		equipped_enhance[slot] = 0
	if player.echo_system != null:
		player.echo_system.echo_deactivated.connect(_on_echo_deactivated)
	if _class_data != null and not _class_data.starting_weapon_id.is_empty():
		equipped_items["weapon"] = DataRegistry.get_item(_class_data.starting_weapon_id)
	_recompute_stats()
	_refresh_visuals()


func _process(delta: float) -> void:
	if _charm_shield_timer > 0.0:
		_charm_shield_timer -= delta
		if _charm_shield_timer <= 0.0 and _player != null:
			_player.stats.clear_shield()


## ---- 穿脱 ----

## 装备物品；返回被替换下来的旧 ItemData（无则 null）。
## 旧装备的强化等级请在调用前用 get_equipped_enhance(slot) 取出并写回背包。
func equip_item(item_data: ItemData, slot: String, enhance_level := 0) -> ItemData:
	if item_data == null or not equipped_items.has(slot):
		return null
	var old: ItemData = equipped_items[slot]
	equipped_items[slot] = item_data
	equipped_enhance[slot] = clampi(enhance_level, 0, 5)
	_recompute_stats()
	_refresh_visuals()
	equipment_changed.emit()
	_sync_session()
	return old


## 卸下装备；返回卸下的 ItemData（无则 null）。
func unequip_item(slot: String) -> ItemData:
	var old: ItemData = equipped_items.get(slot)
	if old == null:
		return null
	equipped_items[slot] = null
	equipped_enhance[slot] = 0
	_recompute_stats()
	_refresh_visuals()
	equipment_changed.emit()
	_sync_session()
	return old


## 从背包条目装备（UI 与测试共用）：装备物品到其 item_type 对应槽位，
## 旧装备（含强化等级）自动写回背包。
func equip_from_inventory(inventory: Inventory, index: int) -> bool:
	var entry := inventory.get_entry(index)
	if entry.is_empty():
		return false
	var item: ItemData = entry["item_data"]
	if item == null or not SLOTS.has(item.item_type):
		return false
	var slot: String = item.item_type
	var old := get_equipped(slot)
	var old_enh := get_equipped_enhance(slot)
	inventory.take_entry(index)
	equip_item(item, slot, int(entry.get("enhance_level", 0)))
	if old != null:
		inventory.add_item(old, 1, old_enh)
	return true


## 设置槽位强化等级并重算属性（强化系统调用）。
func set_enhance_level(slot: String, level: int) -> void:
	if not equipped_enhance.has(slot):
		return
	equipped_enhance[slot] = clampi(level, 0, 5)
	_recompute_stats()
	equipment_changed.emit()
	_sync_session()


func get_equipped(slot: String) -> ItemData:
	var item: Variant = equipped_items.get(slot)
	return item if item is ItemData else null


func get_equipped_enhance(slot: String) -> int:
	return int(equipped_enhance.get(slot, 0))


## ---- 属性汇总 ----

func _enhance_mult(slot: String) -> float:
	return 1.0 + 0.1 * float(equipped_enhance.get(slot, 0))


func get_total_attack_power() -> float:
	var total := 0.0
	if _class_data != null:
		total = _class_data.base_attack_power
	for slot in SLOTS:
		var item: ItemData = equipped_items.get(slot)
		if item != null:
			total += item.attack_power * _enhance_mult(slot)
	return total


func get_total_armor() -> float:
	var total := 0.0
	if _class_data != null:
		total = _class_data.armor
	for slot in SLOTS:
		var item: ItemData = equipped_items.get(slot)
		if item != null:
			total += item.armor * _enhance_mult(slot)
	return total


func get_total_max_health_bonus() -> float:
	var total := 0.0
	for slot in SLOTS:
		var item: ItemData = equipped_items.get(slot)
		if item != null:
			total += item.max_health_bonus * _enhance_mult(slot)
	return total


func get_total_crit_chance() -> float:
	var total := 0.0
	for slot in SLOTS:
		var item: ItemData = equipped_items.get(slot)
		if item != null:
			total += item.crit_chance * _enhance_mult(slot)
	return total


func get_total_skill_haste() -> float:
	var total := 0.0
	for slot in SLOTS:
		var item: ItemData = equipped_items.get(slot)
		if item != null:
			total += item.skill_haste * _enhance_mult(slot)
	return total


func get_total_focus_regen_bonus() -> float:
	var total := 0.0
	for slot in SLOTS:
		var item: ItemData = equipped_items.get(slot)
		if item != null:
			total += item.focus_regen_bonus * _enhance_mult(slot)
	return total


## 所有属性汇总（UI / 存档用）。
func get_equip_summary() -> Dictionary:
	return {
		"attack_power": get_total_attack_power(),
		"armor": get_total_armor(),
		"max_health_bonus": get_total_max_health_bonus(),
		"crit_chance": get_total_crit_chance(),
		"skill_haste": get_total_skill_haste(),
		"focus_regen_bonus": get_total_focus_regen_bonus(),
	}


## ---- 存档序列化 ----

func serialize() -> Dictionary:
	return get_save_data()


## 存档接口（五槽装备与强化等级）。
func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	for slot in SLOTS:
		var item: ItemData = equipped_items.get(slot)
		if item != null:
			data[slot] = {"id": item.id, "enhance_level": equipped_enhance.get(slot, 0)}
	return data


func apply_saved(data: Dictionary) -> void:
	for slot in SLOTS:
		equipped_items[slot] = null
		equipped_enhance[slot] = 0
		var entry: Variant = data.get(slot)
		if entry is Dictionary:
			var item := DataRegistry.get_item(str(entry.get("id", "")))
			if item != null:
				equipped_items[slot] = item
				equipped_enhance[slot] = int(entry.get("enhance_level", 0))
	_recompute_stats()
	_refresh_visuals()
	equipment_changed.emit()
	_sync_session()


## ---- 内部 ----

## 装备属性 → 玩家数值（攻击强度/护甲/生命上限/专注恢复/暴击/技能急速）。
func _recompute_stats() -> void:
	if _player == null:
		return
	var stats := _player.stats
	var combat := _player.combat
	if stats != null and _class_data != null:
		stats.max_health = _class_data.max_health + get_total_max_health_bonus()
		stats.max_focus = _class_data.max_focus
		stats.focus_regen = _class_data.focus_regen + get_total_focus_regen_bonus()
		stats.armor = get_total_armor()
		stats.current_health = minf(stats.current_health, stats.max_health)
	if combat != null:
		combat.attack_power = get_total_attack_power()
		combat.crit_chance = 0.05 + get_total_crit_chance()
		combat.skill_haste = clampf(get_total_skill_haste(), 0.0, combat.skill_haste_cap)


## 武器模型（稀有发光）与手套颜色。
func _refresh_visuals() -> void:
	if _player == null or _player.fp_arms == null:
		return
	var weapon: ItemData = equipped_items.get("weapon")
	var model_path := ""
	var glow := false
	if weapon != null:
		model_path = weapon.model_path
		glow = ItemQuality.rank_for(weapon.quality) >= ItemQuality.RANK_RARE
	_player.fp_arms.set_weapon_model(model_path, glow)
	var gloves: ItemData = equipped_items.get("gloves")
	var tint := Color(0.55, 0.55, 0.58)
	if gloves != null and ItemQuality.rank_for(gloves.quality) >= ItemQuality.RANK_RARE:
		tint = Color(0.45, 0.62, 0.6)
	_player.fp_arms.set_glove_tint(tint)


## 回响护符：回响结束后获得 5 秒护盾（吸收 20 点伤害）。
func _on_echo_deactivated(_echo_id: String) -> void:
	var accessory: ItemData = equipped_items.get("accessory")
	if accessory == null or accessory.id != "echo_charm" or _player == null:
		return
	_player.stats.add_shield(20.0)
	_charm_shield_timer = 5.0
	_player.show_combat_feedback("回响护符：获得护盾", ItemQuality.color_for(ItemQuality.RARE))


func _sync_session() -> void:
	var session := AppFlow.game_session
	if session == null or not is_instance_valid(session):
		return
	session.equipment_data = serialize()
