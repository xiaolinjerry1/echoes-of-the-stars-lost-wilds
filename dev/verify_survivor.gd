extends Node3D
## 飞镖师实际场景回归：成长、连投归航、命中、分身、持久化和主世界残留检查。
var checks := 0
var errors: Array[String] = []
var session: GameSession
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	session=(load("res://scenes/app/game_session.tscn") as PackedScene).instantiate()
	add_child(session)
	AppFlow.game_session=session
	session.initialize("dart_master")
	await get_tree().create_timer(3.0).timeout
	for node in session.find_children("*","HordeDirector",true,false):node.enabled=false
	var p := session.get_player()
	var c := p.survivor
	check(p.survivor_mode,"新版玩家启用")
	check(p.equipment==null and p.inventory==null and p.spirit_companion==null and p.echo_system==null,"旧RPG组件已移除")
	check(p.fp_arms==null and p.camera_pivot.spring_length>3.0,"第三人称完整角色镜头")
	check(DataRegistry.get_all_classes().size()==1 and DataRegistry.get_all_items().is_empty() and DataRegistry.get_all_echoes().is_empty() and DataRegistry.get_all_spirits().is_empty(),"旧静态玩法不再注册")
	check(c.combat.darts.size()==6,"初始六飞镖")
	check(c.dart_count()==6 and is_equal_approx(c.orbit_radius(),2.2),"数量与半径基线")
	check(c.animator!=null,"全身骨骼动画存在")
	check(c.motion.tree!=null and c.motion.tree.active,"走跑连续混合启用")
	var skeleton := c.visual.find_child("Skeleton3D",true,false) as Skeleton3D
	check(skeleton!=null and skeleton.get_bone_count()>=48,"参考角色完整骨架")
	check(skeleton.find_bone("Scarf.04")>=0 and skeleton.find_bone("Finger4.R.02")>=0,"围巾链与独立手指")
	check(session.find_children("EchoStone","",true,false).is_empty() and session.find_children("Altar","",true,false).is_empty(),"回响建筑已从主世界移除")
	check(session.find_children("QuestManager","",true,false).is_empty(),"旧装备回响任务链已退出")
	check(session.find_children("MainWorldGrove","",true,false).size()==1,"巨兽遗迹保留")
	check(get_tree().get_nodes_in_group("enemy").any(func(e):return str(e.enemy_id)=="dread_wyvern"),"飞龙保留")
	check(p.is_on_floor(),"真实营地地面接触")
	var ground_y := p.global_position.y
	var key := InputEventKey.new()
	key.physical_keycode=KEY_SPACE;key.pressed=true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.22).timeout
	check(p.global_position.y-ground_y>0.9 and not p.is_on_floor(),"实际空格输入起跳且可明显离地")
	key=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=false;Input.parse_input_event(key)
	await get_tree().create_timer(0.8).timeout
	check(p.is_on_floor() and absf(p.global_position.y-ground_y)<0.15,"跳跃后稳定落地")
	var enemy := (load("res://scenes/actors/base_enemy.tscn") as PackedScene).instantiate() as BaseEnemy
	enemy.set_script(load("res://scenes/actors/melee_chaser.gd"))
	add_child(enemy)
	enemy.global_position=p.global_position+Vector3(2.2,0,0)
	enemy.max_health=10000;enemy.current_health=10000
	enemy.set_physics_process(false)
	var hp := enemy.current_health
	await get_tree().create_timer(0.8).timeout
	check(enemy.current_health<hp,"环绕接触实际掉血")
	check(c.echo_value>0.0,"接触命中积蓄回响")
	var orbit_count := c.combat.darts.size()
	check(c.combat.launch(Vector3.RIGHT),"左键齐射可发射")
	var entities := c.combat.darts.duplicate()
	check(c.combat.darts.size()==orbit_count,"连投保持同一组实体")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(get_tree().get_nodes_in_group("dart_projectile").size()==1,"第一枚先飞出，其余仍环绕")
	check(c.combat.launch_queue.size()==orbit_count-1,"逐枚发射队列")
	check(not c.combat.launch(Vector3.RIGHT),"齐射间隔防重复")
	await get_tree().create_timer(0.2).timeout
	check(enemy.current_health<hp,"实际环绕实体投出可命中")
	check(c.combat.darts==entities,"投掷没有复制或替换飞镖")
	check(c.combat.launch_queue.size()<orbit_count-1,"后续飞镖按节奏出手")
	await get_tree().create_timer(1.6).timeout
	check(not c.combat.busy() and get_tree().get_nodes_in_group("dart_projectile").is_empty(),"全部飞回归位")
	# 真正的墙体回收，升级不替换在途实体，移动时归航追踪新槽位。
	var target_pos := enemy.global_position
	enemy.global_position += Vector3(0,0,50)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new();box.size=Vector3(0.4,4.0,12.0)
	wall_shape.shape=box;wall.add_child(wall_shape);add_child(wall)
	wall.global_position=p.global_position+Vector3(5,1.5,0)
	await get_tree().physics_frame
	c.combat.cooldown=0.0
	check(c.combat.launch(Vector3.RIGHT),"墙体测试连投启动")
	var wall_x := wall.global_position.x
	var crossed := false
	for frame in 80:
		await get_tree().physics_frame
		for dart in c.combat.darts:
			if dart.global_position.x>wall_x+0.3:crossed=true
	check(not crossed and not c.combat.busy(),"扫掠撞墙后回归，不穿墙或消失")
	wall.queue_free();await get_tree().physics_frame
	c.combat.cooldown=0.0
	check(c.combat.launch(Vector3.FORWARD),"归航移动测试启动")
	await get_tree().create_timer(0.2).timeout
	c.ranks.count+=1;c.combat.rebuild()
	check(entities.all(func(d):return c.combat.darts.has(d)),"强化保留原有在途实体")
	check(c.combat.darts.size()==8,"强化仅补充新飞镖")
	for frame in 20:
		p.global_position.z+=0.06
		await get_tree().physics_frame
	await get_tree().create_timer(1.1).timeout
	check(not c.combat.busy(),"本体移动后飞镖仍全部归位")
	check(c.combat.darts.all(func(d):return absf(d.position.y-1.0)<0.01 and not d.top_level),"归位后恢复环绕局部坐标")
	c.ranks.count=0;c.combat.rebuild()
	enemy.global_position=target_pos
	c.combat.cooldown=0.0;c.combat.launch(Vector3.FORWARD)
	await get_tree().create_timer(0.15).timeout
	check(c.combat.busy(),"读档测试存在在途飞镖")
	c.load_save_data(c.get_save_data())
	check(not c.combat.busy() and c.combat.darts.all(func(d):return not d.top_level),"读档清理旧投掷并恢复环绕")
	c.echo_value=50
	check(not c.activate_ultimate(),"不足能量不能释放")
	c.echo_value=100
	check(c.activate_ultimate() and c.windup>0.0,"满能量结印前摇")
	check(c.clones.is_empty(),"前摇期间无提前分身")
	await get_tree().create_timer(0.7).timeout
	check(c.clones.size()==3,"三分身生成")
	check(c.ultimate_left>9.0 and c.ultimate_left<=10.0,"基础持续十秒")
	check(c.echo_value<100.0 and c.echo_value>80.0,"回响随持续时间消耗")
	check(not c.activate_ultimate(),"不能重复召唤")
	var clone := c.clones[0]
	check(clone.visual.scene_file_path==c.visual.scene_file_path and clone.visual.scale==c.visual.scale,"分身同形态体型")
	check(clone.combat.controller==c and clone.combat.darts.size()==c.dart_count(),"分身共享攻击成长")
	c.mark_target(enemy)
	check(clone.choose_target()==enemy,"分身优先本体攻击的目标")
	var clone_start := clone.global_position
	enemy.global_position = p.global_position + Vector3(10,0,0)
	await get_tree().create_timer(1.2).timeout
	check(clone.combat.volley_count>0,"分身自主齐射")
	check(clone.global_position.distance_to(clone_start)>0.05,"分身自主移动")
	c.end_ultimate()
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("shadow_clone").is_empty() and c.echo_value==0.0,"结束清空分身和回响")
	var damage := c.attack_damage()
	c.add_experience(p.stats.get_exp_to_next_level())
	check(p.stats.level==2 and c.pending_choices==1,"经验升级")
	check(c.attack_damage()>damage,"升级基础攻击自动成长")
	check(c.offered.size()==3 and c.offered[0]!=c.offered[1] and c.offered[1]!=c.offered[2] and c.offered[0]!=c.offered[2],"五种中随机三种不重复")
	check(get_tree().paused and c.hud.mode=="upgrade","升级暂停安全选择")
	var chosen: String=c.offered[0]
	check(c.choose_upgrade(chosen),"选择一次强化")
	check(int(c.ranks[chosen])==1 and not get_tree().paused,"选择生效并恢复游戏")
	check(not c.choose_upgrade(chosen),"选择不能重复领取")
	# Each branch changes the requested statistic and active clones rebuild immediately.
	for id in c.UPGRADE_IDS:
		c.pending_choices=1;c.offered=[id]
		var before := c.ranks.duplicate()
		check(c.choose_upgrade(id) and int(c.ranks[id])==int(before[id])+1,"强化分支 "+id)
	check(c.dart_count()>=8 and c.orbit_radius()>2.2,"数量强化扩大环绕半径")
	check(c.attack_interval()<0.75 and c.attack_damage()>20.0 and c.move_speed()>6.5 and c.ultimate_duration()>10.0,"攻速攻击移速大招强化")
	c.add_experience(p.stats.get_exp_to_next_level()*4)
	check(c.pending_choices>=2,"连续升级排队")
	var snapshot := session.collect_save_snapshot()
	check(snapshot.gameplay_mode=="survivor" and not snapshot.has("inventory_data") and not snapshot.has("collected_echoes"),"存档只保存新玩法")
	var saved := c.get_save_data()
	c.ranks.count=0
	c.load_save_data(saved)
	check(c.ranks==saved.ranks and c.offered==saved.offered and c.pending_choices==saved.pending_choices,"成长及待选项完整恢复")
	var test_path := "user://saves/survivor_regression_only_%d.save" % OS.get_process_id()
	check(SaveService._save_to_path(test_path,snapshot,true,"verify"),"新版存档实际写入")
	var disk: Dictionary=SaveService._load_from_path(test_path)
	check(disk.get("gameplay_mode","")=="survivor" and not disk.has("equipment_data") and not disk.has("echo_energy"),"读盘不复活旧机制")
	check(disk.get("survivor_data",{}).get("pending_choices",0)==saved.pending_choices,"排队选择经过JSON保存")
	p.stats.level=1;p.stats.exp=0;p.stats.current_health=3.0;c.ranks.damage=0
	session.apply_saved_payload(disk)
	check(p.stats.level==int(snapshot.player_data.level) and p.stats.exp==int(snapshot.player_data.exp) and p.stats.current_health==float(snapshot.player_data.health),"实际会话读档恢复等级经验生命")
	check(c.ranks==saved.ranks and c.pending_choices==saved.pending_choices,"实际会话恢复强化和选择")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(test_path+suffix):DirAccess.remove_absolute(test_path+suffix)
	while c.pending_choices>0:c.choose_upgrade(str(c.offered[0]))
	c.echo_value=100;c.activate_ultimate()
	await get_tree().create_timer(0.6).timeout
	c.ultimate_left=0.02
	await get_tree().create_timer(0.2).timeout
	check(c.clones.is_empty() and c.echo_value==0,"到时自动结束")
	# Automatic pickup rewards only once, no equipment drops.
	var xp_before := p.stats.exp
	ExperiencePickup.spawn(self,p.global_position+Vector3(0.2,0,0),3)
	await get_tree().create_timer(0.5).timeout
	check(p.stats.exp==xp_before+3,"经验结晶自动吸附")
	check(get_tree().get_nodes_in_group("loot_drop").is_empty(),"无装备掉落")
	# Actual dialogue interaction uses the new HUD, then returns control.
	p.start_dialogue("巡林者",["小心原野里的生物。"])
	check(p.dialogue_active and c.hud.dialogue_box.visible,"NPC对话接入")
	c.hud.dialogue_box.advance()
	check(not p.dialogue_active,"对话结束恢复控制")
	# Verify death cancels clones and respawns in the same world.
	c.echo_value=100;c.activate_ultimate()
	await get_tree().create_timer(0.6).timeout
	p.take_damage(10000.0,enemy)
	check(p.is_dead() and c.clones.is_empty() and c.echo_value==0,"死亡终止奥义")
	await get_tree().create_timer(2.3).timeout
	check(not p.is_dead() and p.stats.current_health==p.stats.max_health,"死亡营地复活")
	check(c.motion.tree.active,"复活恢复动画混合")
	# Horde spawns through the live navigation map and respects safe camp.
	var director: HordeDirector=session.find_children("*","HordeDirector",true,false)[0]
	p.global_position=WorldLayout.CAMP+Vector3(0,0,-36)
	p.global_position.y=TerrainBuilder.height_at(p.global_position.x,p.global_position.z)+0.1
	director.enabled=true;director.timer=0.0
	await get_tree().create_timer(0.4).timeout
	check(get_tree().get_nodes_in_group("horde_enemy").size()>0,"主世界持续刷怪")
	director.enabled=false
	var hunters := get_tree().get_nodes_in_group("horde_enemy")
	check(hunters.all(func(e): return e.detection_range>=32 and e.state!=BaseEnemy.State.PATROL),"刷怪立即索敌追击")
	check(hunters.all(func(e): return e.attack_power>=10 and e.max_health>=42),"敌人适度提升攻防")
	await verify_boss_feel(p,c)
	check(checks>=93,"BOSS回归流程完整执行")
	print("SURVIVOR_VERIFY ",JSON.stringify({"checks":checks,"errors":errors}))
	AppFlow.game_session=null
	get_tree().paused=false
	session.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if errors.is_empty() else 1)

