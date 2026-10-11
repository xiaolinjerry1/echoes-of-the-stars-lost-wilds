class_name HitEffect
extends Node3D
## HitEffect（命中/爆裂特效）
## 职责：在命中点用一次性 GPUParticles3D 播放颜色爆裂（普通命中 / 碎冰 / 战吼共用），
## 播完自动释放。正式特效资产后续由 Blender / 粒子资产替换，这里保证反馈可读。

const LIFETIME := 0.6


## 在 parent 下生成一次爆裂。
static func spawn_burst(parent: Node, world_position: Vector3, color: Color, amount := 12, speed := 2.5) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var effect := HitEffect.new()
	parent.add_child(effect)
	effect.global_position = world_position
	effect._build(color, amount, speed)


func _build(color: Color, amount: int, speed: float) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = LIFETIME
	particles.one_shot = true
	particles.explosiveness = 1.0

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.12
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 180.0
	process.initial_velocity_min = speed * 0.6
	process.initial_velocity_max = speed
	process.gravity = Vector3(0.0, -4.0, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.2
	particles.process_material = process

	# 正式粒子复用 Blender 烘焙碎石/火花，Godot 只驱动发射与运动。
	var prefab := (load("res://art/models/prop/boss_debris.glb") as PackedScene).instantiate()
	var instance := prefab.find_child("*",true,false) as MeshInstance3D
	if instance==null:
		for node in prefab.find_children("*","MeshInstance3D",true,false):
			instance=node;break
	var mesh: Mesh = instance.mesh
	prefab.free()
	process.scale_min=0.2
	process.scale_max=0.7
	process.color=color
	particles.draw_pass_1 = mesh

	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(LIFETIME + 0.3).timeout.connect(queue_free)
