class_name EchoSystem
extends Node
## EchoSystem（世界回响系统，挂在 Player 下）
## 职责：回响收藏、准备槽（2 个，同一时间只能激活 1 份）、激活与能量管理、
## 切换冷却、回响技能释放（Z/X）与独立冷却、英灵记忆获取入口。
## 能量/冷却/激活状态由角色统一持有，不能通过换回响或读档重置；
## 暂停时（get_tree().paused）本节点随场景树暂停，计时与恢复全部停止。

signal echo_collected(echo_id: String)
signal echo_activated(echo_id: String)
signal echo_deactivated(echo_id: String)
signal energy_changed(current: float, maximum: float)
signal active_time_changed(remaining: float)
signal prep_slots_changed(slots: Array)

@export_group("能量与激活")
## 最大能量
@export var max_energy := 100.0
## 当前能量（激活消耗；初始满值）
@export var current_energy := 100.0
## 未激活时每秒恢复
@export var energy_regen := 5.0
## 激活消耗
@export var activate_cost := 100.0
## 激活持续时间（秒）
@export var activate_duration := 12.0

@export_group("准备槽")
## 准备槽数量（固定 2）
@export var prep_slot_count := 2
## 切换准备槽冷却（秒）
@export var swap_cooldown := 8.0
## 同时可激活的回响数量（平衡核心：固定 1）
@export var max_active_echoes := 1

## 已收藏的回响 id 列表
var collected_echoes: Array[String] = []
## 回响强化等级（echo_id → level；MVP 保留结构）
var echo_levels: Dictionary = {}
## 回响碎片（echo_id → 数量；MVP 保留结构）
var echo_fragments: Dictionary = {}
## 准备槽中的回响 id（可为空串）
var prep_slots: Array[String] = ["", ""]
## 当前激活的回响 id（空 = 未激活）
var active_echo_id := ""
## 激活剩余时间（秒）
var active_timer := 0.0
## 当前选中的准备槽索引
var current_slot_index := 0

var _swap_cooldown_timer := 0.0
## 回响技能 id → 剩余冷却（仅在激活期间计时）
var _skill_cooldowns: Dictionary = {}
var _player: PlayerController = null
var _combat: CombatManager = null
var _audio: AudioStreamPlayer = null
var _in_combat := false


## 由 PlayerController 在 _ready 时调用。
func setup(player: PlayerController) -> void:
	_player = player
	_combat = player.combat
	prep_slots.resize(prep_slot_count)
	_audio = AudioStreamPlayer.new()
	_audio.bus = "SFX"
	add_child(_audio)


func _process(delta: float) -> void:
	update(delta)


## 每帧更新：能量恢复 / 激活计时 / 技能冷却 / 切换冷却 / 输入。
func update(delta: float) -> void:
	if _swap_cooldown_timer > 0.0:
		_swap_cooldown_timer -= delta
	if is_active():
		_tick_active(delta)
	else:
		_tick_energy_regen(delta)
	_handle_input()


## ---- 收藏 / 准备槽 ----

## 收藏一份回响（不重复）。回响通过回响碑（主线）获得。
func collect_echo(echo_id: String) -> void:
	if echo_id.is_empty() or has_collected(echo_id):
		return
	collected_echoes.append(echo_id)
	echo_collected.emit(echo_id)
	_sync_session()
	print("[EchoSystem] 获得回响：%s" % echo_id)
	# 任务系统：回响获取事件
	var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	if quest_manager != null:
		quest_manager.notify_event("echo", echo_id, 1)

	SaveService.request_auto_save("echo")


func has_collected(echo_id: String) -> bool:
	return collected_echoes.has(echo_id)


## 把回响装入准备槽（需已收藏、未激活、脱离战斗）。
func equip_to_slot(slot_index: int, echo_id: String) -> bool:
	if slot_index < 0 or slot_index >= prep_slot_count:
		return false
	if is_active() or _in_combat:
		return false
	if not has_collected(echo_id):
		return false
	prep_slots[slot_index] = echo_id
	prep_slots_changed.emit(prep_slots)
	_sync_session()
	return true


## 切换当前准备槽（未激活 + 冷却结束才可切换）。
func swap_prep_slot() -> bool:
	if is_active() or _swap_cooldown_timer > 0.0:
		return false
	current_slot_index = (current_slot_index + 1) % prep_slot_count
	_swap_cooldown_timer = swap_cooldown
	return true


