class_name SpiritCompanion
extends Node
## SpiritCompanion（精灵伙伴组件，挂在 Player 的 SpiritMount 下）
## 职责：加载精灵数据并生成视觉实体；驱动三种定位的自动/被动效果——
## 治疗型（定时回血 + 低血应急护盾）、攻击型（自动火球 + 火焰增伤）、
## 防御型（受击减伤 + 周期嘲讽）；管理击退状态与等级缩放。
## 精灵不会死亡、无独立血条、无主动按键，全部自动/被动触发。

signal spirit_changed(spirit_data: SpiritData)
signal effect_triggered(effect_type: String, feedback_text: String)

const ENTITY_SCENE := preload("res://scenes/player/spirit_entity.tscn")

@export_group("行为参数")
## 护盾持续时间（秒）
@export var shield_duration := 5.0
## 嘲讽持续时间（秒）
@export var taunt_duration := 3.0
## 被击退后自动回归时间（秒）
@export var knockback_return_time := 2.0
## 是否启用自动效果（自检/演出可临时关闭）
@export var effects_enabled := true

var spirit_data: SpiritData = null
var spirit_level := 1

var _player: PlayerController = null
var _mount: Node3D = null
var _entity: SpiritEntity = null

var _heal_timer := 0.0
var _attack_timer := 0.0
var _shield_cooldown := 0.0
var _taunt_cooldown := 0.0
var _shield_time_left := 0.0
var _is_knocked_back := false
var _return_timer := 0.0


## 由 PlayerController 在 _ready 时调用。
func setup(player: PlayerController) -> void:
	_player = player
	_mount = get_parent() as Node3D
	_spawn_entity()


## ---- 存档接口 ----


## 精灵快照（id 与等级；运行期冷却不保存，读档后重置为就绪）。
func get_save_data() -> Dictionary:
	return {
		"spirit_id": spirit_data.id if spirit_data != null else "",
		"spirit_level": spirit_level,
	}


func load_save_data(data: Dictionary) -> void:
	var saved_id := str(data.get("spirit_id", ""))
	var saved_level := maxi(int(data.get("spirit_level", 1)), 1)
	if saved_id.is_empty():
		return
	initialize(saved_id, saved_level)


func _exit_tree() -> void:
	if _entity != null and is_instance_valid(_entity):
		_entity.queue_free()
	_entity = null


func _process(delta: float) -> void:
	update(delta)


## 初始化/切换精灵（读档时传入存档中的 id 与 spirit_level）。
func initialize(spirit_id: String, level := 1) -> void:
	spirit_data = DataRegistry.get_spirit(spirit_id)
	if spirit_data == null:
		push_error("SpiritCompanion: 找不到精灵数据 %s" % spirit_id)
		return
	spirit_level = maxi(level, 1)
	_heal_timer = 0.0
	_attack_timer = 0.0
	_shield_cooldown = 0.0
	_taunt_cooldown = 0.0
	_shield_time_left = 0.0
	_is_knocked_back = false
	_return_timer = 0.0
	if _player != null and _player.stats != null:
		_player.stats.clear_shield()
	if _entity != null and is_instance_valid(_entity):
		_entity.setup_model(spirit_data)
	spirit_changed.emit(spirit_data)


## 每帧更新所有自动效果计时。
func update(delta: float) -> void:
	if spirit_data == null or _player == null or not effects_enabled:
		return
	_tick_knockback(delta)
	if _is_knocked_back or _player.is_dead():
		return
	_tick_cooldowns(delta)
	if spirit_data.passive_heal_interval > 0.0:
		_tick_heal(delta)
	if spirit_data.emergency_shield_threshold > 0.0:
		_tick_emergency_shield()
	if spirit_data.auto_attack_interval > 0.0:
		_tick_auto_attack(delta)
	if spirit_data.taunt_range > 0.0:
		_tick_taunt()


## ---- 查询 / 对外接口 ----

## 按等级缩放效果值：base × (1 + growth × (等级 - 1))。
func get_effective_value(base_value: float) -> float:
	if spirit_data == null:
		return base_value
	return base_value * (1.0 + spirit_data.growth_coefficient * (spirit_level - 1))


## 玩家火焰伤害加成（烈焰晶灵）。
func get_flame_damage_bonus() -> float:
	if spirit_data == null:
		return 0.0
	return get_effective_value(spirit_data.flame_damage_bonus)


## 玩家受击减伤比例（磐石守灵）。
func get_damage_reduction() -> float:
	if spirit_data == null:
		return 0.0
	return clampf(get_effective_value(spirit_data.damage_reduction), 0.0, 0.9)


## 是否处于被击退状态。
func is_knocked_back() -> bool:
	return _is_knocked_back


## 受到范围伤害时的击退入口（敌人 AoE 技能 / 测试调用）。
func knock_back(from_position: Vector3) -> void:
	if _is_knocked_back:
		return
	_is_knocked_back = true
	_return_timer = knockback_return_time
	if _entity != null and is_instance_valid(_entity):
		_entity.apply_knockback(from_position)


## 测试/演出用：启停自动效果。
func set_effects_enabled(enabled: bool) -> void:
	effects_enabled = enabled


## 玩家受击时通知精灵播放反应特效（磐石守灵裂纹发光等）。
func play_entity_effect(effect_type: String) -> void:
	_play_effect(effect_type)


