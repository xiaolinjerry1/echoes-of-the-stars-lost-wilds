extends Node3D
## 验证森林岩石GLB/PBR、真实MultiMesh挂接和既有大石障碍；可选截图。
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
	while (not forest.is_world_ready() or forest.nav_region.is_baking()) and elapsed<40:
		await get_tree().create_timer(.2).timeout
		elapsed+=.2
	check(forest.is_world_ready() and not forest.nav_region.is_baking(),"真实森林与导航加载完成")
	var terrain: TerrainBuilder
	for node in forest.find_children("*","Node3D",true,false):
		if node is TerrainBuilder:terrain=node
	check(terrain!=null,"森林地形实例存在")
	if terrain==null:
		get_tree().quit(1)
		return
	var rocks := terrain.get_node("RockMesh") as MultiMeshInstance3D
	var mesh := rocks.multimesh.mesh as ArrayMesh
	check(mesh!=null and mesh.get_surface_count()==1,"实际加载单网格岩石")
	check(rocks.material_override==null,"保留Blender材质")
	var arrays := mesh.surface_get_arrays(0)
	var triangles: int=arrays[Mesh.ARRAY_INDEX].size()/3
	check(triangles>300 and triangles<=5000,"岩石几何预算与新资产")
	check(arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),"完整UV")
	check(arrays[Mesh.ARRAY_TANGENT].size()>0,"PBR切线存在")
	var mat := mesh.surface_get_material(0) as StandardMaterial3D
	for prop in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture"]:
		var tex := mat.get(prop) as Texture2D
		check(tex!=null and tex.get_width()==1024 and tex.get_height()==1024,"1K "+prop)
	var bounds := mesh.get_aabb()
	check(absf(bounds.position.y)<.001 and bounds.size.y>1.0 and bounds.size.y<1.4,"底部原点与原岩石尺寸兼容")
	check(rocks.multimesh.instance_count>0,"森林批量岩石存在")
	var body := terrain.get_node("RockMeshObstacles") as StaticBody3D
	var large_count := 0
	var selected := Transform3D.IDENTITY
	var best := INF
	for i in rocks.multimesh.instance_count:
		var transform := rocks.multimesh.get_instance_transform(i)
		if transform.basis.get_scale().x>1.15:large_count+=1
		var distance := Vector2(transform.origin.x+60,transform.origin.z-45).length()
		if distance<best:
			best=distance
			selected=transform
	check(body.collision_layer==1 and body.is_in_group("nav_source"),"大石世界碰撞与导航源保持")
	check(body.get_child_count()==large_count,"保持原有大石障碍数量规则")
	if "--preview-rock" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		add_child(camera)
		camera.position=selected.origin+Vector3(3.0,2.25,3.9)
		camera.look_at(selected.origin+Vector3(0,.5,0))
		camera.fov=52
		camera.current=true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/scenery/rock_in_forest.png")==OK,"实际森林岩石截图")
	FileAccess.open("res://dev/art_work/rock/godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"instances":rocks.multimesh.instance_count,"large_colliders":large_count},"\t"))
	print("FOREST_ROCK_VERIFY: ",checks.size()," checks; errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)
