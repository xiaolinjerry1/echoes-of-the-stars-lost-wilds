class_name StatusEffectComponent
extends Node
## StatusEffectComponent（状态效果组件）
## 职责：挂在怪物/玩家身上，管理状态效果的施加、刷新、计时与移除；
## 对灼烧（burning）每 0.5 秒跳一次持续伤害（power = 每秒伤害 DPS），
## 其余效果只做数据与计时，具体表现由监听方处理。

signal effect_applied(effect_id: String, duration: float, power: float)
signal effect_removed(effect_id: String)

## 灼烧跳伤间隔（秒）
const BURN_TICK_INTERVAL := 0.5

## effect_id → { "duration": float, "power": float, "time_left": float, "source": Node }
var _effects: Dictionary = {}
var _burn_timer := 0.0


func _process(delta: float) -> void:
	_tick_burning(delta)
	if _effects.is_empty():
		return
	var expired: Array[String] = []
	for effect_id: String in _effects:
		var entry: Dictionary = _effects[effect_id]
		entry["time_left"] = float(entry["time_left"]) - delta
		if float(entry["time_left"]) <= 0.0:
			expired.append(effect_id)
	for effect_id in expired:
		remove_effect(effect_id)


## 施加/刷新状态效果。
## power 含义随效果而定：灼烧 = 每秒伤害（DPS），冻结 = 强度，寒意 = 减速比例。
## source 为施加者（灼烧伤害来源记录）。
func apply_effect(effect_id: String, duration: float, power: float = 1.0, source: Node = null) -> void:
	if effect_id.is_empty() or duration <= 0.0:
		return
	var entry: Dictionary
	if _effects.has(effect_id):
		entry = _effects[effect_id]
		entry["duration"] = duration
		entry["time_left"] = duration
		entry["power"] = maxf(float(entry["power"]), power)
		if source != null:
			entry["source"] = source
	else:
		entry = {"duration": duration, "power": power, "time_left": duration, "source": source}
		_effects[effect_id] = entry
	effect_applied.emit(effect_id, duration, float(entry["power"]))


## 移除状态效果（不存在时安全忽略）。
func remove_effect(effect_id: String) -> void:
	if not _effects.has(effect_id):
		return
	_effects.erase(effect_id)
	if effect_id == StatusEffects.BURNING:
		_burn_timer = 0.0
	effect_removed.emit(effect_id)


## 是否拥有某状态效果。
func has_effect(effect_id: String) -> bool:
	return _effects.has(effect_id)


## 某状态效果的强度（无则返回 0）。
func get_effect_power(effect_id: String) -> float:
	if not _effects.has(effect_id):
		return 0.0
	return float(_effects[effect_id]["power"])


## 某状态效果的施加者（无则 null）。
func get_effect_source(effect_id: String) -> Node:
	if not _effects.has(effect_id):
		return null
	var source: Variant = _effects[effect_id].get("source")
	return source if source is Node else null


## 当前所有状态效果 id 列表。
func get_active_effects() -> Array:
	return _effects.keys()


## ---- 内部实现 ----

## 灼烧跳伤：每 0.5 秒对宿主造成 DPS × 0.5 的伤害，并附火焰粒子反馈。
func _tick_burning(delta: float) -> void:
	if not _effects.has(StatusEffects.BURNING):
		_burn_timer = 0.0
		return
	_burn_timer += delta
	if _burn_timer < BURN_TICK_INTERVAL:
		return
	_burn_timer -= BURN_TICK_INTERVAL
	var entry: Dictionary = _effects[StatusEffects.BURNING]
	var tick_damage := float(entry["power"]) * BURN_TICK_INTERVAL
	var owner_node := get_parent()
	if owner_node == null:
		return
	if owner_node.has_method("take_damage"):
		owner_node.call("take_damage", tick_damage)
	if owner_node is Node3D and owner_node.is_inside_tree():
		var fx_parent := owner_node.get_parent()
		if fx_parent != null:
			HitEffect.spawn_burst(fx_parent, (owner_node as Node3D).global_position + Vector3.UP * 0.8, Color(1.0, 0.55, 0.2), 5, 1.3)
