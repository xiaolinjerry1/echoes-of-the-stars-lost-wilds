extends Node3D
## 森林美术验证：贴图/UV/实例预算/高度碰撞/导航，并在真实世界中截图。
var errors: Array[String] = []
var checks: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks.append(label)
	if not ok:
		errors.append(label)
		push_error(label)
func _ready() -> void:
	call_deferred("run")
func check_material(mat: StandardMaterial3D, label: String) -> void:
	check(mat != null, label+"材质")
	if mat == null:
		return
	for prop in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture"]:
		var tex := mat.get(prop) as Texture2D
		check(tex != null and tex.get_width() == 1024 and tex.get_height() == 1024,label+" 1K "+prop)
func run() -> void:
	var forest := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
	add_child(forest)
	var elapsed := 0.0
	while (not forest.is_world_ready() or forest.nav_region.is_baking()) and elapsed < 40:
		await get_tree().create_timer(.2).timeout
		elapsed += .2
	check(forest.is_world_ready() and not forest.nav_region.is_baking(), "森林和导航加载完成")
	var terrain := forest.find_child("Terrain",true,false) as TerrainBuilder
	if terrain == null:
		for node in forest.find_children("*","Node3D",true,false):
			if node is TerrainBuilder:
				terrain=node
	check(terrain != null,"地形构建器存在")
	if terrain == null:
		get_tree().quit(1)
		return
	for name in ["TerrainMesh","RoadMesh"]:
		var visual := terrain.get_node(name) as MeshInstance3D
		check_material(visual.material_override as StandardMaterial3D,name)
		var arrays := visual.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		check(arrays[Mesh.ARRAY_NORMAL][0].y > .5,name+"法线朝上")
		print("SURFACE_DIAG ",name," normal=",arrays[Mesh.ARRAY_NORMAL][0]," alpha_mode=",(visual.material_override as StandardMaterial3D).transparency)
		check(uv.size()==vertices.size() and uv.size()>0,name+"完整UV")
		if name=="TerrainMesh":
			check(visual.is_in_group("nav_source") and vertices.size()==98304,"地形拓扑与导航源保留")
			check(uv[0].is_equal_approx(Vector2(vertices[0].x,vertices[0].z)/4.0),"草地按4米比例映射")
		else:
			var mat := visual.material_override as StandardMaterial3D
			check(mat.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA,BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS],"道路使用Blender渐变透明边缘")
			var min_u := 1.0
			var max_u := 0.0
			var min_gap := INF
			for coord in uv:
				min_u=minf(min_u,coord.x)
				max_u=maxf(max_u,coord.x)
			for i in range(0,vertices.size(),3):
				var center := (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
				min_gap=minf(min_gap,center.y-terrain.surface_height_at(center.x,center.z))
			check(is_zero_approx(min_u) and is_equal_approx(max_u,1),"道路横向UV覆盖软边贴图")
			check(min_gap>0.005,"道路三角形中心不穿地面")
			check(visual.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"道路贴层不投射悬浮阴影")
			print("ROAD_MIN_GAP ",min_gap)
	for name in ["ConiferMesh","BroadleafMesh","GroundGrass"]:
		var visual := terrain.get_node(name) as MultiMeshInstance3D
		check(visual.multimesh.instance_count>0,name+"批量实例存在")
		var mesh := visual.multimesh.mesh
		check_material(mesh.surface_get_material(0) as StandardMaterial3D,name)
		check(absf(mesh.get_aabb().position.y)<.001,name+"资产底部原点")
		if name=="GroundGrass":
			check(visual.multimesh.instance_count<=2200 and not visual.is_in_group("nav_source"),"草簇预算且不阻挡导航")
			var clear := true
			for i in visual.multimesh.instance_count:
				var pos := visual.multimesh.get_instance_transform(i).origin
				if WorldLayout.near_road(TerrainBuilder.road_samples(),pos.x,pos.z,2.7):clear=false
			check(clear,"草簇避开道路")
		else:
			var body := terrain.get_node(name+"Obstacles")
			check(body.get_child_count()==visual.multimesh.instance_count,name+"保留逐树障碍")
	var collision := terrain.get_node("TerrainBody") as StaticBody3D
	check((collision.get_child(0) as CollisionShape3D).shape is HeightMapShape3D,"保留高图碰撞")
	await get_tree().physics_frame
	for p in [Vector2(-78,84),Vector2(-34,30),Vector2(62,40)]:
		var h := TerrainBuilder.height_at(p.x,p.y)
		var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,h+5,p.y),Vector3(p.x,h-5,p.y),1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and absf(hit.position.y-h)<.2,"地面高度碰撞 "+str(p))
	var cycle := get_tree().get_first_node_in_group("day_night")
	var saved_hour: float=cycle.hours
	for hour in [8.0,12.0,17.0,0.0]:
		cycle.set_time_of_day(hour)
		var sun := cycle.get("_sun") as DirectionalLight3D
		var ray_direction := -sun.global_basis.z
		check(ray_direction.y < -.01 if hour>6 and hour<18 else ray_direction.y > .01,"太阳日夜方向 "+str(hour))
	cycle.set_time_of_day(saved_hour)
	if "--preview-forest" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		add_child(camera)
		camera.current=true
		camera.fov=65
		var views := [[Vector3(-74,2.5,-23),Vector3(-65,3,-42),"forest_path"],[Vector3(-49,10,30),Vector3(-63,2,-10),"forest_overview"]]
		for view in views:
			var at: Vector3=view[0]
			var target: Vector3=view[1]
			at.y+=TerrainBuilder.height_at(at.x,at.z)
			target.y+=TerrainBuilder.height_at(target.x,target.z)
			camera.position=at
			camera.look_at(target)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png("res://art/previews/scenery/"+view[2]+".png")==OK,"运行截图 "+view[2])
	FileAccess.open("res://dev/art_work/forest_surface/godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"\t"))
	print("FOREST_SURFACE_VERIFY: ",checks.size()," checks; errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)
