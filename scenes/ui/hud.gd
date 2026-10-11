extends CanvasLayer
## HUD（游戏主界面）
## 职责：生命/专注/异常状态、技能栏（1/2/3 + Z/X 冷却遮罩）、回响区（图标/激活时间/能量）、
## 准星与交互提示、罗盘（方向 + 营地/秘境/任务地标）、任务追踪（主线金框）、精灵面板、
## 精英/BOSS 血条（对比秘境自带 BOSS 条则跳过苔冠巨兽）。
## 面板按键：HUD 常驻处理 Esc（暂停时关闭面板）；地图/拍照在玩家脚本处理。

const SLOT_SIZE := 52.0
const COMPASS_WIDTH := 520.0

var player: PlayerController = null

var _hp_bar: ProgressBar
var _hp_text: Label
var _focus_bar: ProgressBar
var _focus_text: Label
var _status_label_row: HBoxContainer
var _skill_slots: Array = []
var _dodge_pips: Array = []
var _crosshair: Control
var _compass: Control
var _quest_accent: ColorRect
var _elite_panel: Control
var _elite_name: Label
var _elite_bar: ProgressBar
var _echo_name_label: Label
var _ui_timer := 0.0
var _explore_timer := 0.0
var _save_toast: Label
var _save_toast_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_parent() as PlayerController
	_build_vitals()
	_build_skill_bar()
	_build_crosshair()
	_build_compass()
	_build_quest_panel()
	_build_echo_labels()
	_build_elite_bar()
	_build_save_toast()
	_reposition_legacy()
	SaveService.game_saved.connect(_on_game_saved)


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	# 仅处理「暂停中」的面板关闭（未暂停时由玩家脚本处理，避免双触发）
	if get_tree().paused and event.is_action_pressed("ui_cancel"):
		player.close_all_panels()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if player == null or player.stats == null:
		return
	if _save_toast_timer > 0.0:
		_save_toast_timer -= delta
		if _save_toast_timer <= 0.0 and _save_toast != null:
			_save_toast.visible = false
	_update_vitals()
	_update_skill_bar()
	_update_echo_labels()
	_update_elite_bar()
	_update_quest_accent()
	_compass.queue_redraw()
	_explore_timer -= delta
	if _explore_timer <= 0.0:
		_explore_timer = 1.0
		_mark_explored()


## ---- 生命/专注/状态 ----


func _build_vitals() -> void:
	var box := Control.new()
	box.name = "VitalsBox"
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.position = Vector2(16, -104)
	box.size = Vector2(250, 92)
	add_child(box)
	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HealthBar"
	_hp_bar.position = Vector2(0, 0)
	_hp_bar.size = Vector2(232, 20)
	_hp_bar.max_value = 100.0
	_hp_bar.show_percentage = false
	_fill_color(_hp_bar, Color(0.75, 0.16, 0.14))
	box.add_child(_hp_bar)
	_hp_text = Label.new()
	_hp_text.name = "HealthText"
	_hp_text.position = Vector2(6, 0)
	_hp_text.size = Vector2(220, 20)
	_hp_text.add_theme_font_size_override("font_size", 13)
	_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hp_text.add_theme_constant_override("outline_size", 4)
	box.add_child(_hp_text)
	_focus_bar = ProgressBar.new()
	_focus_bar.name = "FocusBar"
	_focus_bar.position = Vector2(0, 24)
	_focus_bar.size = Vector2(232, 14)
	_focus_bar.max_value = 100.0
	_focus_bar.show_percentage = false
	_fill_color(_focus_bar, Color(0.9, 0.55, 0.18))
	box.add_child(_focus_bar)
	_focus_text = Label.new()
	_focus_text.name = "FocusText"
	_focus_text.position = Vector2(6, 23)
	_focus_text.size = Vector2(220, 16)
	_focus_text.add_theme_font_size_override("font_size", 11)
	_focus_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_focus_text.add_theme_constant_override("outline_size", 3)
	box.add_child(_focus_text)
	_status_label_row = HBoxContainer.new()
	_status_label_row.name = "StatusRow"
	_status_label_row.position = Vector2(0, 44)
	_status_label_row.size = Vector2(240, 22)
	_status_label_row.add_theme_constant_override("separation", 6)
	box.add_child(_status_label_row)


