class_name SettingsPanel
extends Control
## 设置面板（画面 / 音频 / 操作 / 辅助 / 游戏说明）
## 职责：读写 SettingsService；分辨率/全屏即时应用（headless 下跳过窗口操作）。

signal closed

var _tabs: TabContainer
var _resolution_button: OptionButton
var _fullscreen_check: CheckButton
var _quality_button: OptionButton
var _fov_slider: HSlider
var _fov_value: Label
var _blur_check: CheckButton
var _shake_check: CheckButton
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _sens_slider: HSlider
var _invert_check: CheckButton
var _colorblind_button: OptionButton
var _subtitle_button: OptionButton
var _assist_check: CheckButton
var _shake_scale_slider: HSlider


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


## ---- 构建 ----


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.75)
	add_child(dim)
	var frame := Panel.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-380, -290)
	frame.size = Vector2(760, 580)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.13, 0.98)
	style.border_color = Color(0.45, 0.5, 0.56, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	var title := Label.new()
	title.text = "设置"
	title.position = Vector2(20, 12)
	title.add_theme_font_size_override("font_size", 24)
	frame.add_child(title)
	_tabs = TabContainer.new()
	_tabs.name = "Tabs"
	_tabs.position = Vector2(16, 48)
	_tabs.size = Vector2(728, 470)
	frame.add_child(_tabs)
	_build_display_tab()
	_build_audio_tab()
	_build_input_tab()
	_build_accessibility_tab()
	_build_help_tab()
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "关闭（Esc）"
	close_button.position = Vector2(500, 528)
	close_button.size = Vector2(120, 36)
	close_button.pressed.connect(close)
	frame.add_child(close_button)
	var reset_button := Button.new()
	reset_button.name = "ResetButton"
	reset_button.text = "恢复默认"
	reset_button.position = Vector2(630, 528)
	reset_button.size = Vector2(110, 36)
	reset_button.pressed.connect(func() -> void:
		SettingsService.reset_to_default()
		_refresh())
	frame.add_child(reset_button)


func _make_row(parent: Control, label_text: String, y: float) -> Label:
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(18, y + 4)
	label.size = Vector2(150, 24)
	label.add_theme_font_size_override("font_size", 15)
	parent.add_child(label)
	return label


func _build_display_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "画面"
	_tabs.add_child(tab)
	var row_a := Control.new()
	row_a.custom_minimum_size = Vector2(0, 40)
	tab.add_child(row_a)
	_make_row(row_a, "分辨率", 0)
	_resolution_button = OptionButton.new()
	_resolution_button.name = "ResolutionButton"
	_resolution_button.position = Vector2(180, 2)
	_resolution_button.size = Vector2(180, 30)
	for res in ["1280x720", "1920x1080", "2560x1440"]:
		_resolution_button.add_item(res)
	_resolution_button.item_selected.connect(func(_i: int) -> void: _apply_resolution())
	row_a.add_child(_resolution_button)
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.name = "FullscreenCheck"
	_fullscreen_check.text = "全屏"
	_fullscreen_check.position = Vector2(400, 0)
	_fullscreen_check.toggled.connect(func(enabled: bool) -> void:
		SettingsService.set_setting("display/window_mode", "fullscreen" if enabled else "windowed")
		_apply_resolution())
	row_a.add_child(_fullscreen_check)
	var row_b := Control.new()
	row_b.custom_minimum_size = Vector2(0, 40)
	tab.add_child(row_b)
	_make_row(row_b, "画质预设", 0)
	_quality_button = OptionButton.new()
	_quality_button.name = "QualityButton"
	_quality_button.position = Vector2(180, 2)
	_quality_button.size = Vector2(180, 30)
	_quality_button.add_item("低")
	_quality_button.add_item("中")
	_quality_button.add_item("高")
	_quality_button.item_selected.connect(func(index: int) -> void:
		SettingsService.set_setting("display/quality", ["low", "medium", "high"][index]))
	row_b.add_child(_quality_button)
	var row_c := Control.new()
	row_c.custom_minimum_size = Vector2(0, 40)
	tab.add_child(row_c)
	_make_row(row_c, "视野角", 0)
	_fov_slider = HSlider.new()
	_fov_slider.name = "FovSlider"
	_fov_slider.min_value = 60.0
	_fov_slider.max_value = 110.0
	_fov_slider.step = 1.0
	_fov_slider.position = Vector2(180, 2)
	_fov_slider.size = Vector2(240, 26)
	_fov_slider.value_changed.connect(func(value: float) -> void:
		if _fov_value != null:
			_fov_value.text = "%d°" % roundi(value)
		SettingsService.set_setting("display/fov", value))
	row_c.add_child(_fov_slider)
	_fov_value = Label.new()
	_fov_value.position = Vector2(430, 4)
	_fov_value.add_theme_font_size_override("font_size", 14)
	row_c.add_child(_fov_value)
	var row_d := Control.new()
	row_d.custom_minimum_size = Vector2(0, 40)
	tab.add_child(row_d)
	_make_row(row_d, "动态模糊", 0)
	_blur_check = CheckButton.new()
	_blur_check.name = "MotionBlurCheck"
	_blur_check.position = Vector2(180, 0)
	_blur_check.toggled.connect(func(enabled: bool) -> void: SettingsService.set_setting("display/motion_blur", enabled))
	row_d.add_child(_blur_check)
	var row_e := Control.new()
	row_e.custom_minimum_size = Vector2(0, 40)
	tab.add_child(row_e)
	_make_row(row_e, "镜头晃动", 0)
	_shake_check = CheckButton.new()
	_shake_check.name = "CameraEffectsCheck"
	_shake_check.position = Vector2(180, 0)
	_shake_check.toggled.connect(func(enabled: bool) -> void: SettingsService.set_setting("display/enable_camera_effects", enabled))
	row_e.add_child(_shake_check)


func _build_audio_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "音频"
	_tabs.add_child(tab)
	for entry in [
		{"key": "audio/master_volume", "label": "主音量"},
		{"key": "audio/music_volume", "label": "音乐音量"},
		{"key": "audio/sfx_volume", "label": "音效音量"},
	]:
		var row := Control.new()
		row.custom_minimum_size = Vector2(0, 46)
		tab.add_child(row)
		_make_row(row, str(entry["label"]), 6)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.position = Vector2(180, 8)
		slider.size = Vector2(340, 28)
		var key := str(entry["key"])
		slider.value_changed.connect(func(value: float) -> void: SettingsService.set_setting(key, value / 100.0))
		row.add_child(slider)
		match key:
			"audio/master_volume":
				_master_slider = slider
			"audio/music_volume":
				_music_slider = slider
			"audio/sfx_volume":
				_sfx_slider = slider


func _build_input_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "操作"
	_tabs.add_child(tab)
	var row_a := Control.new()
	row_a.custom_minimum_size = Vector2(0, 46)
	tab.add_child(row_a)
	_make_row(row_a, "鼠标灵敏度", 6)
	_sens_slider = HSlider.new()
	_sens_slider.name = "SensitivitySlider"
	_sens_slider.min_value = 0.5
	_sens_slider.max_value = 6.0
	_sens_slider.step = 0.1
	_sens_slider.position = Vector2(180, 8)
	_sens_slider.size = Vector2(340, 28)
	_sens_slider.value_changed.connect(func(value: float) -> void: SettingsService.set_setting("input/mouse_sensitivity", value / 1000.0))
	row_a.add_child(_sens_slider)
	var row_b := Control.new()
	row_b.custom_minimum_size = Vector2(0, 40)
	tab.add_child(row_b)
	_make_row(row_b, "反转 Y 轴", 0)
	_invert_check = CheckButton.new()
	_invert_check.name = "InvertYCheck"
	_invert_check.position = Vector2(180, 0)
	_invert_check.toggled.connect(func(enabled: bool) -> void: SettingsService.set_setting("input/invert_y_axis", enabled))
	row_b.add_child(_invert_check)
	var note := Label.new()
	note.position = Vector2(18, 100)
	note.text = "按键重绑定：将在后续版本开放（当前为默认键位）"
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	tab.add_child(note)


func _build_accessibility_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "辅助"
	_tabs.add_child(tab)
	var row_a := Control.new()
	row_a.custom_minimum_size = Vector2(0, 40)
	tab.add_child(row_a)
	_make_row(row_a, "色觉模式", 0)
	_colorblind_button = OptionButton.new()
	_colorblind_button.name = "ColorblindButton"
	_colorblind_button.position = Vector2(180, 2)
	_colorblind_button.size = Vector2(180, 30)
	for mode_name in ["关闭", "红绿辅助", "蓝黄辅助"]:
		_colorblind_button.add_item(mode_name)
	_colorblind_button.item_selected.connect(func(index: int) -> void:
		SettingsService.set_setting("accessibility/colorblind_mode", ["关闭", "红绿辅助", "蓝黄辅助"][index]))
	row_a.add_child(_colorblind_button)
	var row_b := Control.new()
	row_b.custom_minimum_size = Vector2(0, 40)
	tab.add_child(row_b)
	_make_row(row_b, "字幕大小", 0)
	_subtitle_button = OptionButton.new()
	_subtitle_button.name = "SubtitleSizeButton"
	_subtitle_button.position = Vector2(180, 2)
	_subtitle_button.size = Vector2(180, 30)
	for size_name in ["小", "中", "大"]:
		_subtitle_button.add_item(size_name)
	_subtitle_button.item_selected.connect(func(index: int) -> void:
		SettingsService.set_setting("accessibility/subtitle_size", ["小", "中", "大"][index]))
	row_b.add_child(_subtitle_button)
	var row_c := Control.new()
	row_c.custom_minimum_size = Vector2(0, 40)
	tab.add_child(row_c)
	_make_row(row_c, "辅助模式", 0)
	_assist_check = CheckButton.new()
	_assist_check.name = "AssistCheck"
	_assist_check.position = Vector2(180, 0)
	_assist_check.toggled.connect(func(enabled: bool) -> void: SettingsService.set_setting("accessibility/assist_mode", enabled))
	row_c.add_child(_assist_check)
	var hint := Label.new()
	hint.position = Vector2(18, 128)
	hint.text = "辅助模式：降低受到的伤害压力、延长敌人预警时间。"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	tab.add_child(hint)
	var row_d := Control.new()
	row_d.custom_minimum_size = Vector2(0, 46)
	tab.add_child(row_d)
	_make_row(row_d, "镜头晃动幅度", 6)
	_shake_scale_slider = HSlider.new()
	_shake_scale_slider.min_value = 0.0
	_shake_scale_slider.max_value = 150.0
	_shake_scale_slider.step = 10.0
	_shake_scale_slider.position = Vector2(180, 8)
	_shake_scale_slider.size = Vector2(340, 28)
	_shake_scale_slider.value_changed.connect(func(value: float) -> void: SettingsService.set_setting("accessibility/screen_shake_scale", value / 100.0))
	row_d.add_child(_shake_scale_slider)


func _build_help_tab() -> void:
	var tab := ScrollContainer.new()
	tab.name = "游戏说明"
	_tabs.add_child(tab)
	var help := Label.new()
	help.name = "HelpText"
	help.text = SettingsService.game_help_text
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(700, 0)
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.9, 0.9, 0.88))
	tab.add_child(help)


