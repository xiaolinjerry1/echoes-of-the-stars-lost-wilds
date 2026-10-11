extends Node3D
## 完整玩家实例验证手臂蒙皮、武器骨骼跟随、技能动作及暂停；可选真实GPU关键帧截图。
var errors: Array[String] = []
var checks: Array[String] = []
var preview := false
var arms: FPArms

func check(condition: bool, label: String) -> void:
	checks.append(label)
	if not condition:
		errors.append(label)
		push_error("ARMS_VERIFY: " + label)

func _ready() -> void:
	call_deferred("run")

func pose(clip: String, time: float) -> void:
	arms._play(clip, true)
	arms._animation_player.advance(0.1)
	arms._animation_player.seek(time, true)
	arms._animation_player.advance(0.0)
	arms._skeleton.force_update_all_bone_transforms()
	await get_tree().process_frame

func capture(label: String) -> void:
	if not preview:
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png("res://dev/art_work/warrior_arms/godot_" + label + ".png")
	check(result == OK, "运行截图 " + label)

func run() -> void:
	preview = "--preview-arms" in OS.get_cmdline_user_args()
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.combat.set_process(false)
	player.combat.set_physics_process(false)
	player.spirit_companion.set_effects_enabled(false)
	player.get_node("HUD").hide()
	arms = player.fp_arms
	await get_tree().process_frame
	check(arms._skeleton != null and arms._skeleton.get_bone_count() == 38, "38骨骼完整导入")
	check(arms.get_node_or_null("LeftArm") == null and arms.get_node_or_null("RightArm") == null, "移除双胶囊占位")
	check(arms.weapon_mount.get_parent() is BoneAttachment3D, "武器挂在真实右手骨骼插槽")
	check(arms.weapon_mount.get_child_count() == 1, "完整出生流程持剑")
	for side in ["L", "R"]:
		for digit in ["Thumb", "Index", "Middle", "Ring", "Little"]:
			check(arms._skeleton.find_bone(digit + ".3." + side) >= 0, "三节指骨 " + digit + "." + side)
	for node in arms.get_node("WarriorArms").find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.is_ancestor_of(arms.weapon_mount) or arms.weapon_mount.is_ancestor_of(mesh):
			continue
		check(mesh.skin != null, "手臂网格有有效蒙皮")
		for material in arms._arm_materials:
			for property in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture"]:
				var texture := material.get(property) as Texture2D
				check(texture != null and texture.get_width() == 2048, "2K " + property)
	arms._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if preview:
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color(0.13, 0.17, 0.23)
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color(0.75, 0.85, 1.0)
		world.environment.ambient_light_energy = 0.65
		add_child(world)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, -25, 0)
		light.light_color = Color(1.0, 0.84, 0.67)
		light.light_energy = 1.8
		add_child(light)
		player.camera.current = true
	await pose("idle", 0.0)
	var idle_mount := arms.weapon_mount.global_transform
	var grip_relative := arms._skeleton.global_transform.affine_inverse() * arms.weapon_mount.global_transform
	var socket_index := arms._skeleton.find_bone("Weapon.R")
	var socket_offset := arms._skeleton.get_bone_global_pose(socket_index).affine_inverse() * grip_relative
	await capture("idle")
	for clip in ["idle", "attack_1", "attack_2", "attack_3", "block", "hit", "charge", "sweep", "roar", "frost_ring", "frost_crystal_bolt", "fireball", "ember_burst"]:
		check(arms._clips.has(clip), "动作导入 " + clip)
		if not arms._clips.has(clip):
			continue
		var duration := arms._animation_player.get_animation(arms._clips[clip]).length
		var max_error := 0.0
		for i in 13:
			await pose(clip, duration * i / 12.0)
			var expected := arms._skeleton.global_transform * arms._skeleton.get_bone_global_pose(socket_index) * socket_offset
			max_error = maxf(max_error, expected.origin.distance_to(arms.weapon_mount.global_position))
		check(max_error < 0.001, "全程武器跟手不脱离 " + clip)
		await pose(clip, 0.1 if clip.begins_with("attack") or clip == "charge" else 0.3 if clip == "sweep" else duration * 0.4)
		await capture(clip)
		if clip.begins_with("attack"):
			check(arms.weapon_mount.global_position.distance_to(idle_mount.origin) > 0.03, "真实手臂运动 " + clip)
			check(arms.transform.is_equal_approx(Transform3D.IDENTITY), "攻击不靠整节点Tween " + clip)
	var finger := arms._skeleton.find_bone("Index.2.L")
	await pose("idle", 0)
	var rest_finger := arms._skeleton.get_bone_pose_rotation(finger)
	await pose("fireball", 0.3)
	check(rest_finger.angle_to(arms._skeleton.get_bone_pose_rotation(finger)) > 0.2, "施法时左手手指真实张开")
	for id in ["warrior_charge", "warrior_sweep", "warrior_roar", "frost_ring", "frost_crystal_bolt", "fireball", "ember_burst"]:
		arms.play_skill_animation(id)
		check(arms._current_clip == id.trim_prefix("warrior_"), "技能接口 " + id)
	arms.play_block_animation()
	arms.play_hit_reaction()
	arms._animation_player.advance(0.5)
	check(arms._current_clip == "block", "格挡受击后恢复格挡")
	arms.play_idle_animation()
	arms.play_attack_animation(2)
	arms.play_hit_reaction()
	check(arms._current_clip == "attack_2", "受击不打断攻击命中姿势")
	arms._animation_player.advance(0.8)
	check(arms._current_clip == "idle", "攻击收招回到待机")
	arms.set_glove_tint(Color(0.45, 0.62, 0.6))
	check(arms._arm_materials[0].albedo_texture != null, "装备染色保留贴图")
	arms.set_echo_rune(Color.CYAN, true)
	check(arms._arm_materials[0].emission_enabled, "回响发光接口有效")
	arms.set_echo_rune(Color.WHITE, false)
	arms.play_attack_animation(1)
	arms._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	await get_tree().physics_frame
	get_tree().paused = true
	var frozen_time := arms._animation_player.current_animation_position
	await get_tree().create_timer(0.15, true).timeout
	check(is_equal_approx(frozen_time, arms._animation_player.current_animation_position), "暂停菜单冻结骨骼动作")
	get_tree().paused = false
	var report := {"passed": errors.is_empty(), "checks": checks, "errors": errors}
	var file := FileAccess.open("res://dev/art_work/warrior_arms/godot_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("ARMS_VERIFY: ", checks.size(), " checks; errors=", errors)
	player.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if errors.is_empty() else 1)
