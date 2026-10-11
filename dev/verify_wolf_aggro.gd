extends Node
## 复现玩家实际环境：在森林世界里验证野狼是否自动索敌、接近并攻击玩家，并诊断卡住原因。

var errors: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	errors.append(message)
	push_error("WOLF_AGGRO: " + message)


func _wait_until(condition: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if condition.call():
			return true
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	return false


func _terrain_gap(pos: Vector3) -> float:
	return pos.y - TerrainBuilder.height_at(pos.x, pos.z)


func _dump_wolf(wolf: BaseEnemy, label: String) -> void:
	var path := wolf.nav_agent.get_current_navigation_path()
	var first_points: Array = []
	for i in mini(3, path.size()):
		first_points.append(str(path[i].snapped(Vector3(0.01, 0.01, 0.01))))
	print("WOLF_DIAG %s pos=%s gap=%.3f on_floor=%s floor_normal=%s state=%s vel=%s nav_ready=%s finished=%s path=%s first=%s" % [
		label,
		str(wolf.global_position.snapped(Vector3(0.01, 0.01, 0.01))),
		_terrain_gap(wolf.global_position),
		str(wolf.is_on_floor()),
		str(wolf.get_floor_normal().snapped(Vector3(0.01, 0.01, 0.01))),
		BaseEnemy.State.keys()[wolf.state],
		str(wolf.velocity.snapped(Vector3(0.01, 0.01, 0.01))),
		str(wolf._is_navigation_ready()),
		str(wolf.nav_agent.is_navigation_finished()),
		str(path.size()),
		", ".join(first_points),
	])
	for i in wolf.get_slide_collision_count():
		var collision := wolf.get_slide_collision(i)
		var collider := collision.get_collider()
		print("WOLF_DIAG_COLLISION %s #%d collider=%s layer=%s normal=%s depth=%.3f" % [
			label,
			i,
			collider.name if collider != null else "null",
			str(collider.collision_layer) if collider != null else "?",
			str(collision.get_normal().snapped(Vector3(0.01, 0.01, 0.01))),
			collision.get_depth(),
		])


func _run() -> void:
	var session := (load("res://scenes/app/game_session.tscn") as PackedScene).instantiate() as GameSession
	get_tree().root.add_child(session)
	await get_tree().process_frame
	var world := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(world)
	var streamer := world.get_node("NavRegion/Streamer") as WorldStreamer
	if not await _wait_until(func() -> bool: return streamer.is_world_ready(), 60.0):
		_fail("世界未就绪")
		_finish()
		return
	var region := world.get_node("NavRegion") as NavigationRegion3D
	var bake_start := Time.get_ticks_msec()
	if not await _wait_until(func() -> bool: return region.navigation_mesh.get_polygon_count() > 0, 180.0):
		_fail("导航网格未烘焙完成")
		_finish()
		return
	print("WOLF_AGGRO 导航烘焙 %.1fs 多边形=%d" % [
		(Time.get_ticks_msec() - bake_start) / 1000.0,
		region.navigation_mesh.get_polygon_count(),
	])
	await get_tree().create_timer(1.0).timeout
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	get_tree().root.add_child(player)
	player.spirit_companion.set_effects_enabled(false)
	var wolves: Array = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if String(enemy.get("enemy_id")) == "timber_wolf":
			wolves.append(enemy)
	if wolves.is_empty():
		_fail("森林中没有野狼")
		_finish()
		return
	print("WOLF_AGGRO 野狼数量=", wolves.size())
	for i in wolves.size():
		var w: BaseEnemy = wolves[i]
		print("WOLF_AGGRO 狼%d pos=%s gap=%.3f on_floor=%s" % [i, str(w.global_position.snapped(Vector3(0.1, 0.1, 0.1))), _terrain_gap(w.global_position), str(w.is_on_floor())])
	var wolf: BaseEnemy = wolves[0]
	var wolf_start := wolf.global_position
	var terrain_y := TerrainBuilder.height_at(wolf_start.x, wolf_start.z)
	var nav_point := NavigationServer3D.map_get_closest_point(region.get_navigation_map(), Vector3(wolf_start.x, terrain_y + 2.0, wolf_start.z))
	print("WOLF_AGGRO 导航面 dy=%.3f dxz=%.3f" % [
		nav_point.y - terrain_y,
		Vector2(nav_point.x - wolf_start.x, nav_point.z - wolf_start.z).length(),
	])
	var player_pos := Vector3(wolf_start.x, 0.0, wolf_start.z + 10.0)
	player_pos.y = TerrainBuilder.height_at(player_pos.x, player_pos.z) + 0.2
	player.global_position = player_pos
	player.stats.current_health = player.stats.max_health
	var hp_before := player.stats.current_health
	print("WOLF_AGGRO 初始距离=%.2f" % wolf_start.distance_to(player_pos))
	for i in 20:
		await get_tree().create_timer(0.5).timeout
		print("WOLF_AGGRO t=%.1f state=%s dist=%.2f pos=%s vel=%s hp=%.1f" % [
			(i + 1) * 0.5,
			BaseEnemy.State.keys()[wolf.state],
			wolf.global_position.distance_to(player.global_position),
			str(wolf.global_position.snapped(Vector3(0.001, 0.001, 0.001))),
			str(wolf.velocity.snapped(Vector3(0.01, 0.01, 0.01))),
			player.stats.current_health,
		])
	_dump_wolf(wolf, "原地")
	if wolf.state == BaseEnemy.State.PATROL:
		_fail("野狼未进入战斗（一直是 PATROL）")
	elif player.stats.current_health >= hp_before:
		_fail("野狼未造成攻击伤害")
	elif wolf.global_position.distance_to(wolf_start) < 1.0:
		_fail("野狼进入战斗但未接近玩家（位移 %.2f）" % wolf.global_position.distance_to(wolf_start))
	else:
		print("WOLF_AGGRO OK: 野狼自动接近并攻击")
	_finish()


func _finish() -> void:
	print("WOLF_AGGRO_RESULT ", errors)
	get_tree().quit(0 if errors.is_empty() else 1)