func _fill_color(bar: ProgressBar, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", style)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.75)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)


func _update_vitals() -> void:
	var stats := player.stats
	_hp_bar.max_value = stats.max_health
	_hp_bar.value = stats.current_health
	_hp_text.text = "生命 %d / %d" % [roundi(stats.current_health), roundi(stats.max_health)]
	# 生命低于 30% 红色闪烁
	if stats.max_health > 0.0 and stats.current_health / stats.max_health < 0.3:
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.012)
		_hp_bar.modulate = Color(1.0, 0.4 + 0.4 * pulse, 0.4 + 0.4 * pulse, 1.0)
	else:
		_hp_bar.modulate = Color.WHITE
	_focus_bar.max_value = stats.max_focus
	_focus_bar.value = stats.current_focus
	var focus_name := "专注" if player.class_id != "warrior" else "战意"
	_focus_text.text = "%s %d / %d" % [focus_name, roundi(stats.current_focus), roundi(stats.max_focus)]
	_refresh_status_row()


func _refresh_status_row() -> void:
	var statuses: Dictionary = player.get_active_statuses()
	var wanted := statuses.size()
	while _status_label_row.get_child_count() > wanted:
		_status_label_row.get_child(_status_label_row.get_child_count() - 1).queue_free()
		_status_label_row.remove_child(_status_label_row.get_child(_status_label_row.get_child_count() - 1))
	var index := 0
	for effect_id in statuses.keys():
		var label: Label = null
		if index < _status_label_row.get_child_count():
			label = _status_label_row.get_child(index) as Label
		else:
			label = Label.new()
			label.add_theme_font_size_override("font_size", 11)
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			label.add_theme_constant_override("outline_size", 3)
			_status_label_row.add_child(label)
		label.text = "%s %.0fs" % [_status_display_name(effect_id), float(statuses[effect_id])]
		label.add_theme_color_override("font_color", _status_color(effect_id))
		index += 1


func _status_display_name(effect_id: String) -> String:
	match effect_id:
		StatusEffects.FROZEN:
			return "冻结"
		StatusEffects.CHILLED:
			return "冰缓"
		StatusEffects.BURNING:
			return "灼烧"
		StatusEffects.WET:
			return "潮湿"
		StatusEffects.MARKED:
			return "标记"
	return effect_id


func _status_color(effect_id: String) -> Color:
	match effect_id:
		StatusEffects.FROZEN, StatusEffects.CHILLED:
			return Color(0.6, 0.85, 1.0)
		StatusEffects.BURNING:
			return Color(1.0, 0.6, 0.3)
		StatusEffects.WET:
			return Color(0.5, 0.7, 1.0)
		StatusEffects.MARKED:
			return Color(1.0, 0.85, 0.4)
	return Color.WHITE


## ---- 技能栏 ----


func _build_skill_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "SkillBar"
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.position = Vector2(-170, -84)
	bar.size = Vector2(340, 62)
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	var keys := ["1", "2", "3", "Z", "X"]
	for key in keys:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.11, 0.15, 0.82)
		bg.border_color = Color(0.5, 0.52, 0.58, 0.9)
		bg.set_border_width_all(1)
		bg.corner_radius_top_left = 5
		bg.corner_radius_top_right = 5
		bg.corner_radius_bottom_left = 5
		bg.corner_radius_bottom_right = 5
		slot.add_theme_stylebox_override("panel", bg)
		bar.add_child(slot)
		var key_label := Label.new()
		key_label.name = "KeyLabel"
		key_label.text = key
		key_label.position = Vector2(4, 1)
		key_label.add_theme_font_size_override("font_size", 12)
		key_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
		slot.add_child(key_label)
		var name_label := Label.new()
		name_label.name = "NameLabel"
		name_label.position = Vector2(2, 34)
		name_label.size = Vector2(SLOT_SIZE - 4, 16)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.88))
		slot.add_child(name_label)
		var mask := ColorRect.new()
		mask.name = "CooldownMask"
		mask.position = Vector2(1, 1)
		mask.size = Vector2(SLOT_SIZE - 2, SLOT_SIZE - 2)
		mask.color = Color(0, 0, 0, 0.62)
		mask.visible = false
		slot.add_child(mask)
		var cd_label := Label.new()
		cd_label.name = "CooldownLabel"
		cd_label.position = Vector2(0, 12)
		cd_label.size = Vector2(SLOT_SIZE, 24)
		cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_label.add_theme_font_size_override("font_size", 15)
		cd_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		cd_label.visible = false
		slot.add_child(cd_label)
		_skill_slots.append({"panel": slot, "name": name_label, "mask": mask, "cd": cd_label, "key": key})
	# 闪避充能点（Shift）
	var dodge_row := HBoxContainer.new()
	dodge_row.name = "DodgeRow"
	dodge_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dodge_row.position = Vector2(-90, -18)
	dodge_row.size = Vector2(180, 14)
	dodge_row.add_theme_constant_override("separation", 4)
	add_child(dodge_row)
	var dodge_label := Label.new()
	dodge_label.text = "Shift 闪避"
	dodge_label.add_theme_font_size_override("font_size", 11)
	dodge_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	dodge_row.add_child(dodge_label)
	for i in 2:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(12, 8)
		pip.size = Vector2(12, 8)
		pip.color = Color(0.55, 0.8, 1.0)
		dodge_row.add_child(pip)
		_dodge_pips.append(pip)


