extends Node
## AppFlow（应用流程单例，Autoload）
## 职责：主菜单 → 游戏会话 → 返回标题 → 退出的整体流程控制。
## 持有当前 GameSession 根节点引用；不处理任何战斗逻辑。

const MAIN_MENU_SCENE_PATH := "res://scenes/app/main_menu.tscn"
const GAME_SESSION_SCENE_PATH := "res://scenes/app/game_session.tscn"

## 当前游戏会话根节点（未进入游戏时为 null）
var game_session: GameSession = null


## 开始新游戏：按所选职业与精灵创建并初始化游戏会话。
func start_new_game(class_id: String, spirit_id := "", spirit_level := 1) -> void:
	_destroy_session()

	var packed_scene := load(GAME_SESSION_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("AppFlow: 无法加载游戏会话场景 %s" % GAME_SESSION_SCENE_PATH)
		return

	# 本帧末替换当前场景（主菜单）
	get_tree().change_scene_to_packed(packed_scene)
	await get_tree().scene_changed

	game_session = get_tree().current_scene as GameSession
	if game_session == null:
		push_error("AppFlow: 游戏会话场景根节点类型不正确")
		return
	game_session.initialize(class_id, spirit_id, spirit_level)


## 继续游戏：读取指定存档（slot ≤ 0 时自动选择最近存档）并恢复进度。
func continue_game(slot := 0) -> bool:
	var target_slot := slot
	if target_slot <= 0:
		target_slot = _find_latest_save_slot()
	if target_slot <= 0:
		return false
	var payload: Dictionary = SaveService.load_game(target_slot)
	if payload.is_empty():
		return false
	var class_id := str(payload.get("selected_class_id", "dart_master"))
	if class_id.is_empty():
		class_id = "dart_master"
	var spirit_id := str(payload.get("selected_spirit_id", "glow_wisp"))
	var level := int(payload.get("spirit_level", 1))
	await start_new_game(class_id, spirit_id, maxi(level, 1))
	if game_session == null:
		return false
	game_session.apply_saved_payload(payload)
	return true


## 最近存档槽位（无存档返回 0）。
func _find_latest_save_slot() -> int:
	for candidate in [3, 2, 1]:
		if SaveService.has_save(candidate):
			return candidate
	return 0


## 返回标题画面并清理当前会话。
func return_to_title() -> void:
	_destroy_session()
	var err := get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if err != OK:
		push_error("AppFlow: 无法返回主菜单（错误码 %d）" % err)


## 退出游戏。
func quit_game() -> void:
	get_tree().quit()


## 清理并释放当前会话（内部使用）。
func _destroy_session() -> void:
	get_tree().paused = false
	if game_session != null and is_instance_valid(game_session):
		game_session.clear_session()
		game_session.queue_free()
	game_session = null
