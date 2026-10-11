class_name QuestManager
extends Node
## QuestManager（任务管理器，挂在 GameSession 的 WorldState 下）
## 职责：任务生命周期（未开放→可接取→进行中→可交付→已完成）、目标进度、
## 奖励发放（已完成记录防重复领取）、追踪（1 主线 + 最多 2 支线）、NPC 查询。

signal quest_accepted(quest_id: String)
signal quest_ready(quest_id: String)
signal quest_completed(quest_id: String)
signal tracking_changed

const MAX_TRACKED_SIDE := 2

## quest_id → QuestData
var all_quests: Dictionary = {}
## quest_id → { "status": "active"/"ready", "progress": Array[int] }
var active_quests: Dictionary = {}
var completed_quests: Array[String] = []
var tracked_main_quest := ""
var tracked_side_quests: Array[String] = []
## 已改变的世界状态 id
var world_states: Array[String] = []

var _player: PlayerController = null


func _ready() -> void:
	add_to_group("quest_manager")
	_load_quests()


## 由世界生成流程注入玩家（也可自动按组查找）。
func setup(player: PlayerController) -> void:
	_player = player


## ---- 生命周期 ----

func can_accept(quest_id: String) -> bool:
	var quest: QuestData = all_quests.get(quest_id)
	if quest == null:
		return false
	if is_quest_completed(quest_id) or active_quests.has(quest_id):
		return false
	for prereq in quest.prerequisites:
		if not is_quest_completed(str(prereq)):
			return false
	return true


func accept_quest(quest_id: String) -> bool:
	if not can_accept(quest_id):
		return false
	var quest: QuestData = all_quests[quest_id]
	var progress: Array[int] = []
	for i in quest.objectives.size():
		progress.append(0)
	active_quests[quest_id] = {"status": "active", "progress": progress}
	# 自动追踪：主线单独一份，支线最多两份
	if quest.is_main:
		tracked_main_quest = quest_id
	elif tracked_side_quests.size() < MAX_TRACKED_SIDE:
		tracked_side_quests.append(quest_id)
	quest_accepted.emit(quest_id)
	tracking_changed.emit()
	_sync_session()
	return true


## 更新某任务的目标进度（按 类型 + 目标 id 匹配）。
func update_objective(quest_id: String, objective_type: String, target_id: String, count := 1) -> void:
	if not active_quests.has(quest_id):
		return
	var quest: QuestData = all_quests.get(quest_id)
	if quest == null:
		return
	var entry: Dictionary = active_quests[quest_id]
	var progress: Array = entry["progress"]
	var changed := false
	for i in quest.objectives.size():
		var objective: Dictionary = quest.objectives[i]
		if str(objective.get("type", "")) != objective_type:
			continue
		if str(objective.get("target_id", "")) != target_id:
			continue
		var need := int(objective.get("count", 1))
		if int(progress[i]) >= need:
			continue
		progress[i] = mini(int(progress[i]) + count, need)
		changed = true
	if not changed:
		return
	if can_turn_in(quest_id):
		entry["status"] = "ready"
		quest_ready.emit(quest_id)
	tracking_changed.emit()
	_sync_session()


## 全局事件通知：所有进行中的任务都会尝试匹配进度（击杀/采集/探索/回响/连招等）。
func notify_event(objective_type: String, target_id: String, count := 1) -> void:
	for quest_id in active_quests.keys():
		update_objective(str(quest_id), objective_type, target_id, count)


## 标记目标完成（按索引直接置满）。
func complete_objective(quest_id: String, objective_index: int) -> void:
	if not active_quests.has(quest_id):
		return
	var quest: QuestData = all_quests.get(quest_id)
	if quest == null or objective_index < 0 or objective_index >= quest.objectives.size():
		return
	var progress: Array = active_quests[quest_id]["progress"]
	progress[objective_index] = int(quest.objectives[objective_index].get("count", 1))
	update_objective(quest_id, "__noop__", "__noop__", 0)


## 所有目标是否完成（可交付）。
func can_turn_in(quest_id: String) -> bool:
	if not active_quests.has(quest_id):
		return false
	var quest: QuestData = all_quests.get(quest_id)
	if quest == null:
		return false
	return _objectives_complete(quest, active_quests[quest_id]["progress"])


## 交付任务并发放奖励；未完成或已交付返回 false（防重复发放）。
func turn_in_quest(quest_id: String) -> bool:
	if not can_turn_in(quest_id):
		return false
	var quest: QuestData = all_quests[quest_id]
	active_quests.erase(quest_id)
	if not completed_quests.has(quest_id):
		completed_quests.append(quest_id)
	for change in quest.world_state_changes:
		if not world_states.has(str(change)):
			world_states.append(str(change))
	_grant_rewards(quest)
	if tracked_main_quest == quest_id:
		tracked_main_quest = ""
	tracked_side_quests.erase(quest_id)
	quest_completed.emit(quest_id)
	if quest.is_main:
		SaveService.request_auto_save("quest")
	tracking_changed.emit()
	_sync_session()
	return true


func is_quest_completed(quest_id: String) -> bool:
	return completed_quests.has(quest_id)


## ---- NPC 查询 ----

## 该 NPC 当前可接取的任务（按加载顺序，主线优先）。
func get_available_quests_for_npc(npc_id: String) -> Array:
	var result: Array = []
	for data in all_quests.values():
		var quest := data as QuestData
		if quest.giver_npc == npc_id and can_accept(quest.id):
			result.append(quest)
	result.sort_custom(func(a: QuestData, b: QuestData) -> bool: return a.is_main and not b.is_main)
	return result


