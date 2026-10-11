class_name PlayerController
extends CharacterBody3D
## PlayerController（第一人称玩家控制器）
## 职责：第一人称移动（行走/冲刺/跳跃/闪避/冲锋位移）、鼠标视角与镜头效果、
## 交互射线检测与提示、坠落伤害与安全回位、受击反馈与死亡复活、
## 精灵/回响 HUD、英灵记忆幻象。技能/伤害/格挡由 CombatManager、
## 精灵效果由 SpiritCompanion、回响由 EchoSystem 负责。

signal dodge_charges_changed(current: int, maximum: int)
signal interact_target_changed(target: Node)

@export_group("角色")
## 本局职业 id（由世界生成/存档流程注入；测试场景默认 warrior）
@export var class_id := "dart_master"
@export var survivor_mode := false
@onready var survivor: DartMasterController = get_node_or_null("DartMasterController")
## 本局精灵 id（由角色选择/存档流程注入）
@export var spirit_id := ""
## 本局精灵等级
@export var spirit_level := 1

@export_group("移动")
## 步行速度（米/秒）
@export var walk_speed := 5.0
## 冲刺速度（米/秒）
@export var sprint_speed := 7.5
## 跳跃初速度（米/秒，约可跳 1.2 米）
@export var jump_velocity := 5.0
## 重力（米/秒²）
@export var gravity := 25.0

@export_group("闪避")
## 闪避位移距离（米）
@export var dodge_distance := 4.0
## 闪避充能层数上限
@export var dodge_charges_max := 2
## 每层充能恢复时间（秒）
@export var dodge_recovery_time := 5.0
## 闪避位移持续时间（秒）
@export var dodge_duration := 0.15
## 闪避无敌帧时长（秒）
@export var dodge_invincible_time := 0.3

@export_group("视角")
## 鼠标灵敏度（弧度/像素），运行时优先读取 SettingsService
@export var mouse_sensitivity := 0.002
## 俯仰下限（弧度，约 -80°）
@export var camera_pitch_min := -1.4
## 俯仰上限（弧度，约 80°）
@export var camera_pitch_max := 1.4
## 冲刺时视野增加量（度）
@export var sprint_fov_bonus := 6.0
## 移动时头部摆动幅度（米，极低）
@export var bob_amplitude := 0.015

@export_group("坠落与边界")
## 落地速度超过该值触发坠落伤害（米/秒）
@export var fall_damage_speed := 25.0
## 坠落伤害占最大生命比例
@export var fall_damage_ratio := 0.2
## 安全点刷新间隔（秒）
@export var safe_point_interval := 0.5
## 死亡区/坠落返回前的提示时长（秒）
@export var death_zone_return_delay := 1.0

@export_group("死亡")
## 死亡后复活等待（秒）
@export var revive_delay := 2.0
## 复活后的生命比例
@export var revive_health_ratio := 0.5

@export_group("界面")
## 是否显示调试状态标签（HP / 专注 / 闪避充能）
@export var show_status_hud := true