func verify_boss_feel(p: PlayerController, c: DartMasterController) -> void:
	await get_tree().create_timer(1.4).timeout
	for enemy in get_tree().get_nodes_in_group("enemy"): enemy.set_physics_process(false)
	c.combat.set_physics_process(false)
	var beast: BaseEnemy=get_tree().get_first_node_in_group("moss_crown_beast")
	check(beast.max_health==780.0,"巨兽生命适度提升")
	var center: Vector3=beast.global_position
	p.global_position=center+Vector3(4,0,0)
	p.velocity=Vector3.ZERO
	p.stats.current_health=p.stats.max_health
	await get_tree().create_timer(0.25).timeout
	var hp := p.stats.current_health
	var ground := p.global_position.y
	var wave := BossGroundWave.spawn(beast,p.global_position-Vector3(3,0,0),0.0,9.0,24.0)
	var key := InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true;Input.parse_input_event(key)
	await get_tree().create_timer(0.3).timeout
	check(p.global_position.y-ground>0.9 and p.stats.current_health==hp,"真实跳跃避开行进震波")
	key=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=false;Input.parse_input_event(key)
	await get_tree().create_timer(0.9).timeout
	wave=BossGroundWave.spawn(beast,p.global_position-Vector3(3,0,0),0.0,9.0,24.0)
	await get_tree().create_timer(0.4).timeout
	check(p.stats.current_health<hp and wave.hit,"不跳跃被震波实际命中")
	var after := p.stats.current_health
	await get_tree().create_timer(0.5).timeout
	check(p.stats.current_health==after,"同一道震波不会重复伤害")
	beast.current_health=beast.max_health*0.5
	beast.fight_active=true
	beast._sweep_cd=999;beast._charge_cd=999;beast._summon_cd=999
	for id in beast._extra_cooldowns:beast._extra_cooldowns[id]=999
	beast.force_extra("stomp")
	beast.set_physics_process(true)
	p.global_position=center+Vector3(14,0,0)
	p.velocity=Vector3.ZERO
	await get_tree().create_timer(1.2).timeout
	check(get_tree().get_nodes_in_group("boss_hazard").size()>=2,"二阶段双层延迟震波")
	beast._interrupt_skill()
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("boss_hazard").is_empty(),"失衡中断清理残留危险区")
	beast.force_extra("roots")
	check(get_tree().get_nodes_in_group("boss_hazard").size()==3,"根须三个预警落点")
	await get_tree().create_timer(1.4).timeout
	check(p.has_effect("rooted"),"根须预警结束实际束缚")
	beast._interrupt_skill()
	var impacts: Array[String]=[]
	beast.skill_used.connect(func(skill):impacts.append(skill))
	beast.force_extra("slam")
	await get_tree().create_timer(3.05).timeout
	check(impacts.count("slam")==2,"二阶段重砸二连击各自前摇")
	check(not get_tree().get_nodes_in_group("combat_impact").is_empty(),"重砸实际播放Blender碎片反馈")
	beast._interrupt_skill()
	beast.set_physics_process(false)
