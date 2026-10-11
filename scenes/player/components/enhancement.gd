class_name EnhancementSystem
extends Node
## EnhancementSystem（装备强化组件，挂在 Player 下）
## 职责：装备强化 +0..+5（每级主属性 +10%，不失败不降级），消耗回响尘。
## 营地的锻造 NPC 将在后续轮次调用本组件（MVP 提供完整接口）。

const MAX_LEVEL := 5

var _player: PlayerController = null


## 由 PlayerController 在 _ready 时调用。
func setup(player: PlayerController) -> void:
	_player = player


## 强化已装备的某槽位（消耗回响尘）；成功返回 true。
func enhance(slot: String) -> bool:
	if _player == null or _player.equipment == null or _player.inventory == null:
		return false
	var item: ItemData = _player.equipment.get_equipped(slot)
	if item == null:
		return false
	var level: int = _player.equipment.get_equipped_enhance(slot)
	if level >= MAX_LEVEL:
		return false
	var cost := get_enhance_cost(level)
	for material_id in cost:
		if _player.inventory.get_material_count(str(material_id)) < int(cost[material_id]):
			return false
	for material_id in cost:
		_player.inventory.remove_material(str(material_id), int(cost[material_id]))
	_player.equipment.set_enhance_level(slot, level + 1)
	return true


## 从当前等级升到下一级所需材料。
func get_enhance_cost(level: int) -> Dictionary:
	return {"echo_dust": 2 + level * 2}
