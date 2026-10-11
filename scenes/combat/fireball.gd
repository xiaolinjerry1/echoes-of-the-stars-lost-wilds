class_name Fireball
extends Area3D
## Fireball（火球投射物）
## 职责：沿相机方向飞行（20 m/s，射程 25 米），命中/撞墙/到程后 2 米范围爆炸：
## 对范围内目标造成直接伤害并施加灼烧（burning，DPS = 3 + 攻击强度×0.2，持续 4 秒）。

const SPEED := 20.0
const MAX_RANGE := 25.0
const BLAST_RADIUS := 2.0
const HIT_RADIUS := 0.5
const BURN_DURATION := 4.0
const BURN_BASE_DPS := 3.0
const BURN_POWER_COEFFICIENT := 0.2

var skill: SkillData = null
var combat: CombatManager = null
var attacker: Node = null

var _direction := Vector3.FORWARD
var _traveled := 0.0
var _exploded := false


## 计算灼烧每秒伤害（供火球与余烬爆发共用）。
static func compute_burn_dps(attack_power: float) -> float:
	return BURN_BASE_DPS + attack_power * BURN_POWER_COEFFICIENT


## 生成一枚火球。
static func spawn(parent: Node, from: Vector3, direction: Vector3, skill_data: SkillData, combat_manager: CombatManager, attacker_node: Node = null) -> Fireball:
	if parent == null or not parent.is_inside_tree():
		return null
	var fireball := Fireball.new()
	fireball.skill = skill_data
	fireball.combat = combat_manager
	fireball.attacker = attacker_node
	fireball._direction = direction.normalized()
	parent.add_child(fireball)
	fireball.global_position = from
	fireball._build_visual()
	return fireball


func _build_visual() -> void:
	collision_layer = 0
	collision_mask = 1 << 3
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 10
	mesh.rings = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.55, 0.2)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45, 0.1)
	material.emission_energy_multiplier = 3.0
	mesh.material = material
	mesh_instance.mesh = mesh
	add_child(mesh_instance)


func _process(delta: float) -> void:
	var step := SPEED * delta
	_traveled += step
	if _traveled >= MAX_RANGE:
		_explode()
		return
	# 撞墙检测（world_static 第 1 层）
	var space := get_world_3d().direct_space_state
	var ray_params := PhysicsRayQueryParameters3D.create(global_position, global_position + _direction * step, 1)
	var wall := space.intersect_ray(ray_params)
	if not wall.is_empty():
		global_position = wall.get("position", global_position)
		_explode()
		return
	global_position += _direction * step
	# 命中敌人（hit_area 第 4 层）→ 就地爆炸
	var targets := TargetQuery.find_targets(self, HIT_RADIUS, true)
	if not targets.is_empty():
		_explode()


## 2 米范围爆炸：直接伤害 + 施加灼烧（附连招检测）。
func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var parent := get_parent()
	var is_crit := false
	var burn_dps := BURN_BASE_DPS
	if combat != null:
		is_crit = randf() < combat.crit_chance
		burn_dps = compute_burn_dps(combat.attack_power)
	var targets := TargetQuery.find_targets(self, BLAST_RADIUS)
	for target in targets:
		var target_node: Node = target
		var target_stats: Variant = null
		if target_node.has_method("get_stats"):
			target_stats = target_node.call("get_stats")
		var damage := 0.0
		if combat != null and skill != null:
			damage = DamageCalculator.calculate_damage(skill, combat.attack_power, target_stats, is_crit, combat.damage_multiplier)
		# 连招检测（火势扩散等）
		if skill != null:
			var combo_result := ComboSystem.apply_on_hit(skill, target_node, damage, attacker)
			damage = float(combo_result["damage"])
		if target_node.has_method("take_damage"):
			target_node.call("take_damage", damage)
		if target_node.has_method("apply_effect"):
			target_node.call("apply_effect", StatusEffects.BURNING, BURN_DURATION, burn_dps, attacker)
		if target_node is Node3D:
			var hit_position: Vector3 = (target_node as Node3D).global_position + Vector3.UP * 1.4
			DamageNumber.spawn(parent, hit_position, damage, is_crit, Color(1.0, 0.65, 0.3))
			HitEffect.spawn_burst(parent, hit_position, Color(1.0, 0.5, 0.15), 14, 2.8)
	HitEffect.spawn_burst(parent, global_position, Color(1.0, 0.5, 0.15), 26, 4.0)
	queue_free()
