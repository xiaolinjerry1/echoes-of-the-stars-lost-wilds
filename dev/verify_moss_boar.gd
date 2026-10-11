extends Node3D
## 野猪资源、攻击时序、控制中断与死亡专项；可选GPU截图，不访问用户存档。
class Target extends Node3D:
	var hits := 0
	var damage := 0.0
	func take_damage(amount: float, _attacker: Node = null) -> void:
		hits += 1
		damage += amount
var checks: Array[String] = []
var errors: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks.append(label)
	if not ok:
		errors.append(label)
		push_error(label)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var boar := (load("res://scenes/actors/base_enemy.tscn") as PackedScene).instantiate() as CharacterBody3D
	boar.set_script(load("res://scenes/actors/charger.gd"))
	boar.position = Vector3(40, 0, 0)
	add_child(boar)
	boar.set_physics_process(false)
	var actor := boar as Charger
	var target := Target.new()
	add_child(target)
	target.position = Vector3(40, 0, -1.5)
	actor._target = target
	await get_tree().process_frame
	var skeleton := actor.visual.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	check(skeleton.get_bone_count() == 24, "24骨骼")
	check(actor.max_health == 80 and actor.attack_power == 15, "普通野猪属性保留")
	for node in actor.visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		check(mesh.skin != null, "蒙皮存在")
		var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		for prop in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture"]:
			var texture := material.get(prop) as Texture2D
			check(texture != null and texture.get_width() == 2048, "2K " + prop)
	for clip in ["idle", "walk", "run", "heavy", "charge_windup", "charge", "recover", "hit", "stagger", "death"]:
		check(actor._clips.has(clip), "动作 " + clip)
	check(actor._clips.size() == 10, "不混入其他资产动作")
	for clip in ["walk", "run"]:
		actor._play_visual(clip, true)
		actor._animation_player.advance(0.2)
		var previous: Array[Quaternion] = []
		for b in skeleton.get_bone_count():
			previous.append(skeleton.get_bone_pose_rotation(b))
		var maximum := 0.0
		for i in 240:
			actor._animation_player.advance(2.0 / 60.0)
			for b in skeleton.get_bone_count():
				var pose := skeleton.get_bone_pose_rotation(b)
				maximum = maxf(maximum, previous[b].angle_to(pose))
				previous[b] = pose
		check(maximum < deg_to_rad(30), "%s连续4秒骨骼无突变：%.1f°" % [clip,rad_to_deg(maximum)])
	var elite := (load("res://scenes/actors/base_enemy.tscn") as PackedScene).instantiate()
	elite.set_script(load("res://scenes/actors/charger.gd"))
	elite.set("elite", true)
	add_child(elite)
	elite.set_physics_process(false)
	check(elite.max_health == 250 and elite.attack_power == 18, "精英复用资产且保留250血/18攻击")
	elite.queue_free()
	actor._begin_heavy_attack()
	actor._state_time = 0.59
	actor._update_heavy_attack()
	check(target.hits == 0, "重击前摇不提前伤害")
	actor._state_time = 0.6
	actor._update_heavy_attack()
	actor._update_animation(0)
	check(target.hits == 1 and is_equal_approx(target.damage, 18), "0.6秒重击18伤害一次")
	check(is_equal_approx(actor._animation_player.current_animation_position, 0.6), "重击骨骼命中时序一致")
	actor._state_time = 0.8
	actor._update_heavy_attack()
	check(target.hits == 1 and actor.state == BaseEnemy.State.ATTACK, "重击收招不重复结算")
	actor._state_time = 1.0
	actor._update_heavy_attack()
	check(actor.state == BaseEnemy.State.CHASE, "重击完成才回追击")
	target.position.z = -8
	actor._begin_charge(target)
	actor._state_time = 0.9
	actor._update_charge_windup()
	actor._update_animation(0)
	check(actor._charge_phase == 1 and actor._visual_clip == "charge_windup" and actor.visual.scale.is_equal_approx(Vector3.ONE), "蓄力用骨骼、不压扁整体")
	actor._state_time = 1.0
	actor._update_charge_windup()
	actor._update_animation(0.05)
	check(actor._charge_phase == 2 and actor._visual_clip == "charge", "1秒后进入冲锋动作")
	target.position.z = -1.0
	actor._update_charge_dash(0.01)
	check(target.hits == 2 and is_equal_approx(target.damage, 40.5), "冲锋22.5伤害且只命中一次")
	check(actor._recovery_time > 0 and actor.velocity.is_zero_approx(), "命中后停止位移并收势")
	actor._update_state(0.2)
	check(target.hits == 2 and actor._recovery_time > 0, "收势不重复冲击")
	actor._begin_charge(target)
	actor._state_time = 0.3
	actor._update_animation(0)
	var frozen := actor._animation_player.current_animation_position
	actor.apply_effect(StatusEffects.FROZEN, 1.0)
	actor.update_ai(0)
	actor._update_animation(0.2)
	check(actor._charge_phase == 0 and is_equal_approx(frozen, actor._animation_player.current_animation_position), "冻结中断蓄力并保持姿势")
	actor.remove_effect(StatusEffects.FROZEN)
	actor.apply_effect(StatusEffects.STUN, 3.0)
	actor.update_ai(0)
	actor._update_animation(0.1)
	check(actor._visual_clip == "stagger", "眩晕播放骨骼动作")
	actor.remove_effect(StatusEffects.STUN)
	actor.state = BaseEnemy.State.CHASE
	actor._recovery_time = 0
	actor.take_damage(1, target)
	actor._update_animation(0.1)
	check(actor._visual_clip == "hit", "受击动作")
	if "--preview-boar" in OS.get_cmdline_user_args():
		actor.rotation = Vector3.ZERO
		await get_tree().create_timer(1.2).timeout # Let prior test telegraphs expire before the asset review.
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(.12,.16,.22)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.72,0.8,1.0)
		env.environment.ambient_light_energy = 0.8
		add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40,-35,0)
		light.light_energy = 1.6
		add_child(light)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-25,130,0)
		fill.light_color = Color(0.65,0.8,1.0)
		fill.light_energy = 0.8
		add_child(fill)
		var camera := Camera3D.new()
		add_child(camera)
		camera.position = Vector3(42.8,1.9,-3.7)
		camera.look_at(Vector3(40,.6,0))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.5
		camera.current = true
		for entry in [["idle",0.0],["walk",.3],["run",.2],["heavy",.6],["charge_windup",.95],["charge",.2],["stagger",.3],["death",1.2]]:
			actor._play_visual(entry[0], true)
			actor._animation_player.advance(.15)
			actor._animation_player.seek(entry[1], true)
			actor._animation_player.advance(0)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://dev/art_work/moss_boar/godot_"+str(entry[0])+".png")
	actor.take_damage(1000, target)
	actor._update_animation(1.2)
	check(actor.state == BaseEnemy.State.DEAD and actor._visual_clip == "death" and is_zero_approx(actor.visual.rotation.z), "死亡骨骼不叠加整模型倒地")
	await get_tree().create_timer(2.1).timeout
	check(not is_instance_valid(boar), "死亡正常释放")
	var file := FileAccess.open("res://dev/art_work/moss_boar/godot_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"errors":errors,"passed":errors.is_empty()},"\t"))
	print("BOAR_VERIFY: ",checks.size()," checks; errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)
