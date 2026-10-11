extends Node3D
## 在真实森林验证猎人小屋资产、碰撞及日记和宝箱前方通路。
var checks: Array[String] = []
var errors: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks.append(label)
	if not ok:
		errors.append(label)
		push_error(label)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var forest := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
	add_child(forest)
	var elapsed := 0.0
	while (not forest.is_world_ready() or forest.nav_region.is_baking()) and elapsed < 40:
		await get_tree().create_timer(.2).timeout
		elapsed += .2
	check(forest.is_world_ready() and not forest.nav_region.is_baking(), "森林及导航就绪")
	var cabin := forest.find_child("HunterCabin", true, false) as Node3D
	check(cabin != null, "猎人小屋实例存在")
	if cabin == null:
		get_tree().quit(1)
		return
	for asset in ["CabinVisual", "FenceVisual", "BrokenWallVisual"]:
		var meshes := cabin.get_node(asset).find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() == 1, asset + "单网格资产")
		for node in meshes:
			var mesh: Mesh = node.mesh
			var arrays := mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_INDEX].size()/3 <= 5000, asset + "预算")
			check(arrays[Mesh.ARRAY_TEX_UV].size()>0 and arrays[Mesh.ARRAY_TANGENT].size()>0, asset + "UV及切线")
			var mat := node.get_active_material(0) as StandardMaterial3D
			for prop in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture"]:
				var tex := mat.get(prop) as Texture2D
				check(tex != null and tex.get_width()==1024 and tex.get_height()==1024, asset + " 1K " + prop)
	var body := cabin.get_node("CabinCollision")
	check(body.is_in_group("nav_source") and body.collision_layer==1, "建筑世界碰撞和导航源")
	var ray := PhysicsRayQueryParameters3D.create(cabin.global_position+Vector3(0,1.2,3),cabin.global_position+Vector3(0,1.2,0),1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider==body, "封闭小屋阻挡穿墙")
	var diary := forest.find_child("HunterDiary",true,false) as Node3D
	var chest := forest.find_child("ChestCabin",true,false) as Node3D
	check(diary != null and diary.get("item_id")=="hunter_diary", "猎人日记任务物品保留")
	check(chest != null and chest.get("chest_id")=="chest_cabin", "宝箱持久化ID保留")
	var area := forest.find_child("QuestAreaHunterCabin",true,false)
	check(area != null and area.get("area_id")=="hunter_cabin", "探索任务触发器保留")
	var terrain: TerrainBuilder
	for node in forest.find_children("*","Node3D",true,false):
		if node is TerrainBuilder: terrain=node
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=.3
	capsule.height=1.8
	query.shape=capsule
	query.collision_mask=1
	for target in [diary,chest]:
		var blocked := false
		for i in 10:
			var pos: Vector3=target.global_position+Vector3(0,0,3.5-i*.25)
			pos.y=terrain.surface_height_at(pos.x,pos.z)+1.04
			query.transform=Transform3D(Basis.IDENTITY,pos)
			if not get_world_3d().direct_space_state.intersect_shape(query).is_empty():blocked=true
		check(not blocked,target.name+"角色接近通路无障碍")
	if "--preview-cabin" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		add_child(camera)
		camera.position=cabin.global_position+Vector3(10,6.5,13)
		camera.look_at(cabin.global_position+Vector3(0,1.25,1))
		camera.fov=58
		camera.current=true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/scenery/hunter_cabin_in_forest.png")==OK,"森林实景截图")
	FileAccess.open("res://dev/art_work/hunter_cabin/godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"\t"))
	print("HUNTER_CABIN_VERIFY: ",checks.size()," checks; errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)