## 剩余切换冷却（秒，HUD/测试用）。
func get_swap_cooldown_remaining() -> float:
	return maxf(_swap_cooldown_timer, 0.0)


## 标记是否处于战斗（敌人 AI 接入后调用；战斗内不可调整准备槽）。
func set_in_combat(in_combat: bool) -> void:
	_in_combat = in_combat


## ---- 激活 ----

## 是否可激活（未激活 + 能量足够 + 当前槽有回响）。
func can_activate() -> bool:
	if max_active_echoes <= 0 or is_active():
		return false
	if current_energy < activate_cost:
		return false
	return not _get_prepared_echo_id().is_empty()


## 激活当前准备槽的回响（扣除能量，持续 activate_duration 秒）。
func activate_echo() -> bool:
	if not can_activate():
		return false
	var echo_id := _get_prepared_echo_id()
	var echo_data := DataRegistry.get_echo(echo_id)
	if echo_data == null:
		return false
	_set_energy(current_energy - activate_cost)
	active_echo_id = echo_id
	active_timer = activate_duration
	echo_activated.emit(echo_id)
	if _player != null:
		_player.fp_arms.set_echo_rune(echo_data.visual_theme_color, true)
		_player.set_echo_vignette(echo_data.visual_theme_color, true)
	_play_placeholder_sound(880.0)
	return true


## 提前结束激活（不返还能量）。
func deactivate_echo() -> void:
	if not is_active():
		return
	var echo_id := active_echo_id
	active_echo_id = ""
	active_timer = 0.0
	_skill_cooldowns.clear()
	echo_deactivated.emit(echo_id)
	if _player != null:
		_player.fp_arms.set_echo_rune(Color.WHITE, false)
		_player.set_echo_vignette(Color.WHITE, false)
	_play_placeholder_sound(330.0)


func is_active() -> bool:
	return not active_echo_id.is_empty()


## 当前激活回响的中文名（未激活返回空串）。
func get_active_echo_name() -> String:
	if not is_active():
		return ""
	var data := DataRegistry.get_echo(active_echo_id)
	return data.display_name if data != null else active_echo_id


## ---- 回响技能 ----

## 使用激活回响的第 (slot+1) 个技能（Z = 0 / X = 1）。
func use_echo_skill(slot: int) -> bool:
	if not is_active() or _player == null:
		return false
	var skill := _get_skill(slot)
	if skill == null:
		return false
	if get_skill_cooldown_remaining(skill.id) > 0.0:
		_player.show_combat_feedback("回响技能冷却中", Color(0.6, 0.8, 1.0))
		return false
	if _player.is_dead() or _player.is_dodging():
		return false
	_execute_skill(skill)
	_skill_cooldowns[skill.id] = skill.cooldown
	return true


## 当前激活回响的第 (slot+1) 个技能（未激活返回 null，供 HUD 显示）。
func get_echo_skill(slot: int) -> SkillData:
	return _get_skill(slot)


## 技能剩余冷却（秒）。
func get_skill_cooldown_remaining(skill_id: String) -> float:
	return float(_skill_cooldowns.get(skill_id, 0.0))


## ---- 技能实现 ----

func _execute_skill(skill: SkillData) -> void:
	match skill.id:
		"frost_crystal_bolt":
			_execute_frost_bolt(skill)
		"fireball":
			_execute_fireball(skill)
		"ember_burst":
			_execute_ember_burst(skill)
		_:
			_execute_frost_ring(skill)


