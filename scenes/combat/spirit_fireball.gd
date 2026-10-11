class_name SpiritFireball
extends Area3D
## SpiritFireball（精灵火球投射物）
## 职责：由烈焰晶灵自动攻击生成；温和追踪目标飞行，接近后爆裂造成伤害。
## 视觉为发光小球（正式特效资产后续替换）。

const SPEED := 15.0
const LIFETIME := 3.0
const HIT_DISTANCE := 0.6

var damage := 5.0
var target: Node3D = null

var _life := 0.0
var _direction := Vector3.FORWARD


## 生成一枚火球；target 失效时沿初始方向直飞直至超时。
static func spawn(parent: Node, from: Vector3, target_node: Node3D, damage_amount: float) -> SpiritFireball:
	if parent == null or not parent.is_inside_tree():
		return null
	var fireball := SpiritFireball.new()
	fireball.damage = damage_amount
	fireball.target = target_node
	parent.add_child(fireball)
	fireball.global_position = from
	if target_node != null and target_node.is_inside_tree():
		fireball._direction = (target_node.global_position + Vector3.UP * 0.8 - from).normalized()
	fireball._build_visual()
	return fireball


func _build_visual() -> void:
	collision_layer = 0
	collision_mask = 1 << 3
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.12
	shape.shape = sphere
	add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.55, 0.2)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.5, 0.15)
	material.emission_energy_multiplier = 3.0
	mesh.material = material
	mesh_instance.mesh = mesh
	add_child(mesh_instance)


func _process(delta: float) -> void:
	_life += delta
	if _life >= LIFETIME:
		_explode(false)
		return
	if is_instance_valid(target) and target.is_inside_tree():
		var aim_point := target.global_position + Vector3.UP * 0.8
		var desired := (aim_point - global_position).normalized()
		_direction = _direction.lerp(desired, clampf(4.0 * delta, 0.0, 1.0)).normalized()
		if global_position.distance_to(aim_point) <= HIT_DISTANCE:
			_explode(true)
			return
	global_position += _direction * SPEED * delta


func _explode(hit: bool) -> void:
	if hit and is_instance_valid(target) and target.has_method("take_damage"):
		target.call("take_damage", damage)
		if target is Node3D:
			DamageNumber.spawn(get_parent(), (target as Node3D).global_position + Vector3.UP * 1.6, damage, false, Color(1.0, 0.7, 0.35))
	HitEffect.spawn_burst(get_parent(), global_position, Color(1.0, 0.55, 0.2), 16, 3.0)
	queue_free()
