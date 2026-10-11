class_name WyvernFireball
extends Node3D
## 飞龙火球：Blender发光资产、锁定直线轨迹、扫掠碰撞、爆炸单次伤害与灼烧。
const SPEED := 22.0
const MAX_RANGE := 90.0
const SPLASH_RADIUS := 2.2
var source_enemy: Node
var damage := 28.0
var direction := Vector3.FORWARD
var _traveled := 0.0
var _exploded := false

static func spawn(parent: Node, origin: Vector3, target: Vector3, source: Node, amount: float) -> WyvernFireball:
	var ball := WyvernFireball.new()
	ball.source_enemy = source
	ball.damage = amount
	ball.direction = (target-origin).normalized()
	parent.add_child(ball)
	ball.global_position = origin
	return ball

func _ready() -> void:
	add_to_group("wyvern_fireball")
	var packed := load("res://art/models/prop/wyvern_fireball.glb") as PackedScene
	if packed != null: add_child(packed.instantiate())

func _physics_process(delta: float) -> void:
	if _exploded: return
	var step := SPEED * delta
	var destination := global_position + direction * step
	var query := PhysicsRayQueryParameters3D.create(global_position, destination, 1 | 2)
	if is_instance_valid(source_enemy) and source_enemy is CollisionObject3D: query.exclude = [source_enemy.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		_explode()
		return
	global_position = destination
	_traveled += step
	if _traveled >= MAX_RANGE: queue_free()

func _explode() -> void:
	if _exploded: return
	_exploded = true
	var target := get_tree().get_first_node_in_group("player") as Node3D
	if target != null and target.has_method("take_damage") and target.get("_is_dead") != true:
		# 不穿过遮挡伤害玩家；营地安全区同样阻止残留火球。
		if target.global_position.distance_to(WorldLayout.CAMP) >= WorldLayout.CAMP_RADIUS and global_position.distance_to(target.global_position+Vector3.UP) <= SPLASH_RADIUS:
			var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP*.06, target.global_position+Vector3.UP, 1)
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				target.take_damage(damage, source_enemy if is_instance_valid(source_enemy) else null)
				target.apply_effect(StatusEffects.BURNING, 3, 4)
				if is_instance_valid(source_enemy): source_enemy.notify_damage_dealt(damage, target)
	HitEffect.spawn_burst(get_parent(), global_position, Color(1,.25,.025), 24, 3)
	RingEffect.spawn(get_parent(), global_position, Color(1,.25,.025), SPLASH_RADIUS)
	queue_free()