@onready var camera_pivot: SpringArm3D = get_node_or_null("CameraPivot")
@onready var camera: Camera3D = get_node_or_null("CameraPivot/Camera3D")
@onready var interaction_ray: RayCast3D = get_node_or_null("CameraPivot/Camera3D/InteractionRay")
@onready var fp_arms: FPArms = get_node_or_null("CameraPivot/Camera3D/FPArms")
@onready var combat: CombatManager = get_node_or_null("CombatManager")
@onready var spirit_companion: SpiritCompanion = get_node_or_null("SpiritMount/SpiritCompanion")
@onready var echo_system: EchoSystem = get_node_or_null("EchoSystem")
@onready var stats: PlayerStats = get_node_or_null("PlayerStats")
@onready var death_detector: Area3D = get_node_or_null("DeathZoneDetector")
@onready var interact_hint: Label = get_node_or_null("HUD/InteractHint")
@onready var boundary_warning: Label = get_node_or_null("HUD/BoundaryWarning")
@onready var status_label: Label = get_node_or_null("HUD/StatusLabel")
@onready var damage_vignette: ColorRect = get_node_or_null("HUD/DamageVignette")
@onready var combat_feedback: Label = get_node_or_null("HUD/CombatFeedback")
@onready var spirit_icon: ColorRect = get_node_or_null("HUD/SpiritPanel")
@onready var spirit_icon_label: Label = get_node_or_null("HUD/SpiritPanel/SpiritIconLabel")
@onready var spirit_feedback: Label = get_node_or_null("HUD/SpiritFeedback")
@onready var echo_vignette: Control = get_node_or_null("HUD/EchoVignette")
@onready var echo_icon: ColorRect = get_node_or_null("HUD/EchoIcon")
@onready var echo_icon_label: Label = get_node_or_null("HUD/EchoIcon/EchoIconLabel")
@onready var energy_bar: ProgressBar = get_node_or_null("HUD/EnergyBar")
@onready var active_time_bar: ProgressBar = get_node_or_null("HUD/ActiveTimeBar")
@onready var echo_slot1: Label = get_node_or_null("HUD/EchoSlotPanel1/EchoSlot1")
@onready var echo_slot2: Label = get_node_or_null("HUD/EchoSlotPanel2/EchoSlot2")
@onready var echo_panel: EchoPanel = get_node_or_null("HUD/EchoPanel")
@onready var inventory: Inventory = get_node_or_null("Inventory")
@onready var equipment: EquipmentSystem = get_node_or_null("EquipmentSystem")
@onready var enhancement: EnhancementSystem = get_node_or_null("EnhancementSystem")
@onready var inventory_panel: InventoryPanel = get_node_or_null("HUD/InventoryPanel")
@onready var dialogue_box: DialogueBox = get_node_or_null("HUD/DialogueBox")
@onready var quest_tracker: Label = get_node_or_null("HUD/QuestTracker")
@onready var quest_arrow: Label = get_node_or_null("HUD/QuestArrow")
@onready var memory_overlay: ColorRect = get_node_or_null("HUD/MemoryOverlay")
@onready var memory_title: Label = get_node_or_null("HUD/MemoryOverlay/MemoryTitle")
@onready var memory_text: Label = get_node_or_null("HUD/MemoryOverlay/MemoryText")
@onready var map_panel: MapPanel = get_node_or_null("HUD/MapPanel")
@onready var photo_mode: CanvasLayer = get_node_or_null("PhotoMode")
@onready var pause_menu: CanvasLayer = get_node_or_null("PauseMenu")

var _dodge_charges := 0
var _dodge_recharge_timer := 0.0
var _is_dodging := false
var _dodge_time_left := 0.0
var _invincible_time_left := 0.0

var _is_dashing := false
var _dash_dir := Vector3.ZERO
var _dash_speed := 0.0
var _dash_time_left := 0.0

var _fall_speed := 0.0
var _last_safe_position := Vector3.ZERO
var _safe_point_timer := 0.0
var _is_returning := false
var _is_dead := false

var _current_target: Node = null
var _bob_time := 0.0
var _current_bob := 0.0
var _base_fov := 90.0
var _shake_time_left := 0.0
var _shake_strength := 0.0
var _last_spirit_feedback := ""
var _last_spirit_feedback_ms := 0
## 对话进行中（屏蔽战斗/回响/交互输入）
var dialogue_active := false
var _quest_ui_timer := 0.0
## 复活点（营地篝火等；未设置时退回最近安全点）
var _respawn_point := Vector3.INF
## 玩家状态效果：id → 剩余秒数（溪流潮湿 wet 等）
var _active_statuses: Dictionary = {}


func _ready() -> void:
	if survivor_mode:
		add_to_group("player")
		_last_safe_position = global_position
		stats.died.connect(_on_died)
		survivor.setup(self)
		return
	_base_fov = camera.fov
	_last_safe_position = global_position
	_dodge_charges = dodge_charges_max
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interact_hint.visible = false
	boundary_warning.visible = false
	damage_vignette.modulate = Color(1, 1, 1, 0)
	echo_vignette.visible = false
	memory_overlay.visible = false
	death_detector.area_entered.connect(_on_death_zone_area_entered)
	stats.died.connect(_on_died)
	add_to_group("player")
	if combat != null:
		combat.setup(self)
	if spirit_companion != null:
		spirit_companion.spirit_changed.connect(_on_spirit_changed)
		spirit_companion.effect_triggered.connect(_on_spirit_effect)
		spirit_companion.setup(self)
		spirit_companion.initialize(spirit_id, spirit_level)
	if echo_system != null:
		echo_system.setup(self)
	if echo_panel != null:
		echo_panel.setup(self)
	if equipment != null:
		equipment.setup(self)
	if enhancement != null:
		enhancement.setup(self)
	if inventory_panel != null:
		inventory_panel.setup(self)
	if map_panel != null:
		map_panel.setup(self)
	var fov := float(SettingsService.get_setting("display/fov", 90.0))
	camera.fov = fov
	_base_fov = fov