func _update_skill_bar() -> void:
	var combat := player.combat
	var class_skills: Array = []
	if combat != null and combat.class_data != null:
		class_skills = combat.class_data.class_skills
	for i in _skill_slots.size():
		var entry: Dictionary = _skill_slots[i]
		var skill: SkillData = null
		var remaining := 0.0
		var total := 1.0
		var locked := false
		if i < 3:
			if i < class_skills.size():
				skill = class_skills[i]
				if combat != null and skill != null:
					remaining = combat.get_cooldown_remaining(skill.id)
					total = maxf(skill.cooldown, 0.01)
		else:
			var echo_system := player.echo_system
			if echo_system != null:
				locked = not echo_system.is_active()
				skill = echo_system.get_echo_skill(i - 3)
				if skill != null:
					remaining = echo_system.get_skill_cooldown_remaining(skill.id)
					total = maxf(skill.cooldown, 0.01)
		var name_label: Label = entry["name"]
		var mask: ColorRect = entry["mask"]
		var cd_label: Label = entry["cd"]
		var panel: Panel = entry["panel"]
		name_label.text = skill.display_name if skill != null else "—"
		if locked:
			panel.modulate = Color(0.55, 0.55, 0.6, 0.85)
			mask.visible = false
			cd_label.visible = true
			cd_label.text = "锁"
		elif remaining > 0.0:
			panel.modulate = Color.WHITE
			mask.visible = true
			cd_label.visible = true
			cd_label.text = "%.1f" % remaining
		else:
			panel.modulate = Color.WHITE
			mask.visible = false
			cd_label.visible = false
	# 闪避充能
	var charges := int(player.get("_dodge_charges"))
	for i in _dodge_pips.size():
		var pip: ColorRect = _dodge_pips[i]
		pip.color = Color(0.55, 0.8, 1.0) if i < charges else Color(0.25, 0.28, 0.34)


## ---- 准星 / 罗盘 ----


func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.name = "Crosshair"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-8, -8)
	_crosshair.size = Vector2(16, 16)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)
	for rect in [Rect2(7, 0, 2, 5), Rect2(7, 11, 2, 5), Rect2(0, 7, 5, 2), Rect2(11, 7, 5, 2)]:
		var line := ColorRect.new()
		line.position = rect.position
		line.size = rect.size
		line.color = Color(1, 1, 1, 0.85)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crosshair.add_child(line)


func _build_compass() -> void:
	_compass = Control.new()
	_compass.name = "Compass"
	_compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_compass.position = Vector2(-COMPASS_WIDTH * 0.5, 8)
	_compass.size = Vector2(COMPASS_WIDTH, 30)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.draw.connect(_draw_compass)
	add_child(_compass)


