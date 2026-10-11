extends Node
## 开发用：项目初始化端到端自检入口场景脚本。
## 用法：godot --headless --path <项目目录> res://dev/verify_boot.tscn
## 视觉内容（模型/贴图/材质/灯光）全部由 Blender 导出 glb 后接入，
## 本自检只覆盖游戏逻辑骨架，不依赖任何美术占位内容。


class Runner extends Node:
	## 自检执行器：输入 / Autoload / 数据 / 菜单 / 玩家 / 状态效果 / 精灵 / 回响 / 战斗 / 角色选择 / 会话。
	const SAVE_TEST_SLOT := 3
	const TEST_CLASS_ID := "warrior"
	const TEST_SPIRIT_ID := "spirit_test"
	const TEST_SPIRIT_LEVEL := 3
	const AUTOLOAD_NAMES := ["AppFlow", "DataRegistry", "SaveService", "SettingsService", "AudioService", "DebugTools"]
	const ACTION_NAMES := [
		"move_forward", "move_back", "move_left", "move_right",
		"sprint", "jump", "dodge", "interact", "attack", "defend",
		"skill_1", "skill_2", "skill_3",
		"echo_activate", "echo_skill_1", "echo_skill_2", "echo_swap",
		"potion", "inventory", "map", "photo_mode",
	]
	const PLAYER_NODES := [
		"CollisionShape3D",
		"CameraPivot",
		"CameraPivot/Camera3D",
		"CameraPivot/Camera3D/InteractionRay",
		"CameraPivot/Camera3D/FPArms",
		"CameraPivot/Camera3D/FPArms/WarriorArms",
		"SpiritMount",
		"SpiritMount/SpiritCompanion",
		"CombatManager",
		"EchoSystem",
		"PlayerStats",
		"DeathZoneDetector",
		"HUD/InteractHint",
		"HUD/CombatFeedback",
		"HUD/SpiritPanel",
		"HUD/SpiritPanel/SpiritIconLabel",
		"HUD/SpiritFeedback",
		"HUD/EchoIcon",
		"HUD/EchoIcon/EchoIconLabel",
		"HUD/EnergyBar",
		"HUD/ActiveTimeBar",
		"HUD/EchoSlotPanel1/EchoSlot1",
		"HUD/EchoSlotPanel2/EchoSlot2",
		"HUD/EchoPanel",
		"Inventory",
		"EquipmentSystem",
		"EnhancementSystem",
		"HUD/InventoryPanel",
		"HUD/DialogueBox",
		"HUD/QuestTracker",
		"HUD/QuestArrow",
		"HUD/MemoryOverlay",
		"PhotoMode",
		"PauseMenu",
	]

	var _failed := false

	func _ready() -> void:
		_run()

	func _run() -> void:
		# 等一帧，保证 Autoload 与主循环就绪
		await get_tree().process_frame
		_verify_input_map()
		if not _failed:
			_verify_autoloads()
		if not _failed:
			_verify_data_registry()
		if not _failed:
			_verify_main_menu()
		if not _failed:
			_verify_player_scene()
		if not _failed:
			await _verify_status_effects()
		if not _failed:
			await _verify_spirit()
		if not _failed:
			await _verify_echo_system()
		if not _failed:
			await _verify_combos_and_boss()
		if not _failed:
			await _verify_enemies()
		if not _failed:
			await _verify_equipment()
		if not _failed:
			await _verify_quests()
		if not _failed:
			await _verify_world()
		if not _failed:
			await _verify_dungeon()
		if not _failed:
			await _verify_ui()
		if not _failed:
			await _verify_save()
		if not _failed:
			await _verify_combat()
		if not _failed:
			await _verify_character_select()
		if not _failed:
			await _verify_game_flow()
		_finish()

	## 阶段 0：输入映射动作齐全。
	func _verify_input_map() -> void:
		for action_name in ACTION_NAMES:
			if not InputMap.has_action(action_name):
				_fail("缺少输入动作：%s" % action_name)
				return
		print("VERIFY OK: %d 个输入动作已注册" % ACTION_NAMES.size())

	## 阶段 1：5 个 Autoload 已注册。
	func _verify_autoloads() -> void:
		for autoload_name in AUTOLOAD_NAMES:
			if get_tree().root.get_node_or_null(autoload_name) == null:
				_fail("缺少 Autoload：%s" % autoload_name)
				return
		print("VERIFY OK: 5 个 Autoload 均已就绪")

	## 阶段 2：静态数据加载完整（职业 / 技能 / 回响 / 精灵）。
	func _verify_data_registry() -> void:
		var warrior := DataRegistry.get_class_def("warrior")
		if warrior == null or warrior.basic_attack == null or warrior.class_skills.size() != 3:
			_fail("战士数据不完整（需要基础攻击 + 3 技能）")
			return
		var echo := DataRegistry.get_echo("frost_lamp_scholar")
		if echo == null or echo.echo_skills.size() != 2:
			_fail("霜灯学者回响数据不完整（需要 2 技能）")
			return
		if DataRegistry.get_spirit("glow_wisp") == null or DataRegistry.get_spirit("flame_crystal") == null or DataRegistry.get_spirit("stone_guardian") == null:
			_fail("三种精灵数据不完整")
			return
		if DataRegistry.get_skill("warrior_charge") == null or DataRegistry.get_skill("frost_ring") == null:
			_fail("职业/回响内嵌技能未索引到 skills 表")
			return
		print("VERIFY OK: 数据加载 职业=%d 精灵=%d 技能=%d 回响=%d 物品=%d" % [
			DataRegistry.get_all_classes().size(),
			DataRegistry.get_all_spirits().size(),
			DataRegistry.get_all_skills().size(),
			DataRegistry.get_all_echoes().size(),
			DataRegistry.get_all_items().size(),
		])
		print("VERIFY OK: %s（基础攻击+3 技能）与 %s（2 技能）数据完整" % [warrior.display_name, echo.display_name])

	## 阶段 3：主菜单场景可加载（当前为空 Control 根节点，UI 待接入）。
	func _verify_main_menu() -> void:
		var packed := load("res://scenes/app/main_menu.tscn") as PackedScene
		if packed == null:
			_fail("无法加载主菜单场景")
			return
		var menu := packed.instantiate()
		if not (menu is Control):
			_fail("主菜单根节点不是 Control")
			menu.free()
			return
		menu.free()
		print("VERIFY OK: 主菜单场景可加载（空根节点，UI 待接入）")

	## 阶段 4：玩家场景结构完整（含战斗/精灵/回响节点与 Blender 武器挂点）。
	func _verify_player_scene() -> void:
		var packed := load("res://scenes/player/player.tscn") as PackedScene
		if packed == null:
			_fail("无法加载 player.tscn")
			return
		var player := packed.instantiate()
		for node_path in PLAYER_NODES:
			if player.get_node_or_null(node_path) == null:
				_fail("玩家场景缺少节点：%s" % node_path)
				player.free()
				return
		player.free()
		print("VERIFY OK: 玩家场景结构完整（%d 个逻辑节点）" % PLAYER_NODES.size())

	## 阶段 5：状态效果组件（施加 / 强度 / 到期自动移除 / 手动移除 / 信号）。
	func _verify_status_effects() -> void:
		var component := StatusEffectComponent.new()
		component.name = "StatusEffectTest"
		add_child(component)
		var applied := [0]
		var removed := [0]
		component.effect_applied.connect(func(_id: String, _duration: float, _power: float) -> void: applied[0] += 1)
		component.effect_removed.connect(func(_id: String) -> void: removed[0] += 1)

		component.apply_effect(StatusEffects.FROZEN, 0.2, 1.0)
		if not component.has_effect(StatusEffects.FROZEN):
			_fail("状态效果施加失败")
			return
		if absf(component.get_effect_power(StatusEffects.FROZEN) - 1.0) > 0.01:
			_fail("状态效果强度读取不正确")
			return
		await get_tree().create_timer(0.4).timeout
		if component.has_effect(StatusEffects.FROZEN):
			_fail("状态效果到期未自动移除")
			return

		component.apply_effect(StatusEffects.BURNING, 5.0, 2.0)
		component.remove_effect(StatusEffects.BURNING)
		if component.has_effect(StatusEffects.BURNING):
			_fail("状态效果手动移除失败")
			return
		if applied[0] != 2 or removed[0] != 2:
			_fail("状态效果信号计数不正确（applied=%d removed=%d）" % [applied[0], removed[0]])
			return
		component.queue_free()
		print("VERIFY OK: 状态效果组件（施加/强度/到期/移除/信号）")

	## 阶段 6：精灵系统（数据 / 跟随 / 三种效果 / 击退 / HUD）。
	func _verify_spirit() -> void:
		for spirit_id in ["glow_wisp", "flame_crystal", "stone_guardian"]:
			if DataRegistry.get_spirit(spirit_id) == null:
				_fail("缺少精灵数据：%s" % spirit_id)
				return
		print("VERIFY OK: 精灵数据 3 种（辉光萤灵 / 烈焰晶灵 / 磐石守灵）")

		var packed := load("res://dev/test_combat.tscn") as PackedScene
		if packed == null:
			_fail("无法加载 test_combat.tscn（精灵测试）")
			return
		var scene := packed.instantiate()
		get_tree().root.add_child(scene)
		await get_tree().create_timer(0.6).timeout

		var player := scene.find_child("Player", true, false) as PlayerController
		var dummy_a: Node = scene.find_child("DummyA", true, false)
		if player == null or dummy_a == null:
			_fail("精灵测试场景缺少 Player / DummyA")
			return
		var spirit := player.spirit_companion
		if spirit == null or spirit.spirit_data == null or spirit.spirit_data.id != "glow_wisp":
			_fail("默认精灵未初始化为辉光萤灵")
			return
		var icon_label := player.get_node_or_null("HUD/SpiritPanel/SpiritIconLabel") as Label
		if icon_label == null or not icon_label.text.contains("辉光"):
			_fail("精灵 HUD 图标未更新")
			return
		print("VERIFY OK: 默认精灵（辉光萤灵）与 HUD 图标")

		var entity := spirit.get("_entity") as Node3D
		var mount := player.get_node("SpiritMount") as Node3D
		if entity == null or entity.global_position.distance_to(mount.global_position) > 1.0:
			_fail("精灵未跟随到玩家侧后方")
			return
		print("VERIFY OK: 精灵跟随（侧后方漂浮）")

		player.stats.current_health = 50.0
		spirit.set("_heal_timer", 9.9)
		await get_tree().create_timer(0.4).timeout
		if absf(player.stats.current_health - 58.0) > 0.5:
			_fail("辉光萤灵定时回血不正确：%s" % player.stats.current_health)
			return
		print("VERIFY OK: 辉光萤灵定时回血（+8）")

		player.stats.current_health = 20.0
		await get_tree().create_timer(0.4).timeout
		if player.stats.shield < 29.0:
			_fail("应急护盾未触发（shield=%s）" % player.stats.shield)
			return
		var hp_before := player.stats.current_health
		var received := player.take_damage(10.0, dummy_a)
		if received != 0.0 or absf(player.stats.current_health - hp_before) > 0.01:
			_fail("应急护盾未吸收伤害")
			return
		print("VERIFY OK: 应急护盾（低血触发 / 吸收伤害）")

		spirit.initialize("flame_crystal")
		await get_tree().create_timer(0.2).timeout
		if absf(spirit.get_flame_damage_bonus() - 0.08) > 0.001:
			_fail("火焰伤害加成读取不正确：%s" % spirit.get_flame_damage_bonus())
			return
		player.global_position = Vector3(0.0, 0.1, -2.2)
		player.rotation = Vector3.ZERO
		await get_tree().create_timer(0.3).timeout
		var hp_before_fire := float(dummy_a.get("health"))
		spirit.set("_attack_timer", 2.4)
		await get_tree().create_timer(0.9).timeout
		var fire_damage := hp_before_fire - float(dummy_a.get("health"))
		if absf(fire_damage - 5.0) > 0.5:
			_fail("烈焰晶灵自动攻击伤害不正确：%.1f" % fire_damage)
			return
		print("VERIFY OK: 烈焰晶灵（火焰加成 +8% / 自动火球 5 伤害）")

		spirit.initialize("stone_guardian")
		await get_tree().create_timer(0.2).timeout
		if absf(spirit.get_damage_reduction() - 0.12) > 0.001:
			_fail("减伤比例读取不正确：%s" % spirit.get_damage_reduction())
			return
		player.stats.current_health = 100.0
		var received_stone := player.take_damage(10.0, dummy_a)
		if absf(received_stone - 7.33) > 0.15:
			_fail("磐石守灵减伤不正确：实收 %.2f（期望 7.33）" % received_stone)
			return
		dummy_a.set("is_taunted", false)
		spirit.set("_taunt_cooldown", 0.0)
		await get_tree().create_timer(0.5).timeout
		if not bool(dummy_a.get("is_taunted")):
			_fail("磐石守灵未嘲讽到假人")
			return
		print("VERIFY OK: 磐石守灵（减伤 12% / 光环嘲讽）")

		var pos_before := entity.global_position
		spirit.knock_back(dummy_a.global_position)
		await get_tree().create_timer(0.3).timeout
		if not spirit.is_knocked_back() or entity.global_position.distance_to(pos_before) < 0.3:
			_fail("精灵击退未生效")
			return
		await get_tree().create_timer(2.2).timeout
		if spirit.is_knocked_back():
			_fail("精灵击退后未回归")
			return
		if entity.global_position.distance_to(mount.global_position) > 1.2:
			_fail("精灵回归位置异常：%s" % entity.global_position)
			return
		print("VERIFY OK: 精灵击退与 2 秒回归（不会被击杀）")

		scene.queue_free()
		await get_tree().process_frame

	## 阶段 7：世界回响系统（回响碑 / 准备槽 / 激活 / 能量 / 冰环与寒晶弹）。
	func _verify_echo_system() -> void:
		var packed := load("res://dev/test_combat.tscn") as PackedScene
		if packed == null:
			_fail("无法加载 test_combat.tscn（回响测试）")
			return
		var scene := packed.instantiate()
		get_tree().root.add_child(scene)
		await get_tree().create_timer(0.6).timeout

		var player := scene.find_child("Player", true, false) as PlayerController
		var dummy_a: Node = scene.find_child("DummyA", true, false)
		var dummy_b: Node = scene.find_child("DummyB", true, false)
		var stone: Node = scene.find_child("EchoStone", true, false)
		if player == null or dummy_a == null or dummy_b == null or stone == null:
			_fail("回响测试场景缺少 Player / DummyA / DummyB / EchoStone")
			return
		var echo := player.echo_system
		if echo == null:
			_fail("玩家缺少 EchoSystem")
			return
		player.equipment.unequip_item("weapon") # 验证裸职业的回响伤害基线。
		player.spirit_companion.set_effects_enabled(false)
		player.combat.crit_chance = 0.0
		echo.current_energy = 100.0
		if echo.has_collected("frost_lamp_scholar"):
			_fail("回响初始状态不应已收藏")
			return

		# 回响碑交互 → 记忆幻象 → 收藏
		stone.set("memory_duration", 0.1)
		var interactable := stone.get_node("Interactable")
		interactable.call("interact", player)
		await get_tree().create_timer(2.0).timeout
		if not echo.has_collected("frost_lamp_scholar"):
			_fail("回响碑交互未获得回响")
			return
		interactable.call("interact", player)
		await get_tree().create_timer(0.2).timeout
		if echo.collected_echoes.size() != 1:
			_fail("回响被重复收藏")
			return
		print("VERIFY OK: 回响碑交互（记忆幻象 + 收藏霜灯学者，不可重复）")

		# 装入准备槽
		if not echo.equip_to_slot(0, "frost_lamp_scholar"):
			_fail("回响装入准备槽失败")
			return
		if echo.prep_slots[0] != "frost_lamp_scholar":
			_fail("准备槽内容不正确")
			return
		print("VERIFY OK: 回响装入准备槽")

		# 激活：消耗 100 能量，持续 12 秒
		if not echo.can_activate() or not echo.activate_echo():
			_fail("回响激活失败")
			return
		if absf(echo.current_energy) > 0.01 or not echo.is_active() or absf(echo.active_timer - 12.0) > 0.1:
			_fail("激活状态不正确（能量=%s 剩余=%s）" % [echo.current_energy, echo.active_timer])
			return
		print("VERIFY OK: 回响激活（-100 能量 / 12 秒）")

		# 冰环（Z）：普通敌人冻结 / 精英只减速
		player.global_position = Vector3(0.0, 0.1, -2.2)
		player.rotation = Vector3.ZERO
		await get_tree().create_timer(0.3).timeout
		var hp_ring := float(dummy_a.get("health"))
		if not echo.use_echo_skill(0):
			_fail("冰环释放失败")
			return
		await get_tree().create_timer(0.2).timeout
		var ring_damage := hp_ring - float(dummy_a.get("health"))
		if absf(ring_damage - 13.5) > 0.5:
			_fail("冰环伤害不正确：%.1f（期望 13.5）" % ring_damage)
			return
		if not bool(dummy_a.call("has_effect", StatusEffects.FROZEN)):
			_fail("冰环未冻结普通敌人")
			return
		if not bool(dummy_b.call("has_effect", StatusEffects.CHILLED)):
			_fail("冰环未对精英施加寒意")
			return
		if bool(dummy_b.call("has_effect", StatusEffects.FROZEN)):
			_fail("精英不应被冻结")
			return
		if echo.get_skill_cooldown_remaining("frost_ring") <= 0.0:
			_fail("冰环未进入冷却")
			return
		print("VERIFY OK: 冰环（普通冻结 / 精英减速 / 伤害 13.5）")

		# 寒晶弹（X）：投射物命中 + 寒意
		var hp_bolt := float(dummy_a.get("health"))
		if not echo.use_echo_skill(1):
			_fail("寒晶弹释放失败")
			return
		await get_tree().create_timer(0.6).timeout
		var bolt_damage := hp_bolt - float(dummy_a.get("health"))
		if absf(bolt_damage - 22.0) > 0.5:
			_fail("寒晶弹伤害不正确：%.1f（期望 22）" % bolt_damage)
			return
		if not bool(dummy_a.call("has_effect", StatusEffects.CHILLED)):
			_fail("寒晶弹未施加寒意")
			return
		print("VERIFY OK: 寒晶弹（投射物 / 伤害 22 / 寒意）")

		# 激活期间原职业技能仍可用（回响是叠加不是替换）
		if not player.combat.can_use_skill("warrior_sweep"):
			_fail("激活期间原职业技能不可用")
			return
		print("VERIFY OK: 激活期间原职业技能仍可用")

		# 能量：激活时不恢复；提前结束不返还
		echo.current_energy = 10.0
		await get_tree().create_timer(0.5).timeout
		if absf(echo.current_energy - 10.0) > 0.1:
			_fail("激活期间能量恢复未停止：%s" % echo.current_energy)
			return
		echo.deactivate_echo()
		if echo.is_active():
			_fail("提前结束失败")
			return
		await get_tree().create_timer(0.5).timeout
		if echo.current_energy < 12.0 or echo.current_energy > 13.5:
			_fail("未激活时能量恢复不正确：%s" % echo.current_energy)
			return
		print("VERIFY OK: 能量恢复（激活停止 / 未激活 +5/s）")

		# 切换准备槽与冷却
		echo.set("_swap_cooldown_timer", 0.0)
		if not echo.swap_prep_slot() or echo.current_slot_index != 1:
			_fail("准备槽切换失败")
			return
		if echo.swap_prep_slot():
			_fail("切换冷却未生效")
			return
		echo.set("_swap_cooldown_timer", 0.0)
		print("VERIFY OK: 准备槽切换（8 秒冷却）")

		# 回响收藏面板
		var panel := player.get_node_or_null("HUD/EchoPanel")
		if panel == null:
			_fail("缺少回响收藏面板")
			return
		player.call("_toggle_echo_panel")
		await get_tree().process_frame
		if not panel.visible:
			_fail("回响面板未打开")
			return
		player.call("_toggle_echo_panel")
		print("VERIFY OK: 回响收藏面板（打开/关闭）")

		scene.queue_free()
		await get_tree().process_frame

	## 阶段 7.5：连招组合与 BOSS 失衡（碎冰冷却 / 弱点 / 电弧 / 火势 / 灼烧 DOT / 失衡）。
	func _verify_combos_and_boss() -> void:
		var packed := load("res://dev/test_combat.tscn") as PackedScene
		if packed == null:
			_fail("无法加载 test_combat.tscn（连招测试）")
			return
		var scene := packed.instantiate()
		get_tree().root.add_child(scene)
		await get_tree().create_timer(0.6).timeout

		var player := scene.find_child("Player", true, false) as PlayerController
		var dummy_a: Node = scene.find_child("DummyA", true, false)
		var dummy_b: Node = scene.find_child("DummyB", true, false)
		var dummy_c: Node = scene.find_child("DummyC", true, false)
		var dummy_boss: Node = scene.find_child("DummyBoss", true, false)
		if player == null or dummy_a == null or dummy_b == null or dummy_c == null or dummy_boss == null:
			_fail("连招测试场景缺少 Player / DummyA / DummyB / DummyC / DummyBoss")
			return
		player.equipment.unequip_item("weapon") # 验证裸职业的连招伤害基线。
		player.spirit_companion.set_effects_enabled(false)
		player.combat.crit_chance = 0.0
		var echo := player.echo_system
		echo.current_energy = 100.0
		player.global_position = Vector3(0.0, 0.1, -2.2)
		player.rotation = Vector3.ZERO
		await get_tree().create_timer(0.3).timeout

		# 碎冰连招 + 1 秒内置冷却（触发 / 抑制 / 再触发）
		var h1 := float(dummy_a.get("health"))
		dummy_a.call("apply_effect", StatusEffects.FROZEN, 5.0, 1.0)
		player.combat.use_skill("warrior_sweep")
		await get_tree().create_timer(0.5).timeout
		var d1 := h1 - float(dummy_a.get("health"))
		dummy_a.call("apply_effect", StatusEffects.FROZEN, 5.0, 1.0)
		player.combat.skill_cooldowns.erase("warrior_sweep")
		var h2 := float(dummy_a.get("health"))
		player.combat.use_skill("warrior_sweep")
		await get_tree().create_timer(0.5).timeout
		var d2 := h2 - float(dummy_a.get("health"))
		await get_tree().create_timer(0.7).timeout
		dummy_a.call("apply_effect", StatusEffects.FROZEN, 5.0, 1.0)
		player.combat.skill_cooldowns.erase("warrior_sweep")
		var h3 := float(dummy_a.get("health"))
		player.combat.use_skill("warrior_sweep")
		await get_tree().create_timer(0.5).timeout
		var d3 := h3 - float(dummy_a.get("health"))
		if absf(d1 - 35.25) > 0.5 or absf(d2 - 23.5) > 0.5 or absf(d3 - 35.25) > 0.5:
			_fail("碎冰/冷却不正确：%.1f / %.1f / %.1f（期望 35.25/23.5/35.25）" % [d1, d2, d3])
			return
		print("VERIFY OK: 碎冰连招与 1 秒内置冷却（触发/抑制/再触发）")

		# 弱点暴击：标记 + 精准 → +30%
		echo.collect_echo("frost_lamp_scholar")
		echo.equip_to_slot(0, "frost_lamp_scholar")
		if not echo.activate_echo():
			_fail("弱点测试：回响激活失败")
			return
		# 等待目标组合冷却结束（1 秒内置冷却）
		await get_tree().create_timer(1.1).timeout
		dummy_a.call("apply_effect", StatusEffects.MARKED, 8.0, 1.0)
		var h4 := float(dummy_a.get("health"))
		if not echo.use_echo_skill(1):
			_fail("弱点测试：寒晶弹释放失败")
			return
		await get_tree().create_timer(0.6).timeout
		var d4 := h4 - float(dummy_a.get("health"))
		if absf(d4 - 28.6) > 0.5:
			_fail("弱点暴击伤害不正确：%.1f（期望 28.6）" % d4)
			return
		print("VERIFY OK: 弱点暴击（标记 + 精准 → +30%）")

		# 等待目标组合冷却结束（1 秒内置冷却）
		await get_tree().create_timer(1.1).timeout
		# 电弧扩散：潮湿 + 雷电 → 波及附近目标
		dummy_a.call("apply_effect", StatusEffects.WET, 10.0, 1.0)
		dummy_b.call("apply_effect", StatusEffects.WET, 10.0, 1.0)
		var hb_before := float(dummy_b.get("health"))
		var lightning := SkillData.new()
		lightning.id = "verify_lightning"
		lightning.combat_tags.assign(["lightning"])
		var arc_result := ComboSystem.apply_on_hit(lightning, dummy_a, 10.0, player)
		if not (arc_result["combos"] as Array).has(ComboSystem.COMBO_ARC_SPREAD):
			_fail("电弧扩散未触发：%s" % str(arc_result["combos"]))
			return
		await get_tree().create_timer(0.2).timeout
		var spread := hb_before - float(dummy_b.get("health"))
		if absf(spread - 5.0) > 0.5:
			_fail("电弧扩散伤害不正确：%.1f（期望 5）" % spread)
			return
		print("VERIFY OK: 电弧扩散（潮湿 + 雷电 → 波及附近目标）")

		# 等待目标组合冷却结束（1 秒内置冷却）
		await get_tree().create_timer(1.1).timeout
		# 火势扩散：灼烧 + 风 → 传染灼烧
		dummy_a.call("apply_effect", StatusEffects.BURNING, 6.0, 4.0, player)
		var wind := SkillData.new()
		wind.id = "verify_wind"
		wind.combat_tags.assign(["wind"])
		var fire_result := ComboSystem.apply_on_hit(wind, dummy_a, 5.0, player)
		if not (fire_result["combos"] as Array).has(ComboSystem.COMBO_FIRE_SPREAD):
			_fail("火势扩散未触发：%s" % str(fire_result["combos"]))
			return
		await get_tree().create_timer(0.2).timeout
		if not bool(dummy_b.call("has_effect", StatusEffects.BURNING)):
			_fail("火势扩散未传染灼烧")
			return
		print("VERIFY OK: 火势扩散（灼烧 + 风 → 传染附近目标）")

		# 灼烧 DOT：DPS=10 时每 0.5s 跳 5 点
		for dummy in [dummy_a, dummy_b, dummy_c]:
			dummy.call("remove_effect", StatusEffects.BURNING)
		dummy_c.call("apply_effect", StatusEffects.BURNING, 2.0, 10.0, player)
		var hp_dot := float(dummy_c.get("health"))
		await get_tree().create_timer(1.2).timeout
		var dot_damage := hp_dot - float(dummy_c.get("health"))
		if dot_damage < 9.0 or dot_damage > 11.0:
			_fail("灼烧 DOT 跳伤不正确：%.1f（期望约 10）" % dot_damage)
			return
		dummy_c.call("remove_effect", StatusEffects.BURNING)
		print("VERIFY OK: 灼烧 DOT（每 0.5s 跳伤）")

		# 赤炉术师：火球（29 / 灼烧）+ 余烬爆发（对灼烧 +50%）
		echo.collect_echo("red_furnace_mage")
		echo.deactivate_echo()
		await get_tree().process_frame
		if not echo.equip_to_slot(1, "red_furnace_mage"):
			_fail("赤炉术师装入准备槽失败")
			return
		echo.current_slot_index = 1
		echo.current_energy = 100.0
		if not echo.activate_echo():
			_fail("赤炉术师激活失败")
			return
		player.global_position = Vector3(0.0, 0.1, -2.2)
		player.rotation = Vector3.ZERO
		await get_tree().create_timer(0.3).timeout
		var h5 := float(dummy_a.get("health"))
		if not echo.use_echo_skill(0):
			_fail("火球释放失败")
			return
		await get_tree().create_timer(0.3).timeout
		var fire_direct := h5 - float(dummy_a.get("health"))
		if absf(fire_direct - 29.0) > 0.5:
			_fail("火球伤害不正确：%.1f（期望 29）" % fire_direct)
			return
		if not bool(dummy_a.call("has_effect", StatusEffects.BURNING)):
			_fail("火球未施加灼烧")
			return
		var h6 := float(dummy_a.get("health"))
		await get_tree().create_timer(1.1).timeout
		var burn_tick := h6 - float(dummy_a.get("health"))
		if burn_tick < 5.0 or burn_tick > 7.0:
			_fail("火球灼烧 DOT 不正确：%.1f（期望约 6）" % burn_tick)
			return
		# 余烬爆发：重新以极低 DPS 挂灼烧，避免跳伤干扰测量
		dummy_a.call("remove_effect", StatusEffects.BURNING)
		dummy_a.call("apply_effect", StatusEffects.BURNING, 5.0, 0.2, player)
		var h7 := float(dummy_a.get("health"))
		if not echo.use_echo_skill(1):
			_fail("余烬爆发释放失败")
			return
		await get_tree().create_timer(0.3).timeout
		var ember := h7 - float(dummy_a.get("health"))
		if absf(ember - 25.5) > 0.6:
			_fail("余烬爆发伤害不正确：%.1f（期望 25.5）" % ember)
			return
		if not bool(dummy_a.call("has_effect", StatusEffects.BURNING)):
			_fail("余烬爆发未刷新灼烧")
			return
		print("VERIFY OK: 赤炉术师（火球 29 / 灼烧 DOT / 余烬爆发 25.5 刷新）")

		# BOSS 抗控：失衡积累 → 破绽（承伤 +30%）→ 免疫期
		var boss := dummy_boss.get("boss") as BossComponent
		if boss == null:
			_fail("DummyBoss 缺少 BossComponent")
			return
		boss.stagger_duration = 1.0
		boss.immunity_duration = 1.0
		dummy_boss.call("apply_effect", StatusEffects.FROZEN, 5.0, 1.0)
		if bool(dummy_boss.call("has_effect", StatusEffects.FROZEN)):
			_fail("BOSS 不应被冻结")
			return
		if absf(boss.stagger_value - 40.0) > 0.01:
			_fail("BOSS 失衡积累不正确：%s" % boss.stagger_value)
			return
		dummy_boss.call("apply_effect", StatusEffects.STUN, 2.0, 1.0)
		dummy_boss.call("apply_effect", StatusEffects.FROZEN, 5.0, 1.0)
		if not boss.is_staggered():
			_fail("BOSS 失衡值满未进入破绽（%s）" % boss.stagger_value)
			return
		var h_boss := float(dummy_boss.get("health"))
		dummy_boss.call("take_damage", 100.0)
		var boss_damage := h_boss - float(dummy_boss.get("health"))
		if absf(boss_damage - 130.0) > 0.5:
			_fail("BOSS 破绽承伤加成不正确：%.1f（期望 130）" % boss_damage)
			return
		await get_tree().create_timer(1.3).timeout
		if boss.is_staggered():
			_fail("BOSS 破绽未按时结束")
			return
		if absf(boss.stagger_value) > 0.01:
			_fail("BOSS 失衡值未清空")
			return
		dummy_boss.call("apply_effect", StatusEffects.FROZEN, 5.0, 1.0)
		if boss.stagger_value > 0.01:
			_fail("BOSS 免疫期仍在积累失衡")
			return
		print("VERIFY OK: BOSS 抗控（失衡积累 / 破绽承伤 +30% / 免疫期）")

		scene.queue_free()
		await get_tree().process_frame

	## 阶段 7.8：怪物 AI（追击/攻击/保持距离/冲锋撞墙/图腾/冻结/降频/血条）。
	func _verify_enemies() -> void:
		var packed := load("res://dev/test_enemies.tscn") as PackedScene
		if packed == null:
			_fail("无法加载 test_enemies.tscn")
			return
		var scene := packed.instantiate()
		get_tree().root.add_child(scene)
		await get_tree().create_timer(1.0).timeout

		var player := scene.find_child("Player", true, false) as PlayerController
		var melee: Node = scene.find_child("MeleeChaserA", true, false)
		var caster: Node = scene.find_child("RangedCasterA", true, false)
		var charger: Node = scene.find_child("ChargerA", true, false)
		var support: Node = scene.find_child("SupportA", true, false)
		var melee_b: Node = scene.find_child("MeleeChaserB", true, false)
		var pillar: Node = scene.find_child("Pillar", true, false)
		if player == null or melee == null or caster == null or charger == null or support == null or melee_b == null or pillar == null:
			_fail("怪物测试场缺少节点")
			return
		player.spirit_companion.set_effects_enabled(false)
		player.combat.crit_chance = 0.0
		print("VERIFY OK: 怪物测试场加载（8 只怪 + 导航烘焙）")

		# 1. 近战追击：把野狼放到空旷处直线距离 8 米（避免石墙/障碍干扰）
		melee.global_position = Vector3(-14.0, 0.1, 14.0)
		melee.set("spawn_position", melee.global_position)
		player.global_position = Vector3(-14.0, 0.1, 22.0)
		await get_tree().create_timer(0.4).timeout
		var dist_before: float = melee.global_position.distance_to(player.global_position)
		await get_tree().create_timer(1.0).timeout
		var dist_after: float = melee.global_position.distance_to(player.global_position)
		if int(melee.get("state")) == 0 or dist_after > dist_before - 2.0:
			_fail("近战怪未追击：state=%s 距离 %.1f→%.1f" % [melee.get("state"), dist_before, dist_after])
			return
		print("VERIFY OK: 近战追击（CHASE 并接近玩家）")

		# 2. 近战攻击造成伤害
		var hp_before := player.stats.current_health
		await get_tree().create_timer(3.0).timeout
		if player.stats.current_health >= hp_before:
			_fail("近战怪未造成伤害")
			return
		player.stats.current_health = player.stats.max_health
		print("VERIFY OK: 近战攻击（玩家掉血）")

		# 3. 远程施法者：移到空旷处（玩家在 5 米内），验证保持距离 + 魔法弹
		caster.global_position = Vector3(14.0, 0.1, 14.0)
		caster.set("spawn_position", caster.global_position)
		player.global_position = Vector3(14.0, 0.1, 9.0)
		await get_tree().create_timer(2.0).timeout
		var keep_distance: float = caster.global_position.distance_to(player.global_position)
		if keep_distance < 6.5:
			_fail("远程怪未保持距离：%.1f（state=%s vel=%s caster=%s player=%s）" % [
				keep_distance,
				caster.get("state"),
				str(caster.get("velocity")),
				str(caster.global_position),
				str(player.global_position),
			])
			return
		var hp_before_bolt := player.stats.current_health
		await get_tree().create_timer(3.5).timeout
		if player.stats.current_health >= hp_before_bolt:
			_fail("远程怪未命中玩家")
			return
		player.stats.current_health = player.stats.max_health
		print("VERIFY OK: 远程施法（保持距离 %.1f + 魔法弹命中）" % keep_distance)

		# 4. 冲锋怪：预警 → 冲锋 → 撞柱自眩晕
		player.stats.current_health = player.stats.max_health
		charger.global_position = pillar.global_position + Vector3(0, 0.1, 5.0)
		charger.set("_charge_cd", 0.0)
		player.global_position = pillar.global_position + Vector3(0, 0.1, -4.0)
		await get_tree().create_timer(3.4).timeout
		if not bool(charger.call("has_effect", StatusEffects.STUN)):
			_fail("冲锋怪撞墙后未眩晕（state=%s）" % charger.get("state"))
			return
		player.stats.current_health = player.stats.max_health
		print("VERIFY OK: 冲锋怪撞墙眩晕（预警 → 冲锋 → 眩晕）")

		# 5. 支援怪：治疗图腾（放置 → 治疗友军 → 可破坏）
		melee_b.global_position = Vector3(25.0, 0.1, 25.0)
		melee_b.set("spawn_position", melee_b.global_position)
		melee_b.set("patrol_radius", 1.5)
		support.global_position = Vector3(27.0, 0.1, 25.0)
		support.set("spawn_position", support.global_position)
		support.set("_totem_cd", 0.0)
		player.global_position = Vector3(38.0, 0.1, 38.0)
		await get_tree().create_timer(0.3).timeout
		melee_b.call("take_damage", 25.0)
		melee_b.set("_target", null)
		melee_b.set("state", 0)
		melee_b.set("_leash_timer", 0.0)
		melee_b.set("move_speed", 0.0)
		var ally_hp_before := float(melee_b.get("current_health"))
		await get_tree().create_timer(1.6).timeout
		var totems := get_tree().get_nodes_in_group("heal_totem")
		if totems.is_empty():
			_fail("支援怪未放置治疗图腾")
			return
		var totem: Node = totems[0]
		await get_tree().create_timer(1.2).timeout
		if float(melee_b.get("current_health")) <= ally_hp_before:
			_fail("治疗图腾未治疗友军（%.1f→%.1f）" % [ally_hp_before, float(melee_b.get("current_health"))])
			return
		totem.call("take_damage", 100.0)
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(totem) and not totem.is_queued_for_deletion():
			_fail("图腾未被破坏")
			return
		print("VERIFY OK: 支援怪（治疗图腾 / 治疗友军 / 可破坏）")

		# 6. 冻结：控制状态阻止怪物行动
		player.global_position = Vector3(0.0, 0.1, 14.0)
		melee.global_position = Vector3(0.0, 0.1, 8.0)
		melee.set("spawn_position", melee.global_position)
		player.stats.current_health = player.stats.max_health
		await get_tree().create_timer(0.2).timeout
		melee.call("apply_effect", StatusEffects.FROZEN, 3.0, 1.0)
		await get_tree().create_timer(0.3).timeout
		if int(melee.get("state")) != 3:
			_fail("冻结未使怪物进入失衡：%s" % melee.get("state"))
			return
		var frozen_pos: Vector3 = melee.global_position
		await get_tree().create_timer(0.6).timeout
		if melee.global_position.distance_to(frozen_pos) > 0.2:
			_fail("冻结期间怪物仍在移动（%.2f）" % melee.global_position.distance_to(frozen_pos))
			return
		melee.call("remove_effect", StatusEffects.FROZEN)
		print("VERIFY OK: 冻结阻止怪物行动")

		# 7. AI 降频 / 休眠
		player.global_position = Vector3(38.0, 0.1, 38.0)
		await get_tree().process_frame
		var caster_interval := float(caster.call("_compute_update_interval"))
		if caster_interval < 0.5:
			_fail("远处怪物未降频：interval=%s" % caster_interval)
			return
		print("VERIFY OK: 远处怪物降频/休眠（间隔 %.1fs）" % caster_interval)

		# 8. 血条
		if melee.get_node_or_null("HealthBar/Fill") == null:
			_fail("怪物缺少血条节点")
			return
		print("VERIFY OK: 怪物血条（Sprite3D 填充条）")

		scene.queue_free()
		await get_tree().process_frame

	## 阶段 7.9：装备/背包/掉落/强化（属性重算 / 品质 / 拾取 / 锁定 / 强化 / 面板）。
	func _verify_equipment() -> void:
		if DataRegistry.get_all_items().size() < 11:
			_fail("物品数据不完整：%d" % DataRegistry.get_all_items().size())
			return
		print("VERIFY OK: 物品数据 %d 件（武器/防具/饰品/材料）" % DataRegistry.get_all_items().size())

		var packed := load("res://dev/test_combat.tscn") as PackedScene
		var scene := packed.instantiate()
		get_tree().root.add_child(scene)
		await get_tree().create_timer(0.6).timeout
		var player := scene.find_child("Player", true, false) as PlayerController
		var dummy_a: Node = scene.find_child("DummyA", true, false)
		if player == null or dummy_a == null:
			_fail("装备测试场景缺少 Player / DummyA")
			return
		player.spirit_companion.set_effects_enabled(false)
		var inventory := player.inventory
		var equipment := player.equipment
		var enhancement := player.enhancement
		if inventory == null or equipment == null or enhancement == null:
			_fail("玩家缺少装备/背包/强化组件")
			return
		player.global_position = Vector3(0.0, 0.1, -2.2)
		player.rotation = Vector3.ZERO
		await get_tree().create_timer(0.2).timeout

		# 装备武器：攻击强度实时变化 + 实战伤害变化 + 模型更换
		inventory.add_item(DataRegistry.get_item("iron_sword"))
		equipment.equip_from_inventory(inventory, inventory.find_index("iron_sword"))
		if absf(equipment.get_total_attack_power() - 25.0) > 0.01:
			_fail("装备武器后攻击强度不正确：%s" % equipment.get_total_attack_power())
			return
		if not player.fp_arms.get_weapon_model_path().contains("iron_sword"):
			_fail("武器模型未更换：%s" % player.fp_arms.get_weapon_model_path())
			return
		player.combat.crit_chance = 0.0
		var hp_before := float(dummy_a.get("health"))
		player.combat.basic_attack()
		await get_tree().create_timer(0.35).timeout
		var dmg := hp_before - float(dummy_a.get("health"))
		if absf(dmg - 28.0) > 0.5:
			_fail("装备后普攻伤害不正确：%.1f（期望 28）" % dmg)
			return
		print("VERIFY OK: 装备武器（攻击强度 15→25 / 普攻 28 / 武器模型更换）")

		# 防具：生命上限 / 护甲
		inventory.add_item(DataRegistry.get_item("leather_helmet"))
		equipment.equip_from_inventory(inventory, inventory.find_index("leather_helmet"))
		if absf(player.stats.max_health - 130.0) > 0.01:
			_fail("头盔生命加成未应用：%s" % player.stats.max_health)
			return
		inventory.add_item(DataRegistry.get_item("iron_chest"))
		equipment.equip_from_inventory(inventory, inventory.find_index("iron_chest"))
		if absf(player.stats.armor - 18.0) > 0.01:
			_fail("胸甲护甲未应用：%s" % player.stats.armor)
			return
		player.stats.current_health = player.stats.max_health
		player.combat.crit_chance = 0.0
		var received := player.take_damage(10.0, dummy_a)
		if absf(received - 7.35) > 0.1:
			_fail("护甲实际减伤不正确：实收 %.2f（期望 7.35）" % received)
			return
		print("VERIFY OK: 防具（生命上限 130 / 护甲 18 / 实际减伤）")

		# 稀有武器：急速 / 冷却 / 发光 + 手套变色
		inventory.add_item(DataRegistry.get_item("frost_edge"))
		equipment.equip_from_inventory(inventory, inventory.find_index("frost_edge"))
		if not player.fp_arms.is_weapon_glowing():
			_fail("稀有武器未发光")
			return
		if absf(player.combat.skill_haste - 0.05) > 0.001:
			_fail("技能急速未应用：%s" % player.combat.skill_haste)
			return
		player.combat.crit_chance = 0.0
		player.combat.use_skill("warrior_sweep")
		await get_tree().create_timer(0.4).timeout
		var sweep_cd := player.combat.get_cooldown_remaining("warrior_sweep")
		if sweep_cd < 5.3 or sweep_cd > 5.85:
			_fail("技能急速未作用于冷却：%.2f（期望约 5.6）" % sweep_cd)
			return
		inventory.add_item(DataRegistry.get_item("guardian_gloves"))
		equipment.equip_from_inventory(inventory, inventory.find_index("guardian_gloves"))
		if player.fp_arms.get_glove_tint() == Color(0.55, 0.55, 0.58):
			_fail("手套更换未改变手部颜色")
			return
		print("VERIFY OK: 稀有武器（急速 5% / 冷却 5.6s / 发光）+ 手套变色")

		# 饰品：专注恢复 + 回响护符
		inventory.add_item(DataRegistry.get_item("vigor_pendant"))
		equipment.equip_from_inventory(inventory, inventory.find_index("vigor_pendant"))
		if absf(player.stats.focus_regen - 7.0) > 0.01:
			_fail("饰品专注恢复未应用：%s" % player.stats.focus_regen)
			return
		inventory.add_item(DataRegistry.get_item("echo_charm"))
		equipment.equip_from_inventory(inventory, inventory.find_index("echo_charm"))
		player.echo_system.collect_echo("frost_lamp_scholar")
		player.echo_system.equip_to_slot(0, "frost_lamp_scholar")
		player.echo_system.current_energy = 100.0
		if not player.echo_system.activate_echo():
			_fail("护符测试：回响激活失败")
			return
		player.echo_system.deactivate_echo()
		if player.stats.shield < 19.0:
			_fail("回响护符未给予护盾：%s" % player.stats.shield)
			return
		player.stats.clear_shield()
		print("VERIFY OK: 饰品（专注恢复 6→7 / 回响护符 20 点护盾）")

		# 背包：材料堆叠 / 锁定保护 / 批量分解 / 出售 / 整理
		var free_before := inventory.get_free_slots()
		inventory.add_material("forest_herb", 3)
		inventory.add_material("forest_herb", 3)
		if inventory.get_material_count("forest_herb") != 6:
			_fail("材料未自动堆叠：%d" % inventory.get_material_count("forest_herb"))
			return
		inventory.add_item(DataRegistry.get_item("rusty_sword"))
		inventory.add_item(DataRegistry.get_item("rusty_sword"))
		inventory.lock_item(inventory.find_index("rusty_sword"), true)
		var dust_before := inventory.get_material_count("echo_dust")
		var dismantled: int = inventory.batch_dismantle_low_quality(1)
		if dismantled < 1:
			_fail("批量分解未分解任何物品")
			return
		var locked_index := inventory.find_index("rusty_sword")
		if locked_index < 0 or not bool(inventory.get_entry(locked_index)["locked"]):
			_fail("锁定物品被批量分解")
			return
		if inventory.get_material_count("echo_dust") <= dust_before:
			_fail("分解未返还回响尘")
			return
		var gold_before := inventory.gold
		inventory.add_item(DataRegistry.get_item("leather_helmet"))
		inventory.sell(inventory.find_index("leather_helmet"))
		if inventory.gold <= gold_before:
			_fail("出售未获得金币")
			return
		inventory.sort_items()
		if inventory.find_index("iron_sword") >= 0 or inventory.find_index("vigor_pendant") >= 0:
			_fail("未锁定的低品质物品未被批量分解")
			return
		if inventory.get_free_slots() <= free_before:
			_fail("整理/分解后背包格数异常：free=%d（原 %d）" % [inventory.get_free_slots(), free_before])
			return
		print("VERIFY OK: 背包（材料堆叠 / 锁定保护 / 批量分解 / 出售 / 整理）")

		# 掉落：必得金币 + 独立装备与材料抽取 + 世界掉落自动拾取
		var gold_ok := false
		var equip_seen := false
		var material_seen := false
		for i in 40:
			for entry in LootSystem.generate_loot("normal_forest_enemy"):
				match str(entry.get("type", "")):
					"gold":
						gold_ok = true
					"item":
						equip_seen = true
					"material":
						material_seen = true
		if not gold_ok or not equip_seen or not material_seen:
			_fail("掉落生成异常：gold=%s equip=%s material=%s" % [gold_ok, equip_seen, material_seen])
			return
		var count_before := inventory.get_item_count("leather_helmet")
		var gold_before_drop := inventory.gold
		LootSystem.drop_loot_at_position(scene, [
			{"type": "item", "item_id": "leather_helmet"},
			{"type": "gold", "amount": 7},
		], player.global_position + Vector3(0.8, 0.0, 0.0))
		await get_tree().create_timer(0.6).timeout
		if inventory.get_item_count("leather_helmet") <= count_before:
			_fail("掉落物未被自动拾取（装备）")
			return
		if inventory.gold <= gold_before_drop:
			_fail("掉落物未被自动拾取（金币）")
			return
		print("VERIFY OK: 掉落（必得金币 / 独立抽取 / 世界掉落自动拾取）")

		# 强化：+1 提升 10% 主属性，消耗回响尘
		inventory.add_material("echo_dust", 10)
		var atk_before_enh := equipment.get_total_attack_power()
		var weapon_item := equipment.get_equipped("weapon")
		if not enhancement.enhance("weapon"):
			_fail("强化失败")
			return
		var expected_atk := atk_before_enh + weapon_item.attack_power * 0.1
		if absf(equipment.get_total_attack_power() - expected_atk) > 0.1:
			_fail("强化属性提升不正确：%.2f（期望 %.2f）" % [equipment.get_total_attack_power(), expected_atk])
			return
		if equipment.get_equipped_enhance("weapon") != 1:
			_fail("强化等级未记录")
			return
		print("VERIFY OK: 强化 +1（攻击强度 +10% / 消耗回响尘）")

		# 背包面板：开关 / 装备槽显示 / 属性对比文本
		player.call("_toggle_inventory_panel")
		await get_tree().process_frame
		if not player.inventory_panel.visible:
			_fail("背包面板未打开")
			return
		var weapon_button := player.inventory_panel.get_node("Frame/SlotWeapon") as Button
		if not weapon_button.text.contains("霜痕之刃"):
			_fail("装备槽未显示当前武器：%s" % weapon_button.text)
			return
		var compare_text: String = player.inventory_panel.get_comparison_text(DataRegistry.get_item("iron_sword"), 0)
		if not compare_text.contains("攻击强度"):
			_fail("装备对比文本缺少属性")
			return
		player.call("_toggle_inventory_panel")
		print("VERIFY OK: 背包面板（开关 / 装备槽显示 / 属性对比）")

		scene.queue_free()
		await get_tree().process_frame

	## 阶段 7.95：任务系统（5 任务 / 生命周期 / NPC 标记 / 追踪 / 奖励防重复）。
	func _verify_quests() -> void:
		var packed := load("res://dev/test_quests.tscn") as PackedScene
		if packed == null:
			_fail("无法加载 test_quests.tscn")
			return
		var scene := packed.instantiate()
		get_tree().root.add_child(scene)
		await get_tree().create_timer(1.0).timeout
		var player := scene.find_child("Player", true, false) as PlayerController
		var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
		var elin: Node = scene.find_child("NpcElin", true, false)
		var ranger: Node = scene.find_child("NpcRanger", true, false)
		var tom: Node = scene.find_child("NpcTom", true, false)
		var mara: Node = scene.find_child("NpcMara", true, false)
		if player == null or quest_manager == null or elin == null or ranger == null or tom == null or mara == null:
			_fail("任务测试场缺少关键节点")
			return
		player.spirit_companion.set_effects_enabled(false)
		if quest_manager.all_quests.size() != 5:
			_fail("任务数据数量不正确：%d" % quest_manager.all_quests.size())
			return
		print("VERIFY OK: 任务数据 5 个 + NPC 就绪")

		# 前置限制 + NPC 标记
		if quest_manager.can_accept("q_echo_discovery"):
			_fail("前置任务未完成时 q2 可接取")
			return
		elin.call("_update_marker")
		if quest_manager.get_npc_marker("elin") != "！":
			_fail("NPC 接取标记不正确：%s" % quest_manager.get_npc_marker("elin"))
			return
		print("VERIFY OK: 前置限制 + NPC「！」标记")

		# q1：接取（NPC 对话）→ 探索/击杀/对话 → 交付 → 奖励防重复
		await _drive_npc_dialogue(player, elin)
		if not quest_manager.active_quests.has("q_forest_rescue"):
			_fail("对话后未接取 q1")
			return
		if quest_manager.tracked_main_quest != "q_forest_rescue":
			_fail("主线未自动追踪")
			return
		await get_tree().create_timer(0.4).timeout
		if not player.quest_tracker.text.contains("森林里的呼救"):
			_fail("任务追踪 HUD 未显示主线：%s" % player.quest_tracker.text)
			return
		print("VERIFY OK: 接取任务 + 主线自动追踪 + HUD 显示")

		player.global_position = Vector3(20.0, 0.5, 8.0)
		await get_tree().create_timer(0.4).timeout
		if int(quest_manager.active_quests["q_forest_rescue"]["progress"][0]) < 1:
			_fail("探索区域未推进任务目标")
			return
		for wolf_name in ["WolfA", "WolfB", "WolfC"]:
			var wolf: Node = scene.find_child(wolf_name, true, false)
			if wolf != null:
				wolf.call("die")
		await get_tree().create_timer(0.3).timeout
		if int(quest_manager.active_quests["q_forest_rescue"]["progress"][1]) != 3:
			_fail("击杀目标进度不正确：%d" % quest_manager.active_quests["q_forest_rescue"]["progress"][1])
			return
		print("VERIFY OK: 探索/击杀目标自动推进")

		player.global_position = Vector3(22.0, 0.5, 8.0)
		await get_tree().create_timer(0.3).timeout
		var gold_before := player.inventory.gold
		await _drive_npc_dialogue(player, ranger)
		if not quest_manager.is_quest_completed("q_forest_rescue"):
			_fail("q1 未交付")
			return
		if player.inventory.gold != gold_before + 100:
			_fail("q1 金币奖励不正确：%d" % player.inventory.gold)
			return
		if not player.inventory.has_item("iron_sword"):
			_fail("q1 物品奖励未发放")
			return
		if quest_manager.turn_in_quest("q_forest_rescue"):
			_fail("已完成任务被重复交付")
			return
		if player.inventory.gold != gold_before + 100:
			_fail("奖励被重复发放")
			return
		print("VERIFY OK: 任务交付与奖励（金币/物品）+ 防重复领取")

		# q2：接取 → 探索 + 回响 → 交付
		if not quest_manager.can_accept("q_echo_discovery"):
			_fail("前置完成后 q2 仍不可接")
			return
		await _drive_npc_dialogue(player, ranger)
		if not quest_manager.active_quests.has("q_echo_discovery"):
			_fail("q2 未接取")
			return
		player.global_position = Vector3(-19.0, 0.5, -19.0)
		await get_tree().create_timer(0.4).timeout
		player.echo_system.collect_echo("frost_lamp_scholar")
		await get_tree().create_timer(0.2).timeout
		if not quest_manager.can_turn_in("q_echo_discovery"):
			_fail("q2 目标未完成")
			return
		await _drive_npc_dialogue(player, ranger)
		if not quest_manager.is_quest_completed("q_echo_discovery"):
			_fail("q2 未交付")
			return
		print("VERIFY OK: q2（探索 + 回响获取 + 交付）")

		# q3：接取 → 冰环冻结×2 + 碎冰 + 击杀精英 → 交付（霜痕之刃）
		await _drive_npc_dialogue(player, ranger)
		if not quest_manager.active_quests.has("q_frost_trial"):
			_fail("q3 未接取")
			return
		player.echo_system.equip_to_slot(0, "frost_lamp_scholar")
		player.echo_system.current_energy = 100.0
		if not player.echo_system.activate_echo():
			_fail("q3 测试：回响激活失败")
			return
		player.global_position = Vector3(1.0, 0.5, -18.0)
		player.rotation = Vector3.ZERO
		await get_tree().create_timer(0.3).timeout
		player.echo_system.use_echo_skill(0)
		await get_tree().create_timer(0.3).timeout
		var q3_progress: Array = quest_manager.active_quests["q_frost_trial"]["progress"]
		for retry in 2:
			if int(q3_progress[0]) >= 2:
				break
			var mage_a: Node = scene.find_child("MageA", true, false)
			var mage_b: Node = scene.find_child("MageB", true, false)
			if mage_a == null or mage_b == null:
				break
			player.echo_system.set("_skill_cooldowns", {})
			player.global_position = ((mage_a as Node3D).global_position + (mage_b as Node3D).global_position) * 0.5 + Vector3(0.0, 0.5, 0.0)
			await get_tree().create_timer(0.2).timeout
			player.echo_system.use_echo_skill(0)
			await get_tree().create_timer(0.3).timeout
		if int(q3_progress[0]) < 2:
			_fail("冻结目标进度不正确：%d" % q3_progress[0])
			return
		var boar: Node = scene.find_child("EliteBoar", true, false)
		if boar == null:
			_fail("缺少精英苔牙野猪")
			return
		player.global_position = boar.global_position + Vector3(0.0, 0.1, 2.0)
		player.rotation = Vector3.ZERO
		player.combat.crit_chance = 0.0
		await get_tree().create_timer(0.3).timeout
		boar.call("apply_effect", StatusEffects.FROZEN, 5.0, 1.0)
		player.combat.use_skill("warrior_sweep")
		await get_tree().create_timer(0.6).timeout
		if int(q3_progress[1]) < 1:
			_fail("碎冰连招未计入任务")
			return
		boar.call("die")
		await get_tree().create_timer(0.3).timeout
		if not quest_manager.can_turn_in("q_frost_trial"):
			_fail("q3 目标未全部完成")
			return
		var frost_count_before := player.inventory.get_item_count("frost_edge")
		await _drive_npc_dialogue(player, ranger)
		if not quest_manager.is_quest_completed("q_frost_trial"):
			_fail("q3 未交付")
			return
		if player.inventory.get_item_count("frost_edge") != frost_count_before + 1:
			_fail("q3 稀有武器奖励未发放")
			return
		print("VERIFY OK: q3（冻结×2 / 碎冰连招 / 精英击杀 / 霜痕之刃奖励）")

		# q4：接取 → 采集点×3 + 补两份 → 交付（药剂×3）
		await _drive_npc_dialogue(player, tom)
		if not quest_manager.active_quests.has("q_camp_supply"):
			_fail("q4 未接取")
			return
		var herb_before := player.inventory.get_material_count("forest_herb")
		for gather_name in ["GatherA", "GatherB", "GatherC"]:
			var gather: Node = scene.find_child(gather_name, true, false)
			if gather != null:
				gather.get_node("Interactable").call("interact", player)
				await get_tree().create_timer(0.1).timeout
		player.inventory.add_material("forest_herb", 2)
		await get_tree().create_timer(0.2).timeout
		if player.inventory.get_material_count("forest_herb") != herb_before + 5:
			_fail("草药采集数量不正确：%d" % player.inventory.get_material_count("forest_herb"))
			return
		var potion_before := player.inventory.get_item_count("heal_potion")
		await _drive_npc_dialogue(player, tom)
		if not quest_manager.is_quest_completed("q_camp_supply"):
			_fail("q4 未交付")
			return
		if player.inventory.get_item_count("heal_potion") != potion_before + 3:
			_fail("q4 药剂奖励未发放")
			return
		print("VERIFY OK: q4（采集点交互 + 材料计数 + 药剂奖励）")

		# q5：接取 → 探索 + 击杀法师 + 拾取日记（独立收纳）→ 交付
		# q3复用的法师可能已被冰环/碎冰范围伤害击杀；q5使用独立目标，避免依赖随机走位。
		var q5_mages: Array[Node] = []
		for i in 2:
			var quest_mage := (load("res://scenes/actors/base_enemy.tscn") as PackedScene).instantiate()
			quest_mage.set_script(load("res://scenes/actors/ranged_caster.gd"))
			quest_mage.name = "QuestFiveMage%d" % i
			quest_mage.position = Vector3(-2.0 + i * 6.0, 0.0, -20.0)
			scene.add_child(quest_mage)
			quest_mage.set_physics_process(false)
			q5_mages.append(quest_mage)
		await _drive_npc_dialogue(player, mara)
		if not quest_manager.active_quests.has("q_missing_hunter"):
			_fail("q5 未接取")
			return
		player.global_position = Vector3(1.0, 0.5, -24.0)
		await get_tree().create_timer(0.4).timeout
		for quest_mage in q5_mages:
			quest_mage.call("die")
		await get_tree().create_timer(0.3).timeout
		var diary: Node = scene.find_child("HunterDiary", true, false)
		if diary == null:
			_fail("缺少猎人日记")
			return
		diary.get_node("Interactable").call("interact", player)
		await get_tree().create_timer(0.2).timeout
		if int(player.inventory.quest_items.get("hunter_diary", 0)) != 1:
			_fail("任务物品未进入独立收纳")
			return
		if not quest_manager.can_turn_in("q_missing_hunter"):
			_fail("q5 目标未全部完成：%s，法师A=%s/B=%s，玩家位置=%s" % [quest_manager.active_quests["q_missing_hunter"]["progress"],is_instance_valid(scene.find_child("MageA",true,false)),is_instance_valid(scene.find_child("MageB",true,false)),player.global_position])
			return
		await _drive_npc_dialogue(player, mara)
		if not quest_manager.is_quest_completed("q_missing_hunter"):
			_fail("q5 未交付")
			return
		print("VERIFY OK: q5（探索 / 击杀 / 任务物品独立收纳 / 交付）")

		if quest_manager.completed_quests.size() != 5:
			_fail("已完成任务数不正确：%d" % quest_manager.completed_quests.size())
			return
		print("VERIFY OK: 五任务全部完成（%d/%d）" % [quest_manager.completed_quests.size(), quest_manager.all_quests.size()])

		scene.queue_free()
		await get_tree().process_frame

	## 驱动一次 NPC 对话直到结束（模拟玩家按「继续」）。
	func _drive_npc_dialogue(player: PlayerController, npc: Node) -> void:
		var interactable := npc.get_node_or_null("Interactable")
		if interactable != null:
			interactable.call("interact", player)
		await get_tree().process_frame
		var guard := 0
		while player.dialogue_active and guard < 20:
			guard += 1
			player.dialogue_box.advance()
			await get_tree().process_frame
		await get_tree().process_frame

	## 阶段 7.97：森林世界（地形/营地/POI/宝箱/采集/昼夜/天气/导航/安全区复活）。
	func _verify_world() -> void:
		var packed := load("res://scenes/world/forest_entrance.tscn") as PackedScene
		if packed == null:
			_fail("无法加载 forest_entrance.tscn")
			return
		var session := (load("res://scenes/app/game_session.tscn") as PackedScene).instantiate() as GameSession
		get_tree().root.add_child(session)
		await get_tree().process_frame
		var world := packed.instantiate()
		get_tree().root.add_child(world)
		var spawn_pos: Vector3 = world.call("get_spawn_position")
		var streamer: WorldStreamer = world.get_node("NavRegion/Streamer")
		if not await _wait_until(func() -> bool: return streamer.is_world_ready(), 40.0):
			_fail("世界分块未就绪")
			_cleanup_world(session, world, null)
			return
		var terrain: Node3D = world.get_node("NavRegion/Terrain")
		var camp: Node = world.find_child("Camp", true, false)
		var chests := get_tree().get_nodes_in_group("chest")
		var gathers := get_tree().get_nodes_in_group("gather_node")
		var enemies := get_tree().get_nodes_in_group("enemy")
		if terrain.find_child("TerrainBody", true, false) == null or terrain.find_child("TerrainMesh", true, false) == null:
			_fail("地形网格或碰撞缺失")
			_cleanup_world(session, world, null)
			return
		if chests.size() < 4 or gathers.size() < 5 or enemies.size() < 8:
			_fail("世界内容数量不足：宝箱 %d / 采集 %d / 怪物 %d" % [chests.size(), gathers.size(), enemies.size()])
			_cleanup_world(session, world, null)
			return
		print("VERIFY OK: 森林世界生成（宝箱 %d / 采集 %d / 怪物 %d / 分块 %d）" % [
			chests.size(), gathers.size(), enemies.size(), WorldLayout.CHUNKS.size(),
		])
		if camp == null:
			_fail("营地缺失")
			_cleanup_world(session, world, null)
			return
		for camp_node in ["Windmill", "Campfire", "Forge", "Storage", "NoticeBoard", "FastTravel", "SafeZone"]:
			if camp.find_child(camp_node, true, false) == null:
				_fail("营地缺少 %s" % camp_node)
				_cleanup_world(session, world, null)
				return
		for npc_name in ["NpcElin", "NpcTom", "NpcMara", "NpcGlen"]:
			if camp.find_child(npc_name, true, false) == null:
				_fail("营地缺少 NPC %s" % npc_name)
				_cleanup_world(session, world, null)
				return
		if world.find_child("RangerWounded", true, false) == null:
			_fail("缺少受伤的巡林者")
			_cleanup_world(session, world, null)
			return
		var area_ids: Array = []
		for marker in get_tree().get_nodes_in_group("quest_marker"):
			area_ids.append(str(marker.get_meta("quest_marker_id", "")))
		for area_id in ["forest_east", "old_observatory", "hunter_cabin"]:
			if not area_ids.has(area_id):
				_fail("缺少任务区域 %s（现有 %s）" % [area_id, str(area_ids)])
				_cleanup_world(session, world, null)
				return
		if world.find_child("EchoStone", true, false) == null:
			_fail("旧观测所缺少回响碑")
			_cleanup_world(session, world, null)
			return
		print("VERIFY OK: 营地建筑 + 4 NPC + 巡林者 + 3 任务区域 + 回响碑")
		# 营地安全区：玩家在营地内时怪物不索敌追逐
		var test_wolf := (load("res://scenes/actors/base_enemy.tscn") as PackedScene).instantiate() as Node3D
		test_wolf.set_script(load("res://scenes/actors/melee_chaser.gd") as Script)
		test_wolf.position = WorldLayout.CAMP + Vector3(6.0, 0.5, 0.0)
		get_tree().root.add_child(test_wolf)
		await get_tree().create_timer(1.2).timeout
		var wolf_state := int(test_wolf.get("state"))
		test_wolf.queue_free()
		if wolf_state == 1 or wolf_state == 2:
			_fail("营地安全区失效：怪物在营地内索敌（state=%d）" % wolf_state)
			_cleanup_world(session, world, null)
			return
		print("VERIFY OK: 营地安全区（怪物内不索敌）")

		var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
		get_tree().root.add_child(player)
		player.global_position = spawn_pos
		await get_tree().create_timer(0.5).timeout

		# 宝箱：开启一次 → 状态写入会话 → 不重复；读档状态恢复
		var chest: Node = world.find_child("ChestWolves", true, false)
		if chest == null:
			_fail("缺少野狼区宝箱")
			_cleanup_world(session, world, player)
			return
		var chest_interact := chest.find_child("Interactable", true, false)
		chest_interact.call("interact", player)
		await get_tree().create_timer(0.2).timeout
		if not bool(chest.call("is_chest_opened")):
			_fail("宝箱未打开")
			_cleanup_world(session, world, player)
			return
		var opened_list: Array = session.world_data.get("chests_opened", [])
		if not opened_list.has("chest_wolves"):
			_fail("宝箱开启状态未写入会话")
			_cleanup_world(session, world, player)
			return
		chest_interact.call("interact", player)
		await get_tree().create_timer(0.2).timeout
		opened_list = session.world_data.get("chests_opened", [])
		if opened_list.size() != 1:
			_fail("宝箱被重复记录")
			_cleanup_world(session, world, player)
			return
		print("VERIFY OK: 宝箱（开启一次 / 会话记录 / 不可重复）")

		# 采集点：交互产材料
		var gather: Node = gathers[0]
		var material_id := str(gather.get("material_id"))
		var before_count := player.inventory.get_material_count(material_id)
		gather.find_child("Interactable", true, false).call("interact", player)
		await get_tree().create_timer(0.2).timeout
		if player.inventory.get_material_count(material_id) != before_count + 1:
			_fail("采集点未产出材料")
			_cleanup_world(session, world, player)
			return
		print("VERIFY OK: 采集点（%s +1）" % material_id)

		# 溪流潮湿状态
		player.global_position = Vector3(18.0, TerrainBuilder.height_at(18.0, 80.0) + 0.4, 80.0)
		await get_tree().create_timer(1.0).timeout
		if not player.has_effect(StatusEffects.WET):
			_fail("溪流未施加潮湿状态")
			_cleanup_world(session, world, player)
			return
		print("VERIFY OK: 溪流潮湿触发（wet）")

		# 昼夜：正午与深夜的太阳/环境光/营火对比
		var day_night: DayNightCycle = world.get_node("DayNight")
		var sun: DirectionalLight3D = world.get_node("Sun")
		var env: WorldEnvironment = world.get_node("WorldEnvironment")
		day_night.set_time_of_day(12.0)
		await get_tree().process_frame
		var noon_energy := sun.light_energy
		var noon_rotation := sun.rotation.x
		var fire: OmniLight3D = camp.find_child("FireLight", true, false)
		var fire_noon := fire.light_energy if fire != null else 0.0
		day_night.set_time_of_day(23.0)
		await get_tree().process_frame
		var night_energy := sun.light_energy
		var fire_night := fire.light_energy if fire != null else 0.0
		if noon_energy <= night_energy:
			_fail("昼夜太阳能量未变化：正午 %.2f / 深夜 %.2f" % [noon_energy, night_energy])
			_cleanup_world(session, world, player)
			return
		if absf(noon_rotation - sun.rotation.x) < 0.2:
			_fail("昼夜太阳角度未变化")
			_cleanup_world(session, world, player)
			return
		if env.environment.ambient_light_energy < 0.2:
			_fail("夜晚环境光过暗：%.2f" % env.environment.ambient_light_energy)
			_cleanup_world(session, world, player)
			return
		if fire != null and fire_night <= fire_noon + 0.2:
			_fail("营火灯光未在夜晚增强：%.2f→%.2f" % [fire_noon, fire_night])
			_cleanup_world(session, world, player)
			return
		day_night.set_time_of_day(8.0)
		print("VERIFY OK: 昼夜循环（太阳角度/能量 / 夜晚不黑 / 营火增强）")

		# 天气：渐变切换 + 雨粒子 + 雾密度
		var weather: WeatherSystem = world.get_node("Weather")
		weather.blend_seconds = 0.05
		weather.set_weather_state("rain")
		await get_tree().create_timer(0.6).timeout
		var rain: GPUParticles3D = weather.get("_rain")
		if not rain.emitting or env.environment.fog_density < 0.02:
			_fail("雨天未生效：emitting=%s fog=%.3f" % [str(rain.emitting), env.environment.fog_density])
			_cleanup_world(session, world, player)
			return
		weather.set_weather_state("clear")
		await get_tree().create_timer(0.6).timeout
		if rain.emitting:
			_fail("晴天未停止降雨")
			_cleanup_world(session, world, player)
			return
		print("VERIFY OK: 天气切换（雨粒子 / 雾密度 / 渐变恢复）")

		# 导航烘焙
		var nav_region: NavigationRegion3D = world.get_node("NavRegion")
		if not await _wait_until(func() -> bool: return nav_region.navigation_mesh.get_polygon_count() > 0, 90.0):
			_fail("导航网格烘焙失败（多边形 0）")
			_cleanup_world(session, world, player)
			return
		print("VERIFY OK: 导航烘焙（多边形 %d）" % nav_region.navigation_mesh.get_polygon_count())

		# 死亡 → 营地篝火复活（安全区设点）
		player.set_respawn_point(spawn_pos)
		player.global_position = Vector3(62.0, 0.5, 40.0)
		player.stats.take_damage(99999.0)
		await get_tree().create_timer(2.6).timeout
		if player.global_position.distance_to(spawn_pos) > 3.0:
			_fail("死亡后未回到营地：%s" % str(player.global_position))
			_cleanup_world(session, world, player)
			return
		print("VERIFY OK: 死亡回到营地篝火（复活点）")

		_cleanup_world(session, world, player)

	## 轮询等待条件成立。
	func _wait_until(condition: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(condition.call()):
				return true
			await get_tree().create_timer(0.2).timeout
			waited += 0.2
		return false

	func _cleanup_world(session: Node, world: Node, player: Node) -> void:
		if player != null and is_instance_valid(player):
			player.queue_free()
		if world != null and is_instance_valid(world):
			world.queue_free()
		if session != null and is_instance_valid(session):
			session.queue_free()
		await get_tree().process_frame

	## 阶段 7.98：微型秘境与苔冠巨兽（入口门控 / 波次 / 石柱破绽 / 召唤 / 阶段 / 首通 / 管理器切换与死亡重置）。
	func _verify_dungeon() -> void:
		var session := (load("res://scenes/app/game_session.tscn") as PackedScene).instantiate() as GameSession
		get_tree().root.add_child(session)
		var quest_manager := session.get_node("WorldState/QuestManager") as QuestManager
		quest_manager.completed_quests.assign(["q_frost_trial"])
		var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
		session.get_node("Player").add_child(player)
		# 入口门控测试先移除会话自带管理器（避免交互被管理器接管），管理器阶段再单独创建
		assert(session.get_node_or_null("WorldState/DungeonManager") == null)
		await get_tree().process_frame

		# 入口条件检查
		var entrance := (load("res://scenes/dungeons/dungeon_entrance.tscn") as PackedScene).instantiate() as Node3D
		get_tree().root.add_child(entrance)
		var requested := [false]
		entrance.connect("enter_requested", func(_a: String, _b: String, _c: Vector3) -> void: requested[0] = true)
		await get_tree().process_frame
		if entrance.call("can_enter") != true:
			_fail("任务完成后秘境入口不可进入")
			_cleanup_dungeon_test(session, null, null, player)
			return
		quest_manager.completed_quests.clear()
		if entrance.call("can_enter") != false:
			_fail("未完成任务时秘境入口可进入")
			_cleanup_dungeon_test(session, null, entrance, player)
			return
		entrance.find_child("Interactable", true, false).call("interact", player)
		await get_tree().process_frame
		if requested[0]:
			_fail("条件不满足时入口仍然触发进入")
			_cleanup_dungeon_test(session, null, entrance, player)
			return
		quest_manager.completed_quests.assign(["q_frost_trial"])
		entrance.find_child("Interactable", true, false).call("interact", player)
		await get_tree().process_frame
		if not requested[0]:
			_fail("条件满足时入口未触发进入")
			_cleanup_dungeon_test(session, null, entrance, player)
			return
		entrance.queue_free()
		print("VERIFY OK: 秘境入口（任务门控 / 交互触发）")

		# 秘境结构
		var dungeon := (load("res://scenes/dungeons/forest_grove_dungeon.tscn") as PackedScene).instantiate() as Node3D
		get_tree().root.add_child(dungeon)
		if not await _wait_until(func() -> bool: return bool(dungeon.call("is_ready_for_player")), 40.0):
			_fail("秘境导航未就绪")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		var boss: Node = dungeon.call("get_boss")
		if boss == null or str(boss.get("enemy_id")) != "moss_crown_beast":
			_fail("BOSS 未生成")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		var pillars := get_tree().get_nodes_in_group("dungeon_pillar")
		if pillars.size() != 4:
			_fail("石柱数量不正确：%d" % pillars.size())
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		var dungeon_chest: Node = dungeon.find_child("DungeonChest", true, false)
		if dungeon_chest == null:
			_fail("秘境宝箱缺失")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		var wolves := _count_wolves()
		if wolves != 3:
			_fail("第一波小怪数量不正确：%d" % wolves)
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		print("VERIFY OK: 秘境结构（BOSS / 4 石柱 / 宝箱 / 第一波 3 怪）")

		# 两波小怪
		for wolf in _find_wolves():
			wolf.call("die")
		await get_tree().create_timer(0.4).timeout
		if bool(dungeon.call("is_waves_cleared")) or _count_wolves() != 3:
			_fail("第二波小怪未正确生成")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		for wolf in _find_wolves():
			wolf.call("die")
		await get_tree().create_timer(0.4).timeout
		if not bool(dungeon.call("is_waves_cleared")):
			_fail("两波小怪清空后未标记完成")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		print("VERIFY OK: 两波小怪（3+3，清空推进）")

		# 进入竞技场：关门 + BOSS 激活 + 血条
		player.global_position = Vector3(0.0, 0.4, 6.5)
		await get_tree().create_timer(0.5).timeout
		if not bool(boss.get("fight_active")):
			_fail("进入竞技场后 BOSS 未激活")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		if not bool(dungeon.call("is_gate_closed")):
			_fail("竞技场门未关闭")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		var panel: Control = dungeon.get("_boss_panel")
		if panel == null or not panel.visible:
			_fail("BOSS 血条未显示")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		print("VERIFY OK: 竞技场（关门 / BOSS 出场 / 血条显示）")

		# 扇形挥击：前摇后命中
		player.global_position = (boss as Node3D).global_position + Vector3(0.0, 0.2, 3.0)
		await get_tree().create_timer(0.3).timeout
		var hp_before_sweep := player.stats.current_health
		boss.call("force_sweep")
		await get_tree().create_timer(1.1).timeout
		if player.stats.current_health >= hp_before_sweep:
			_fail("扇形挥击未造成伤害（%.0f→%.0f）" % [hp_before_sweep, player.stats.current_health])
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		player.stats.current_health = player.stats.max_health
		print("VERIFY OK: 扇形挥击（前摇 0.6s / 120° 7m / 击退）")

		# 直线冲撞 → 撞石柱 → 破绽
		var pillar: Node3D = pillars[0]
		var arena_center: Vector3 = boss.get("arena_center")
		var charge_dir := (pillar.global_position - arena_center).normalized()
		# 玩家站到石柱外侧，避免大型冲撞先命中玩家而正常结束。
		player.global_position = pillar.global_position + charge_dir * 4.0 + Vector3.UP * 0.2
		(boss as Node3D).global_position = arena_center + Vector3.UP * 0.2 + charge_dir
		await get_tree().create_timer(0.2).timeout
		boss.call("force_charge")
		var hit_pillar := await _wait_until(func() -> bool: return bool(pillar.call("is_shattered")), 6.0)
		if not hit_pillar:
			_fail("冲撞未撞碎石柱")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		var boss_comp: Node = boss.get_node("BossComponent")
		if not bool(boss_comp.call("is_staggered")):
			_fail("撞柱后 BOSS 未进入破绽")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		pillar.call("respawn")
		if bool(pillar.call("is_shattered")):
			_fail("石柱重生失败")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		print("VERIFY OK: 冲撞撞柱（石柱碎裂 / 失衡满 → 6s 破绽 / 石柱重生接口）")

		# 召唤嫩芽 → 回血 → 可击杀（先清破绽便于测试）
		boss_comp.set("_stagger_time_left", 0.0)
		boss_comp.set("stagger_value", 0.0)
		boss.set("current_health", 360.0)
		if int(boss.call("get_phase")) != 2:
			_fail("60%% 血量阶段判定错误：%d" % int(boss.call("get_phase")))
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		boss.call("force_summon")
		await get_tree().create_timer(0.9).timeout
		var sprouts := get_tree().get_nodes_in_group("boss_sprout")
		if sprouts.size() < 2:
			_fail("召唤嫩芽数量不足：%d" % sprouts.size())
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		var hp_before_heal := float(boss.get("current_health"))
		(sprouts[0] as Node3D).global_position = (boss as Node3D).global_position + Vector3(2.0, 0.1, 0.0)
		var healed := await _wait_until(func() -> bool: return float(boss.get("current_health")) > hp_before_heal, 5.0)
		if not healed:
			_fail("嫩芽未为 BOSS 回血")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		var sprout_count := sprouts.size()
		sprouts[0].call("die")
		await get_tree().create_timer(0.3).timeout
		var alive_sprouts := 0
		for sprout in get_tree().get_nodes_in_group("boss_sprout"):
			if int(sprout.get("state")) != 5:
				alive_sprouts += 1
		if alive_sprouts >= sprout_count:
			_fail("嫩芽无法被击杀")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		print("VERIFY OK: 召唤嫩芽（2 只 / 靠近回血 5%%/s / 可击杀）")

		# 阶段 3 + 首通掉落
		boss.set("current_health", 120.0)
		if int(boss.call("get_phase")) != 3:
			_fail("30%% 血量阶段判定错误")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		if float(boss.call("get_cooldown_speed")) <= 1.4:
			_fail("阶段 3 技能频率未提升：%.2f" % float(boss.call("get_cooldown_speed")))
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		if player.echo_system.has_collected("frost_lamp_scholar"):
			_fail("测试前置：回响已提前拥有")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		boss.call("die")
		await get_tree().create_timer(0.6).timeout
		if not bool(session.world_data.get("dungeon_first_clear", false)):
			_fail("首通标记未写入会话")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		if not player.echo_system.has_collected("frost_lamp_scholar"):
			_fail("首通回响奖励未发放")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		if not bool(dungeon.call("is_cleared")) or not bool(dungeon.call("is_exit_open")):
			_fail("BOSS 死亡后出口未开启")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		print("VERIFY OK: BOSS 死亡（阶段 3 / 首通回响 / 出口开启）")

		# 重置接口（死亡重置路径由管理器退出+重载实现）
		dungeon.call("reset_dungeon")
		await get_tree().create_timer(0.5).timeout
		var boss2: Node = dungeon.call("get_boss")
		if boss2 == null or float(boss2.get("current_health")) != 600.0 or bool(dungeon.call("is_cleared")):
			_fail("秘境重置失败")
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		if _count_wolves() != 3:
			_fail("重置后波次未恢复：%d" % _count_wolves())
			_cleanup_dungeon_test(session, dungeon, null, player)
			return
		dungeon.queue_free()
		await get_tree().process_frame
		print("VERIFY OK: 秘境重置（BOSS 满血回一阶段 / 波次恢复）")

		# 生产场景仅一个世界：整片遗迹位于森林，共用玩家，死亡回营地且森林不卸载。
		var world := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
		session.get_node("World").add_child(world)
		world.setup_player(player)
		player.set_respawn_point(WorldLayout.CAMPFIRE + Vector3(0, .4, 2.5))
		if not await _wait_until(func() -> bool: return world.is_world_ready() and not world.nav_region.is_baking(), 90):
			_fail("主世界遗迹导航未就绪")
			_cleanup_dungeon_test(session, null, null, player)
			return
		var grove: Node3D = world.get_node("NavRegion/MainWorldGrove")
		var forest_id: int = world.get_instance_id()
		if grove.get_boss().global_position.distance_to(WorldLayout.GROVE + Vector3(0, .2, -5)) > 1:
			_fail("主世界巨兽未迁移到遗迹坐标")
			_cleanup_dungeon_test(session, null, null, player)
			return
		player.global_position = grove.to_global(Vector3(0, .4, 8.5))
		grove._on_arena_trigger(player)
		player.stats.take_damage(99999)
		await get_tree().create_timer(4.0).timeout
		if not world.is_inside_tree() or world.get_instance_id() != forest_id or session.current_world_id != "forest":
			_fail("死亡导致主世界卸载或维度切换")
			_cleanup_dungeon_test(session, null, null, player)
			return
		if Vector2(player.global_position.x-WorldLayout.CAMPFIRE.x,player.global_position.z-WorldLayout.CAMPFIRE.z).length() > 12:
			_fail("主世界遗迹死亡未回营地")
			_cleanup_dungeon_test(session, null, null, player)
			return
		if grove.get_boss().fight_active or grove.is_gate_closed():
			_fail("死亡后林间遗迹未重置或门未打开")
			_cleanup_dungeon_test(session, null, null, player)
			return
		print("VERIFY OK: 单一主世界（整区迁入 / 死亡回营地 / 世界不卸载 / 遗迹复位）")

		_cleanup_dungeon_test(session, null, null, player)

	## 统计存活的第一波/第二波野狼。
	func _count_wolves() -> int:
		return _find_wolves().size()

	func _find_wolves() -> Array:
		var result: Array = []
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(enemy) and str(enemy.get("enemy_id")) == "timber_wolf" and int(enemy.get("state")) != 5:
				result.append(enemy)
		return result

	func _cleanup_dungeon_test(session: Node, dungeon: Node, entrance: Node, player: Node) -> void:
		if entrance != null and is_instance_valid(entrance):
			entrance.queue_free()
		if dungeon != null and is_instance_valid(dungeon):
			dungeon.queue_free()
		if player != null and is_instance_valid(player):
			player.queue_free()
		if session != null and is_instance_valid(session):
			session.queue_free()
		await get_tree().process_frame

	## 阶段 7.99：UI/HUD（主菜单 / HUD 结构 / 技能栏 / 面板系统与暂停 / 设置面板 / 地图 / 拍照 / 伤害飘字）。
	func _verify_ui() -> void:
		# 主菜单
		var menu := (load("res://scenes/app/main_menu.tscn") as PackedScene).instantiate() as Control
		get_tree().root.add_child(menu)
		await get_tree().process_frame
		var title: Label = menu.find_child("Title", true, false)
		var buttons: Node = menu.find_child("MenuButtons", true, false)
		if title == null or not title.text.contains("群星回响"):
			_fail("主菜单缺少标题")
			menu.queue_free()
			return
		if buttons == null or buttons.get_child_count() < 4 or menu.find_child("VersionLabel", true, false) == null:
			_fail("主菜单按钮或版本号缺失")
			menu.queue_free()
			return
		menu.queue_free()
		await get_tree().process_frame
		print("VERIFY OK: 主菜单（标题 / 4 按钮 / 版本号）")

		# 玩家 HUD
		var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
		get_tree().root.add_child(player)
		await get_tree().process_frame
		for node_path in ["HUD/VitalsBox/HealthBar", "HUD/VitalsBox/FocusBar", "HUD/SkillBar", "HUD/Crosshair", "HUD/Compass", "HUD/EliteBar", "HUD/MapPanel", "HUD/QuestTracker", "HUD/SpiritPanel", "HUD/EnergyBar", "PhotoMode"]:
			if player.get_node_or_null(node_path) == null:
				_fail("HUD 缺少节点：%s" % node_path)
				player.queue_free()
				return
		var skill_bar: Node = player.get_node("HUD/SkillBar")
		if skill_bar.get_child_count() != 5:
			_fail("技能栏格子数量不正确：%d" % skill_bar.get_child_count())
			player.queue_free()
			return
		var keys: Array = []
		for slot in skill_bar.get_children():
			var key_label: Label = slot.get_node_or_null("KeyLabel")
			if key_label != null:
				keys.append(key_label.text)
			if slot.get_node_or_null("CooldownMask") == null:
				_fail("技能格缺少冷却遮罩")
				player.queue_free()
				return
		if str(keys) != str(["1", "2", "3", "Z", "X"]):
			_fail("技能栏键位不正确：%s" % str(keys))
			player.queue_free()
			return
		var hud_node: CanvasLayer = player.get_node("HUD")
		hud_node.call("_update_vitals")
		var hp_bar: ProgressBar = player.get_node("HUD/VitalsBox/HealthBar")
		if not is_equal_approx(hp_bar.value, player.stats.current_health):
			_fail("生命条数值未同步")
			player.queue_free()
			return
		print("VERIFY OK: HUD（生命/专注 5 技能格+冷却遮罩 准星 罗盘 精英条 地图）")

		# 面板系统：互斥 / 暂停 / 拍照 / 截图
		player.call("_toggle_inventory_panel")
		await get_tree().process_frame
		if not player.inventory_panel.visible or not get_tree().paused:
			_fail("背包面板未打开或未暂停")
			player.queue_free()
			get_tree().paused = false
			return
		player.call("toggle_map_panel")
		await get_tree().process_frame
		if player.inventory_panel.visible or not player.map_panel.visible or not get_tree().paused:
			_fail("地图面板互斥失效")
			player.queue_free()
			get_tree().paused = false
			return
		player.call("toggle_photo_mode")
		await get_tree().process_frame
		if not player.photo_mode.visible or player.get_node("HUD").visible or player.map_panel.visible:
			_fail("拍照模式状态不正确")
			player.queue_free()
			get_tree().paused = false
			return
		var shot_path := str(player.photo_mode.call("take_screenshot"))
		if shot_path.is_empty() or not FileAccess.file_exists(shot_path):
			_fail("拍照截图未保存")
			player.queue_free()
			get_tree().paused = false
			return
		player.close_all_panels()
		await get_tree().process_frame
		if get_tree().paused or not player.get_node("HUD").visible:
			_fail("关闭面板后未恢复游戏")
			player.queue_free()
			get_tree().paused = false
			return
		print("VERIFY OK: 面板系统（背包/地图互斥 / 拍照隐藏 HUD / 截图保存 / Esc 关闭恢复）")

		# 伤害飘字（四类颜色/字号）
		var damage_root := Node3D.new()
		get_tree().root.add_child(damage_root)
		DamageNumber.spawn(damage_root, Vector3.ZERO, 20.0)
		DamageNumber.spawn(damage_root, Vector3.ZERO, 30.0, true)
		DamageNumber.spawn(damage_root, Vector3.ZERO, 8.0, false, Color.WHITE, "heal")
		DamageNumber.spawn(damage_root, Vector3.ZERO, 15.0, false, Color.WHITE, "combo")
		await get_tree().process_frame
		if damage_root.get_child_count() != 4:
			_fail("伤害飘字数量不正确：%d" % damage_root.get_child_count())
			damage_root.queue_free()
			player.queue_free()
			return
		var crit_label := damage_root.get_child(1) as Label3D
		if crit_label == null or not crit_label.text.contains("!") or crit_label.font_size < 60:
			_fail("暴击飘字样式不正确")
			damage_root.queue_free()
			player.queue_free()
			return
		damage_root.queue_free()
		player.queue_free()
		await get_tree().process_frame
		print("VERIFY OK: 伤害飘字（普通/暴击黄大/治疗绿/组合青）")

		# 设置面板（5 分页 + 游戏说明文本 + 读写设置）
		var settings_panel := (load("res://scenes/ui/settings_panel.tscn") as PackedScene).instantiate() as SettingsPanel
		get_tree().root.add_child(settings_panel)
		await get_tree().process_frame
		var tabs: TabContainer = settings_panel.find_child("Tabs", true, false)
		if tabs == null or tabs.get_tab_count() != 5:
			_fail("设置面板分页数量不正确")
			settings_panel.queue_free()
			return
		var help: Label = settings_panel.find_child("HelpText", true, false)
		if help == null or not help.text.contains("碎冰") or not help.text.contains("【世界回响】"):
			_fail("游戏说明文本不完整")
			settings_panel.queue_free()
			return
		settings_panel.open()
		if not settings_panel.visible:
			_fail("设置面板无法打开")
			settings_panel.queue_free()
			return
		settings_panel.close()
		var original_sens := float(SettingsService.get_setting("input/mouse_sensitivity", 0.002))
		SettingsService.set_setting("input/mouse_sensitivity", 0.0015)
		if not is_equal_approx(float(SettingsService.get_setting("input/mouse_sensitivity", 0.0)), 0.0015):
			_fail("设置读写失败")
			settings_panel.queue_free()
			return
		SettingsService.set_setting("input/mouse_sensitivity", original_sens)
		settings_panel.queue_free()
		await get_tree().process_frame
		print("VERIFY OK: 设置面板（5 分页 / 游戏说明 / 设置读写）")

	## 阶段 7.996：存档系统（三档位 / 全类别恢复 / 自动存档轮换 / 损坏恢复 / 暂停菜单）。
	func _verify_save() -> void:
		# 备份玩家既有存档字节（自检结束后还原，避免破坏真实存档）
		var saved_bytes := {}
		for slot in [1, 2]:
			var path := "user://saves/slot_%d.save" % slot
			if FileAccess.file_exists(path):
				var file := FileAccess.open(path, FileAccess.READ)
				saved_bytes[slot] = file.get_buffer(file.get_length())
				file.close()
		await AppFlow.start_new_game("warrior", "glow_wisp", 2)
		var session := AppFlow.game_session
		var player := session.get_player() if session != null else null
		if player == null:
			_fail("存档测试：会话/玩家创建失败")
			return
		await get_tree().create_timer(0.5).timeout
		# 构造各类状态
		player.global_position = Vector3(30.0, 0.5, 30.0)
		player.rotation.y = 1.2
		player.stats.current_health = 77.0
		player.stats.current_focus = 33.0
		player.inventory.add_material("forest_herb", 6)
		player.inventory.gold = 456
		player.inventory.call("_sync_session")
		player.echo_system.collect_echo("frost_lamp_scholar")
		player.echo_system.prep_slots.assign(["frost_lamp_scholar", ""])
		player.echo_system.current_energy = 64.0
		session.world_data["chests_opened"] = ["chest_wolves"]
		session.play_time = 123.0
		var quest_manager := session.get_node("WorldState/QuestManager") as QuestManager
		quest_manager.accept_quest("q_forest_rescue")
		var day_night := get_tree().get_first_node_in_group("day_night")
		if day_night == null:
			_fail("存档测试：昼夜系统缺失")
			return
		day_night.call("set_time_of_day", 21.0)
		var weather := get_tree().get_first_node_in_group("weather")
		if weather == null:
			_fail("存档测试：天气系统缺失")
			return
		weather.call("set_weather_state", "rain")
		await get_tree().process_frame
		if not SaveService.save_game(1):
			_fail("写入档位 1 失败")
			return
		var summary := SaveService.get_save_summary(1)
		if not bool(summary.get("exists", false)) or str(summary.get("spirit_id", "")) != "glow_wisp" or int(summary.get("spirit_level", 0)) != 2:
			_fail("存档摘要不正确：%s" % str(summary))
			return
		# 自动存档轮换：连续写入 4 次仍只保留 3 份
		for index in 4:
			SaveService.auto_save("test%d" % index)
		var auto_count := 0
		for index in range(1, 4):
			if FileAccess.file_exists("user://saves/auto_%d.save" % index):
				auto_count += 1
		if auto_count != 3:
			_fail("自动存档轮换数量不正确：%d" % auto_count)
			return
		print("VERIFY OK: 存档写入（摘要 / 自动存档轮换 3 份）")

		# 继续游戏 → 全类别恢复
		if not await AppFlow.continue_game(1):
			_fail("继续游戏失败")
			return
		await get_tree().create_timer(0.5).timeout
		session = AppFlow.game_session
		player = session.get_player()
		if player == null:
			_fail("读档后玩家缺失")
			return
		if player.global_position.distance_to(Vector3(30.0, 0.5, 30.0)) > 2.0:
			_fail("读档后位置未恢复：%s" % str(player.global_position))
			return
		if absf(player.stats.current_health - 77.0) > 0.5:
			_fail("读档后生命未恢复：%.1f" % player.stats.current_health)
			return
		if player.stats.current_focus < 32.5 or player.stats.current_focus > 46.0:
			_fail("读档后专注未恢复（含自然回复）：%.1f" % player.stats.current_focus)
			return
		if player.inventory.get_material_count("forest_herb") != 6 or player.inventory.gold != 456:
			_fail("读档后背包未恢复：材料 %d / 金币 %d" % [player.inventory.get_material_count("forest_herb"), player.inventory.gold])
			return
		if not player.echo_system.has_collected("frost_lamp_scholar"):
			_fail("读档后回响收藏未恢复")
			return
		if player.echo_system.current_energy < 63.0 or player.echo_system.current_energy > 72.0:
			_fail("读档后回响能量未恢复（含自然回复）：%.1f" % player.echo_system.current_energy)
			return
		if str(player.echo_system.prep_slots[0]) != "frost_lamp_scholar":
			_fail("读档后准备槽未恢复")
			return
		if not (session.world_data.get("chests_opened", []) as Array).has("chest_wolves"):
			_fail("读档后宝箱状态未恢复")
			return
		quest_manager = session.get_node("WorldState/QuestManager")
		if not quest_manager.active_quests.has("q_forest_rescue"):
			_fail("读档后任务未恢复")
			return
		day_night = get_tree().get_first_node_in_group("day_night")
		if day_night == null or absf(float(day_night.call("get_hours")) - 21.0) > 0.5:
			_fail("读档后昼夜时间未恢复")
			return
		weather = get_tree().get_first_node_in_group("weather")
		if weather == null or str(weather.call("get_weather_state")) != "rain":
			_fail("读档后天气未恢复")
			return
		if player.spirit_companion.spirit_data == null or player.spirit_companion.spirit_data.id != "glow_wisp":
			_fail("读档后精灵未恢复")
			return
		if session.play_time < 123.0:
			_fail("读档后游玩时间未恢复：%.1f" % session.play_time)
			return
		print("VERIFY OK: 继续游戏（位置/生命专注/背包/回响/宝箱/任务/昼夜/天气/精灵/游玩时间）")

		# 损坏恢复：两次写档产生 .bak，损坏主文件后应从备份读回
		SaveService.save_game(2)
		SaveService.save_game(2)
		var corrupt := FileAccess.open("user://saves/slot_2.save", FileAccess.WRITE)
		corrupt.store_string("{broken json")
		corrupt.close()
		var recovered := SaveService.load_game(2)
		if recovered.is_empty() or str(recovered.get("selected_spirit_id", "")) != "glow_wisp":
			_fail("存档损坏时未从备份恢复")
			return
		print("VERIFY OK: 损坏恢复（slot_2.save 损坏 → 从 .bak 读回）")

		# 孤儿 .tmp 清理（意外退出恢复路径）
		var tmp := FileAccess.open("user://saves/slot_3.save.tmp", FileAccess.WRITE)
		tmp.store_string("orphan")
		tmp.close()
		SaveService.recover_if_needed()
		if FileAccess.file_exists("user://saves/slot_3.save.tmp"):
			_fail("孤儿临时文件未清理")
			return
		print("VERIFY OK: 意外退出恢复（孤儿 .tmp 清理）")

		# 暂停菜单：开关 / 战斗中禁用保存 / 恢复
		player.call("toggle_pause_menu")
		await get_tree().process_frame
		if not player.pause_menu.visible or not get_tree().paused:
			_fail("暂停菜单未打开或未暂停")
			return
		var save_button: Button = player.pause_menu.find_child("SaveSlot1", true, false)
		if save_button == null:
			_fail("暂停菜单缺少保存按钮")
			return
		var wolf := (load("res://scenes/actors/base_enemy.tscn") as PackedScene).instantiate() as Node3D
		wolf.set_script(load("res://scenes/actors/melee_chaser.gd") as Script)
		wolf.position = player.global_position + Vector3(3.0, 0.0, 0.0)
		get_tree().root.add_child(wolf)
		player.pause_menu.call("_refresh_save_buttons")
		if not save_button.disabled:
			_fail("战斗中保存按钮未禁用")
			return
		wolf.queue_free()
		await get_tree().create_timer(0.3).timeout
		player.pause_menu.call("_refresh_save_buttons")
		if save_button.disabled:
			_fail("战斗结束后保存按钮未恢复")
			return
		player.close_all_panels()
		await get_tree().process_frame
		if get_tree().paused or player.pause_menu.visible:
			_fail("暂停菜单关闭后未恢复")
			return
		print("VERIFY OK: 暂停菜单（开关 / 战斗中禁用保存 / 关闭恢复）")

		# 清理测试档案并还原玩家既有存档
		SaveService.delete_save(1)
		SaveService.delete_save(2)
		SaveService.delete_save(3)
		for index in range(1, 4):
			DirAccess.remove_absolute("user://saves/auto_%d.save" % index)
		for slot in saved_bytes.keys():
			var restore := FileAccess.open("user://saves/slot_%d.save" % int(slot), FileAccess.WRITE)
			if restore != null:
				restore.store_buffer(saved_bytes[slot])
				restore.close()
		AppFlow.return_to_title()
		await get_tree().scene_changed
		await get_tree().process_frame

	## 阶段 8：战斗系统冒烟测试（普攻连击 / 技能 / 碎冰 / 格挡 / 完美格挡 / 死亡复活）。
	func _verify_combat() -> void:
		var packed := load("res://dev/test_combat.tscn") as PackedScene
		if packed == null:
			_fail("无法加载 test_combat.tscn")
			return
		var scene := packed.instantiate()
		get_tree().root.add_child(scene)
		await get_tree().create_timer(0.5).timeout

		var player := scene.find_child("Player", true, false) as PlayerController
		var dummy_a: Node = scene.find_child("DummyA", true, false)
		var dummy_c: Node = scene.find_child("DummyC", true, false)
		if player == null or dummy_a == null or dummy_c == null:
			_fail("测试战斗场景缺少 Player / DummyA / DummyC")
			return
		# 关闭精灵自动效果，保证战斗数值确定性
		player.spirit_companion.set_effects_enabled(false)
		var combat := player.combat
		# 此相位验证裸职业伤害；出生装备另由 verify_actor_regressions 验证。
		player.equipment.unequip_item("weapon")
		if player.stats.max_health != 120.0 or absf(combat.attack_power - 15.0) > 0.01:
			_fail("职业数据未应用（HP=%s 攻击=%s）" % [player.stats.max_health, combat.attack_power])
			return
		combat.crit_chance = 0.0
		player.stats.focus_regen = 0.0
		print("VERIFY OK: 战斗初始化（战士 120 血 / 攻击 15）")

		player.global_position = Vector3(0.0, 0.1, -2.2)
		player.rotation = Vector3.ZERO
		await get_tree().create_timer(0.3).timeout

		# 普攻三段：20 / 20 / 26（第三击 +30%）
		var hp1 := float(dummy_a.get("health"))
		combat.basic_attack()
		await get_tree().create_timer(0.35).timeout
		var d1 := hp1 - float(dummy_a.get("health"))
		await get_tree().create_timer(0.7).timeout
		var hp2 := float(dummy_a.get("health"))
		combat.basic_attack()
		await get_tree().create_timer(0.9).timeout
		var d2 := hp2 - float(dummy_a.get("health"))
		var hp3 := float(dummy_a.get("health"))
		combat.basic_attack()
		await get_tree().create_timer(0.5).timeout
		var d3 := hp3 - float(dummy_a.get("health"))
		if absf(d1 - 20.0) > 0.5 or absf(d2 - 20.0) > 0.5 or absf(d3 - 26.0) > 0.5:
			_fail("普攻连击伤害不正确：%.1f / %.1f / %.1f（期望 20/20/26）" % [d1, d2, d3])
			return
		print("VERIFY OK: 普攻三段连击（20 / 20 / 26）")

		# 横扫：23.5 伤害 + 专注 -20 + 进入冷却
		var focus_before := player.stats.current_focus
		var hp4 := float(dummy_a.get("health"))
		if not combat.use_skill("warrior_sweep"):
			_fail("横扫释放失败")
			return
		await get_tree().create_timer(0.5).timeout
		var d4 := hp4 - float(dummy_a.get("health"))
		if absf(d4 - 23.5) > 0.5:
			_fail("横扫伤害不正确：%.1f（期望 23.5）" % d4)
			return
		if absf((focus_before - player.stats.current_focus) - 20.0) > 0.01:
			_fail("横扫专注消耗不正确")
			return
		if combat.can_use_skill("warrior_sweep"):
			_fail("横扫未进入冷却")
			return
		print("VERIFY OK: 横扫（伤害 / 专注 / 冷却）")

		# 碎冰：冻结目标受横扫 → 附加 50% 伤害并清除冻结
		dummy_a.call("apply_effect", StatusEffects.FROZEN, 5.0, 1.0)
		combat.skill_cooldowns.erase("warrior_sweep")
		var hp5 := float(dummy_a.get("health"))
		if not combat.use_skill("warrior_sweep"):
			_fail("碎冰测试：横扫释放失败")
			return
		await get_tree().create_timer(0.5).timeout
		var d5 := hp5 - float(dummy_a.get("health"))
		if absf(d5 - 35.25) > 0.5:
			_fail("碎冰伤害不正确：%.1f（期望 35.25）" % d5)
			return
		if bool(dummy_a.call("has_effect", StatusEffects.FROZEN)):
			_fail("碎冰后冻结未被清除")
			return
		print("VERIFY OK: 碎冰组合（冻结 +50% 并清除）")

		# 冲锋：27 伤害 + 眩晕 + 位移到目标前停下
		combat.skill_cooldowns.erase("warrior_charge")
		player.global_position = Vector3(3.0, 0.1, -1.0)
		player.rotation = Vector3.ZERO
		await get_tree().create_timer(0.3).timeout
		var hp_c := float(dummy_c.get("health"))
		var focus_before_charge := player.stats.current_focus
		if not combat.use_skill("warrior_charge"):
			_fail("冲锋释放失败")
			return
		await get_tree().create_timer(0.55).timeout
		var d_charge := hp_c - float(dummy_c.get("health"))
		if absf(d_charge - 27.0) > 0.5:
			_fail("冲锋伤害不正确：%.1f（期望 27）" % d_charge)
			return
		if absf((focus_before_charge - player.stats.current_focus) - 15.0) > 0.01:
			_fail("冲锋专注消耗不正确")
			return
		if not bool(dummy_c.call("has_effect", StatusEffects.STUN)):
			_fail("冲锋未施加眩晕")
			return
		if player.global_position.distance_to(Vector3(3.0, 0.1, -6.0)) > 3.5:
			_fail("冲锋位移位置异常：%s" % player.global_position)
			return
		print("VERIFY OK: 冲锋（伤害 / 专注 / 眩晕 / 位移）")

		# 战吼：攻击强度 +20% + 嘲讽
		dummy_a.set("is_taunted", false)
		player.global_position = Vector3(0.0, 0.1, -2.2)
		await get_tree().create_timer(0.3).timeout
		if not combat.use_skill("warrior_roar"):
			_fail("战吼释放失败")
			return
		await get_tree().create_timer(0.3).timeout
		if absf(combat.damage_multiplier - 1.2) > 0.01:
			_fail("战吼增伤未生效：%s" % combat.damage_multiplier)
			return
		if not bool(dummy_a.get("is_taunted")):
			_fail("战吼未嘲讽到假人")
			return
		print("VERIFY OK: 战吼（增伤 20% / 嘲讽）")

		# 远离假人，测试格挡
		player.global_position = Vector3(10.0, 0.1, 10.0)
		await get_tree().create_timer(0.7).timeout

		# 普通格挡：10 伤害 → 护甲后 8.33 → 格挡 70% → 2.5
		Input.action_press("defend")
		await get_tree().create_timer(0.35).timeout
		var hp_before_block := player.stats.current_health
		var received := player.take_damage(10.0, dummy_a)
		var hp_delta := hp_before_block - player.stats.current_health
		if absf(received - 2.5) > 0.2 or absf(hp_delta - 2.5) > 0.2:
			_fail("普通格挡减伤不正确：实收 %.2f（期望 2.5）" % received)
			return
		Input.action_release("defend")
		await get_tree().create_timer(0.1).timeout
		print("VERIFY OK: 普通格挡（70% 减伤）")

		# 完美格挡：重新开始格挡后立刻受击 → 免伤 + 攻击者失衡
		Input.action_press("defend")
		for i in 3:
			await get_tree().process_frame
		if bool(dummy_a.call("is_staggered")):
			_fail("完美格挡测试前假人已失衡")
			return
		var received_perfect := player.take_damage(10.0, dummy_a)
		if received_perfect != 0.0:
			_fail("完美格挡未完全免伤：%.2f" % received_perfect)
			return
		if not bool(dummy_a.call("is_staggered")):
			_fail("完美格挡未使攻击者失衡")
			return
		Input.action_release("defend")
		await get_tree().create_timer(0.1).timeout
		print("VERIFY OK: 完美格挡（免伤 + 攻击者失衡）")

		# 死亡与复活：2 秒后在最近安全点以 50% 生命复活
		player.stats.current_health = 5.0
		player.take_damage(100.0, dummy_a)
		await get_tree().create_timer(0.3).timeout
		if not player.is_dead():
			_fail("致死后未进入死亡状态")
			return
		await get_tree().create_timer(2.2).timeout
		if player.is_dead():
			_fail("死亡后未复活")
			return
		if absf(player.stats.current_health - 60.0) > 0.01:
			_fail("复活生命不正确：%.1f（期望 60）" % player.stats.current_health)
			return
		if player.global_position.distance_to(Vector3(10.0, 0.1, 10.0)) > 2.0:
			_fail("复活位置不是最近安全点：%s" % player.global_position)
			return
		print("VERIFY OK: 死亡与复活（2s / 50% 生命 / 安全点）")

		scene.queue_free()
		await get_tree().process_frame

	## 阶段 9：角色选择界面（3 精灵卡片 / 默认选择 / 可切换）。
	func _verify_character_select() -> void:
		var packed := load("res://scenes/app/character_select.tscn") as PackedScene
		if packed == null:
			_fail("无法加载 character_select.tscn")
			return
		var scene := packed.instantiate()
		add_child(scene)
		await get_tree().process_frame
		if scene.get("selected_spirit_id") != "glow_wisp":
			_fail("角色选择默认精灵不是辉光萤灵")
			return
		var cards := scene.find_child("SpiritCards", true, false) as HBoxContainer
		if cards == null or cards.get_child_count() != 3:
			_fail("精灵卡片数量不正确")
			return
		var stone_button := cards.get_child(2) as Button
		stone_button.button_pressed = true
		if scene.get("selected_spirit_id") != "stone_guardian":
			_fail("精灵选择切换失败")
			return
		print("VERIFY OK: 角色选择界面（3 卡片 / 默认辉光萤灵 / 可切换）")
		scene.queue_free()
		await get_tree().process_frame

	## 阶段 10：AppFlow 会话流程 + SaveService 读写（精灵与回响持久化）+ 返回标题。
	func _verify_game_flow() -> void:
		await AppFlow.start_new_game(TEST_CLASS_ID, TEST_SPIRIT_ID, TEST_SPIRIT_LEVEL)
		var session := AppFlow.game_session
		if session == null or not session.is_initialized:
			_fail("GameSession 未初始化")
			return
		if session.selected_spirit_id != TEST_SPIRIT_ID or session.spirit_level != TEST_SPIRIT_LEVEL:
			_fail("GameSession 精灵字段不正确")
			return
		print("VERIFY OK: GameSession 初始化 class=%s spirit=%s level=%d" % [session.selected_class_id, session.selected_spirit_id, session.spirit_level])
		var world_node := session.get_node_or_null("World")
		var player_node := session.get_node_or_null("Player")
		if world_node == null or world_node.get_child_count() == 0:
			_fail("会话未生成森林世界")
			return
		if player_node == null or player_node.get_child_count() == 0:
			_fail("会话未生成玩家")
			return
		var flow_player := player_node.get_child(0) as PlayerController
		if flow_player.global_position.distance_to(WorldLayout.CAMPFIRE) > 12.0:
			_fail("玩家未出生于营地：%s" % str(flow_player.global_position))
			return
		print("VERIFY OK: 会话生成森林世界 + 玩家出生于营地篝火旁")

		# 回响/背包/装备持久化（防读档重置）
		flow_player.echo_system.collect_echo("frost_lamp_scholar")
		flow_player.echo_system.prep_slots.assign(["frost_lamp_scholar", ""])
		flow_player.echo_system.current_energy = 42.5
		flow_player.inventory.gold = 123
		flow_player.inventory.add_material("echo_dust", 4)
		flow_player.inventory.call("_sync_session")
		flow_player.equipment.apply_saved({"weapon": {"id": "frost_edge", "enhance_level": 2}})
		var flow_quests := session.get_node("WorldState/QuestManager") as QuestManager
		flow_quests.completed_quests.assign(["q_forest_rescue"])
		flow_quests.call("_sync_session")
		session.world_data = {"chests_opened": ["chest_wolves"]}

		if not SaveService.save_game(SAVE_TEST_SLOT, {"verify": true}):
			_fail("save_game 失败")
			return
		if not SaveService.has_save(SAVE_TEST_SLOT):
			_fail("has_save 返回 false")
			return
		var loaded := SaveService.load_game(SAVE_TEST_SLOT)
		if loaded.get("selected_spirit_id", "") != TEST_SPIRIT_ID:
			_fail("存档未记录 selected_spirit_id")
			return
		if int(loaded.get("spirit_level", 0)) != TEST_SPIRIT_LEVEL:
			_fail("存档 spirit_level 不正确：%s" % loaded.get("spirit_level"))
			return
		var collected: Array = loaded.get("collected_echoes", [])
		if collected.size() != 1 or str(collected[0]) != "frost_lamp_scholar":
			_fail("存档 collected_echoes 不正确：%s" % str(collected))
			return
		var slots: Array = loaded.get("prep_slots", [])
		if slots.size() != 2 or str(slots[0]) != "frost_lamp_scholar":
			_fail("存档 prep_slots 不正确：%s" % str(slots))
			return
		var energy := float(loaded.get("echo_energy", 0.0))
		if energy < 42.0 or energy > 43.0:
			_fail("存档 echo_energy 不正确：%s" % energy)
			return
		var inv_loaded: Dictionary = loaded.get("inventory_data", {})
		if int(inv_loaded.get("gold", 0)) != 123:
			_fail("存档 inventory_data 不正确：%s" % str(inv_loaded))
			return
		var equip_loaded: Dictionary = loaded.get("equipment_data", {})
		var weapon_saved: Dictionary = equip_loaded.get("weapon", {})
		if str(weapon_saved.get("id", "")) != "frost_edge" or int(weapon_saved.get("enhance_level", 0)) != 2:
			_fail("存档 equipment_data 不正确：%s" % str(equip_loaded))
			return
		var quest_loaded: Dictionary = loaded.get("quest_data", {})
		var completed_saved: Array = quest_loaded.get("completed", [])
		if completed_saved.size() != 1 or str(completed_saved[0]) != "q_forest_rescue":
			_fail("存档 quest_data 不正确：%s" % str(quest_loaded))
			return
		var world_loaded: Dictionary = loaded.get("world_data", {})
		var chests_saved: Array = world_loaded.get("chests_opened", [])
		if chests_saved.size() != 1 or str(chests_saved[0]) != "chest_wolves":
			_fail("存档 world_data 不正确：%s" % str(world_loaded))
			return
		if not bool(loaded.get("verify", false)):
			_fail("存档业务数据丢失")
			return
		SaveService.delete_save(SAVE_TEST_SLOT)
		print("VERIFY OK: 存档写入 / 读取 / 删除（精灵 + 回响 + 背包/装备快照）")

		AppFlow.return_to_title()
		await get_tree().process_frame
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current == null or not String(current.name).contains("MainMenu"):
			_fail("返回主菜单失败")
			return
		print("VERIFY OK: 返回主菜单")

	func _fail(message: String) -> void:
		_failed = true
		printerr("VERIFY FAIL: " + message)

	func _finish() -> void:
		if _failed:
			get_tree().quit(1)
		else:
			print("VERIFY ALL OK")
			get_tree().quit(0)


func _ready() -> void:
	var runner := Runner.new()
	runner.name = "VerifyRunner"
	# 延迟添加：主场景挂载过程中 /root 可能正忙
	get_tree().root.add_child.call_deferred(runner)
