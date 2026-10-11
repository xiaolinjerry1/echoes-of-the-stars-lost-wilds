class_name TargetQuery
extends RefCounted
## TargetQuery（目标查询工具，纯静态类）
## 职责：按 hit_area（物理第 4 层）查询范围内实现了 take_damage 的目标，
## 供精灵自动攻击 / 嘲讽与后续敌人 AI 共用。

## 查询以 origin_node 为圆心、radius 米内的目标列表；
## nearest_only 为 true 时只返回最近的一个。
static func find_targets(origin_node: Node3D, radius: float, nearest_only := false) -> Array:
	var targets: Array = []
	if origin_node == null or not origin_node.is_inside_tree():
		return targets
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, origin_node.global_position)
	params.collision_mask = 1 << 3  # 第 4 层：hit_area
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var results := origin_node.get_world_3d().direct_space_state.intersect_shape(params, 32)
	for result in results:
		var collider: Variant = result.get("collider")
		if not (collider is Node3D) or targets.has(collider):
			continue
		if not (collider as Node).has_method("take_damage"):
			continue
		targets.append(collider)
	if nearest_only and targets.size() > 1:
		var origin: Vector3 = origin_node.global_position
		targets.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
		return [targets[0]]
	return targets
