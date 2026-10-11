extends Control
## 主菜单
## 职责：标题/副标题、渐变背景 + 漂浮粒子、新游戏/继续游戏/设置/退出按钮、版本号。

const CHARACTER_SELECT_PATH := "res://scenes/app/character_select.tscn"

var _continue_button: Button
var _settings_panel: SettingsPanel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_content()
	_settings_panel = preload("res://scenes/ui/settings_panel.tscn").instantiate() as SettingsPanel
	add_child(_settings_panel)
	_refresh_continue_button()


func _unhandled_input(event: InputEvent) -> void:
	if _settings_panel != null and _settings_panel.visible:
		return  # 由设置面板自己处理 Esc
	if event.is_action_pressed("ui_cancel"):
		_settings_panel.open()


func _build_background() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.05, 0.07, 0.14))
	gradient.set_color(1, Color(0.10, 0.16, 0.20))
	gradient.add_point(0.55, Color(0.07, 0.11, 0.18))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 1.0)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 8
	texture.height = 256
	var background := TextureRect.new()
	background.name = "Background"
	background.texture = texture
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var particles := GPUParticles2D.new()
	particles.name = "Motes"
	particles.amount = 48
	particles.lifetime = 9.0
	particles.preprocess = 4.0
	particles.position = Vector2(640, 380)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, -1, 0)
	process.spread = 30.0
	process.initial_velocity_min = 6.0
	process.initial_velocity_max = 16.0
	process.gravity = Vector3(0, -2.0, 0)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(640, 360, 1)
	process.scale_min = 0.4
	process.scale_max = 1.2
	particles.process_material = process
	var dot := GradientTexture2D.new()
	var dot_gradient := Gradient.new()
	dot_gradient.set_color(0, Color(0.9, 0.95, 1.0, 0.0))
	dot_gradient.set_color(1, Color(0.9, 0.95, 1.0, 0.0))
	dot_gradient.add_point(0.5, Color(0.9, 0.95, 1.0, 0.8))
	dot.gradient = dot_gradient
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 24
	dot.height = 24
	particles.texture = dot
	add_child(particles)


func _build_content() -> void:
	var title := Label.new()
	title.name = "Title"
	title.text = "群星回响"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-320, 96)
	title.size = Vector2(640, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	add_child(title)
	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "失落原野"
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(-320, 186)
	subtitle.size = Vector2(640, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 30)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	add_child(subtitle)
	var buttons := VBoxContainer.new()
	buttons.name = "MenuButtons"
	buttons.set_anchors_preset(Control.PRESET_CENTER)
	buttons.position = Vector2(-140, 20)
	buttons.size = Vector2(280, 260)
	buttons.add_theme_constant_override("separation", 14)
	add_child(buttons)
	var new_game := _make_button("新的游戏")
	new_game.name = "NewGameButton"
	new_game.pressed.connect(func() -> void: get_tree().change_scene_to_file(CHARACTER_SELECT_PATH))
	buttons.add_child(new_game)
	_continue_button = _make_button("继续游戏")
	_continue_button.name = "ContinueButton"
	_continue_button.pressed.connect(_on_continue_pressed)
	buttons.add_child(_continue_button)
	var settings := _make_button("设置")
	settings.name = "SettingsButton"
	settings.pressed.connect(func() -> void: _settings_panel.open())
	buttons.add_child(settings)
	var quit_button := _make_button("退出游戏")
	quit_button.name = "QuitButton"
	quit_button.pressed.connect(func() -> void: AppFlow.quit_game())
	buttons.add_child(quit_button)
	var version := Label.new()
	version.name = "VersionLabel"
	version.text = str(ProjectSettings.get_setting("application/config/version", "dev"))
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position = Vector2(-210, -36)
	version.size = Vector2(190, 24)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.add_theme_font_size_override("font_size", 13)
	version.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	add_child(version)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 46)
	button.add_theme_font_size_override("font_size", 20)
	return button


func _refresh_continue_button() -> void:
	if _continue_button == null:
		return
	var slot := _find_latest_slot()
	_continue_button.disabled = slot <= 0
	if slot <= 0:
		_continue_button.text = "继续游戏"
		return
	var summary := SaveService.get_save_summary(slot)
	_continue_button.text = "继续游戏 · 飞镖师 Lv.%d" % int(summary.get("spirit_level",1))
	_continue_button.tooltip_text = "档位 %d · 游玩 %s" % [slot, _format_play_time(float(summary.get("play_time", 0.0)))]


func _format_play_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d 分 %d 秒" % [total / 60, total % 60]


func _find_latest_slot() -> int:
	for slot in [3, 2, 1]:
		if SaveService.has_save(slot):
			return slot
	return 0


func _on_continue_pressed() -> void:
	var slot := _find_latest_slot()
	if slot <= 0:
		return
	AppFlow.continue_game(slot)
