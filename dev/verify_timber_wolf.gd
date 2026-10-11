extends Node
## 验证野狼 PBR、蒙皮、动画姿势及咬击/控制/死亡的实际状态联动，不读写玩家存档。

class DamageTarget extends Node3D:
	var hit_count := 0
	var total_damage := 0.0
	func take_damage(amount: float, _attacker: Node = null) -> void:
		hit_count += 1
		total_damage += amount

var _errors: Array[String] = []
var _checks: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	_checks.append(label)
	if not condition:
		_errors.append(label)
		push_error("WOLF VERIFY: " + label)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _check_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		_check(mesh_instance.skin != null, "网格含蒙皮")
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D
			_check(material != null, "PBR 材质存在")
			if material != null:
				for property in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture"]:
					var texture := material.get(property) as Texture2D
					_check(texture != null and texture.get_width() == 2048 and texture.get_height() == 2048, "2K " + property)
	for child in node.get_children():
		_check_meshes(child)

func _run() -> void:
	var world := Node3D.new()
	add_child(world)
	var target := DamageTarget.new()
	world.add_child(target)
	target.position = Vector3(40, 0, -1.4)
	var packed := load("res://scenes/actors/base_enemy.tscn") as PackedScene
	var wolf := packed.instantiate() as CharacterBody3D
	wolf.set_script(load("res://scenes/actors/melee_chaser.gd"))
	wolf.position = Vector3(40, 0, 0)
	world.add_child(wolf)
	wolf.set_physics_process(false)
	await get_tree().process_frame
	var actor := wolf as MeleeChaser
	actor._target = target
	actor.state = BaseEnemy.State.CHASE
	var skeleton := _find_skeleton(actor.visual)
	_check(skeleton != null and skeleton.get_bone_count() == 24, "24 骨骼导入")
	_check_meshes(actor.visual)
	for clip in [&"idle", &"walk", &"run", &"bite", &"hit", &"death", &"backstep", &"stagger"]:
		_check(actor._clips.has(clip), "动画存在 " + clip)
	if actor._animation_player == null or skeleton == null:
		world.queue_free()
		_finish()
		return
	for clip in MeleeChaser.LOOP_CLIPS:
		_check(actor._animation_player.get_animation(actor._clips[clip]).loop_mode == Animation.LOOP_LINEAR, "循环 " + clip)
	var leg := skeleton.find_bone("Front.L.Upper")
	_check(leg >= 0, "四足骨名保留")
	if leg >= 0:
		actor._play_visual(&"walk", true)
		actor._animation_player.advance(0.1) # Complete the deliberate 0.08s locomotion crossfade.
		actor._animation_player.seek(0.0, true)
		actor._animation_player.advance(0.0)
		var first := skeleton.get_bone_pose_rotation(leg)
		actor._animation_player.seek(0.3, true)
		actor._animation_player.advance(0.0)
		_check(first.angle_to(skeleton.get_bone_pose_rotation(leg)) > 0.05, "行走真实改变腿骨姿势")
	actor.state = BaseEnemy.State.PATROL
	actor.velocity = Vector3(0, 0, -1.6)
	actor._play_visual(&"walk", true)
	for i in 120:
		actor._update_skeletal_animation(1.0 / 60.0)
	_check(actor._visual_clip == &"walk" and absf(actor._playback_rate - 1.6 / (0.88 / 1.2)) < 0.02, "行走步频平滑收敛到移动速度")
	var switches := 0
	var last_clip := actor._visual_clip
	for i in 120:
		actor.velocity.z = -1.95 if i % 2 == 0 else -2.05
		actor._update_skeletal_animation(1.0 / 60.0)
		if actor._visual_clip != last_clip:
			switches += 1
		last_clip = actor._visual_clip
	_check(switches == 0, "速度在旧临界值附近波动两秒不反复切换")
	actor.velocity.z = -3.5
	for i in 120:
		actor._update_skeletal_animation(1.0 / 60.0)
	_check(actor._visual_clip == &"run", "持续加速后切换跑步")
	actor._attack_timer = 1.0
	actor._chase(1.0 / 60.0)
	_check(Vector2(actor.velocity.x, actor.velocity.z).is_zero_approx(), "攻击距离内冷却时停步，不持续顶撞玩家")
	# Sample exported rotations over repeated real-time cycles, including the loop seam.
	actor._play_visual(&"run", true)
	actor._animation_player.advance(0.2)
	var previous: Array[Quaternion] = []
	for b in skeleton.get_bone_count():
		previous.append(skeleton.get_bone_pose_rotation(b))
	var max_angle := 0.0
	for i in 360:
		actor._animation_player.advance(2.1 / 60.0)
		for b in skeleton.get_bone_count():
			var rotation := skeleton.get_bone_pose_rotation(b)
			max_angle = maxf(max_angle, previous[b].angle_to(rotation))
			previous[b] = rotation
	_check(max_angle < deg_to_rad(24.0), "最快步频连续六秒无腿骨大角度跳变：%.1f°" % rad_to_deg(max_angle))
	actor.state = BaseEnemy.State.CHASE
	var head := skeleton.find_bone("Head")
	var hips := skeleton.find_bone("Hips")
	if head >= 0 and hips >= 0:
		var forward := skeleton.get_bone_global_rest(head).origin - skeleton.get_bone_global_rest(hips).origin
		_check((actor.visual.transform.basis * forward).z < 0.0, "资产 +Z 已适配 AI -Z 朝向")
	actor._begin_melee_attack()
	actor._state_time = 0.399
	actor._update_attack()
	_check(target.hit_count == 0, "前摇不提前扣血")
	actor._state_time = 0.4
	actor._update_attack()
	actor._update_skeletal_animation(0.0)
	_check(target.hit_count == 1 and is_equal_approx(target.total_damage, 8.0), "0.4 秒命中一次且伤害仍为 8")
	_check(absf(actor._animation_player.current_animation_position - 0.4) < 0.001, "咬击姿势与 AI 时钟一致")
	actor._state_time = 0.65
	actor._update_attack()
	actor._update_attack()
	_check(target.hit_count == 1, "收招期间不会重复扣血")
	actor._state_time = 0.8
	actor._update_attack()
	_check(actor.state == BaseEnemy.State.CHASE and actor._backstep_time > 0.0, "完整收招后进入后退")
	actor._begin_melee_attack()
	actor._state_time = 0.2
	actor._update_skeletal_animation(0.0)
	var frozen_time := actor._animation_player.current_animation_position
	actor.apply_effect(StatusEffects.FROZEN, 1.0)
	actor.update_ai(0.0)
	actor._update_skeletal_animation(0.2)
	_check(actor.state == BaseEnemy.State.STAGGERED and is_equal_approx(actor._animation_player.current_animation_position, frozen_time), "冻结中断攻击并保持姿势")
	actor.remove_effect(StatusEffects.FROZEN)
	actor._attack_timer = 1.0
	actor.update_ai(0.01)
	_check(target.hit_count == 1 and actor.state != BaseEnemy.State.ATTACK, "解冻没有补发旧咬击伤害")
	actor._begin_melee_attack()
	actor.on_parried(1.0)
	actor.update_ai(0.0)
	actor._update_skeletal_animation(0.1)
	_check(actor._visual_clip == &"stagger", "完美格挡后播放眩晕姿势")
	actor.remove_effect(StatusEffects.STUN)
	actor.state = BaseEnemy.State.CHASE
	actor.take_damage(1.0, target)
	actor._update_skeletal_animation(0.05)
	_check(actor._visual_clip == &"hit", "非攻击时受击动画")
	var death_count := [0]
	actor.enemy_died.connect(func(_enemy: Node) -> void: death_count[0] += 1)
	actor.take_damage(1000.0, target)
	actor._update_skeletal_animation(1.2)
	_check(actor.state == BaseEnemy.State.DEAD and actor._visual_clip == &"death", "骨骼死亡动画")
	_check(is_zero_approx(actor.visual.rotation.z), "死亡不叠加原有整模型旋转 Tween")
	actor.die()
	_check(death_count[0] == 1, "死亡事件只触发一次")
	await get_tree().create_timer(2.1).timeout
	_check(not is_instance_valid(wolf), "死亡展示结束后正常释放")
	world.queue_free()
	await get_tree().process_frame
	_finish()

func _finish() -> void:
	var report := {"passed": _errors.is_empty(), "checks": _checks, "errors": _errors}
	var file := FileAccess.open("res://dev/art_work/timber_wolf/godot_validation.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("WOLF_VERIFY: ", JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)