func _process(delta: float) -> void:
	if survivor_mode:
		_tick_statuses(delta)
		survivor.tick(delta)
		return
	status_label.visible = show_status_hud
	if show_status_hud:
		_update_status_label()
	_update_interaction()
	_update_echo_hud()
	_tick_statuses(delta)
	# 任务追踪 HUD（0.25 秒节流）
	_quest_ui_timer -= delta
	if _quest_ui_timer <= 0.0:
		_quest_ui_timer = 0.25
		_update_quest_tracker()


func _physics_process(delta: float) -> void:
	if survivor_mode:
		survivor.move(delta)
		return
	if _is_returning or _is_dead:
		return

	_update_dodge_timers(delta)
	_update_dash(delta)

	# 重力与坠落速度记录
	if is_on_floor():
		if _fall_speed > 0.0:
			_handle_landing(_fall_speed)
			_fall_speed = 0.0
	else:
		velocity.y -= gravity * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)

	# 跳跃：仅地面可用，位移（闪避/冲锋）中不可跳
	if is_on_floor() and not _is_dashing and not has_effect(StatusEffects.ROOTED) and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	# 闪避输入
	if Input.is_action_just_pressed("dodge") and not has_effect(StatusEffects.ROOTED):
		try_dodge()

	# 水平移动：位移中沿位移方向，否则 WASD 相对相机
	if _is_dashing:
		velocity.x = _dash_dir.x * _dash_speed
		velocity.z = _dash_dir.z * _dash_speed
	else:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction := camera_pivot.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			direction = direction.normalized()
			var speed := walk_speed
			if Input.is_action_pressed("sprint"):
				speed = sprint_speed
			if combat != null:
				speed *= combat.get_move_speed_multiplier()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0

	if has_effect(StatusEffects.ROOTED):
		velocity.x = 0
		velocity.z = 0
	move_and_slide()
	_update_safe_point(delta)
	_update_camera_effects(delta)


func _unhandled_input(event: InputEvent) -> void:
	if survivor_mode:
		survivor.input(event)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event as InputEventMouseMotion)
	elif event.is_action_pressed("inventory"):
		_toggle_inventory_panel()
	elif event.is_action_pressed("ui_cancel"):
		# Esc：关闭面板；无面板时打开暂停菜单
		if any_panel_open():
			close_all_panels()
		else:
			_toggle_pause_menu()
	elif event.is_action_pressed("map"):
		_toggle_map_panel()
	elif event.is_action_pressed("photo_mode"):
		_toggle_photo_mode()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_I:
			_toggle_echo_panel()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not echo_panel.visible and not inventory_panel.visible:
			_set_mouse_captured(true)


## ---- 对外接口 ----

## 受到伤害的统一入口：无敌帧免疫 → 护甲 → 格挡 → 精灵减伤 → 护盾 → 生命。
## 返回实际造成的伤害（被格挡/免疫/护盾吸收时为 0）。
func take_damage(amount: float, source: Node = null) -> float:
	if _is_dead or is_invincible():
		return 0.0
	var final := DamageCalculator.apply_armor(amount, stats.armor)
	if combat != null:
		final = combat.filter_incoming_damage(final, source)
	if final > 0.0 and spirit_companion != null:
		final *= 1.0 - spirit_companion.get_damage_reduction()
	final = stats.absorb_with_shield(final)
	if final <= 0.0:
		return 0.0
	stats.take_damage(final)
	_play_damage_feedback()
	if spirit_companion != null and spirit_companion.get_damage_reduction() > 0.0:
		spirit_companion.play_entity_effect("damage_reduction")
	return final


## 是否处于死亡等待复活状态。
func is_dead() -> bool:
	return _is_dead


## 是否处于无敌帧（战斗系统查询）。
func is_invincible() -> bool:
	return _invincible_time_left > 0.0


## 相机水平前方方向（技能/冲锋/格挡判定用）。
func get_aim_direction_flat() -> Vector3:
	var direction := -camera.global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return -global_transform.basis.z
	return direction.normalized()


## 屏幕中央战斗文字反馈（技能失败原因/格挡/碎冰/回响获取等）。
func show_combat_feedback(text: String, color := Color(1, 1, 1)) -> void:
	if survivor_mode:
		survivor.hud.show_feedback(text,color)
		return
	if combat_feedback == null:
		return
	combat_feedback.text = text
	combat_feedback.modulate = Color(color.r, color.g, color.b, 1.0)
	combat_feedback.visible = true
	var tween := create_tween()
	tween.tween_interval(0.55)
	tween.tween_property(combat_feedback, "modulate:a", 0.0, 0.4)