## UI 用：精灵效果摘要（HUD Tooltip / 角色面板）。
func get_effect_summary() -> String:
	if spirit_data == null:
		return ""
	var lines: Array[String] = [spirit_data.display_name]
	if not spirit_data.description.is_empty():
		lines.append(spirit_data.description)
	if spirit_data.passive_heal_interval > 0.0:
		lines.append("· 每 %d 秒恢复 %.0f 生命" % [int(spirit_data.passive_heal_interval), get_effective_value(spirit_data.passive_heal_amount)])
	if spirit_data.emergency_shield_threshold > 0.0:
		lines.append("· 生命低于 %d%% 时获得 %.0f 点护盾（冷却 %ds）" % [
			int(spirit_data.emergency_shield_threshold * 100.0),
			get_effective_value(spirit_data.emergency_shield_amount),
			int(spirit_data.emergency_shield_cooldown),
		])
	if spirit_data.auto_attack_interval > 0.0:
		lines.append("· 每 %.1f 秒自动攻击最近敌人（%.0f 伤害）" % [
			spirit_data.auto_attack_interval,
			get_effective_value(spirit_data.auto_attack_damage),
		])
	if spirit_data.flame_damage_bonus > 0.0:
		lines.append("· 玩家火焰伤害 +%d%%" % int(get_effective_value(spirit_data.flame_damage_bonus) * 100.0))
	if spirit_data.damage_reduction > 0.0:
		lines.append("· 玩家受到伤害 -%d%%" % int(get_effective_value(spirit_data.damage_reduction) * 100.0))
	if spirit_data.taunt_range > 0.0:
		lines.append("· 每 %d 秒嘲讽 %.0f 米内敌人" % [int(spirit_data.taunt_cooldown), spirit_data.taunt_range])
	return "\n".join(lines)


## ---- 内部实现 ----

func _spawn_entity() -> void:
	if _mount == null or _player == null:
		return
	_entity = ENTITY_SCENE.instantiate() as SpiritEntity
	var world := _player.get_parent()
	if world == null:
		world = _mount
	# 延迟一帧挂载：玩家 _ready 时场景根节点可能仍在挂载过程中（busy）
	_attach_entity.call_deferred(world)


func _attach_entity(world: Node) -> void:
	if _entity == null or not is_instance_valid(_entity):
		return
	if world == null or not is_instance_valid(world):
		return
	world.add_child(_entity)
	_entity.global_position = _mount.global_position
	_entity.follow_target = _mount


func _tick_knockback(delta: float) -> void:
	if not _is_knocked_back:
		return
	_return_timer -= delta
	if _return_timer <= 0.0:
		_is_knocked_back = false
		if _entity != null and is_instance_valid(_entity):
			_entity.end_knockback()


func _tick_cooldowns(delta: float) -> void:
	if _shield_cooldown > 0.0:
		_shield_cooldown -= delta
	if _taunt_cooldown > 0.0:
		_taunt_cooldown -= delta
	if _shield_time_left > 0.0:
		_shield_time_left -= delta
		if _shield_time_left <= 0.0 and _player != null:
			_player.stats.clear_shield()


func _tick_heal(delta: float) -> void:
	_heal_timer += delta
	if _heal_timer < spirit_data.passive_heal_interval:
		return
	_heal_timer = 0.0
	var stats := _player.stats
	if stats.current_health >= stats.max_health:
		return
	var amount := get_effective_value(spirit_data.passive_heal_amount)
	stats.heal(amount)
	_play_effect("heal")
	DamageNumber.spawn(_player.get_parent(), _player.global_position + Vector3.UP * 1.9, amount, false, Color(0.5, 1.0, 0.55))
	effect_triggered.emit("heal", "+%d" % roundi(amount))


func _tick_emergency_shield() -> void:
	if _shield_cooldown > 0.0 or _shield_time_left > 0.0:
		return
	var stats := _player.stats
	if stats.max_health <= 0.0 or stats.current_health / stats.max_health > spirit_data.emergency_shield_threshold:
		return
	stats.add_shield(get_effective_value(spirit_data.emergency_shield_amount))
	_shield_time_left = shield_duration
	_shield_cooldown = spirit_data.emergency_shield_cooldown
	_play_effect("shield")
	_player.show_combat_feedback("应急护盾！", Color(1.0, 0.95, 0.7))
	effect_triggered.emit("shield", "护盾！")


func _tick_auto_attack(delta: float) -> void:
	_attack_timer += delta
	if _attack_timer < spirit_data.auto_attack_interval:
		return
	_attack_timer = 0.0
	var targets := TargetQuery.find_targets(_player, spirit_data.auto_attack_range, true)
	if targets.is_empty():
		return
	var target: Node3D = targets[0]
	_play_effect("attack")
	var from := _player.global_position + Vector3.UP * 1.4
	if _entity != null and is_instance_valid(_entity):
		from = _entity.global_position
	SpiritFireball.spawn(_player.get_parent(), from, target, get_effective_value(spirit_data.auto_attack_damage))


func _tick_taunt() -> void:
	if _taunt_cooldown > 0.0:
		return
	var targets := TargetQuery.find_targets(_player, spirit_data.taunt_range)
	if targets.is_empty():
		return
	_taunt_cooldown = spirit_data.taunt_cooldown
	var taunted := 0
	for target in targets:
		if target.has_method("on_taunted"):
			target.call("on_taunted", _player, taunt_duration)
			taunted += 1
	if taunted > 0:
		_play_effect("taunt")
		effect_triggered.emit("taunt", "嘲讽！")


func _play_effect(effect_type: String) -> void:
	if _entity != null and is_instance_valid(_entity):
		_entity.play_effect(effect_type)
