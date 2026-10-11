extends Node3D
## 验证整片遗迹在森林内的实际坐标/导航，以及飞龙俯冲、火球、闪避、打断与近战窗口。
var checks := 0
var errors: Array[String] = []
class Target:
	extends CharacterBody3D
	var hits := 0
	var effects: Dictionary = {}
	var _is_dead := false
	func take_damage(_amount: float, _source: Node = null) -> void: hits += 1
	func apply_external_knockback(_dir: Vector3, _force: float) -> void: pass
	func apply_effect(id: String, duration: float, _power := 1.0) -> void: effects[id] = duration
	func add_camera_shake(_strength: float, _duration: float) -> void: pass
	func set_respawn_point(_point: Vector3) -> void: pass
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors.append(label); push_error(label)
func _ready() -> void: call_deferred("run")
func tick(dragon: Node, duration: float) -> void:
	for i in ceili(duration * 60):
		dragon._physics_process(1.0/60)
		await get_tree().physics_frame
func run() -> void:
	var forest := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
	add_child(forest)
	var elapsed := 0.0
	while (not forest.is_world_ready() or forest.nav_region.is_baking()) and elapsed < 100:
		await get_tree().create_timer(.2).timeout
		elapsed += .2
	check(elapsed < 100, "主世界导航完成")
	check(forest.find_children("*", "WorldEnvironment", true, false).size() == 1, "只有一个世界环境")
	check(forest.find_children("*", "NavigationRegion3D", true, false).size() == 1, "全区共用森林导航")
	check(forest.find_child("DungeonEntrance", true, false) == null, "主世界无维度传送入口")
	var session := (load("res://scenes/app/game_session.tscn") as PackedScene).instantiate()
	add_child(session)
	check(session.get_node_or_null("WorldState/DungeonManager") == null, "生产会话无维度管理器")
	var grove: Node3D = forest.get_node("NavRegion/MainWorldGrove")
	check(grove.global_position == WorldLayout.GROVE, "完整遗迹坐标")
	check(grove.get_boss() != null and grove.get_boss().global_position.distance_to(WorldLayout.GROVE+Vector3(0,0,-5)) < 1, "巨兽在主世界")
	check(grove._wave_enemies.size() == 3, "原第一波小怪保留")
	check(grove.find_child("DungeonChest",true,false) != null, "原奖励宝箱保留")
	for i in 4:
		var pillar: Node3D = grove.find_child("Pillar"+str(i+1),true,false)
		check(pillar != null and pillar.global_position.distance_to(WorldLayout.GROVE) < 24, "石柱迁移"+str(i))
	# 南门连续路径：营地北路到遗迹南门，路径必须跨入区域，而非悬空/分离导航。
	var from := WorldLayout.GROVE_ENTRANCE + Vector3(0,.2,8)
	var to := grove.to_global(Vector3(0,.2,20))
	var map: RID = forest.nav_region.get_navigation_map()
	var route := NavigationServer3D.map_get_path(map,from,to,true)
	check(route.size() >= 2 and route[-1].distance_to(to) < 2, "南门导航可直接步行进入")
	var space := get_world_3d().direct_space_state
	var door_ray := PhysicsRayQueryParameters3D.create(WorldLayout.GROVE_ENTRANCE+Vector3(0,1.5,8),WorldLayout.GROVE_ENTRANCE+Vector3(0,1.5,-8),1)
	check(space.intersect_ray(door_ray).is_empty(), "南门中线没有封闭墙")
	var beast = grove.get_boss()
	beast.set_physics_process(false)
	beast._do_summon()
	for sprout in get_tree().get_nodes_in_group("boss_sprout"):
		check(sprout.global_position.distance_to(WorldLayout.GROVE) < 25, "召唤嫩芽使用主世界坐标")
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	var dragon = forest.get_node("NavRegion/DreadWyvern")
	check(dragon._motion.player != null, "飞龙骨骼播放器")
	for clip in ["idle","fly","dive_windup","dive","recover","fire_windup","fire","hit","stagger","death","land"]:
		check(dragon._motion.clips.has(clip), "飞龙动作"+clip)
	var meshes: Array = dragon.visual.find_children("*","MeshInstance3D",true,false)
	check(not meshes.is_empty() and meshes[0].skin != null, "飞龙蒙皮")
	var triangles := 0
	for node in meshes:
		for surface in node.mesh.get_surface_count():
			var arrays = node.mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size()/3
			var mat = node.get_active_material(surface)
			for channel in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture"]:
				check(mat.get(channel) != null and mat.get(channel).get_width()==2048,"飞龙2K "+channel)
	check(triangles <= 10000, "飞龙面数预算")
	var target := Target.new()
	target.add_to_group("player")
	target.collision_layer = 2
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=.35
	capsule.height=1.8
	shape.shape=capsule
	shape.position.y=.9
	target.add_child(shape)
	add_child(target)
	var ground := Vector3(45,TerrainBuilder.height_at(45,-96),-96)
	target.global_position=ground+Vector3(0,.05,0)
	dragon.global_position=ground+Vector3(0,12,20)
	dragon.start_dive(target)
	await tick(dragon, .8)
	check(target.hits==0, "俯冲前摇无伤害")
	var locked: Vector3=dragon._locked_target
	target.global_position+=Vector3(12,0,0)
	await tick(dragon, .5)
	check(dragon._locked_target==locked,"俯冲落点锁定")
	await tick(dragon,1.2)
	check(target.hits==0,"离开俯冲落点可闪避")
	dragon.global_position=ground+Vector3(0,12,20)
	target.global_position=ground+Vector3(0,.05,0)
	target.hits=0
	dragon.start_dive(target)
	await tick(dragon,2.5)
	check(target.hits==1,"俯冲命中且只结算一次")
	check(dragon.flight_state==dragon.Flight.RECOVER,"俯冲结束收招")
	check(dragon.global_position.y-ground.y < 3,"俯冲后地面近战窗口")
	dragon.start_fireball(target)
	await tick(dragon,.8)
	check(get_tree().get_nodes_in_group("wyvern_fireball").is_empty(),"火球前摇不发弹")
	await tick(dragon,.4)
	check(get_tree().get_nodes_in_group("wyvern_fireball").size()==1,"每次吐火只发一颗")
	for ball in get_tree().get_nodes_in_group("wyvern_fireball"):ball.queue_free()
	await get_tree().physics_frame
	# 独立火球实际扫掠玩家并一次爆炸，随后灼烧；射线防止穿墙。
	target.hits=0
	WyvernFireball.spawn(self,target.global_position+Vector3(0,1,8),target.global_position+Vector3.UP,dragon,28)
	await get_tree().create_timer(.6).timeout
	check(target.hits==1,"实际火球碰撞单次伤害")
	check(target.effects.has("burning"),"火球附加灼烧")
	var wall := PropFactory.static_body(Vector3(5,5,.5),target.global_position+Vector3(0,2,4))
	add_child(wall)
	await get_tree().physics_frame
	target.hits=0
	WyvernFireball.spawn(self,target.global_position+Vector3(0,1,8),target.global_position+Vector3.UP,dragon,28)
	await get_tree().create_timer(.6).timeout
	check(target.hits==0,"火球被墙阻挡")
	wall.queue_free()
	dragon.start_dive(target)
	dragon.boss.add_stagger(100)
	await tick(dragon,.4)
	check(dragon._warning==null and dragon.flight_state==dragon.Flight.STAGGER,"失衡打断俯冲")
	check(target.hits==0,"失衡不结算残留攻击")
	dragon.boss._stagger_time_left=0
	target.global_position=WorldLayout.CAMP+Vector3(0,.1,0)
	dragon.flight_state=dragon.Flight.PATROL
	dragon._attack_cd=0
	await tick(dragon,.2)
	check(dragon.flight_state==dragon.Flight.PATROL,"营地不索敌")
	dragon.take_damage(1)
	check(dragon._motion.current=="hit", "飞龙受击骨骼反馈")
	# 正常AI自行循环两类招式，验证不是仅调试入口可用。
	target.global_position=ground+Vector3(0,.05,0)
	dragon.global_position=ground+Vector3(0,12,18)
	dragon._attack_cd=0
	dragon._next_dive=true
	var used: Array[String]=[]
	dragon.skill_used.connect(func(clip: String) -> void: used.append(clip))
	await tick(dragon,19)
	check(used.has("dive") and used.has("fireball") and used.has("fireball_released"), "正常AI交替俯冲和火球")
	for ball in get_tree().get_nodes_in_group("wyvern_fireball"):ball.queue_free()
	# 实际战士的近战查询命中落地飞龙，而非只靠逻辑距离模拟。
	target.remove_from_group("player")
	var warrior := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	add_child(warrior)
	dragon.global_position=ground+Vector3(0,.2,0)
	dragon.rotation.y=0
	warrior.global_position=ground+Vector3(0,.4,-5)
	warrior.rotation.y=PI
	warrior.camera.rotation.x=0
	warrior.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(warrior.combat._query_cone_targets(3,90).has(dragon.hit_area), "战士近战可命中地面飞龙")
	warrior.queue_free()
	await get_tree().physics_frame
	target.add_to_group("player")
	target.global_position=ground+Vector3(0,.05,0)
	dragon.global_position=ground+Vector3(0,8,0)
	dragon.take_damage(99999)
	check(dragon.state==BaseEnemy.State.DEAD and dragon._motion.current=="death", "骨骼死亡动作")
	await get_tree().physics_frame
	check(dragon.hit_area.collision_layer==0, "死亡禁用受击体")
	check(session.world_data.get("killed_elite",{}).get("dread_wyvern",false),"飞龙击杀进度写入会话")
	for drop in get_tree().get_nodes_in_group("loot_drop"):
		check(drop.global_position.y < ground.y+3,"飞龙掉落落在地面")
	for path in ["res://art/source/dread_wyvern.blend","res://art/previews/enemy/dread_wyvern.png","res://art/source/wyvern_fireball.blend"]:
		check(FileAccess.file_exists(path),"新资产独立归档")
	print("SINGLE_WORLD_WYVERN_VERIFY: ",checks," checks; errors=",errors)
	for child in get_children():child.queue_free()
	for frame in 4:await get_tree().process_frame
	get_tree().quit(0 if errors.is_empty() else 1)