## 开始一段直线位移（闪避/冲锋共用）。direction 会自动水平化。
func start_dash(direction: Vector3, distance: float, duration: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		flat = -global_transform.basis.z
	_dash_dir = flat.normalized()
	_dash_speed = distance / maxf(duration, 0.01)
	_dash_time_left = duration
	_is_dashing = true


## 立即停止位移（冲锋命中目标时调用）。
func stop_dash() -> void:
	_dash_time_left = 0.0
	_is_dashing = false
	velocity.x = 0.0
	velocity.z = 0.0


## 是否处于位移中（闪避或冲锋）。
func is_dashing() -> bool:
	return _is_dashing


## 尝试闪避；无充能、位移中或返回/死亡时返回 false。
func try_dodge() -> bool:
	if _is_dodging or _is_dashing or _is_returning or _is_dead or _dodge_charges <= 0:
		return false
	_dodge_charges -= 1
	_dodge_time_left = dodge_duration
	_invincible_time_left = dodge_invincible_time
	_is_dodging = true
	start_dash(_get_move_direction_or_forward(), dodge_distance, dodge_duration)
	dodge_charges_changed.emit(_dodge_charges, dodge_charges_max)
	return true


## 当前剩余闪避充能层数。
func get_dodge_charges() -> int:
	return _dodge_charges


## 是否处于闪避中（不含冲锋位移）。
func is_dodging() -> bool:
	return _is_dodging


## 交互射线当前指向的可交互目标（无则返回 null）。
func get_interact_target() -> Node:
	return _current_target


## 播放英灵记忆幻象（占位：主题色渐隐遮罩 + 称号 + 记忆文本），
## 结束后由调用方（回响碑）继续收藏流程。
func play_memory_vision(echo_data: EchoData, duration := 5.0) -> void:
	if memory_overlay == null or echo_data == null:
		return
	memory_overlay.color = Color(
		echo_data.visual_theme_color.r * 0.25,
		echo_data.visual_theme_color.g * 0.25,
		echo_data.visual_theme_color.b * 0.3,
		1.0
	)
	memory_title.text = "%s · %s" % [echo_data.display_name, echo_data.title]
	memory_text.text = echo_data.memory_text
	memory_overlay.modulate = Color(1, 1, 1, 0)
	memory_overlay.visible = true
	var fade_in := create_tween()
	fade_in.tween_property(memory_overlay, "modulate:a", 1.0, 0.6)
	await get_tree().create_timer(duration).timeout
	var fade_out := create_tween()
	fade_out.tween_property(memory_overlay, "modulate:a", 0.0, 0.8)
	await fade_out.finished
	memory_overlay.visible = false


## 激活期间屏幕边缘回响色带（不遮挡准星）。
func set_echo_vignette(color: Color, enabled: bool) -> void:
	if echo_vignette == null:
		return
	echo_vignette.visible = enabled
	if not enabled:
		return
	var edge := Color(color.r, color.g, color.b, 0.22)
	for strip_name in ["VTop", "VBottom", "VLeft", "VRight"]:
		var strip := echo_vignette.get_node_or_null(strip_name) as ColorRect
		if strip != null:
			strip.color = edge


## ---- 内部实现 ----

func _update_dodge_timers(delta: float) -> void:
	if _invincible_time_left > 0.0:
		_invincible_time_left -= delta
	if _is_dodging:
		_dodge_time_left -= delta
		if _dodge_time_left <= 0.0:
			_is_dodging = false
	if _dodge_charges >= dodge_charges_max:
		_dodge_recharge_timer = 0.0
		return
	_dodge_recharge_timer += delta
	if _dodge_recharge_timer >= dodge_recovery_time:
		_dodge_recharge_timer = 0.0
		_dodge_charges += 1
		dodge_charges_changed.emit(_dodge_charges, dodge_charges_max)


func _update_dash(delta: float) -> void:
	if not _is_dashing:
		return
	_dash_time_left -= delta
	if _dash_time_left <= 0.0:
		_is_dashing = false
		velocity.x = 0.0
		velocity.z = 0.0


## 闪避/冲锋方向：有移动输入则朝输入方向，否则朝相机正前方。
func _get_move_direction_or_forward() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3
	if input_dir.length_squared() > 0.0001:
		direction = camera_pivot.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	else:
		direction = -camera_pivot.global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = -global_transform.basis.z
	return direction.normalized()


## 落地处理：超过安全速度时扣血并回安全点。
func _handle_landing(landing_speed: float) -> void:
	if landing_speed <= fall_damage_speed:
		return
	stats.take_damage(stats.max_health * fall_damage_ratio)
	_return_to_safe_point("坠落冲击")


## 定期刷新最近安全点（仅在踩在地面且非位移中）。
func _update_safe_point(delta: float) -> void:
	_safe_point_timer += delta
	if _safe_point_timer < safe_point_interval:
		return
	_safe_point_timer = 0.0
	if is_on_floor() and not _is_dashing:
		_last_safe_position = global_position


## 设置复活点（营地篝火；进入安全区时调用）。
func set_respawn_point(position: Vector3) -> void:
	_respawn_point = position


## 外部击退（BOSS 冲撞等）：施加瞬时水平速度冲击。
func apply_external_knockback(direction: Vector3, force: float) -> void:
	if survivor_mode:
		survivor.knockback = direction * force
		return
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	velocity += flat.normalized() * force


## 屏幕震动（BOSS 出场/冲撞等）。
func add_camera_shake(strength := 0.05, duration := 0.3) -> void:
	_shake_strength = strength
	_shake_time_left = maxf(duration, 0.22)


## 施加玩家状态效果（wet 等；数值效果后续扩展）。
func apply_effect(effect_id: String, duration: float, _power := 1.0) -> void:
	_active_statuses[effect_id] = maxf(float(_active_statuses.get(effect_id, 0.0)), duration)


## 当前玩家状态效果：id → 剩余秒数（HUD 显示）。
func get_active_statuses() -> Dictionary:
	return _active_statuses.duplicate()


## ---- 存档接口 ----


## 玩家状态快照（位置/朝向/生命/专注/等级/经验/所在世界）。
func get_save_data() -> Dictionary:
	var session := get_tree().get_first_node_in_group("game_session") as GameSession
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation": [rotation.y, camera.rotation.x],
		"health": stats.current_health,
		"focus": stats.current_focus,
		"level": stats.level,
		"exp": stats.exp,
		"world_id": session.current_world_id if session != null else "forest",
	}