func _draw_compass() -> void:
	if player == null or player.camera == null:
		return
	var width := _compass.size.x
	var center := width * 0.5
	var half_range := PI
	_compass.draw_rect(Rect2(0, 0, width, 30), Color(0.06, 0.08, 0.1, 0.55), true)
	var forward := -player.camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var heading := atan2(forward.x, -forward.z)
	# 方位刻度（每 15°，30°/90° 更亮）
	for deg in range(0, 360, 15):
		var angle := deg_to_rad(float(deg))
		var rel := wrapf(angle - heading, -PI, PI)
		if absf(rel) > half_range:
			continue
		var x := center + rel / half_range * (width * 0.5)
		var tick_color := Color(0.9, 0.9, 0.9, 0.5)
		var tick_h := 5.0
		if deg % 90 == 0:
			tick_color = Color(1, 0.92, 0.75, 0.95)
			tick_h = 9.0
		_compass.draw_line(Vector2(x, 26), Vector2(x, 26 - tick_h), tick_color, 1.5)
		if deg % 90 == 0:
			_compass.draw_string(ThemeDB.fallback_font, Vector2(x - 5, 12), _compass_letter(deg), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, tick_color)
	# 地标
	for landmark in _landmark_entries():
		var pos: Vector3 = landmark["position"]
		var delta := pos - player.global_position
		var bearing := atan2(delta.x, -delta.z)
		var rel := wrapf(bearing - heading, -PI, PI)
		if absf(rel) > half_range:
			continue
		var x := center + rel / half_range * (width * 0.5)
		var color: Color = landmark["color"]
		_compass.draw_rect(Rect2(x - 3, 1, 7, 7), color, true)
		_compass.draw_string(ThemeDB.fallback_font, Vector2(x - 4, 21), str(landmark["letter"]), HORIZONTAL_ALIGNMENT_CENTER, -1, 11, color)


func _compass_letter(deg: int) -> String:
	match deg:
		0:
			return "N"
		90:
			return "E"
		180:
			return "S"
		270:
			return "W"
	return ""


func _landmark_entries() -> Array:
	var entries: Array = [
		{"position": WorldLayout.CAMP, "letter": "营", "color": Color(1.0, 0.85, 0.4)},
		{"position": WorldLayout.GROVE, "letter": "兽", "color": Color(0.95, 0.65, 0.2)},
		{"position": WorldLayout.WYVERN_NEST, "letter": "龙", "color": Color(1.0, 0.25, 0.1)},
	]
	for marker in get_tree().get_nodes_in_group("quest_marker"):
		if marker is Node3D and marker.has_meta("quest_marker_id"):
			entries.append({"position": (marker as Node3D).global_position, "letter": "!", "color": Color(1.0, 0.5, 0.35)})
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and bool(enemy.call("is_elite")) and str(enemy.get("enemy_id")) not in ["moss_crown_beast", "dread_wyvern"]:
			if int(enemy.get("state")) != 5:
				entries.append({"position": (enemy as Node3D).global_position, "letter": "精", "color": Color(1.0, 0.3, 0.3)})
				break
	return entries


## ---- 任务追踪装饰 / 回响标签 / 精英血条 ----


func _build_quest_panel() -> void:
	var tracker := get_node_or_null("QuestTracker") as Label
	if tracker == null:
		return
	var panel := Panel.new()
	panel.name = "QuestPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-372, 84)
	panel.size = Vector2(360, 260)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.55)
	style.corner_radius_top_left = 6
	style.corner_radius_bottom_left = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	move_child(panel, tracker.get_index())
	_quest_accent = ColorRect.new()
	_quest_accent.name = "QuestAccent"
	_quest_accent.position = Vector2(0, 0)
	_quest_accent.size = Vector2(4, 260)
	_quest_accent.color = Color(0.85, 0.7, 0.3)
	_quest_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_quest_accent)


func _update_quest_accent() -> void:
	if _quest_accent == null:
		return
	var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	var main_tracked := quest_manager != null and not quest_manager.tracked_main_quest.is_empty()
	_quest_accent.color = Color(0.9, 0.72, 0.3) if main_tracked else Color(0.6, 0.6, 0.62)


func _build_echo_labels() -> void:
	_echo_name_label = Label.new()
	_echo_name_label.name = "EchoNameLabel"
	_echo_name_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_echo_name_label.position = Vector2(-300, -196)
	_echo_name_label.size = Vector2(280, 18)
	_echo_name_label.add_theme_font_size_override("font_size", 12)
	_echo_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_echo_name_label.add_theme_constant_override("outline_size", 4)
	add_child(_echo_name_label)


