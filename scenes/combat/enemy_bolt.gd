class_name EnemyBolt
extends Area3D
## EnemyBolt（敌方魔法弹）
## 职责：朝玩家直线飞行（15 m/s，射程 15 米），命中玩家或障碍后爆裂。
## 命中时把伤害转交给目标并把战报回传给施法者（damage_dealt 信号）。

const SPEED := 15.0
const MAX_RANGE := 15.0
const HIT_RADIUS := 0.7

var damage := 5.0
var target: Node3D = null
var source_enemy: Node = null

var _direction := Vector3.FORWARD
var _traveled := 0.0
var _exploded := false


## 生成一枚魔法弹。
static func spawn(parent: Node, from: Vector3, target_node: Node3D, damage_amount: float, enemy: Node = null) -> EnemyBolt:
	if parent == null or not parent.is_inside_tree():
		return null
	var bolt := EnemyBolt.new()
	bolt.damage = damage_amount
	bolt.target = target_node
	bolt.source_enemy = enemy
	if target_node != null:
		bolt._direction = (target_node.global_position + Vector3.UP * 1.0 - from).normalized()
	parent.add_child(bolt)
	bolt.global_position = from
	bolt._build_visual()
	return bolt


func _build_visual() -> void:
	collision_layer = 0
	collision_mask = 1 << 3
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	shape.shape = sphere
	add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.9, 0.55)
	material.emission_enabled = true
	material.emission = Color(0.4, 1.0, 0.5)
	material.emission_energy_multiplier = 2.5
	mesh.material = material
	mesh_instance.mesh = mesh
	add_child(mesh_instance)


func _process(delta: float) -> void:
	if _exploded:
		return
	var step := SPEED * delta
	_traveled += step
	if _traveled >= MAX_RANGE:
		_explode(false)
		return
	# 撞墙检测（world_static 第 1 层）
	var space := get_world_3d().direct_space_state
	var ray_params := PhysicsRayQueryParameters3D.create(global_position, global_position + _direction * step, 1)
	var wall := space.intersect_ray(ray_params)
	if not wall.is_empty():
		global_position = wall.get("position", global_position)
		_explode(false)
		return
	global_position += _direction * step
	# 命中玩家
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		if global_position.distance_to(target.global_position + Vector3.UP * 1.0) <= HIT_RADIUS:
			if target.has_method("take_damage"):
				target.call("take_damage", damage, source_enemy)
			if source_enemy != null and is_instance_valid(source_enemy) and source_enemy.has_method("notify_damage_dealt"):
				source_enemy.call("notify_damage_dealt", damage, target)
			_explode(true)


func _explode(hit: bool) -> void:
	if _exploded:
		return
	_exploded = true
	HitEffect.spawn_burst(get_parent(), global_position, Color(0.45, 1.0, 0.55), 14 if hit else 8, 2.4)
	queue_free()