## 恢复玩家状态；world_id 为森林时才回写位置（秘境内存档回森林出生点）。
func apply_saved_data(data: Dictionary) -> void:
	stats.current_health = clampf(float(data.get("health", stats.max_health)), 1.0, stats.max_health)
	stats.current_focus = clampf(float(data.get("focus", stats.max_focus)), 0.0, stats.max_focus)
	stats.level = maxi(int(data.get("level", 1)), 1)
	stats.exp = maxi(int(data.get("exp", 0)), 0)
	var rotation_values: Array = data.get("rotation", [])
	if rotation_values.size() >= 2:
		rotation.y = float(rotation_values[0])
		camera.rotation.x = clampf(float(rotation_values[1]), camera_pitch_min, camera_pitch_max)
	var position_values: Array = data.get("position", [])
	if position_values.size() >= 3 and str(data.get("world_id", "forest")) == "forest":
		global_position = Vector3(float(position_values[0]), float(position_values[1]), float(position_values[2]))
		velocity = Vector3.ZERO
		_last_safe_position = global_position


func has_effect(effect_id: String) -> bool:
	return float(_active_statuses.get(effect_id, 0.0)) > 0.0


func _tick_statuses(delta: float) -> void:
	if _active_statuses.is_empty():
		return
	for key in _active_statuses.keys():
		var left := float(_active_statuses[key]) - delta
		if left <= 0.0:
			_active_statuses.erase(key)
		else:
			_active_statuses[key] = left


## 进入 environment_trigger 层的死亡区（在 death_zone 组内）时触发。
func _on_death_zone_area_entered(area: Area3D) -> void:
	if not area.is_in_group("death_zone"):
		return
	_return_to_safe_point("已进入危险区域")


func _on_died() -> void:
	if _is_dead:
		return
	_handle_death()


## 死亡 → 等待 revive_delay 秒 → 在最近安全点以 50% 生命复活（保留装备与进度）。
func _handle_death() -> void:
	if survivor_mode:
		_is_dead = true
		survivor.end_ultimate()
		survivor.play_animation("death",2.0)
		show_combat_feedback("你倒下了……正在返回营地",Color(1,0.5,0.5))
		await get_tree().create_timer(revive_delay,false).timeout
		stats.heal(stats.max_health)
		global_position = _respawn_point if _respawn_point.is_finite() else WorldLayout.CAMPFIRE+Vector3(0,1,2)
		velocity = Vector3.ZERO
		_is_dead = false
		survivor.animation_lock = 0.0
		return
	_is_dead = true
	stop_dash()
	_is_dodging = false
	velocity = Vector3.ZERO
	boundary_warning.text = "你倒下了……%.0f 秒后复活" % revive_delay
	boundary_warning.visible = true
	await get_tree().create_timer(revive_delay).timeout
	stats.heal(stats.max_health * revive_health_ratio)
	global_position = _respawn_point if _respawn_point.is_finite() else _last_safe_position
	velocity = Vector3.ZERO
	_fall_speed = 0.0
	boundary_warning.visible = false
	_is_dead = false


