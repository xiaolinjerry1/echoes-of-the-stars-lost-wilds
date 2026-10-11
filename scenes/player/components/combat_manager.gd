class_name CombatManager
extends Node
## CombatManager（玩家战斗管理器）
## 职责：持有职业数据与攻击强度；管理技能冷却/专注/前摇执行；
## 命中检测与伤害结算（含碎冰组合）；格挡与完美格挡伤害过滤。
## 挂在 Player 下，由 PlayerController 调用 setup() 注入引用。

signal skill_used(skill_id: String)
signal skill_failed(skill_id: String, reason: String)

@export_group("基础")
## 基础攻击技能 id（在职业数据的 basic_attack 中定义）
@export var basic_attack_id := "warrior_basic"
## 暴击率（0-1），可由装备提升
@export var crit_chance := 0.05
## 技能急速（0-1，减少冷却），上限 25%
@export var skill_haste := 0.0
## 技能急速上限
@export var skill_haste_cap := 0.25
## 普攻连击窗口（秒）
@export var combo_window := 1.2
## 连续第 3 击伤害加成比例
@export var combo_finisher_bonus := 0.3

@export_group("格挡")
## 格挡正面扇形角度（度）
@export var block_arc_degrees := 120.0
## 普通格挡减伤比例
@export var block_damage_reduction := 0.7
## 完美格挡窗口（秒，开始格挡后）
@export var perfect_block_window := 0.2
## 完美格挡使攻击者失衡时长（秒）
@export var parry_stagger_duration := 1.5

@export_group("战吼")
## 攻击强度提升比例
@export var roar_attack_bonus := 0.2
## 增益持续时间（秒）
@export var roar_duration := 5.0
## 嘲讽半径（米）
@export var roar_radius := 5.0
## 嘲讽持续时间（秒）
@export var roar_taunt_duration := 3.0

@export_group("冲锋")
## 冲锋位移时长（秒）
@export var charge_dash_duration := 0.25
## 冲锋命中判定半径（米）
@export var charge_hit_radius := 1.6
## 冲锋眩晕时长（秒）
@export var charge_stun_duration := 0.5

## 当前职业数据
var class_data: ClassData = null
## 玩家攻击强度（基础值 + 装备加成）
var attack_power := 0.0
## 技能 id → 剩余冷却（秒）
var skill_cooldowns: Dictionary = {}
## 当前增伤乘区（战吼等 buff）
var damage_multiplier := 1.0

var _skills: Dictionary = {}
var _player: PlayerController = null
var _stats: PlayerStats = null
var _fp_arms: FPArms = null

var _action_locked := false
var _action_timer := 0.0
var _pending_skill: SkillData = null

var _blocking := false
var _block_started_at := -1000.0
var _clock := 0.0

var _combo_count := 0
var _combo_time_left := 0.0
var _buff_time_left := 0.0

var _charge_skill: SkillData = null
var _charge_active := false
var _charge_hit_done := false


## 由 PlayerController 在 _ready 时调用。
func setup(player: PlayerController) -> void:
	_player = player
	_stats = player.stats
	_fp_arms = player.fp_arms
	initialize(player.class_id)


## 从 DataRegistry 加载职业数据并应用基础属性。
func initialize(class_id: String) -> void:
	class_data = DataRegistry.get_class_def(class_id)
	if class_data == null:
		push_error("CombatManager: 找不到职业数据 %s" % class_id)
		return
	attack_power = class_data.base_attack_power
	_stats.apply_class_data(class_data)
	_skills.clear()
	skill_cooldowns.clear()
	if class_data.basic_attack != null:
		_skills[class_data.basic_attack.id] = class_data.basic_attack
	for skill in class_data.class_skills:
		_skills[skill.id] = skill


func _process(delta: float) -> void:
	update(delta)


## 每帧更新：冷却 / 前摇 / 连击 / 增益 / 格挡 / 冲锋命中 / 输入。
func update(delta: float) -> void:
	_clock += delta
	_tick_cooldowns(delta)
	_tick_action(delta)
	_tick_combo(delta)
	_tick_buff(delta)
	_update_block_state()
	_tick_charge()
	_handle_input()


## ---- 查询接口 ----

## 技能当前是否可用（冷却/专注/行动状态均满足）。
func can_use_skill(skill_id: String) -> bool:
	return get_skill_fail_reason(skill_id).is_empty()


