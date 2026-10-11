class_name WorldStreamer
extends Node3D
## WorldStreamer（分块流式加载器）
## 职责：按玩家位置加载/卸载周边分块；加载距离（圈数）与卸载距离分离，避免边界抖动；
## 资源后台加载（load_threaded_request）、主线程分批实例化；碰撞就绪后计入已加载。
## MVP：force_all_loaded = true 时一次加载全部 4 块，代码结构保留真流式路径。

signal all_loaded()

@export var force_all_loaded := true
@export var chunk_scene_dir := "res://scenes/world/chunks/"
@export var load_ring := 1
@export var unload_ring := 2

var _player: Node3D
var _chunks: Dictionary = {}
var _pending: Array = []
var _world_ready := false


func setup(player: Node3D, chunk_ids: Array) -> void:
	_player = player
	if not _pending.is_empty() or not _chunks.is_empty():
		return
	for id in chunk_ids:
		var path := chunk_scene_dir + str(id) + ".tscn"
		ResourceLoader.load_threaded_request(path)
		_pending.append({"id": str(id), "path": path})
	set_process(true)


func is_world_ready() -> bool:
	return _world_ready


func get_chunk(chunk_id: String) -> WorldChunk:
	return _chunks.get(chunk_id) as WorldChunk


func _process(_delta: float) -> void:
	if not _pending.is_empty():
		_poll_pending()
		return
	if not _world_ready:
		_world_ready = true
		all_loaded.emit()
	if force_all_loaded or _player == null:
		return
	_update_streaming()


## 后台加载轮询：等待完成 → 主线程实例化（每帧只处理一个分块）。
func _poll_pending() -> void:
	var item: Dictionary = _pending[0]
	var path := str(item["path"])
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	_pending.pop_front()
	var packed: PackedScene = null
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
	if packed == null:
		push_error("WorldStreamer: 无法加载分块 %s" % path)
		return
	var chunk := packed.instantiate() as WorldChunk
	if chunk == null:
		push_error("WorldStreamer: 分块根节点不是 WorldChunk（%s）" % path)
		return
	add_child(chunk)
	chunk.load_content()
	_chunks[chunk.chunk_id] = chunk


## 真流式：按玩家所在分块 ± 圈数 加载/卸载。
func _update_streaming() -> void:
	var center := _player.global_position
	var cell := Vector2i(
		int(floor((center.x + WorldLayout.HALF) / WorldLayout.CHUNK_SIZE)),
		int(floor((center.z + WorldLayout.HALF) / WorldLayout.CHUNK_SIZE))
	)
	for id in WorldLayout.CHUNKS.keys():
		var origin: Vector2 = WorldLayout.CHUNKS[id]
		var chunk_cell := Vector2i(
			int(floor((origin.x + WorldLayout.HALF) / WorldLayout.CHUNK_SIZE)),
			int(floor((origin.y + WorldLayout.HALF) / WorldLayout.CHUNK_SIZE))
		)
		var ring := maxi(absi(chunk_cell.x - cell.x), absi(chunk_cell.y - cell.y))
		var chunk := get_chunk(str(id))
		if ring <= load_ring:
			if chunk == null and not _is_pending(str(id)):
				var path := chunk_scene_dir + str(id) + ".tscn"
				ResourceLoader.load_threaded_request(path)
				_pending.append({"id": str(id), "path": path})
		elif ring > unload_ring and chunk != null:
			chunk.unload_content()
			_chunks.erase(str(id))
			chunk.queue_free()


func _is_pending(chunk_id: String) -> bool:
	for item in _pending:
		if str(item["id"]) == chunk_id:
			return true
	return false
