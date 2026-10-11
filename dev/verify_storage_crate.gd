extends Node3D
## 验证仓储木箱的真实资产、碰撞和可交互射线；可选加载森林截图，不读写存档。
var errors: Array[String] = []
var checks: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks.append(label)
	if not ok:
		errors.append(label)
		push_error(label)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var camp := (load("res://scenes/world/camp.tscn") as PackedScene).instantiate()
	add_child(camp)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var storage := camp.get_node("Storage") as Node3D
	var meshes := storage.get_node("StorageVisual").find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "仓储木箱使用单网格GLB")
	if meshes.size() != 1:
		get_tree().quit(1)
		return
	var mesh := meshes[0] as MeshInstance3D
	check(mesh.mesh is ArrayMesh, "Blender网格替代占位")
	var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	for prop in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture"]:
		var tex := mat.get(prop) as Texture2D
		check(tex != null and tex.get_width() == 1024 and tex.get_height() == 1024, "1K " + prop)
	var bounds := mesh.get_aabb()
	check(bounds.size.x < 1.2 and bounds.size.y > .9 and bounds.size.y < 1.0 and absf(bounds.position.y) < .001, "木箱比例与底部原点")
	var body := storage.get_node("StorageCollision") as StaticBody3D
	check(body.collision_layer == 1 and body.is_in_group("nav_source"), "实体碰撞参与导航烘焙")
	var space := get_world_3d().direct_space_state
	var origin := storage.global_position
	var solid_ray := PhysicsRayQueryParameters3D.create(origin+Vector3(0,.5,2), origin+Vector3(0,.5,0), 1)
	var hit := space.intersect_ray(solid_ray)
	check(not hit.is_empty() and hit.collider == body, "箱体阻挡穿行")
	var area := storage.get_node("Interactable") as Interactable
	check(area.interact_text == "打开仓库" and area.interacted.is_connected(camp._on_storage_interacted), "保留仓库交互及信号")
	var interact_ray := PhysicsRayQueryParameters3D.create(origin+Vector3(0,1.3,2), origin+Vector3(0,.5,0), 17)
	interact_ray.collide_with_areas = true
	hit = space.intersect_ray(interact_ray)
	check(not hit.is_empty() and hit.collider == area, "交互射线先命中触发区")
	if "--preview-crate" in OS.get_cmdline_user_args():
		camp.queue_free()
		await get_tree().process_frame
		var forest := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
		add_child(forest)
		var wait_time := 0.0
		while (not forest.is_world_ready() or forest.nav_region.is_baking()) and wait_time < 30:
			await get_tree().create_timer(.2).timeout
			wait_time += .2
		check(forest.is_world_ready() and not forest.nav_region.is_baking(), "真实森林加载与导航烘焙完成")
		var camera := Camera3D.new()
		add_child(camera)
		camera.position = origin+Vector3(1.85,1.5,2.5)
		camera.look_at(origin+Vector3(0,.45,0))
		camera.fov = 50
		camera.current = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/prop/storage_crate_in_camp.png") == OK, "营地实际运行截图")
		forest.queue_free()
	else:
		camp.queue_free()
	await get_tree().process_frame
	FileAccess.open("res://dev/art_work/storage_crate/godot_validation.json", FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"\t"))
	print("STORAGE_CRATE_VERIFY: ", checks.size(), " checks; errors=", errors)
	get_tree().quit(0 if errors.is_empty() else 1)
