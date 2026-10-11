extends Node3D
## 在真实森林验证瀑布材质、水潭、入口通行及潮湿触发，可选实景截图。
class WetProbe extends CharacterBody3D:
	var effects: Array = []
	func apply_effect(id: String, duration: float, power: float) -> void:
		effects.append([id, duration, power])
var checks: Array[String] = []
var errors: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks.append(label)
	if not ok:
		errors.append(label)
		push_error(label)
func _ready() -> void:
	call_deferred("run")
func frames() -> void:
	for i in 4: await get_tree().physics_frame
func run() -> void:
	var forest := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
	add_child(forest)
	var elapsed := 0.0
	while (not forest.is_world_ready() or forest.nav_region.is_baking()) and elapsed < 40:
		await get_tree().create_timer(.2).timeout
		elapsed += .2
	check(forest.is_world_ready() and not forest.nav_region.is_baking(), "森林导航就绪")
	var waterfall := forest.find_child("Waterfall", true, false)
	var terrain: TerrainBuilder
	for node in forest.find_children("*", "Node3D", true, false):
		if node is TerrainBuilder: terrain = node
	check(waterfall != null and terrain != null, "真实场景挂接")
	if waterfall == null or terrain == null:
		get_tree().quit(1)
		return
	for asset in ["Cliff", "Curtain", "Pond"]:
		var root := waterfall.get_node(asset)
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() == 1, asset + "单网格GLB")
		for node in meshes:
			var mesh: Mesh = node.mesh
			var arrays := mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_INDEX].size() / 3 <= 5000, asset + "面数预算")
			check(arrays[Mesh.ARRAY_TEX_UV].size() > 0 and arrays[Mesh.ARRAY_TANGENT].size() > 0, asset + "UV与切线")
			var mat := node.get_active_material(0) as StandardMaterial3D
			for prop in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture"]:
				var tex := mat.get(prop) as Texture2D
				check(tex != null and tex.get_width() == 1024 and tex.get_height() == 1024, asset + " 1K " + prop)
			if asset != "Cliff":
				check(mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED, asset + "透明材质")
	var flow: StandardMaterial3D = waterfall._flow_materials[0]
	var before := flow.uv1_offset.y
	await get_tree().create_timer(.2).timeout
	check(not is_equal_approx(before, flow.uv1_offset.y), "水幕流动播放")
	var water_y := TerrainBuilder.pond_water_height()
	check(is_equal_approx(waterfall.get_node("Pond").global_position.y, water_y), "潭水与溪流同水位")
	var depth := water_y - terrain.surface_height_at(18, 56.4)
	check(depth > .4 and depth < .9, "浅潭底低于水面")
	# Use a player-sized capsule against world collisions along the actual entrance route.
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .3
	capsule.height = 1.8
	query.shape = capsule
	query.collision_mask = 1
	var blocked: Array = []
	for i in 33:
		var z := 55.6 - i * .25
		query.transform = Transform3D(Basis.IDENTITY, Vector3(18, terrain.surface_height_at(18,z) + 1.03, z))
		if not get_world_3d().direct_space_state.intersect_shape(query).is_empty(): blocked.append(z)
	check(blocked.is_empty(), "1.8米角色从潭水到秘境入口通道畅通 " + str(blocked))
	var entrance := get_tree().get_first_node_in_group("dungeon_entrance")
	check(entrance != null and entrance.required_quest == "q_frost_trial", "秘境任务门槛保留")
	check(entrance.dungeon_scene_path == "res://scenes/dungeons/forest_grove_dungeon.tscn", "秘境目的地保留")
	var probe := WetProbe.new()
	probe.collision_layer = 2
	probe.collision_mask = 0
	probe.add_to_group("player")
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = .9
	probe.add_child(shape)
	add_child(probe)
	probe.position = Vector3(30, 2, 56)
	await frames()
	check(probe.effects.is_empty(), "干地无潮湿")
	probe.position = Vector3(18, terrain.surface_height_at(18,54), 54)
	await frames()
	check(not probe.effects.is_empty() and probe.effects[0] == ["wet",6.0,1.0], "入潭施加wet")
	var count := probe.effects.size()
	await get_tree().create_timer(2.2).timeout
	check(probe.effects.size() > count, "潭内刷新wet")
	probe.position = Vector3(30,2,56)
	await frames()
	count = probe.effects.size()
	await get_tree().create_timer(2.2).timeout
	check(probe.effects.size() == count, "离潭停止刷新")
	probe.queue_free()
	if "--preview-waterfall" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		add_child(camera)
		camera.position = Vector3(27,6,71)
		camera.look_at(Vector3(18,1.7,51))
		camera.fov = 57
		camera.current = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/scenery/waterfall_in_forest.png") == OK, "实景截图")
	FileAccess.open("res://dev/art_work/waterfall_cliff/godot_validation.json", FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors}, "\t"))
	print("WATERFALL_VERIFY: ", checks.size(), " checks; errors=", errors)
	get_tree().quit(0 if errors.is_empty() else 1)