## 技能不可用原因（空串 = 可用）。
func get_skill_fail_reason(skill_id: String) -> String:
	if _player == null or _stats == null:
		return "系统未就绪"
	if _player.is_dead():
		return "已倒下"
	if not _skills.has(skill_id):
		return "技能不存在"
	if _blocking:
		return "格挡中"
	if _player.is_dodging():
		return "闪避中"
	if _action_locked:
		return "行动中"
	var remaining := get_cooldown_remaining(skill_id)
	if remaining > 0.0:
		return "冷却中 %.1fs" % remaining
	var skill: SkillData = _skills[skill_id]
	if _stats.current_focus < skill.focus_cost:
		return "专注不足"
	return ""


## 技能剩余冷却（秒）。
func get_cooldown_remaining(skill_id: String) -> float:
	return float(skill_cooldowns.get(skill_id, 0.0))


## 是否处于格挡姿态。
func is_blocking() -> bool:
	return _blocking


## 是否处于技能前摇/行动锁定。
func is_action_locked() -> bool:
	return _action_locked


## 移动速度倍率（格挡时减半）。
func get_move_speed_multiplier() -> float:
	return 0.5 if _blocking else 1.0


## ---- 技能释放 ----

## 释放指定技能；失败时发出 skill_failed 并在屏幕提示原因。
func use_skill(skill_id: String) -> bool:
	var reason := get_skill_fail_reason(skill_id)
	if not reason.is_empty():
		skill_failed.emit(skill_id, reason)
		_show_feedback(reason)
		return false
	var skill: SkillData = _skills[skill_id]
	_start_skill(skill)
	return true


## 基础攻击（三段连击：每第 3 击伤害 +30%）。
func basic_attack() -> bool:
	var reason := get_skill_fail_reason(basic_attack_id)
	if not reason.is_empty():
		skill_failed.emit(basic_attack_id, reason)
		return false
	_combo_count = (_combo_count % 3) + 1
	_combo_time_left = combo_window
	var skill: SkillData = _skills[basic_attack_id]
	_start_skill(skill)
	return true


## 按槽位释放职业主技能（0 起）。
func use_skill_by_slot(slot: int) -> bool:
	if class_data == null or slot < 0 or slot >= class_data.class_skills.size():
		return false
	return use_skill(class_data.class_skills[slot].id)


## 设置技能冷却（应用技能急速，上限 25%）。
func set_cooldown(skill_id: String) -> void:
	var skill: SkillData = _skills.get(skill_id)
	if skill == null:
		return
	var haste := clampf(skill_haste, 0.0, skill_haste_cap)
	skill_cooldowns[skill_id] = skill.cooldown * (1.0 - haste)


## ---- 受击过滤（供 PlayerController.take_damage 调用） ----

## 应用格挡（含完美格挡）修正；返回修正后的伤害。
func filter_incoming_damage(amount: float, source: Node) -> float:
	if not _blocking or amount <= 0.0:
		return amount
	if not (source is Node3D):
		return amount
	var to_attacker := (source as Node3D).global_position - _player.global_position
	to_attacker.y = 0.0
	var forward := _player.get_aim_direction_flat()
	if to_attacker.length_squared() > 0.0001 and forward.angle_to(to_attacker.normalized()) > deg_to_rad(block_arc_degrees * 0.5):
		return amount  # 背后攻击无法格挡
	var is_perfect := (_clock - _block_started_at) <= perfect_block_window
	if is_perfect:
		_show_feedback("完美格挡！", Color(1.0, 0.95, 0.6))
		HitEffect.spawn_burst(_player, _player.global_position + forward * 0.8 + Vector3.UP * 1.2, Color(1.0, 0.95, 0.7), 20, 3.0)
		if source.has_method("on_parried"):
			source.call("on_parried", parry_stagger_duration)
		return 0.0
	_show_feedback("格挡", Color(0.8, 0.9, 1.0))
	HitEffect.spawn_burst(_player, _player.global_position + forward * 0.8 + Vector3.UP * 1.2, Color(0.75, 0.85, 1.0), 10, 2.0)
	return amount * (1.0 - block_damage_reduction)


## ---- 内部实现 ----

func _start_skill(skill: SkillData) -> void:
	_play_skill_animation(skill)
	if skill.cast_time <= 0.0:
		_execute_skill(skill)
		return
	_action_locked = true
	_action_timer = skill.cast_time
	_pending_skill = skill


