extends Node3D
## 验证锻造台的真实资产、碰撞和可交互射线；可选加载森林截图，不读写存档。
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
	var forge := camp.get_node("Forge") as Node3D
	var meshes := forge.get_node("ForgeVisual").find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "锻造台使用单网格GLB")
	if meshes.size() != 1:
		get_tree().quit(1)
		return
	var mesh := meshes[0] as MeshInstance3D
	check(mesh.mesh is ArrayMesh, "Blender网格替代占位")
	var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	for prop in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture"]:
		var tex := mat.get(prop) as Texture2D
		check(tex != null and tex.get_width() == 1024 and tex.get_height() == 1024, "1K " + prop)
	check(mat.emission_enabled and mat.emission_texture != null and mat.emission_texture.get_width() == 1024, "炭火自发光来自Blender贴图")
	var bounds := mesh.get_aabb()
	check(bounds.size.x < 3.3 and bounds.size.y > 2.6 and bounds.size.y < 2.8 and absf(bounds.position.y) < .001, "锻造台比例与底部原点")
	var body := forge.get_node("AnvilCollision") as StaticBody3D
	check(body.collision_layer == 1 and body.is_in_group("nav_source"), "实体碰撞参与导航烘焙")
	var space := get_world_3d().direct_space_state
	var origin := forge.global_position
	var solid_ray := PhysicsRayQueryParameters3D.create(origin+Vector3(0,.5,2), origin+Vector3(0,.5,0), 1)
	var hit := space.intersect_ray(solid_ray)
	check(not hit.is_empty() and hit.collider == body, "铁砧阻挡穿行")
	var area := forge.get_node("Interactable") as Interactable
	check(area.interact_text == "锻造台（强化装备）" and area.interacted.is_connected(camp._on_forge_interacted), "保留锻造交互及信号")
	var interact_ray := PhysicsRayQueryParameters3D.create(origin+Vector3(0,1.3,2), origin+Vector3(0,.5,0), 17)
	interact_ray.collide_with_areas = true
	hit = space.intersect_ray(interact_ray)
	check(not hit.is_empty() and hit.collider == area, "交互射线先命中触发区")
	var hearth := forge.get_node("HearthCollision") as StaticBody3D
	var hearth_ray := PhysicsRayQueryParameters3D.create(origin+Vector3(1.6,1,3), origin+Vector3(1.6,1,0), 1)
	hit = space.intersect_ray(hearth_ray)
	check(not hit.is_empty() and hit.collider == hearth and hearth.is_in_group("nav_source"), "炉体实体碰撞与导航分组")
	var hut_body := camp.get_node("Hut/HutCollision") as StaticBody3D
	var hut_shape := hut_body.get_child(0) as CollisionShape3D
	var hearth_shape := hearth.get_child(0) as CollisionShape3D
	var hut_size := (hut_shape.shape as BoxShape3D).size
	var hearth_size := (hearth_shape.shape as BoxShape3D).size
	check(not AABB(hut_body.global_position-hut_size/2, hut_size).intersects(AABB(hearth.global_position-hearth_size/2, hearth_size)), "炉体与小屋不再交叠")
	var glen := camp.get_node("NpcGlen") as StaticBody3D
	var npc_ray := PhysicsRayQueryParameters3D.create(glen.global_position+Vector3(0,1,2), glen.global_position+Vector3(0,1,0), 1)
	hit = space.intersect_ray(npc_ray)
	check(not hit.is_empty() and hit.collider == glen, "铁匠正面可以接近")
	if "--preview-forge" in OS.get_cmdline_user_args():
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
		camera.position = origin+Vector3(-3.2,2.8,4.5)
		camera.look_at(origin+Vector3(.8,1.1,0))
		camera.fov = 50
		camera.current = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/prop/camp_forge_in_camp.png") == OK, "营地实际运行截图")
		forest.queue_free()
	else:
		camp.queue_free()
	await get_tree().process_frame
	FileAccess.open("res://dev/art_work/camp_forge/godot_validation.json", FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"\t"))
	print("CAMP_FORGE_VERIFY: ", checks.size(), " checks; errors=", errors)
	get_tree().quit(0 if errors.is_empty() else 1)

