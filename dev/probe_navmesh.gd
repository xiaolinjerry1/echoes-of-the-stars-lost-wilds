extends Node
## 探测森林导航网格高度与地形高度的偏差，定位野狼卡住原因。

func _ready() -> void:
	call_deferred("_run")


func _wait_until(condition: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if condition.call():
			return true
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	return false


func _run() -> void:
	var session := (load("res://scenes/app/game_session.tscn") as PackedScene).instantiate() as GameSession
	get_tree().root.add_child(session)
	await get_tree().process_frame
	var world := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(world)
	var streamer := world.get_node("NavRegion/Streamer") as WorldStreamer
	if not await _wait_until(func() -> bool: return streamer.is_world_ready(), 60.0):
		print("NAV_PROBE 世界未就绪")
		get_tree().quit(1)
		return
	await get_tree().create_timer(1.0).timeout
	var region := world.get_node("NavRegion") as NavigationRegion3D
	var map := region.get_navigation_map()
	print("NAV_PROBE map_valid=", map.is_valid(), " region_enabled=", region.enabled)
	for z in [30, 35, 40, 44, 48, 53, 58]:
		for x in [54, 58, 62, 64, 68, 72]:
			var terrain := TerrainBuilder.height_at(x, z)
			var closest := NavigationServer3D.map_get_closest_point(map, Vector3(x, terrain + 3.0, z))
			var horizontal := Vector2(closest.x - x, closest.z - z).length()
			print("NAV_PROBE x=%d z=%d terrain=%.3f nav_y=%.3f nav_dy=%.3f nav_dxz=%.3f" % [
				x, z, terrain, closest.y, closest.y - terrain, horizontal,
			])
	var mesh := region.navigation_mesh
	var vertices := mesh.get_vertices()
	var near_count := 0
	var y_min := INF
	var y_max := -INF
	for vertex in vertices:
		if Vector2(vertex.x - 64.0, vertex.z - 44.0).length() < 8.0:
			near_count += 1
			y_min = minf(y_min, vertex.y)
			y_max = maxf(y_max, vertex.y)
	print("NAV_PROBE 顶点数=%d 狼附近顶点=%d y范围=[%.3f, %.3f] 地形=%.3f" % [
		vertices.size(), near_count, y_min, y_max, TerrainBuilder.height_at(64.0, 44.0),
	])
	print("NAV_PROBE 营地附近 nav=(%.3f, %.3f) 地形=%.3f" % [
		NavigationServer3D.map_get_closest_point(map, WorldLayout.CAMPFIRE + Vector3(0, 3, 0)).y,
		NavigationServer3D.map_get_closest_point(map, WorldLayout.CAMPFIRE + Vector3(0, 3, 0)).z,
		TerrainBuilder.height_at(WorldLayout.CAMPFIRE.x, WorldLayout.CAMPFIRE.z),
	])
	get_tree().quit(0)