## 显示提示并延时传送回安全点。
func _return_to_safe_point(reason: String) -> void:
	if _is_returning or _is_dead:
		return
	_is_returning = true
	stop_dash()
	velocity = Vector3.ZERO
	_fall_speed = 0.0
	boundary_warning.text = "%s，正在返回安全点……" % reason
	boundary_warning.visible = true
	await get_tree().create_timer(death_zone_return_delay).timeout
	global_position = _last_safe_position
	velocity = Vector3.ZERO
	boundary_warning.visible = false
	_is_returning = false


## 受击反馈：红色边缘闪烁 + 相机轻微抖动 + 手臂反应（抖动可在设置中关闭）。
func _play_damage_feedback() -> void:
	if survivor_mode:
		survivor.play_animation("hit",0.25)
		return
	damage_vignette.modulate = Color(1, 1, 1, 0.45)
	var tween := create_tween()
	tween.tween_property(damage_vignette, "modulate:a", 0.0, 0.45)
	if bool(SettingsService.get_setting("display/enable_camera_effects", true)):
		_shake_time_left = 0.22
		_shake_strength = 0.035
	if fp_arms != null:
		fp_arms.play_hit_reaction()


## 应用鼠标视角（yaw 给 CameraPivot，pitch 给 Camera3D）。
func _apply_look(event: InputEventMouseMotion) -> void:
	var sensitivity := float(SettingsService.get_setting("input/mouse_sensitivity", mouse_sensitivity))
	camera_pivot.rotate_y(-event.relative.x * sensitivity)
	var invert := bool(SettingsService.get_setting("input/invert_y_axis", false))
	var pitch_delta := event.relative.y * sensitivity * (-1.0 if invert else 1.0)
	camera.rotation.x = clampf(camera.rotation.x - pitch_delta, camera_pitch_min, camera_pitch_max)


## 镜头效果：冲刺增视野 + 极低幅度头部摆动 + 受击抖动；可在设置中整体关闭。
func _update_camera_effects(delta: float) -> void:
	var effects_enabled := bool(SettingsService.get_setting("display/enable_camera_effects", true))
	var fov_setting := float(SettingsService.get_setting("display/fov", _base_fov))
	if not is_equal_approx(fov_setting, _base_fov):
		_base_fov = fov_setting
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var target_fov := _base_fov
	var target_bob := 0.0
	if effects_enabled:
		if horizontal_speed > walk_speed + 0.5:
			target_fov = _base_fov + sprint_fov_bonus
		if is_on_floor() and horizontal_speed > 0.5:
			_bob_time += delta * (9.0 + horizontal_speed * 1.2)
			target_bob = sin(_bob_time) * bob_amplitude * clampf(horizontal_speed / walk_speed, 0.5, 1.5)
	camera.fov = lerpf(camera.fov, target_fov, 8.0 * delta)
	_current_bob = lerpf(_current_bob, target_bob, 12.0 * delta)
	var shake := Vector2.ZERO
	if effects_enabled and _shake_time_left > 0.0:
		_shake_time_left -= delta
		var strength := _shake_strength * maxf(_shake_time_left / 0.22, 0.0)
		shake = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	camera.position = Vector3(shake.x, _current_bob + shake.y, 0.0)


## 每帧刷新交互目标与提示，按 E 调用目标 interact(player)。
func _update_interaction() -> void:
	if dialogue_active:
		return
	var target := _find_interact_target()
	if target != _current_target:
		_current_target = target
		interact_target_changed.emit(target)
		_refresh_interact_hint()
	if _current_target != null and Input.is_action_just_pressed("interact"):
		_current_target.call("interact", self)


## 交互射线命中的可交互节点：自身或父节点实现 interact() 即可。
func _find_interact_target() -> Node:
	if not interaction_ray.is_colliding():
		return null
	var collider := interaction_ray.get_collider()
	if collider == null:
		return null
	if collider.has_method("interact"):
		return collider as Node
	var parent := (collider as Node).get_parent()
	if parent != null and parent.has_method("interact"):
		return parent
	return null


## 根据当前目标刷新屏幕中央提示。
func _refresh_interact_hint() -> void:
	if _current_target == null:
		interact_hint.visible = false
		return
	var hint_text := "交互"
	var value: Variant = _current_target.get("interact_text")
	if value is String and not (value as String).is_empty():
		hint_text = value
	interact_hint.text = "按 E %s" % hint_text
	interact_hint.visible = true


