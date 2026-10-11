extends CanvasLayer
## 暂停菜单（Esc 打开）
## 职责：继续游戏 / 手动保存到 3 个档位（战斗中禁用）/ 读取档位 / 设置 /
## 返回主菜单（确认丢失未保存进度）/ 退出游戏。

var _player: PlayerController
var _save_buttons: Array = []
var _load_buttons: Array = []
var _settings_panel: SettingsPanel
var _confirm_dialog: ConfirmationDialog
var _feedback: Label
var _timer := 0.0


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_build()


func open(target: PlayerController) -> void:
	_player = target
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	_timer = 0.0
	set_process(true)


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	# 战斗中状态变化时刷新保存按钮可用性
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	_refresh_save_buttons()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.72)
	add_child(dim)
	var frame := Panel.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-300, -250)
	frame.size = Vector2(600, 500)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.13, 0.97)
	style.border_color = Color(0.45, 0.5, 0.56, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	var title := Label.new()
	title.name = "Title"
	title.text = "暂停"
	title.position = Vector2(24, 14)
	title.add_theme_font_size_override("font_size", 26)
	frame.add_child(title)
	var buttons := VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.position = Vector2(24, 58)
	buttons.size = Vector2(552, 300)
	buttons.add_theme_constant_override("separation", 10)
	frame.add_child(buttons)
	var resume := _make_button("继续游戏")
	resume.name = "ResumeButton"
	resume.pressed.connect(func() -> void:
		if _player != null:
			_player.close_all_panels())
	buttons.add_child(resume)
	# 手动保存到 3 个档位
	var save_row := HBoxContainer.new()
	save_row.name = "SaveRow"
	save_row.add_theme_constant_override("separation", 8)
	buttons.add_child(save_row)
	var save_label := Label.new()
	save_label.text = "保存到："
	save_label.custom_minimum_size = Vector2(96, 40)
	save_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	save_row.add_child(save_label)
	for slot in range(1, 4):
		var save_button := _make_button("档位 %d" % slot)
		save_button.name = "SaveSlot%d" % slot
		save_button.custom_minimum_size = Vector2(120, 40)
		save_button.pressed.connect(_on_save_pressed.bind(slot))
		save_row.add_child(save_button)
		_save_buttons.append(save_button)
	# 读取档位
	var load_row := HBoxContainer.new()
	load_row.name = "LoadRow"
	load_row.add_theme_constant_override("separation", 8)
	buttons.add_child(load_row)
	var load_label := Label.new()
	load_label.text = "读取："
	load_label.custom_minimum_size = Vector2(96, 40)
	load_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	load_row.add_child(load_label)
	for slot in range(1, 4):
		var load_button := _make_button("查看档位 %d" % slot)
		load_button.name = "LoadSlot%d" % slot
		load_button.custom_minimum_size = Vector2(120, 40)
		load_button.pressed.connect(_on_load_pressed.bind(slot))
		load_row.add_child(load_button)
		_load_buttons.append(load_button)
	var settings_button := _make_button("设置")
	settings_button.name = "SettingsButton"
	settings_button.pressed.connect(_on_settings_pressed)
	buttons.add_child(settings_button)
	var title_button := _make_button("返回主菜单")
	title_button.name = "TitleButton"
	title_button.pressed.connect(_on_title_pressed)
	buttons.add_child(title_button)
	var quit_button := _make_button("退出游戏")
	quit_button.name = "QuitButton"
	quit_button.pressed.connect(func() -> void: AppFlow.quit_game())
	buttons.add_child(quit_button)
	_feedback = Label.new()
	_feedback.name = "Feedback"
	_feedback.position = Vector2(24, 430)
	_feedback.size = Vector2(552, 30)
	_feedback.add_theme_font_size_override("font_size", 14)
	_feedback.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	frame.add_child(_feedback)
	_settings_panel = preload("res://scenes/ui/settings_panel.tscn").instantiate() as SettingsPanel
	add_child(_settings_panel)
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.name = "ConfirmDialog"
	_confirm_dialog.title = "返回主菜单"
	_confirm_dialog.dialog_text = "未保存的进度将丢失，确定返回主菜单吗？"
	_confirm_dialog.ok_button_text = "确定返回"
	_confirm_dialog.cancel_button_text = "取消"
	_confirm_dialog.confirmed.connect(func() -> void:
		AppFlow.return_to_title())
	frame.add_child(_confirm_dialog)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(552, 40)
	button.add_theme_font_size_override("font_size", 17)
	return button


func _refresh() -> void:
	_refresh_save_buttons()
	_refresh_load_buttons()


func _refresh_save_buttons() -> void:
	var session := get_tree().get_first_node_in_group("game_session") as GameSession
	var in_combat := session != null and session.is_in_combat()
	for button in _save_buttons:
		button.disabled = in_combat
		button.tooltip_text = "战斗中无法保存" if in_combat else ""


func _refresh_load_buttons() -> void:
	for index in _load_buttons.size():
		var slot := index + 1
		var button: Button = _load_buttons[index]
		var summary := SaveService.get_save_summary(slot)
		if not bool(summary.get("exists", false)):
			button.text = "档位 %d：空" % slot
			button.disabled = true
			continue
		button.disabled = false
		var class_name_text := _display_name_for_class(str(summary.get("class_id", "warrior")))
		var spirit_name := _display_name_for_spirit(str(summary.get("spirit_id", "")))
		button.text = "档位 %d：%s·%s Lv.%d" % [slot, class_name_text, spirit_name, int(summary.get("spirit_level", 1))]
		button.tooltip_text = "保存于 %s · 游玩 %s" % [
			str(summary.get("save_time", 0.0)),
			_format_play_time(float(summary.get("play_time", 0.0))),
		]


func _display_name_for_class(class_id: String) -> String:
	var data := DataRegistry.get_class_def(class_id)
	return data.display_name if data != null else class_id


func _display_name_for_spirit(spirit_id: String) -> String:
	var data := DataRegistry.get_spirit(spirit_id)
	return data.display_name if data != null else "无精灵"


func _format_play_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d 分 %d 秒" % [total / 60, total % 60]


func _on_save_pressed(slot: int) -> void:
	var session := get_tree().get_first_node_in_group("game_session") as GameSession
	if session != null and session.is_in_combat():
		_feedback.text = "战斗中无法保存"
		_feedback.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		return
	if SaveService.save_game(slot):
		_feedback.text = "已保存到档位 %d" % slot
		_feedback.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		_refresh_load_buttons()
	else:
		_feedback.text = "保存失败"
		_feedback.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))


func _on_load_pressed(slot: int) -> void:
	if SaveService.has_save(slot):
		AppFlow.continue_game(slot)


func _on_settings_pressed() -> void:
	if _settings_panel != null:
		_settings_panel.open()


func _on_title_pressed() -> void:
	if _confirm_dialog != null:
		_confirm_dialog.popup_centered()