func _update_echo_labels() -> void:
	var echo_system := player.echo_system
	if echo_system == null:
		return
	if echo_system.is_active():
		_echo_name_label.text = "回响：%s（激活中）" % echo_system.get_active_echo_name()
		_echo_name_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	elif echo_system.get("active_echo_id") != "":
		_echo_name_label.text = "回响：%s（冷却）" % echo_system.get_active_echo_name()
		_echo_name_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	else:
		var energy := float(echo_system.current_energy)
		_echo_name_label.text = "回响未激活 · 能量恢复中（%d/100）" % roundi(energy)
		_echo_name_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))


func _build_elite_bar() -> void:
	_elite_panel = Panel.new()
	_elite_panel.name = "EliteBar"
	_elite_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_elite_panel.position = Vector2(-210, 42)
	_elite_panel.size = Vector2(420, 42)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.06, 0.7)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	_elite_panel.add_theme_stylebox_override("panel", style)
	_elite_panel.visible = false
	add_child(_elite_panel)
	_elite_name = Label.new()
	_elite_name.position = Vector2(0, 2)
	_elite_name.size = Vector2(420, 18)
	_elite_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_elite_name.add_theme_font_size_override("font_size", 13)
	_elite_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
	_elite_panel.add_child(_elite_name)
	_elite_bar = ProgressBar.new()
	_elite_bar.position = Vector2(12, 22)
	_elite_bar.size = Vector2(396, 13)
	_elite_bar.show_percentage = false
	_fill_color(_elite_bar, Color(0.72, 0.25, 0.2))
	_elite_panel.add_child(_elite_bar)


func _update_elite_bar() -> void:
	var best: Node = null
	var best_distance := 45.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or int(enemy.get("state")) == 5:
			continue
		if not bool(enemy.call("is_elite")):
			continue
		if str(enemy.get("enemy_id")) == "moss_crown_beast":
			continue
		var distance := player.global_position.distance_to((enemy as Node3D).global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	if best == null:
		_elite_panel.visible = false
		return
	_elite_panel.visible = true
	_elite_name.text = str(best.get("display_name"))
	_elite_bar.max_value = float(best.get("max_health"))
	_elite_bar.value = float(best.get("current_health"))


## ---- 保存提示 ----


func _build_save_toast() -> void:
	_save_toast = Label.new()
	_save_toast.name = "SaveToast"
	_save_toast.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_save_toast.position = Vector2(-220, -40)
	_save_toast.size = Vector2(204, 24)
	_save_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_save_toast.add_theme_font_size_override("font_size", 14)
	_save_toast.add_theme_color_override("font_color", Color(0.75, 0.95, 0.8))
	_save_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_save_toast.add_theme_constant_override("outline_size", 4)
	_save_toast.visible = false
	add_child(_save_toast)


func _on_game_saved(manual: bool, reason: String) -> void:
	if _save_toast == null:
		return
	_save_toast.text = "已保存" if manual else "自动保存（%s）" % reason
	_save_toast.visible = true
	_save_toast_timer = 2.0


## ---- 探索标记（供地图面板） ----


func _mark_explored() -> void:
	var session := get_tree().get_first_node_in_group("game_session") as GameSession
	if session == null:
		return
	var pos := player.global_position
	var cell := "%d%d" % [
		int(floor((pos.x + WorldLayout.HALF) / WorldLayout.CHUNK_SIZE)),
		int(floor((pos.z + WorldLayout.HALF) / WorldLayout.CHUNK_SIZE)),
	]
	var explored: Array = session.world_data.get("explored_quadrants", [])
	if not explored.has(cell):
		explored.append(cell)
		session.world_data["explored_quadrants"] = explored


## ---- 旧节点重排（保持节点名不变，供玩家脚本引用） ----


func _reposition_legacy() -> void:
	var echoes_hint := get_node_or_null("EchoHint") as Label
	if echoes_hint != null:
		echoes_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		echoes_hint.position = Vector2(-300, -112)
		echoes_hint.size = Vector2(600, 16)
		echoes_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var interact := get_node_or_null("InteractHint") as Label
	if interact != null:
		interact.position = Vector2(-250, 76)