## 更新左上角调试状态标签。
func _update_status_label() -> void:
	status_label.text = "HP %d/%d  专注 %d/%d  闪避 %d/%d  Lv.%d" % [
		roundi(stats.current_health), roundi(stats.max_health),
		roundi(stats.current_focus), roundi(stats.max_focus),
		_dodge_charges, dodge_charges_max,
		stats.level,
	]


## ---- 精灵 HUD ----

func _on_spirit_changed(data: SpiritData) -> void:
	if data == null:
		return
	if spirit_icon != null:
		spirit_icon.color = _spirit_role_color(data.role)
		if spirit_companion != null:
			spirit_icon.tooltip_text = spirit_companion.get_effect_summary()
	if spirit_icon_label != null:
		spirit_icon_label.text = data.display_name.substr(0, 2)
	if spirit_feedback != null:
		spirit_feedback.text = ""


func _on_spirit_effect(_effect_type: String, feedback_text: String) -> void:
	if feedback_text.is_empty() or spirit_feedback == null:
		return
	var now := Time.get_ticks_msec()
	if feedback_text == _last_spirit_feedback and now - _last_spirit_feedback_ms < 800:
		return
	_last_spirit_feedback = feedback_text
	_last_spirit_feedback_ms = now
	spirit_feedback.text = feedback_text
	spirit_feedback.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(spirit_feedback, "modulate:a", 0.0, 0.5)


func _spirit_role_color(role: String) -> Color:
	match role:
		"heal":
			return Color(1.0, 0.85, 0.45)
		"damage":
			return Color(1.0, 0.45, 0.15)
		_:
			return Color(0.55, 0.65, 0.8)


## ---- 回响 HUD ----

func _toggle_echo_panel() -> void:
	if echo_panel == null:
		return
	var opening := not echo_panel.visible
	_close_panels_no_sync()
	if opening:
		echo_panel.visible = true
		echo_panel.refresh()
	_sync_panel_state()


## 面板协调：任一面板打开时暂停游戏（HUD 之外），互斥且 Esc 可全部关闭。
func any_panel_open() -> bool:
	if survivor_mode:
		return survivor.hud.panel_open()
	if inventory_panel != null and inventory_panel.visible:
		return true
	if echo_panel != null and echo_panel.visible:
		return true
	if map_panel != null and map_panel.visible:
		return true
	if photo_mode != null and photo_mode.visible:
		return true
	if pause_menu != null and pause_menu.visible:
		return true
	return false


func close_all_panels() -> void:
	if survivor_mode:
		survivor.hud.close_panel()
		return
	_close_panels_no_sync()
	_sync_panel_state()


func _close_panels_no_sync() -> void:
	if inventory_panel != null:
		inventory_panel.visible = false
	if echo_panel != null:
		echo_panel.visible = false
	if map_panel != null:
		map_panel.close_panel()
	if photo_mode != null and photo_mode.visible:
		photo_mode.call("close")
	if pause_menu != null and pause_menu.visible:
		pause_menu.call("close")


func _sync_panel_state() -> void:
	var opened := any_panel_open()
	get_tree().paused = opened
	_set_mouse_captured(not opened)


func _toggle_map_panel() -> void:
	if map_panel == null:
		return
	var opening := not map_panel.visible
	_close_panels_no_sync()
	if opening:
		map_panel.open_panel()
	_sync_panel_state()


func toggle_map_panel() -> void:
	if survivor_mode:
		if survivor.hud.map_panel.visible: survivor.hud.map_panel.close_panel()
		else: survivor.hud.map_panel.open_panel()
		return
	_toggle_map_panel()


func _toggle_photo_mode() -> void:
	if photo_mode == null:
		return
	var opening := not photo_mode.visible
	_close_panels_no_sync()
	if opening:
		photo_mode.call("open", self)
	_sync_panel_state()


func toggle_photo_mode() -> void:
	_toggle_photo_mode()


func _toggle_pause_menu() -> void:
	if pause_menu == null:
		return
	var opening := not pause_menu.visible
	_close_panels_no_sync()
	if opening:
		pause_menu.call("open", self)
	_sync_panel_state()


func toggle_pause_menu() -> void:
	if survivor_mode:
		survivor.hud.toggle_pause()
		return
	_toggle_pause_menu()


