class_name MapPanel
extends Control
## 地图面板（M 键）
## 职责：森林区域俯视图（4 分块色块）、已探索区域高亮、营地/秘境/任务目标标记、
## 玩家位置箭头（跟随视角朝向）；Esc/关闭按钮退出。

const MAP_SIZE := 512.0

var _player: PlayerController
var _canvas: Control
var _title: Label


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func setup(player: PlayerController) -> void:
	_player = player


func open_panel() -> void:
	visible = true
	refresh()


func close_panel() -> void:
	visible = false
	if _player != null and _player.survivor_mode:
		get_tree().paused=false
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED


func refresh() -> void:
	_canvas.queue_redraw()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-MAP_SIZE * 0.5 - 18, -MAP_SIZE * 0.5 - 52)
	frame.size = Vector2(MAP_SIZE + 36, MAP_SIZE + 104)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	style.border_color = Color(0.45, 0.5, 0.55, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	_title = Label.new()
	_title.name = "MapTitle"
	_title.text = "晨露林地 · 地图"
	_title.position = Vector2(18, 10)
	_title.add_theme_font_size_override("font_size", 22)
	frame.add_child(_title)
	var hint := Label.new()
	hint.text = "M / Esc 关闭 · 已探索区域高亮"
	hint.position = Vector2(18, MAP_SIZE + 70)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	frame.add_child(hint)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "关闭"
	close_button.position = Vector2(MAP_SIZE - 70, 8)
	close_button.size = Vector2(72, 28)
	close_button.pressed.connect(func() -> void: close_panel())
	frame.add_child(close_button)
	_canvas = Control.new()
	_canvas.name = "MapCanvas"
	_canvas.position = Vector2(18, 46)
	_canvas.size = Vector2(MAP_SIZE, MAP_SIZE)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	frame.add_child(_canvas)


func _world_to_map(world_pos: Vector3) -> Vector2:
	var uv := Vector2(
		(world_pos.x + WorldLayout.HALF) / WorldLayout.SIZE,
		(world_pos.z + WorldLayout.HALF) / WorldLayout.SIZE
	)
	return Vector2(uv.x * MAP_SIZE, uv.y * MAP_SIZE)


func _draw_map() -> void:
	var explored := _explored_quadrants()
	var half := MAP_SIZE * 0.5
	for cx in 2:
		for cz in 2:
			var cell := "%d%d" % [cx, cz]
			var base := Color(0.13, 0.18, 0.14) if explored.has(cell) else Color(0.07, 0.08, 0.1)
			_canvas.draw_rect(Rect2(cx * half, cz * half, half, half), base, true)
			_canvas.draw_rect(Rect2(cx * half, cz * half, half, half), Color(0.3, 0.35, 0.32, 0.5), false, 1.0)
	# 地标
	_draw_marker(WorldLayout.CAMP, "营", Color(1.0, 0.85, 0.4))
	_draw_marker(WorldLayout.GROVE, "兽", Color(0.95, 0.65, 0.2))
	_draw_marker(WorldLayout.WYVERN_NEST, "龙", Color(1.0, 0.25, 0.1))
	_draw_marker(WorldLayout.OBSERVATORY, "塔", Color(0.6, 0.75, 1.0))
	for marker in get_tree().get_nodes_in_group("quest_marker"):
		if marker is Node3D and marker.has_meta("quest_marker_id"):
			_draw_marker((marker as Node3D).global_position, "!", Color(1.0, 0.5, 0.35))
	# 玩家箭头
	if _player != null and is_instance_valid(_player):
		var pos := _world_to_map(_player.global_position)
		var forward := -_player.camera.global_transform.basis.z
		var angle := atan2(forward.x, forward.z)
		var arrow := PackedVector2Array()
		arrow.append(pos + Vector2(sin(angle), -cos(angle)) * 9.0)
		arrow.append(pos + Vector2(sin(angle + 2.5), -cos(angle + 2.5)) * 7.0)
		arrow.append(pos + Vector2(sin(angle - 2.5), -cos(angle - 2.5)) * 7.0)
		_canvas.draw_colored_polygon(arrow, Color(1.0, 0.95, 0.6))


func _draw_marker(world_pos: Vector3, letter: String, color: Color) -> void:
	var pos := _world_to_map(world_pos)
	_canvas.draw_rect(Rect2(pos.x - 7, pos.y - 7, 14, 14), Color(0.05, 0.06, 0.08, 0.9), true)
	_canvas.draw_rect(Rect2(pos.x - 7, pos.y - 7, 14, 14), color, false, 2.0)
	_canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(-5, 5), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, color)


func _explored_quadrants() -> Array:
	var session := get_tree().get_first_node_in_group("game_session") as GameSession
	if session == null:
		return ["00", "01", "10", "11"]
	return session.world_data.get("explored_quadrants", ["00"])
