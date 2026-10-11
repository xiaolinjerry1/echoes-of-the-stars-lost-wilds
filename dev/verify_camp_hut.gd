extends Node3D
## 检查营地真实挂接、建筑碰撞和铁匠可达性；可选加载森林并截图，不读写存档。
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
	var hut := camp.get_node("Hut") as Node3D
	var visual := hut.get_node("HutVisual")
	var meshes := visual.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "营地用单网格GLB替代占位")
	var mesh := meshes[0] as MeshInstance3D
	check(mesh.mesh is ArrayMesh, "实际加载Blender网格")
	var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	for prop in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture"]:
		var tex := mat.get(prop) as Texture2D
		check(tex != null and tex.get_width() == 1024 and tex.get_height() == 1024, "1K " + prop)
	check(mesh.get_aabb().size.y > 4.5 and mesh.get_aabb().size.x < 5.8, "屋顶烟囱尺寸与营地比例")
	var body := hut.get_node("HutCollision") as StaticBody3D
	check(body.is_in_group("nav_source") and body.collision_layer == 1, "建筑保留世界碰撞及导航烘焙分组")
	var wall_query := PhysicsRayQueryParameters3D.create(hut.global_position+Vector3(0,1.2,3),hut.global_position+Vector3(0,1.2,0),1)
	var hit := get_world_3d().direct_space_state.intersect_ray(wall_query)
	check(not hit.is_empty() and hit.collider == body, "封闭门面不能穿墙")
	var glen: Node3D
	for npc in camp.find_children("*", "Node3D", true, false):
		if npc.get_script() == load("res://scenes/actors/npc.gd") and npc.get("npc_id") == "glen":
			glen = npc
	check(glen != null, "铁匠实例存在")
	if glen != null:
		var rel := hut.to_local(glen.global_position)
		check(absf(rel.x) > 2.65 or absf(rel.z) > 2.15, "铁匠与墙体留出角色半径")
		var approach := PhysicsRayQueryParameters3D.create(glen.global_position+Vector3(0,1,2.5),glen.global_position+Vector3(0,1,0),1)
		var approach_hit := get_world_3d().direct_space_state.intersect_ray(approach)
		check(not approach_hit.is_empty() and approach_hit.collider == glen, "铁匠正面交互路线无遮挡")
	if "--preview-hut" in OS.get_cmdline_user_args():
		camp.queue_free()
		await get_tree().process_frame
		var forest := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
		add_child(forest)
		var wait_time := 0.0
		while (not forest.is_world_ready() or forest.nav_region.is_baking()) and wait_time < 30:
			await get_tree().create_timer(.2).timeout
			wait_time += .2
		var camera := Camera3D.new()
		add_child(camera)
		var center := WorldLayout.CAMP+Vector3(11,0,-8)
		camera.position = center+Vector3(7.5,4.5,9.5)
		camera.look_at(center+Vector3(0,2,0))
		camera.fov = 60
		camera.current = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/scenery/hut_in_camp.png") == OK, "真实森林营地运行截图")
		forest.queue_free()
	else:
		camp.queue_free()
	await get_tree().process_frame
	FileAccess.open("res://dev/art_work/hut/godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"\t"))
	print("HUT_VERIFY: ",checks.size()," checks; errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)