## ---- 读写 ----


func _refresh() -> void:
	_resolution_button.select(["1280x720", "1920x1080", "2560x1440"].find(str(SettingsService.get_setting("display/resolution", "1280x720"))))
	_fullscreen_check.set_pressed_no_signal(str(SettingsService.get_setting("display/window_mode", "windowed")) == "fullscreen")
	var quality_index := ["low", "medium", "high"].find(str(SettingsService.get_setting("display/quality", "high")))
	_quality_button.select(maxi(quality_index, 0))
	var fov := float(SettingsService.get_setting("display/fov", 90.0))
	_fov_slider.set_value_no_signal(fov)
	_fov_value.text = "%d°" % roundi(fov)
	_blur_check.set_pressed_no_signal(bool(SettingsService.get_setting("display/motion_blur", true)))
	_shake_check.set_pressed_no_signal(bool(SettingsService.get_setting("display/enable_camera_effects", true)))
	_master_slider.set_value_no_signal(float(SettingsService.get_setting("audio/master_volume", 1.0)) * 100.0)
	_music_slider.set_value_no_signal(float(SettingsService.get_setting("audio/music_volume", 0.8)) * 100.0)
	_sfx_slider.set_value_no_signal(float(SettingsService.get_setting("audio/sfx_volume", 0.9)) * 100.0)
	_sens_slider.set_value_no_signal(float(SettingsService.get_setting("input/mouse_sensitivity", 0.002)) * 1000.0)
	_invert_check.set_pressed_no_signal(bool(SettingsService.get_setting("input/invert_y_axis", false)))
	_colorblind_button.select(["关闭", "红绿辅助", "蓝黄辅助"].find(str(SettingsService.get_setting("accessibility/colorblind_mode", "关闭"))))
	_subtitle_button.select(["小", "中", "大"].find(str(SettingsService.get_setting("accessibility/subtitle_size", "中"))))
	_assist_check.set_pressed_no_signal(bool(SettingsService.get_setting("accessibility/assist_mode", false)))
	_shake_scale_slider.set_value_no_signal(float(SettingsService.get_setting("accessibility/screen_shake_scale", 1.0)) * 100.0)


func _apply_resolution() -> void:
	SettingsService.set_setting("display/resolution", _resolution_button.get_item_text(_resolution_button.selected))
	SettingsService.set_setting("display/window_mode", "fullscreen" if _fullscreen_check.button_pressed else "windowed")
	if DisplayServer.get_name() == "headless":
		return
	if _fullscreen_check.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var parts := _resolution_button.get_item_text(_resolution_button.selected).split("x")
	if parts.size() == 2:
		DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
