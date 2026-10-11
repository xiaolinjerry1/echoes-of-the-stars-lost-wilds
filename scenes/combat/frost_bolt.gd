class_name FrostBolt
extends Area3D
## FrostBolt（寒晶弹投射物）
## 职责：沿相机方向直线飞行（25 m/s，射程 20 米），命中敌人或障碍后冰碎爆裂；
## 伤害走统一 DamageCalculator，命中施加寒意（chilled）。

const SPEED := 25.0
const MAX_RANGE := 20.0
const HIT_RADIUS := 0.5

var skill: SkillData = null
var combat: CombatManager = null

var _direction := Vector3.FORWARD
var _traveled := 0.0


## 生成一枚寒晶弹。
static func spawn(parent: Node, from: Vector3, direction: Vector3, skill_data: SkillData, combat_manager: CombatManager) -> FrostBolt:
	if parent == null or not parent.is_inside_tree():
		return null
	var bolt := FrostBolt.new()
	bolt.skill = skill_data
	bolt.combat = combat_manager
	bolt._direction = direction.normalized()
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
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.85, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.45, 0.75, 1.0)
	material.emission_energy_multiplier = 2.5
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
	# 命中敌人（hit_area 第 4 层）
	var targets := TargetQuery.find_targets(self, HIT_RADIUS, true)
	if not targets.is_empty():
		_hit_target(targets[0])


func _hit_target(target: Node) -> void:
	var target_stats: Variant = null
	if target.has_method("get_stats"):
		target_stats = target.call("get_stats")
	var is_crit := false
	var damage := 0.0
	if combat != null and skill != null:
		is_crit = randf() < combat.crit_chance
		damage = DamageCalculator.calculate_damage(skill, combat.attack_power, target_stats, is_crit, combat.damage_multiplier)
	# 连招检测（弱点暴击等）
	if skill != null:
		var combo_result := ComboSystem.apply_on_hit(skill, target, damage, null)
		damage = float(combo_result["damage"])
	if target.has_method("take_damage"):
		target.call("take_damage", damage)
	if target.has_method("apply_effect") and skill != null:
		target.call("apply_effect", StatusEffects.CHILLED, skill.status_duration, 0.3)
	if target is Node3D:
		DamageNumber.spawn(get_parent(), (target as Node3D).global_position + Vector3.UP * 1.6, damage, is_crit, Color(0.6, 0.85, 1.0))
	HitEffect.spawn_burst(get_parent(), global_position, Color(0.6, 0.85, 1.0), 20, 3.2)
	queue_free()


func _explode() -> void:
	HitEffect.spawn_burst(get_parent(), global_position, Color(0.6, 0.85, 1.0), 12, 2.4)
	queue_free()