func _execute_skill(skill: SkillData) -> void:
	# 资源与冷却
	if skill.focus_cost > 0.0 and not _stats.use_focus(skill.focus_cost):
		skill_failed.emit(skill.id, "专注不足")
		return
	set_cooldown(skill.id)
	skill_used.emit(skill.id)
	match skill.id:
		"warrior_charge":
			_execute_charge(skill)
		"warrior_sweep":
			_execute_sweep(skill)
		"warrior_roar":
			_execute_roar(skill)
		_:
			_execute_melee_cleave(skill)


## 普攻/通用近战：60° 扇形
func _execute_melee_cleave(skill: SkillData) -> void:
	var bonus := 1.0
	if skill.id == basic_attack_id and _combo_count >= 3:
		bonus = 1.0 + combo_finisher_bonus
		_show_feedback("连击终结！", Color(1.0, 0.9, 0.5))
	var targets := _query_cone_targets(skill.range, 60.0)
	_apply_skill_damage(skill, targets, bonus)


## 横扫：120° 扇形；对冻结目标由 _apply_skill_damage 统一触发碎冰
func _execute_sweep(skill: SkillData) -> void:
	var targets := _query_cone_targets(skill.range, 120.0)
	_apply_skill_damage(skill, targets)


## 冲锋：朝准星方向冲刺，命中第一个敌人造成伤害并眩晕
func _execute_charge(skill: SkillData) -> void:
	var direction := _player.get_aim_direction_flat()
	_charge_skill = skill
	_charge_active = true
	_charge_hit_done = false
	_player.start_dash(direction, skill.range, charge_dash_duration)


func _tick_charge() -> void:
	if not _charge_active:
		return
	if _charge_hit_done or _player == null or not _player.is_dashing():
		_charge_active = false
		return
	var hits := _query_cone_targets(charge_hit_radius, 360.0)
	if hits.is_empty():
		return
	_charge_hit_done = true
	_charge_active = false
	var target: Node = hits[0]
	_apply_skill_damage(_charge_skill, [target])
	if target.has_method("apply_effect"):
		target.call("apply_effect", StatusEffects.STUN, charge_stun_duration)
	_player.stop_dash()


## 战吼：5 秒攻击强度 +20%，周围敌人被嘲讽
func _execute_roar(_skill: SkillData) -> void:
	damage_multiplier = 1.0 + roar_attack_bonus
	_buff_time_left = roar_duration
	HitEffect.spawn_burst(_player, _player.global_position + Vector3.UP, Color(1.0, 0.82, 0.35), 36, 4.0)
	var targets := _query_cone_targets(roar_radius, 360.0)
	var taunted := 0
	for target in targets:
		if target.has_method("on_taunted"):
			target.call("on_taunted", _player, roar_taunt_duration)
			taunted += 1
	_show_feedback("战吼！攻击力 +%d%%（嘲讽 %d 个目标）" % [int(roar_attack_bonus * 100), taunted])


func _apply_skill_damage(skill: SkillData, targets: Array, bonus_multiplier := 1.0) -> void:
	if skill == null or targets.is_empty():
		return
	var is_crit := randf() < crit_chance
	var multiplier := damage_multiplier * bonus_multiplier
	# 精灵火焰增伤（烈焰晶灵）：带 fire 标签的玩家伤害额外加成
	if skill.combat_tags.has("fire") and _player.spirit_companion != null:
		multiplier *= 1.0 + _player.spirit_companion.get_flame_damage_bonus()
	var fx_parent := _player.get_parent()
	for target in targets:
		if not (target is Node) or not target.is_inside_tree():
			continue
		var target_node: Node = target
		var target_stats: Variant = null
		if target_node.has_method("get_stats"):
			target_stats = target_node.call("get_stats")
		var damage := DamageCalculator.calculate_damage(skill, attack_power, target_stats, is_crit, multiplier)
		# 连招组合（碎冰/电弧/火势/弱点）：由 ComboSystem 统一检测、加成与反馈
		var combo_result := ComboSystem.apply_on_hit(skill, target_node, damage, _player)
		damage = float(combo_result["damage"])
		if target_node.has_method("take_damage"):
			target_node.call("take_damage", damage)
		var effect_position := _player.global_position + Vector3.UP
		if target_node is Node3D:
			effect_position = (target_node as Node3D).global_position + Vector3.UP * 1.2
		DamageNumber.spawn(fx_parent, effect_position, damage, is_crit)
		var combos: Array = combo_result["combos"]
		for combo_name in combos:
			_show_feedback("%s！" % ComboSystem.DISPLAY_NAMES.get(combo_name, combo_name), ComboSystem.COLORS.get(combo_name, Color.WHITE))
		if combos.is_empty():
			HitEffect.spawn_burst(fx_parent, effect_position, Color(1.0, 0.9, 0.6), 10, 2.2)


