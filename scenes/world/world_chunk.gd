class_name WorldChunk
extends Node3D
## WorldChunk（世界分块）
## 职责：承载一块 128×128 米的世界内容（营地/POI/敌人刷新点/任务区域）。
## 提供 load_content()/unload_content()/is_loaded() 与状态存取接口；
## 卸载前把已打开宝箱等状态写入 GameSession.world_data，加载时恢复。
## MVP：内容静态常驻，load/unload 以可见性+处理开关实现，后续可替换为动态实例化。

@export var chunk_id := ""

var bounds := AABB()
var _loaded := false


func _ready() -> void:
	if chunk_id.is_empty():
		chunk_id = name
	var origin: Vector2 = WorldLayout.CHUNKS.get(chunk_id, Vector2.ZERO)
	bounds = AABB(
		Vector3(origin.x, -50.0, origin.y),
		Vector3(WorldLayout.CHUNK_SIZE, 100.0, WorldLayout.CHUNK_SIZE)
	)
	_loaded = true


func load_content() -> void:
	if _loaded:
		return
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_loaded = true
	apply_state()


func unload_content() -> void:
	if not _loaded:
		return
	save_state()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_loaded = false


func is_loaded() -> bool:
	return _loaded


## 卸载前保存分块内可持久化状态（已打开宝箱）。
func save_state() -> void:
	var session := _session()
	if session == null:
		return
	var opened: Array = session.world_data.get("chests_opened", [])
	for chest in find_children("*", "", true, false):
		if chest.is_in_group("chest") and chest.has_method("is_chest_opened") and bool(chest.call("is_chest_opened")):
			var chest_id := str(chest.call("get_chest_id"))
			if not chest_id.is_empty() and not opened.has(chest_id):
				opened.append(chest_id)
	session.world_data["chests_opened"] = opened


## 加载时从会话恢复状态（宝箱在 _ready 自行恢复，这里补充会话回写）。
func apply_state() -> void:
	var session := _session()
	if session == null:
		return
	for chest in find_children("*", "", true, false):
		if chest.is_in_group("chest") and chest.has_method("apply_saved_state"):
			chest.call("apply_saved_state")


func _session() -> GameSession:
	if not is_inside_tree():
		return null
	return get_tree().current_scene as GameSession