## 每帧刷新回响 HUD（能量条 / 激活条 / 技能槽 / 图标）。
func _update_echo_hud() -> void:
	if echo_system == null:
		return
	energy_bar.max_value = echo_system.max_energy
	energy_bar.value = echo_system.current_energy
	if echo_system.is_active():
		active_time_bar.visible = true
		active_time_bar.max_value = echo_system.activate_duration
		active_time_bar.value = echo_system.active_timer
		# 最后 3 秒闪烁提示
		var alpha := 1.0
		if echo_system.active_timer <= 3.0:
			alpha = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 120.0))
		active_time_bar.modulate.a = alpha
		echo_icon.modulate.a = alpha
	else:
		active_time_bar.visible = false
		echo_icon.modulate.a = 1.0
	# 图标：激活中显示激活回响，否则显示当前准备槽
	var icon_color := Color(0.3, 0.3, 0.35)
	var icon_text := "无"
	var echo_id := ""
	if echo_system.is_active():
		echo_id = echo_system.active_echo_id
	elif not echo_system.prep_slots.is_empty():
		echo_id = echo_system.prep_slots[echo_system.current_slot_index]
	if not echo_id.is_empty():
		var echo_data := DataRegistry.get_echo(echo_id)
		if echo_data != null:
			icon_color = echo_data.visual_theme_color
			icon_text = echo_data.display_name.substr(0, 2)
	echo_icon.color = icon_color
	echo_icon_label.text = icon_text
	_update_echo_slot(echo_slot1, echo_system.get_echo_skill(0), 0)
	_update_echo_slot(echo_slot2, echo_system.get_echo_skill(1), 1)


func _update_echo_slot(label: Label, skill: SkillData, slot: int) -> void:
	if label == null:
		return
	if skill == null or echo_system == null or not echo_system.is_active():
		label.text = "◎ 未激活"
		label.modulate = Color(0.55, 0.55, 0.6, 0.8)
		return
	var key := "Z" if slot == 0 else "X"
	var remaining := echo_system.get_skill_cooldown_remaining(skill.id)
	if remaining > 0.0:
		label.text = "%s %s %.1fs" % [key, skill.display_name, remaining]
		label.modulate = Color(0.7, 0.75, 0.85, 0.9)
	else:
		label.text = "%s %s" % [key, skill.display_name]
		label.modulate = Color(1, 1, 1, 1)


## ---- NPC 对话 ----

## 开始一段 NPC 对话（结束后执行 on_finished 回调，用于接取/交付任务）。
func start_dialogue(speaker: String, lines: Array, on_finished := Callable()) -> void:
	if survivor_mode:
		dialogue_active = true
		survivor.hud.dialogue_box.start(speaker,lines,func():
				dialogue_active=false
				if on_finished.is_valid():on_finished.call())
		return
	if dialogue_box == null:
		return
	dialogue_active = true
	dialogue_box.start(speaker, lines, func() -> void:
		dialogue_active = false
		if on_finished.is_valid():
			on_finished.call())


## 是否处于对话中（战斗/回响/交互输入会临时屏蔽）。
func is_dialogue_active() -> bool:
	return dialogue_active


## ---- 任务追踪 HUD ----

func _get_quest_manager() -> QuestManager:
	return get_tree().get_first_node_in_group("quest_manager") as QuestManager


func _update_quest_tracker() -> void:
	var quest_manager := _get_quest_manager()
	if quest_manager == null or quest_tracker == null:
		return
	var lines: Array[String] = []
	for entry in quest_manager.get_tracked_entries():
		var quest: QuestData = entry["quest"]
		lines.append(("[主线] " if quest.is_main else "[支线] ") + quest.display_name)
		var progress: Array = entry["progress"]
		for i in quest.objectives.size():
			var objective: Dictionary = quest.objectives[i]
			var need := int(objective.get("count", 1))
			var have := int(progress[i])
			var mark := "√" if have >= need else "%d/%d" % [have, need]
			lines.append("  · %s  %s" % [str(objective.get("description", "")), mark])
	quest_tracker.text = "\n".join(lines)
	_update_quest_arrow(quest_manager)


## 屏幕中上方的方向箭头：指向第一个未完成目标的标记点。
func _update_quest_arrow(quest_manager: QuestManager) -> void:
	if quest_arrow == null:
		return
	var target_position: Variant = quest_manager.get_first_tracked_target_position()
	if target_position == null:
		quest_arrow.visible = false
		return
	var to_target: Vector3 = (target_position as Vector3) - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance < 4.0:
		quest_arrow.visible = false
		return
	var camera_forward := -camera.global_transform.basis.z
	camera_forward.y = 0.0
	var angle := camera_forward.signed_angle_to(to_target.normalized(), Vector3.UP)
	quest_arrow.visible = true
	quest_arrow.rotation = angle
	quest_arrow.text = "▲ %.0f m" % distance


## ---- 背包 HUD ----

func _toggle_inventory_panel() -> void:
	if inventory_panel == null:
		return
	var opening := not inventory_panel.visible
	_close_panels_no_sync()
	if opening:
		inventory_panel.visible = true
		inventory_panel.refresh()
	_sync_panel_state()


func _set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
