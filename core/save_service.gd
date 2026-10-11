extends Node
## SaveService（存档服务单例，Autoload）
## 职责：三存档位 + 自动存档轮换的写入/读取/备份/版本迁移/恢复；
## 写入策略：先写 .tmp 并回读校验 → 旧档转 .bak → 替换正式文件；
## 启动时清理孤儿 .tmp 并可从 .bak 恢复；本服务不直接修改 UI（通过 game_saved 信号通知）。

signal game_saved(manual: bool, reason: String)

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 3
const AUTO_COUNT := 3
const SAVE_VERSION := 2
const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"

const KEY_VERSION := "version"
const KEY_CREATED_AT := "created_at"
const KEY_SAVE_TIME := "save_time"
const KEY_PLAY_TIME := "play_time"
const KEY_GAME_VERSION := "game_version"
const KEY_DATA := "data"

var _pending_auto_reason := ""
var _auto_requested := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	recover_if_needed()


## ---- 查询 ----


func has_save(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	return FileAccess.file_exists(_slot_path(slot))


## 存档摘要（供主菜单/暂停菜单显示）。
func get_save_summary(slot: int) -> Dictionary:
	var summary := {
		"slot": slot, "exists": false, "class_id": "", "spirit_id": "",
		"spirit_level": 0, "save_time": 0.0, "play_time": 0.0, "world_id": "forest",
	}
	if not has_save(slot):
		return summary
	var envelope: Variant = _read_json_file(_slot_path(slot))
	if envelope == null:
		envelope = _read_json_file(_slot_path(slot) + BACKUP_SUFFIX)
	if typeof(envelope) != TYPE_DICTIONARY:
		return summary
	var data: Dictionary = (envelope as Dictionary).get(KEY_DATA, {})
	var player_data: Dictionary = data.get("player_data", {})
	summary["exists"] = true
	summary["class_id"] = str(data.get("selected_class_id", "dart_master"))
	summary["spirit_id"] = str(data.get("selected_spirit_id", ""))
	summary["spirit_level"] = int(player_data.get("level", 1))
	summary["save_time"] = float((envelope as Dictionary).get(KEY_SAVE_TIME, 0.0))
	summary["play_time"] = float((envelope as Dictionary).get(KEY_PLAY_TIME, 0.0))
	summary["world_id"] = str(player_data.get("world_id", "forest"))
	return summary


## 三个手动存档位的摘要列表。
func list_slot_summaries() -> Array:
	var result: Array = []
	for slot in range(1, SLOT_COUNT + 1):
		result.append(get_save_summary(slot))
	return result


## ---- 写入 ----


## 手动/普通写入存档（data 缺省字段自动补全）。
func save_game(slot: int, data: Dictionary = {}) -> bool:
	if not _is_valid_slot(slot):
		push_error("SaveService: 无效存档位 %d（应为 1-%d）" % [slot, SLOT_COUNT])
		return false
	var ok := _save_to_path(_slot_path(slot), data, false, "")
	if ok:
		game_saved.emit(true, "")
	return ok


## 请求自动存档（延迟到空闲帧执行，避免在系统回调中途写入）。
func request_auto_save(reason: String) -> void:
	if _auto_requested:
		return
	_auto_requested = true
	_pending_auto_reason = reason
	_run_pending_auto_save.call_deferred()


func _run_pending_auto_save() -> void:
	_auto_requested = false
	var reason := _pending_auto_reason
	_pending_auto_reason = ""
	auto_save(reason)


## 自动存档：轮换写入 auto_1..auto_3（保留最近 3 份）。
func auto_save(reason: String) -> bool:
	var slot_key := _next_auto_slot_key()
	var ok := _save_to_path(_auto_path(slot_key), {}, false, reason)
	if ok:
		game_saved.emit(false, reason)
	return ok


## ---- 读取 ----


## 读取存档数据；主文件损坏时尝试 .bak 备份，均失败返回空字典。
func load_game(slot: int) -> Dictionary:
	if not _is_valid_slot(slot):
		push_error("SaveService: 无效存档位 %d" % slot)
		return {}
	return _load_from_path(_slot_path(slot))


## ---- 删除 ----


func delete_save(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	var path := _slot_path(slot)
	_delete_file(path + TEMP_SUFFIX)
	_delete_file(path + BACKUP_SUFFIX)
	return _delete_file(path)


## ---- 意外退出恢复 ----

## 启动时检查孤儿 .tmp：主文件不可用时用备份恢复；一并清理临时文件。
func recover_if_needed() -> void:
	var paths: Array = []
	for slot in range(1, SLOT_COUNT + 1):
		paths.append(_slot_path(slot))
	for index in range(1, AUTO_COUNT + 1):
		paths.append(_auto_path("auto_%d" % index))
	for path in paths:
		var temp := str(path) + TEMP_SUFFIX
		if FileAccess.file_exists(temp):
			# 有临时文件：主文件缺失/损坏时尝试用备份恢复，然后清理
			if _read_json_file(str(path)) == null:
				var backup := str(path) + BACKUP_SUFFIX
				if FileAccess.file_exists(backup):
					_delete_file(str(path))
					DirAccess.rename_absolute(backup, str(path))
					print("[SaveService] 已从备份恢复：%s" % path)
			_delete_file(temp)
		elif FileAccess.file_exists(str(path)):
			continue


## ---- 内部：写入/读取核心 ----

func _save_to_path(path: String, data: Dictionary, _is_auto: bool, reason: String) -> bool:
	if not _ensure_save_dir():
		return false
	var payload := data.duplicate(true)
	_autofill_from_session(payload)
	var envelope := {
		KEY_VERSION: SAVE_VERSION,
		KEY_CREATED_AT: Time.get_datetime_string_from_system(),
		KEY_SAVE_TIME: Time.get_unix_time_from_system(),
		KEY_PLAY_TIME: _current_play_time(),
		KEY_GAME_VERSION: str(ProjectSettings.get_setting("application/config/version", "dev")),
		KEY_DATA: payload,
	}
	if not reason.is_empty():
		envelope["auto_reason"] = reason
	var temp_path := path + TEMP_SUFFIX
	if not _write_json_file(temp_path, envelope):
		return false
	# 校验临时文件可解析后再替换
	if _read_json_file(temp_path) == null:
		push_error("SaveService: 临时存档校验失败，已取消写入（%s）" % path)
		_delete_file(temp_path)
		return false
	if FileAccess.file_exists(path):
		_delete_file(path + BACKUP_SUFFIX)
		var backup_err := DirAccess.rename_absolute(path, path + BACKUP_SUFFIX)
		if backup_err != OK:
			push_warning("SaveService: 旧存档备份失败（错误码 %d）" % backup_err)
	var replace_err := DirAccess.rename_absolute(temp_path, path)
	if replace_err != OK:
		push_error("SaveService: 替换存档失败（错误码 %d）" % replace_err)
		return false
	return true


func _load_from_path(path: String) -> Dictionary:
	var envelope: Variant = _read_json_file(path)
	if envelope == null:
		push_warning("SaveService: 存档不可用，尝试读取备份：%s" % path)
		var backup: Variant = _read_json_file(path + BACKUP_SUFFIX)
		if backup == null:
			return {}
		envelope = backup
	if typeof(envelope) != TYPE_DICTIONARY:
		push_error("SaveService: 存档格式不正确：%s" % path)
		return {}
	var migrated := _migrate(envelope as Dictionary)
	var data: Variant = migrated.get(KEY_DATA, {})
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var payload := SaveMigration.validate_and_repair(data as Dictionary)
	payload["save_meta"] = {
		"save_version": int(migrated.get(KEY_VERSION, SAVE_VERSION)),
		"game_version": str(migrated.get(KEY_GAME_VERSION, "")),
		"save_time": float(migrated.get(KEY_SAVE_TIME, 0.0)),
		"play_time": float(migrated.get(KEY_PLAY_TIME, 0.0)),
	}
	return payload


## 补全会话侧的全部快照（会话不存在时保留 data 原值）。
func _autofill_from_session(payload: Dictionary) -> void:
	var session := AppFlow.game_session
	if session != null and is_instance_valid(session):
		var snapshot := session.collect_save_snapshot()
		for key in snapshot.keys():
			if not payload.has(key):
				payload[key] = snapshot[key]
	# 兜底默认（无会话场景，如自检直接写档）
	for key in SaveMigration.DATA_DEFAULTS.keys():
		if not payload.has(key):
			var value: Variant = SaveMigration.DATA_DEFAULTS[key]
			payload[key] = value.duplicate(true) if typeof(value) == TYPE_ARRAY or typeof(value) == TYPE_DICTIONARY else value
	if not payload.has("selected_class_id"):
		payload["selected_class_id"] = _current_class_id()


## ---- 版本迁移 ----

func _migrate(envelope: Dictionary) -> Dictionary:
	var version := int(envelope.get(KEY_VERSION, 0))
	if version < SAVE_VERSION:
		envelope = SaveMigration.migrate(envelope, version, SAVE_VERSION)
	envelope[KEY_VERSION] = maxi(version, SAVE_VERSION)
	var data: Variant = envelope.get(KEY_DATA, {})
	if typeof(data) == TYPE_DICTIONARY:
		envelope[KEY_DATA] = SaveMigration.migrate(data as Dictionary, int((data as Dictionary).get("save_version", 0)), SAVE_VERSION)
	return envelope


## ---- 自动存档轮换 ----

func _auto_path(auto_key: String) -> String:
	return "%s/%s.save" % [SAVE_DIR, auto_key]


## 选择最旧的自动存档槽（未满时用空槽）。
func _next_auto_slot_key() -> String:
	var oldest_key := "auto_1"
	var oldest_time := INF
	for index in range(1, AUTO_COUNT + 1):
		var key := "auto_%d" % index
		var path := _auto_path(key)
		if not FileAccess.file_exists(path):
			return key
		var envelope: Variant = _read_json_file(path)
		var save_time := 0.0
		if typeof(envelope) == TYPE_DICTIONARY:
			save_time = float((envelope as Dictionary).get(KEY_SAVE_TIME, 0.0))
		if save_time < oldest_time:
			oldest_time = save_time
			oldest_key = key
	return oldest_key


## ---- 内部工具 ----

func _is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


func _slot_path(slot: int) -> String:
	return "%s/slot_%d.save" % [SAVE_DIR, slot]


func _ensure_save_dir() -> bool:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		return true
	var err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		push_error("SaveService: 无法创建存档目录（错误码 %d）" % err)
		return false
	return true


func _current_class_id() -> String:
	var session := AppFlow.game_session
	if session == null or not is_instance_valid(session):
		return "dart_master"
	return session.selected_class_id


func _current_play_time() -> float:
	var session := AppFlow.game_session
	if session == null or not is_instance_valid(session):
		return 0.0
	return session.play_time


func _write_json_file(path: String, data: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: 无法写入 %s（错误码 %d）" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func _read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _delete_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(path) == OK