## 冰环：以玩家为中心的范围 AOE；普通敌人冻结，精英/BOSS 只减速。
func _execute_frost_ring(skill: SkillData) -> void:
	var echo_data := DataRegistry.get_echo(active_echo_id)
	var color := Color(0.45, 0.8, 1.0)
	if echo_data != null:
		color = echo_data.visual_theme_color
	var fx_parent := _player.get_parent()
	RingEffect.spawn(fx_parent, _player.global_position + Vector3.UP * 0.12, color, skill.range)
	var targets := TargetQuery.find_targets(_player, skill.range)
	var is_crit := false
	if _combat != null:
		is_crit = randf() < _combat.crit_chance
	for target in targets:
		var target_node: Node = target
		var target_stats: Variant = null
		if target_node.has_method("get_stats"):
			target_stats = target_node.call("get_stats")
		var damage := 0.0
		if _combat != null:
			damage = DamageCalculator.calculate_damage(skill, _combat.attack_power, target_stats, is_crit, _combat.damage_multiplier)
		# 连招检测（弱点暴击等）
		var combo_result := ComboSystem.apply_on_hit(skill, target_node, damage, _player)
		damage = float(combo_result["damage"])
		if target_node.has_method("take_damage"):
			target_node.call("take_damage", damage)
		if target_node is Node3D:
			var hit_position: Vector3 = (target_node as Node3D).global_position + Vector3.UP
			DamageNumber.spawn(fx_parent, hit_position + Vector3.UP * 0.6, damage, is_crit, color)
			HitEffect.spawn_burst(fx_parent, hit_position, color, 16, 2.8)
		for combo_name in combo_result["combos"]:
			_player.show_combat_feedback("%s！" % ComboSystem.DISPLAY_NAMES.get(combo_name, combo_name), ComboSystem.COLORS.get(combo_name, Color.WHITE))
		# 冻结普通敌人；精英/BOSS 只施加寒意（减速）
		if target_node.has_method("apply_effect"):
			var elite := target_node.has_method("is_elite") and bool(target_node.call("is_elite"))
			if elite:
				target_node.call("apply_effect", StatusEffects.CHILLED, skill.status_duration, 0.5, _player)
			else:
				target_node.call("apply_effect", StatusEffects.FROZEN, skill.status_duration, 1.0, _player)
				# 任务系统：冻结事件
				var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
				if quest_manager != null:
					quest_manager.notify_event("freeze", "frozen", 1)
	if _player != null:
		_player.fp_arms.play_skill_animation("frost_ring")


## 寒晶弹：沿相机方向发射投射物。
func _execute_frost_bolt(skill: SkillData) -> void:
	var camera := _player.camera
	var origin := camera.global_position + (-camera.global_transform.basis.z) * 0.6
	var direction := -camera.global_transform.basis.z
	FrostBolt.spawn(_player.get_parent(), origin, direction, skill, _combat)
	_player.fp_arms.play_skill_animation("frost_crystal_bolt")


## 火球：沿相机方向发射，命中后 2 米范围爆炸并施加灼烧。
func _execute_fireball(skill: SkillData) -> void:
	var camera := _player.camera
	var origin := camera.global_position + (-camera.global_transform.basis.z) * 0.6
	var direction := -camera.global_transform.basis.z
	Fireball.spawn(_player.get_parent(), origin, direction, skill, _combat, _player)
	_player.fp_arms.play_skill_animation("fireball")


## 余烬爆发：以玩家为中心；对灼烧目标 +50% 并刷新灼烧。
func _execute_ember_burst(skill: SkillData) -> void:
	var color := Color(1.0, 0.5, 0.2)
	var echo_data := DataRegistry.get_echo(active_echo_id)
	if echo_data != null:
		color = echo_data.visual_theme_color
	var fx_parent := _player.get_parent()
	RingEffect.spawn(fx_parent, _player.global_position + Vector3.UP * 0.12, color, skill.range)
	var targets := TargetQuery.find_targets(_player, skill.range)
	var is_crit := false
	if _combat != null:
		is_crit = randf() < _combat.crit_chance
	for target in targets:
		var target_node: Node = target
		var has_burning := target_node.has_method("has_effect") and bool(target_node.call("has_effect", StatusEffects.BURNING))
		var target_stats: Variant = null
		if target_node.has_method("get_stats"):
			target_stats = target_node.call("get_stats")
		var damage := 0.0
		if _combat != null:
			damage = DamageCalculator.calculate_damage(skill, _combat.attack_power, target_stats, is_crit, _combat.damage_multiplier)
		if has_burning:
			damage *= 1.5
			# 刷新灼烧持续时间（沿用当前 DPS 公式）
			if target_node.has_method("apply_effect"):
				target_node.call("apply_effect", StatusEffects.BURNING, Fireball.BURN_DURATION, _burn_dps(), _player)
		# 连招检测（火势扩散等）
		var combo_result := ComboSystem.apply_on_hit(skill, target_node, damage, _player)
		damage = float(combo_result["damage"])
		if target_node.has_method("take_damage"):
			target_node.call("take_damage", damage)
		if target_node is Node3D:
			var hit_position: Vector3 = (target_node as Node3D).global_position + Vector3.UP * 1.2
			DamageNumber.spawn(fx_parent, hit_position, damage, is_crit, color)
			HitEffect.spawn_burst(fx_parent, hit_position, color, 18, 3.2)
		for combo_name in combo_result["combos"]:
			_player.show_combat_feedback("%s！" % ComboSystem.DISPLAY_NAMES.get(combo_name, combo_name), ComboSystem.COLORS.get(combo_name, Color.WHITE))
	if _player != null:
		_player.fp_arms.play_skill_animation("ember_burst")


