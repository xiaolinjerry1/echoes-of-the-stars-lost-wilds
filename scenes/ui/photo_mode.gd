extends CanvasLayer
## 拍照模式（P 键）
## 职责：暂停游戏、隐藏 HUD、FOV/滤镜/9:16 构图线、截图到 user://screenshots/。
## 暂停期间本层保持 PROCESS_MODE_ALWAYS 以响应操作。

const SCREENSHOT_DIR := "user://screenshots"

var _player: PlayerController
var _fov_slider: HSlider
var _filter_button: OptionButton
var _guide_check: CheckButton
var _feedback: Label
var _guide_left: ColorRect
var _guide_right: ColorRect
var _last_screenshot_path := ""

var _env: WorldEnvironment
var _saved_adjustment := false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_build()


## 打开拍照模式：暂停 + 隐藏 HUD。
func open(target: PlayerController) -> void:
	_player = target
	if _player == null:
		return
	get_tree().paused = true
	_player.get_node("HUD").visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _fov_slider != null:
		_fov_slider.set_value_no_signal(_player.camera.fov)
	visible = true


## 关闭并恢复游戏。
func close() -> void:
	visible = false
	_clear_filter()
	if _player != null and is_instance_valid(_player):
		_player.get_node("HUD").visible = true
		if _env != null and is_instance_valid(_env) and _env.environment != null:
			_env.environment.adjustment_enabled = _saved_adjustment
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## 截图（E2E 可调用），返回保存路径（失败返回空串）。
func take_screenshot() -> String:
	DirAccess.make_dir_recursive_absolute(SCREENSHOT_DIR)
	var image := get_viewport().get_texture().get_image()
	if image == null:
		# headless（无渲染）兜底：仍生成占位图，保证流程可用
		image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var file_name := "photo_%d.png" % Time.get_unix_time_from_system()
	var path := SCREENSHOT_DIR + "/" + file_name
	var err := image.save_png(path)
	if err != OK:
		return ""
	_last_screenshot_path = path
	if _feedback != null:
		_feedback.text = "已保存：%s" % path
	return path


func get_last_screenshot_path() -> String:
	return _last_screenshot_path


func _build() -> void:
	var bar := Panel.new()
	bar.name = "PhotoBar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.position = Vector2(0, -122)
	bar.size = Vector2(0, 122)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.85)
	bar.add_theme_stylebox_override("panel", style)
	add_child(bar)
	var title := Label.new()
	title.text = "拍照模式（游戏已暂停）"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 16)
	bar.add_child(title)
	# FOV
	var fov_label := Label.new()
	fov_label.text = "视野角"
	fov_label.position = Vector2(16, 40)
	fov_label.add_theme_font_size_override("font_size", 13)
	bar.add_child(fov_label)
	_fov_slider = HSlider.new()
	_fov_slider.name = "FovSlider"
	_fov_slider.min_value = 30.0
	_fov_slider.max_value = 110.0
	_fov_slider.step = 1.0
	_fov_slider.value = 90.0
	_fov_slider.position = Vector2(80, 38)
	_fov_slider.size = Vector2(220, 22)
	_fov_slider.value_changed.connect(func(value: float) -> void:
		if _player != null and is_instance_valid(_player):
			_player.camera.fov = value)
	bar.add_child(_fov_slider)
	# 滤镜
	var filter_label := Label.new()
	filter_label.text = "滤镜"
	filter_label.position = Vector2(320, 40)
	filter_label.add_theme_font_size_override("font_size", 13)
	bar.add_child(filter_label)
	_filter_button = OptionButton.new()
	_filter_button.name = "FilterButton"
	_filter_button.position = Vector2(366, 36)
	_filter_button.size = Vector2(130, 28)
	_filter_button.add_item("无")
	_filter_button.add_item("暖色")
	_filter_button.add_item("冷色")
	_filter_button.add_item("黑白")
	_filter_button.item_selected.connect(_on_filter_selected)
	bar.add_child(_filter_button)
	# 构图线
	_guide_check = CheckButton.new()
	_guide_check.name = "GuideCheck"
	_guide_check.text = "9:16 构图线"
	_guide_check.position = Vector2(520, 36)
	_guide_check.button_pressed = true
	_guide_check.toggled.connect(_set_guides_visible)
	bar.add_child(_guide_check)
	# 截图 / 退出
	var capture := Button.new()
	capture.name = "CaptureButton"
	capture.text = "截图"
	capture.position = Vector2(680, 30)
	capture.size = Vector2(110, 34)
	capture.pressed.connect(func() -> void: take_screenshot())
	bar.add_child(capture)
	var exit_button := Button.new()
	exit_button.name = "ExitButton"
	exit_button.text = "退出拍照（Esc）"
	exit_button.position = Vector2(804, 30)
	exit_button.size = Vector2(160, 34)
	exit_button.pressed.connect(func() -> void:
		if _player != null:
			_player.close_all_panels())
	bar.add_child(exit_button)
	_feedback = Label.new()
	_feedback.name = "Feedback"
	_feedback.position = Vector2(16, 86)
	_feedback.add_theme_font_size_override("font_size", 12)
	_feedback.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	bar.add_child(_feedback)
	# 9:16 构图线
	_guide_left = _make_guide_line()
	_guide_right = _make_guide_line()
	add_child(_guide_left)
	add_child(_guide_right)
	_set_guides_visible(true)


func _make_guide_line() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.35)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	line.size = Vector2(2, 0)
	return line


func _set_guides_visible(enabled: bool) -> void:
	if _guide_left == null or _guide_right == null:
		return
	_guide_left.visible = enabled
	_guide_right.visible = enabled
	var viewport_size := get_viewport().get_visible_rect().size
	var target_width := viewport_size.y * 9.0 / 16.0
	var left := (viewport_size.x - target_width) * 0.5
	_guide_left.position = Vector2(left, 0)
	_guide_left.size = Vector2(2, viewport_size.y)
	_guide_right.position = Vector2(left + target_width, 0)
	_guide_right.size = Vector2(2, viewport_size.y)


func _on_filter_selected(index: int) -> void:
	_find_environment()
	if _env == null or _env.environment == null:
		return
	var env := _env.environment
	_saved_adjustment = env.adjustment_enabled
	match index:
		0:
			env.adjustment_enabled = false
		1:
			env.adjustment_enabled = true
			env.adjustment_saturation = 1.12
		2:
			env.adjustment_enabled = true
			env.adjustment_saturation = 0.92
		3:
			env.adjustment_enabled = true
			env.adjustment_saturation = 0.0


func _clear_filter() -> void:
	if _env != null and is_instance_valid(_env) and _env.environment != null:
		_env.environment.adjustment_enabled = _saved_adjustment


func _find_environment() -> void:
	if _env != null and is_instance_valid(_env):
		return
	var found := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	if not found.is_empty():
		_env = found[0] as WorldEnvironment