## 该 NPC 当前可交付的任务（主线优先）。
func get_turn_in_quests_for_npc(npc_id: String) -> Array:
	var result: Array = []
	for quest_id in active_quests.keys():
		var quest: QuestData = all_quests.get(str(quest_id))
		if quest == null or quest.turn_in_npc != npc_id:
			continue
		if can_turn_in(str(quest_id)):
			result.append(quest)
	result.sort_custom(func(a: QuestData, b: QuestData) -> bool: return a.is_main and not b.is_main)
	return result


## NPC 头顶标记状态：空串 / "！"（可接） / "？"（可交付）。
func get_npc_marker(npc_id: String) -> String:
	if not get_turn_in_quests_for_npc(npc_id).is_empty():
		return "？"
	if not get_available_quests_for_npc(npc_id).is_empty():
		return "！"
	return ""


## ---- 追踪 ----

func track_quest(quest_id: String) -> void:
	if not active_quests.has(quest_id):
		return
	var quest: QuestData = all_quests.get(quest_id)
	if quest == null:
		return
	if quest.is_main:
		tracked_main_quest = quest_id
	elif not tracked_side_quests.has(quest_id):
		if tracked_side_quests.size() >= MAX_TRACKED_SIDE:
			tracked_side_quests.pop_front()
		tracked_side_quests.append(quest_id)
	tracking_changed.emit()


func untrack_quest(quest_id: String) -> void:
	if tracked_main_quest == quest_id:
		tracked_main_quest = ""
	tracked_side_quests.erase(quest_id)
	tracking_changed.emit()


## HUD 用：当前追踪的任务条目 [{ "quest": QuestData, "progress": Array }]。
func get_tracked_entries() -> Array:
	var entries: Array = []
	if not tracked_main_quest.is_empty() and active_quests.has(tracked_main_quest):
		entries.append(_make_entry(tracked_main_quest))
	for quest_id in tracked_side_quests:
		if active_quests.has(quest_id):
			entries.append(_make_entry(quest_id))
	return entries


## HUD 用：第一个未完成目标的标记位置（无则 null）。
func get_first_tracked_target_position() -> Variant:
	for entry in get_tracked_entries():
		var quest: QuestData = entry["quest"]
		var progress: Array = entry["progress"]
		for i in quest.objectives.size():
			var objective: Dictionary = quest.objectives[i]
			if int(progress[i]) >= int(objective.get("count", 1)):
				continue
			var position: Variant = get_marker_position(str(objective.get("target_id", "")))
			if position != null:
				return position
	return null


## 按 id 在世界中查找任务标记位置（group: quest_marker + meta quest_marker_id）。
func get_marker_position(target_id: String) -> Variant:
	for node in get_tree().get_nodes_in_group("quest_marker"):
		if node is Node3D and str(node.get_meta("quest_marker_id", "")) == target_id:
			return (node as Node3D).global_position
	return null


## ---- 存档序列化 ----

func serialize() -> Dictionary:
	return get_save_data()


func get_save_data() -> Dictionary:
	var active: Dictionary = {}
	for quest_id in active_quests:
		active[quest_id] = (active_quests[quest_id]["progress"] as Array).duplicate()
	return {
		"active": active,
		"completed": completed_quests.duplicate(),
		"world_states": world_states.duplicate(),
		"tracked_main": tracked_main_quest,
		"tracked_side": tracked_side_quests.duplicate(),
	}


func apply_saved(data: Dictionary) -> void:
	active_quests.clear()
	completed_quests.clear()
	world_states.clear()
	for id in data.get("completed", []):
		completed_quests.append(str(id))
	for id in data.get("world_states", []):
		world_states.append(str(id))
	var active: Dictionary = data.get("active", {})
	for id in active:
		var quest: QuestData = all_quests.get(str(id))
		if quest == null:
			continue
		var saved_progress: Array = active[id]
		var progress: Array[int] = []
		for i in quest.objectives.size():
			progress.append(int(saved_progress[i]) if i < saved_progress.size() else 0)
		active_quests[str(id)] = {
			"status": "ready" if _objectives_complete(quest, progress) else "active",
			"progress": progress,
		}
	tracked_main_quest = str(data.get("tracked_main", ""))
	tracked_side_quests.clear()
	for id in data.get("tracked_side", []):
		tracked_side_quests.append(str(id))
	tracking_changed.emit()
	_sync_session()


## ---- 内部 ----

func _load_quests() -> void:
	all_quests.clear()
	for data in DataRegistry.get_all_quests():
		var quest := data as QuestData
		if quest != null:
			all_quests[quest.id] = quest


func _make_entry(quest_id: String) -> Dictionary:
	return {
		"quest": all_quests[quest_id],
		"progress": active_quests[quest_id]["progress"],
	}


func _objectives_complete(quest: QuestData, progress: Array) -> bool:
	for i in quest.objectives.size():
		if int(progress[i]) < int(quest.objectives[i].get("count", 1)):
			return false
	return true


func _grant_rewards(quest: QuestData) -> void:
	var player := _resolve_player()
	if player == null:
		return
	var rewards := quest.rewards
	player.inventory.add_gold(int(rewards.get("gold", 0)))
	player.stats.add_exp(int(rewards.get("exp", 0)))
	for item_entry in rewards.get("items", []):
		if not (item_entry is Dictionary):
			continue
		var item := DataRegistry.get_item(str(item_entry.get("item_id", "")))
		if item != null:
			player.inventory.add_item(item, int(item_entry.get("count", 1)))
	var echo_id := str(rewards.get("echo_id", ""))
	if not echo_id.is_empty() and player.echo_system != null:
		player.echo_system.collect_echo(echo_id)


func _resolve_player() -> PlayerController:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	return _player


func _sync_session() -> void:
	var session := AppFlow.game_session
	if session == null or not is_instance_valid(session):
		return
	session.quest_data = serialize()