## ---- 内部实现 ----

func _burn_dps() -> float:
	var power := 0.0
	if _combat != null:
		power = _combat.attack_power
	return Fireball.compute_burn_dps(power)


func _tick_active(delta: float) -> void:
	for skill_id in _skill_cooldowns.keys():
		var remaining := float(_skill_cooldowns[skill_id]) - delta
		if remaining <= 0.0:
			_skill_cooldowns.erase(skill_id)
		else:
			_skill_cooldowns[skill_id] = remaining
	active_timer -= delta
	active_time_changed.emit(maxf(active_timer, 0.0))
	if active_timer <= 0.0:
		deactivate_echo()


func _tick_energy_regen(delta: float) -> void:
	if current_energy >= max_energy:
		return
	_set_energy(minf(current_energy + energy_regen * delta, max_energy))


func _set_energy(value: float) -> void:
	current_energy = clampf(value, 0.0, max_energy)
	energy_changed.emit(current_energy, max_energy)
	_sync_session()


func _get_skill(slot: int) -> SkillData:
	if not is_active():
		return null
	var echo_data := DataRegistry.get_echo(active_echo_id)
	if echo_data == null or slot < 0 or slot >= echo_data.echo_skills.size():
		return null
	return echo_data.echo_skills[slot]


func _get_prepared_echo_id() -> String:
	if prep_slots.is_empty():
		return ""
	var index := clampi(current_slot_index, 0, prep_slots.size() - 1)
	return prep_slots[index]


func _handle_input() -> void:
	if _player == null or _player.is_dead():
		return
	if not _is_gameplay_input_active():
		return
	if Input.is_action_just_pressed("echo_activate"):
		if is_active():
			deactivate_echo()
		else:
			activate_echo()
	elif Input.is_action_just_pressed("echo_skill_1"):
		use_echo_skill(0)
	elif Input.is_action_just_pressed("echo_skill_2"):
		use_echo_skill(1)
	elif Input.is_action_just_pressed("echo_swap"):
		swap_prep_slot()


## 游戏输入是否可用（与战斗系统一致：headless 自检时放行；对话中屏蔽）。
func _is_gameplay_input_active() -> bool:
	if _player != null and _player.is_dialogue_active():
		return false
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return true
	return DisplayServer.get_name() == "headless"


## 状态同步到游戏会话（供存档持久化；防读档重置能量）。
func _sync_session() -> void:
	var session := AppFlow.game_session
	if session == null or not is_instance_valid(session):
		return
	session.collected_echoes.assign(collected_echoes)
	session.prep_slots.assign(prep_slots)
	session.echo_energy = current_energy


## ---- 占位音效（代码生成，无外部音频资产） ----

func _play_placeholder_sound(freq: float) -> void:
	if _audio == null:
		return
	_audio.stream = ComboNotifier.make_beep(freq, 0.16)
	_audio.play()


func get_save_data() -> Dictionary:
	return {
		"collected_echoes": collected_echoes.duplicate(),
		"prep_slots": prep_slots.duplicate(),
		"echo_energy": current_energy,
		"echo_levels": echo_levels.duplicate(),
		"echo_fragments": echo_fragments.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	collected_echoes.assign(data.get("collected_echoes", []))
	prep_slots.assign(data.get("prep_slots", ["", ""]))
	current_energy = clampf(float(data.get("echo_energy", max_energy)), 0.0, max_energy)
	echo_levels = (data.get("echo_levels", {}) as Dictionary).duplicate()
	echo_fragments = (data.get("echo_fragments", {}) as Dictionary).duplicate()
	active_echo_id = ""
	active_timer = 0.0
	if _player != null:
		_player.set_echo_vignette(Color.WHITE, false)
	_sync_session()