## 扇形命中查询：命中第 4 层（hit_area）且实现 take_damage 的目标。
func _query_cone_targets(radius: float, arc_degrees: float) -> Array:
	var targets: Array = []
	if _player == null or not _player.is_inside_tree():
		return targets
	var origin := _player.global_position + Vector3.UP * 1.2
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collision_mask = 1 << 3  # 第 4 层：hit_area
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var results := _player.get_world_3d().direct_space_state.intersect_shape(params, 32)
	var forward := _player.get_aim_direction_flat()
	var half_angle := deg_to_rad(arc_degrees * 0.5)
	for result in results:
		var collider: Variant = result.get("collider")
		if not (collider is Node) or targets.has(collider):
			continue
		var target: Node = collider
		if not (target is Node3D) or not target.has_method("take_damage"):
			continue
		var aim_point := (target as Node3D).global_position
		if target.has_method("get_melee_target_point"):
			aim_point = target.call("get_melee_target_point", origin)
		var to_target: Vector3 = aim_point - _player.global_position
		to_target.y = 0.0
		var distance := to_target.length()
		if distance > radius + 0.6:
			continue
		if distance > 0.05 and arc_degrees < 359.9:
			if forward.angle_to(to_target / distance) > half_angle:
				continue
		targets.append(target)
	return targets


func _tick_cooldowns(delta: float) -> void:
	for skill_id in skill_cooldowns.keys():
		var remaining := float(skill_cooldowns[skill_id]) - delta
		if remaining <= 0.0:
			skill_cooldowns.erase(skill_id)
		else:
			skill_cooldowns[skill_id] = remaining


func _tick_action(delta: float) -> void:
	if not _action_locked:
		return
	if _player == null or _player.is_dead():
		_action_locked = false
		_pending_skill = null
		return
	_action_timer -= delta
	if _action_timer > 0.0:
		return
	_action_locked = false
	var skill := _pending_skill
	_pending_skill = null
	if skill != null:
		_execute_skill(skill)


func _tick_combo(delta: float) -> void:
	if _combo_time_left <= 0.0:
		return
	_combo_time_left -= delta
	if _combo_time_left <= 0.0:
		_combo_count = 0


func _tick_buff(delta: float) -> void:
	if _buff_time_left <= 0.0:
		return
	_buff_time_left -= delta
	if _buff_time_left <= 0.0:
		damage_multiplier = 1.0


func _update_block_state() -> void:
	if _player == null:
		return
	var want_block := _is_gameplay_input_active() \
			and Input.is_action_pressed("defend") \
			and not _player.is_dead() \
			and not _player.is_dodging()
	if want_block and not _blocking:
		_block_started_at = _clock
		if _fp_arms != null:
			_fp_arms.play_block_animation()
	elif not want_block and _blocking:
		if _fp_arms != null:
			_fp_arms.play_idle_animation()
	_blocking = want_block


func _handle_input() -> void:
	if _player == null or _player.is_dead():
		return
	if not _is_gameplay_input_active():
		return
	if Input.is_action_just_pressed("attack"):
		basic_attack()
	elif Input.is_action_just_pressed("skill_1"):
		use_skill_by_slot(0)
	elif Input.is_action_just_pressed("skill_2"):
		use_skill_by_slot(1)
	elif Input.is_action_just_pressed("skill_3"):
		use_skill_by_slot(2)


## 游戏输入是否可用：鼠标已捕获；无显示服务器（headless 自检）时鼠标模式恒为
## VISIBLE，此时放行以便自动化测试与服务器环境。对话进行中时屏蔽战斗输入。
func _is_gameplay_input_active() -> bool:
	if _player != null and _player.is_dialogue_active():
		return false
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return true
	return DisplayServer.get_name() == "headless"


func _play_skill_animation(skill: SkillData) -> void:
	if _fp_arms == null:
		return
	if skill.id == basic_attack_id:
		_fp_arms.play_attack_animation(_combo_count)
	else:
		_fp_arms.play_skill_animation(skill.id)


func _show_feedback(text: String, color := Color(1, 1, 1)) -> void:
	if _player != null:
		_player.show_combat_feedback(text, color)
