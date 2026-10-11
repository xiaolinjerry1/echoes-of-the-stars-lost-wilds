extends Area3D
## HitArea（怪物受击代理）
## 职责：攻击命中本 Area 时把所有战斗接口调用转交给父节点（怪物本体）。
## 怪物本体保持在 actor_body 层（避免被攻击查询直接命中造成重复结算），
## 只有本 Area 在 hit_area 层作为唯一受击判定体。

func take_damage(amount: float, attacker: Node = null) -> void:
	_delegate("take_damage", [amount, attacker])

## 大型箱形受击体按最近表面算近战距离，避免站在巨兽头前却打不到中心点。
func get_melee_target_point(origin: Vector3) -> Vector3:
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null or not collision.shape is BoxShape3D: return global_position
	var half := (collision.shape as BoxShape3D).size * 0.5
	var local := collision.to_local(origin)
	return collision.to_global(Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y), clampf(local.z, -half.z, half.z)))


func get_stats() -> Variant:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method("get_stats"):
		return owner_node.call("get_stats")
	return null


func apply_effect(effect_id: String, duration: float, power := 1.0, source: Node = null) -> void:
	_delegate("apply_effect", [effect_id, duration, power, source])


func remove_effect(effect_id: String) -> void:
	_delegate("remove_effect", [effect_id])


func has_effect(effect_id: String) -> bool:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method("has_effect"):
		return bool(owner_node.call("has_effect", effect_id))
	return false


func get_effect_power(effect_id: String) -> float:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method("get_effect_power"):
		return float(owner_node.call("get_effect_power", effect_id))
	return 0.0


func is_elite() -> bool:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method("is_elite"):
		return bool(owner_node.call("is_elite"))
	return false


func is_staggered() -> bool:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method("is_staggered"):
		return bool(owner_node.call("is_staggered"))
	return false


func on_taunted(source: Node, duration: float) -> void:
	_delegate("on_taunted", [source, duration])


func on_parried(duration: float) -> void:
	_delegate("on_parried", [duration])


func notify_damage_dealt(amount: float, target: Node) -> void:
	_delegate("notify_damage_dealt", [amount, target])


func _delegate(method_name: String, args: Array) -> void:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method(method_name):
		owner_node.callv(method_name, args)
