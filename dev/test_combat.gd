extends Node3D
## 开发用战斗测试场（仅 dev/test_combat.tscn）
## 职责：提供测试假人环境与快捷操作——
## K = 冻结全部假人（碎冰测试），L = 清除冻结；
## 7 / 8 / 9 = 切换精灵；J = 模拟范围伤害击退精灵；
## H = 施加潮湿（电弧测试），N = 施加标记（弱点测试），G = 对最近假人打出电弧测试。


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or (event as InputEventKey).echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_K:
			_apply_to_all(StatusEffects.FROZEN, 8.0, 1.0)
			print("[TestCombat] 已冻结所有假人（8s）")
		KEY_L:
			for dummy in get_tree().get_nodes_in_group("test_dummy"):
				dummy.call("remove_effect", StatusEffects.FROZEN)
			print("[TestCombat] 已清除冻结")
		KEY_H:
			_apply_to_all(StatusEffects.WET, 8.0, 1.0)
			print("[TestCombat] 已施加潮湿（测试电弧扩散）")
		KEY_N:
			_apply_to_all(StatusEffects.MARKED, 8.0, 1.0)
			print("[TestCombat] 已施加标记（测试弱点暴击）")
		KEY_7:
			_switch_spirit("glow_wisp")
		KEY_8:
			_switch_spirit("flame_crystal")
		KEY_9:
			_switch_spirit("stone_guardian")
		KEY_J:
			_knock_spirit()
		KEY_G:
			_arc_test()


func _apply_to_all(effect_id: String, duration: float, power: float) -> void:
	for dummy in get_tree().get_nodes_in_group("test_dummy"):
		dummy.call("apply_effect", effect_id, duration, power)


func _switch_spirit(spirit_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player == null or player.spirit_companion == null:
		return
	player.spirit_companion.initialize(spirit_id)
	print("[TestCombat] 已切换精灵：%s" % spirit_id)


func _knock_spirit() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player == null or player.spirit_companion == null:
		return
	player.spirit_companion.knock_back(player.global_position + Vector3(0.0, 0.0, -3.0))
	print("[TestCombat] 模拟范围伤害：击退精灵")


## 电弧测试：用代码构造 lightning 标签技能，对最近假人打出一次并触发连招检测。
func _arc_test() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player == null:
		return
	var targets := TargetQuery.find_targets(player, 20.0, true)
	if targets.is_empty():
		print("[TestCombat] 电弧测试：附近没有目标")
		return
	var dummy: Node = targets[0]
	var skill := SkillData.new()
	skill.id = "dev_lightning"
	skill.display_name = "测试电弧"
	skill.combat_tags.assign(["lightning"])
	var result := ComboSystem.apply_on_hit(skill, dummy, 10.0, player)
	if dummy.has_method("take_damage"):
		dummy.call("take_damage", float(result["damage"]))
	print("[TestCombat] 电弧测试：组合=%s" % str(result["combos"]))
