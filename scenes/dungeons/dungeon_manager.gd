class_name DungeonManager
extends Node
## DungeonManager（秘境管理器）
## 职责：秘境进入/退出（0.5s 黑屏过渡）、大世界暂存与恢复、玩家放置与复活点、
## 玩家在秘境死亡时退出秘境回营地（BOSS 战随场景释放而重置）。
## 设计边界：秘境独立加载；进入时把大世界整棵子树移出场景树（物理/AI 全部暂停）。

signal dungeon_entered(dungeon: Node)
signal dungeon_exited()

const FADE_DURATION := 0.5

var active_dungeon: Node = null

var _stashed_world: Node = null
var _entrance_position := Vector3.ZERO
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _busy := false


func _ready() -> void:
	add_to_group("dungeon_manager")


func is_in_dungeon() -> bool:
	return active_dungeon != null


func is_busy() -> bool:
	return _busy


## 进入秘境：条件检查 → 淡出 → 暂存大世界 → 加载秘境 → 等待就绪 → 放置玩家 → 淡入。
func enter_dungeon(dungeon_scene_path: String, required_quest: String, entrance_position: Vector3) -> void:
	if _busy or active_dungeon != null:
		return
	var session := _session()
	var player := _player()
	if session == null or player == null:
		push_error("DungeonManager: 缺少会话或玩家")
		return
	var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	if not required_quest.is_empty() and quest_manager != null and not quest_manager.is_quest_completed(required_quest):
		player.show_combat_feedback("还未满足进入条件", Color(0.85, 0.75, 0.6))
		return
	var packed := load(dungeon_scene_path) as PackedScene
	if packed == null:
		push_error("DungeonManager: 无法加载秘境场景 %s" % dungeon_scene_path)
		return
	_busy = true
	_entrance_position = entrance_position
	if not player._respawn_point.is_finite():
		player.set_respawn_point(WorldLayout.CAMPFIRE)
	# 提前连接死亡信号：进入流程中（含淡出）死亡也能正确退出
	if not player.stats.died.is_connected(_on_player_died):
		player.stats.died.connect(_on_player_died)
	await _fade_to_black()
	var world_holder := session.get_node_or_null("World")
	if world_holder == null:
		push_error("DungeonManager: 会话缺少 World 节点")
		_busy = false
		await _fade_from_black()
		return
	var dungeon := packed.instantiate()
	if world_holder.get_child_count() > 0:
		_stashed_world = world_holder.get_child(0)
		world_holder.remove_child(_stashed_world)
	world_holder.add_child(dungeon)
	active_dungeon = dungeon
	var session_now := _session()
	if session_now != null:
		session_now.current_world_id = "dungeon"
	SaveService.request_auto_save("dungeon")
	await _wait_dungeon_ready(dungeon)
	player.global_position = dungeon.call("get_entrance_position")
	player.velocity = Vector3.ZERO
	await _fade_from_black()
	_busy = false
	dungeon_entered.emit(dungeon)


## 退出秘境：淡出 → 释放秘境 → 恢复大世界 → 玩家回到入口附近安全点 → 淡入。
func exit_dungeon() -> void:
	if _busy or active_dungeon == null:
		return
	_busy = true
	await _fade_to_black()
	var session := _session()
	var dungeon := active_dungeon
	active_dungeon = null
	if session != null:
		session.current_world_id = "forest"
	var world_holder := session.get_node_or_null("World") if session != null else null
	if world_holder != null:
		if dungeon != null and dungeon.get_parent() == world_holder:
			world_holder.remove_child(dungeon)
		if _stashed_world != null:
			world_holder.add_child(_stashed_world)
			_stashed_world = null
	if dungeon != null and is_instance_valid(dungeon):
		dungeon.queue_free()
	var player := _player()
	if player != null:
		player.global_position = _entrance_position + Vector3(0.0, 0.4, 3.0)
		player.velocity = Vector3.ZERO
	await _fade_from_black()
	_busy = false
	dungeon_exited.emit()


## 玩家在秘境死亡：退出秘境（玩家自身的死亡计时随后会传送回营地篝火）。
func _on_player_died() -> void:
	if active_dungeon == null or _busy:
		return
	await exit_dungeon()


## ---- 内部 ----

func _session() -> GameSession:
	return get_tree().get_first_node_in_group("game_session") as GameSession


func _player() -> PlayerController:
	var session := _session()
	if session == null:
		return null
	var player_holder := session.get_node_or_null("Player")
	if player_holder == null or player_holder.get_child_count() == 0:
		return null
	return player_holder.get_child(0) as PlayerController


func _wait_dungeon_ready(dungeon: Node) -> void:
	var waited := 0.0
	while waited < 20.0:
		if dungeon.has_method("is_ready_for_player") and bool(dungeon.call("is_ready_for_player")):
			return
		if not is_instance_valid(dungeon):
			return
		await get_tree().create_timer(0.2).timeout
		waited += 0.2


func _ensure_fade() -> void:
	if _fade_layer != null:
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "DungeonFade"
	_fade_layer.layer = 100
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)
	add_child(_fade_layer)


func _fade_to_black() -> void:
	_ensure_fade()
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
	await tween.finished


func _fade_from_black() -> void:
	_ensure_fade()
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
	await tween.finished
