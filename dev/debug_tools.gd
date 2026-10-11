extends Node
## DebugTools（开发调试工具，Autoload）
## 职责：开发期快捷操作，方便逐项验收；正式发行版可移除本 Autoload。
## 快捷键：F1 调试面板 / F2 回满 / F3 +1000 金币与基础装备 / F4 解锁全部回响 /
## F5 传送回营地 / F6 切换昼夜（天气切换为 F7）。

var _overlay: CanvasLayer
var _label: Label
var _overlay_visible := false


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _process(_delta: float) -> void:
	if not _overlay_visible or _label == null:
		return
	var player := get_player()
	var lines: Array[String] = [
		"FPS: %d" % Engine.get_frames_per_second(),
	]
	if player != null:
		lines.append("坐标: %.1f, %.1f, %.1f" % [player.global_position.x, player.global_position.y, player.global_position.z])
		lines.append("生命: %d/%d  战意: %d/%d" % [
			roundi(player.stats.current_health), roundi(player.stats.max_health),
			roundi(player.stats.current_focus), roundi(player.stats.max_focus),
		])
		if player.echo_system != null:
			lines.append("回响能量: %d  激活: %s" % [
				roundi(player.echo_system.current_energy),
				player.echo_system.get_active_echo_name() if player.echo_system.is_active() else "无",
			])
	var session := AppFlow.game_session
	if session != null and is_instance_valid(session):
		lines.append("世界: %s  游玩: %.0f 秒" % [session.current_world_id, session.play_time])
	lines.append("敌人: %d" % get_tree().get_nodes_in_group("enemy").size())
	_label.text = "\n".join(lines)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F1:
			toggle_overlay()
		KEY_F2:
			heal_full()
		KEY_F3:
			grant_gold_and_gear()
		KEY_F4:
			unlock_all_echoes()
		KEY_F5:
			teleport_to_camp()
		KEY_F6:
			cycle_day_night()


func get_player() -> PlayerController:
	var session := AppFlow.game_session
	if session == null or not is_instance_valid(session):
		return null
	return session.get_player()


## F1：调试面板（FPS / 坐标 / 状态 / 能量 / 敌人数量）。
func toggle_overlay() -> void:
	_overlay_visible = not _overlay_visible
	if _overlay == null:
		_overlay = CanvasLayer.new()
		_overlay.name = "DebugOverlay"
		_overlay.layer = 95
		_label = Label.new()
		_label.name = "DebugLabel"
		_label.position = Vector2(12, 6)
		_label.add_theme_font_size_override("font_size", 14)
		_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_label.add_theme_constant_override("outline_size", 5)
		_overlay.add_child(_label)
		add_child(_overlay)
	_overlay.visible = _overlay_visible


## F2：回满生命与专注。
func heal_full() -> void:
	var player := get_player()
	if player == null:
		return
	player.stats.heal(player.stats.max_health)
	player.stats.current_focus = player.stats.max_focus
	player.show_combat_feedback("调试：生命与专注已回满", Color(0.6, 1.0, 0.6))


## F3：+1000 金币与全部基础装备。
func grant_gold_and_gear() -> void:
	var player := get_player()
	if player != null:player.survivor.add_experience(player.stats.get_exp_to_next_level())


## F4：解锁全部回响。
func unlock_all_echoes() -> void:
	var player := get_player()
	if player != null:player.survivor.echo_value=100.0


## F5：传送回营地篝火。
func teleport_to_camp() -> void:
	var player := get_player()
	if player == null:
		return
	player.global_position = WorldLayout.CAMPFIRE + Vector3(0.0, 0.5, 2.5)
	player.velocity = Vector3.ZERO
	player.show_combat_feedback("调试：已传送回营地", Color(0.8, 0.9, 1.0))


## F6：昼夜切换（+12 小时循环）。
func cycle_day_night() -> void:
	var day_night := get_tree().get_first_node_in_group("day_night")
	if day_night == null:
		return
	var hours := float(day_night.call("get_hours"))
	day_night.call("set_time_of_day", fposmod(hours + 12.0, 24.0))
