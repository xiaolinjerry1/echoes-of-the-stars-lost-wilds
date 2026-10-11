extends Node3D
## 实例化完整玩家验证初始武器、换装及新旧载荷恢复；不读写玩家存档。
var errors: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		errors.append(label)
		push_error(label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var session := GameSession.new()
	add_child(session)
	session.set_process(false)
	var holder := Node3D.new()
	holder.name = "Player"
	session.add_child(holder)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	holder.add_child(player)
	player.set_physics_process(false)
	player.spirit_companion.set_effects_enabled(false)
	await get_tree().process_frame
	var mount := player.fp_arms.weapon_mount
	check(player.equipment.get_equipped("weapon") == DataRegistry.get_item("rusty_sword"), "出生武器槽装备初始剑")
	check(player.combat.attack_power == 20.0, "初始剑属性实际生效：15+5")
	check(mount.get_child_count() == 1 and not mount.get_child(0).is_queued_for_deletion(), "初始化后剑未被删除")
	check(not mount.find_children("*", "MeshInstance3D", true, false).is_empty(), "持剑挂点含实际网格")
	var tip := mount.global_transform * Vector3(0, 0.98, 0)
	var grip := mount.global_transform * Vector3(0, 0.115, 0)
	check((player.camera.global_transform.affine_inverse() * tip).z < (player.camera.global_transform.affine_inverse() * grip).z, "剑尖朝远离相机方向")
	check(player.camera.is_position_in_frustum(tip) and player.camera.is_position_in_frustum(grip), "剑尖和握柄均在视锥内")
	var first := mount.get_child(0)
	player.fp_arms.set_weapon_model("res://art/models/player/iron_sword.glb")
	check(mount.get_child(0) == first, "无关属性刷新不反复重建武器")
	var saved := session.collect_save_snapshot()
	check(saved.equipment_data.has("weapon") and saved.starter_equipment_granted, "快照包含真实出生装备及补发标记")
	player.equipment.unequip_item("weapon")
	check(mount.get_child_count() == 0, "主动卸下立即空手")
	session.apply_saved_payload(saved)
	check(mount.get_child_count() == 1, "重新载入出生快照恢复剑")
	player.equipment.unequip_item("weapon")
	var empty := session.collect_save_snapshot()
	session.apply_saved_payload(empty)
	check(player.equipment.get_equipped("weapon") == null and mount.get_child_count() == 0, "新存档主动空手状态保留")
	session.apply_saved_payload({"equipment_data": {}, "inventory_data": {"items": []}})
	check(player.equipment.get_equipped("weapon") == DataRegistry.get_item("rusty_sword"), "无武器旧存档补发初始剑")
	session.apply_saved_payload({"equipment_data": {}, "inventory_data": {"items": [{"id": "iron_sword", "quantity": 1}]}})
	check(player.equipment.get_equipped("weapon") == null, "旧存档背包已有武器不重复补发")
	player.equipment.equip_item(DataRegistry.get_item("frost_edge"), "weapon", 2)
	var rare := session.collect_save_snapshot()
	session.apply_saved_payload(rare)
	check(player.equipment.get_equipped("weapon") == DataRegistry.get_item("frost_edge") and player.equipment.get_equipped_enhance("weapon") == 2, "保留稀有剑及强化等级")
	check(mount.get_child_count() == 1 and player.fp_arms.is_weapon_glowing(), "换装和读档不重叠生成武器")
	if "--preview-weapon" in OS.get_cmdline_user_args():
		player.equipment.equip_item(DataRegistry.get_item("rusty_sword"), "weapon")
		player.get_node("HUD").hide()
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.15, 0.2, 0.28)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_energy = 0.8
		add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-30, -30, 0)
		light.light_energy = 1.8
		add_child(light)
		player.camera.current = true
		for mesh in mount.find_children("*", "MeshInstance3D", true, false):
			print("WEAPON_BOUNDS: ", mesh.name, " ", mesh.get_aabb(), " camera_transform=", player.camera.global_transform.affine_inverse() * mesh.global_transform)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://art/previews/player/iron_sword_equipped.png")
	print("ACTOR_REGRESSIONS: ", checks, " checks; errors=", errors)
	session.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if errors.is_empty() else 1)
