extends Node3D
## 检查Blender溪流材质、河岸贴地、河床碎石与实际Area潮湿进入/刷新/离开。
class WetProbe extends CharacterBody3D:
	var effects: Array = []
	func apply_effect(id: String, duration: float, power: float) -> void:
		effects.append([id,duration,power])
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
	for i in 4:await get_tree().physics_frame
func run() -> void:
	var forest := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
	add_child(forest)
	var elapsed := 0.0
	while (not forest.is_world_ready() or forest.nav_region.is_baking()) and elapsed<40:
		await get_tree().create_timer(.2).timeout
		elapsed+=.2
	check(forest.is_world_ready() and not forest.nav_region.is_baking(),"森林导航就绪")
	var terrain: TerrainBuilder
	for node in forest.find_children("*","Node3D",true,false):
		if node is TerrainBuilder:terrain=node
	if terrain==null:
		get_tree().quit(1)
		return
	for name in ["CreekWater","CreekBank","RiverPebbles"]:
		var mesh: Mesh
		var mat: StandardMaterial3D
		var node := terrain.get_node(name)
		if node is MultiMeshInstance3D:
			mesh=node.multimesh.mesh
			mat=mesh.surface_get_material(0)
			check(node.multimesh.instance_count>0 and node.multimesh.instance_count<200,"河床碎石实例预算")
			check(not node.is_in_group("nav_source"),"碎石不阻挡导航")
		else:
			mesh=node.mesh
			mat=node.material_override
			var arrays := mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_NORMAL][0].y>.5,name+"法线朝上")
			check(arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),name+"完整UV")
			check(mat.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA,BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS],name+"Blender透明软边")
		for prop in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture"]:
			var tex := mat.get(prop) as Texture2D
			check(tex!=null and tex.get_width()==1024 and tex.get_height()==1024,name+" 1K "+prop)
	var water_mat := terrain.get_node("CreekWater").material_override as StandardMaterial3D
	check(water_mat.render_priority>terrain.get_node("CreekBank").material_override.render_priority,"水面在透明河岸之后绘制")
	var offset_before := water_mat.uv1_offset.y
	await get_tree().create_timer(.2).timeout
	check(not is_equal_approx(water_mat.uv1_offset.y,offset_before),"波纹沿河滚动")
	var min_depth := INF
	for sample in TerrainBuilder.creek_samples():
		var p: Vector2=sample.pos
		var water_y: float=sample.base_h-TerrainBuilder.CREEK_DEPTH+TerrainBuilder.WATER_OFFSET
		min_depth=minf(min_depth,water_y-terrain.surface_height_at(p.x,p.y))
	check(min_depth>.05,"上游到下游水面不埋入河床")
	var bank_mesh := terrain.get_node("CreekBank").mesh as ArrayMesh
	var bank_vertices: PackedVector3Array=bank_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var min_gap := INF
	for i in range(0,bank_vertices.size(),3):
		var center := (bank_vertices[i]+bank_vertices[i+1]+bank_vertices[i+2])/3.0
		min_gap=minf(min_gap,center.y-terrain.surface_height_at(center.x,center.z))
	check(min_gap>0,"河岸贴层不穿地")
	var zone := terrain.get_node("WaterZone") as Area3D
	check(zone.collision_layer==64 and zone.collision_mask==2 and zone.get_child_count()>10,"潮湿区物理配置")
	var probe := WetProbe.new()
	probe.collision_layer=2
	probe.collision_mask=0
	probe.add_to_group("player")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=.3
	capsule.height=1.8
	shape.shape=capsule
	shape.position.y=.9
	probe.add_child(shape)
	add_child(probe)
	probe.position=Vector3(30,TerrainBuilder.height_at(30,84),84)
	await frames()
	check(probe.effects.is_empty(),"干地不触发潮湿")
	var sample: Dictionary=TerrainBuilder.creek_samples()[16]
	var point: Vector2=sample.pos
	probe.position=Vector3(point.x,terrain.surface_height_at(point.x,point.y),point.y)
	await frames()
	check(not probe.effects.is_empty() and probe.effects[0]==["wet",6.0,1.0],"进入溪流施加6秒wet")
	var count := probe.effects.size()
	await get_tree().create_timer(2.2).timeout
	check(probe.effects.size()>count,"留在溪流持续刷新wet")
	probe.position=Vector3(30,TerrainBuilder.height_at(30,84),84)
	await frames()
	count=probe.effects.size()
	await get_tree().create_timer(2.2).timeout
	check(probe.effects.size()==count,"离开溪流停止刷新wet")
	probe.queue_free()
	if "--preview-creek" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		add_child(camera)
		camera.position=Vector3(18,TerrainBuilder.height_at(18,98)+4,98)
		camera.look_at(Vector3(18,TerrainBuilder.height_at(18,83)+.4,83))
		camera.fov=65
		camera.current=true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/scenery/creek_in_forest.png")==OK,"实际溪流截图")
	FileAccess.open("res://dev/art_work/creek_assets/godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"min_water_depth":min_depth,"min_bank_gap":min_gap},"\t"))
	print("CREEK_VERIFY: ",checks.size()," checks; errors=",errors," min depth=",min_depth," bank gap=",min_gap)
	get_tree().quit(0 if errors.is_empty() else 1)
