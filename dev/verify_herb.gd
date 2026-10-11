extends Node3D
## 验证草药全套材质、森林挂接、采集防重复和刷新；不写存档。
var errors: Array[String]=[]
var checks := 0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func _ready() -> void:call_deferred("run")
func run() -> void:
	var forest := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
	add_child(forest)
	var elapsed := 0.0
	while (not forest.is_world_ready() or forest.nav_region.is_baking()) and elapsed<40:
		await get_tree().create_timer(.2).timeout
		elapsed+=.2
	check(forest.is_world_ready() and not forest.nav_region.is_baking(),"森林导航就绪")
	var herbs := get_tree().get_nodes_in_group("gather_node")
	check(not herbs.is_empty(),"真实森林采集点存在")
	if herbs.is_empty():get_tree().quit(1);return
	var herb = herbs[0]
	check(herb.amount==1 and herb.material_id=="forest_herb" and herb.respawn_time==20,"原采集配置保持")
	check(not herb.visual.get_node("Stem").visible and not herb.visual.get_node("Leaves").visible,"隐藏旧占位")
	var found := false
	for node in herb.visual.find_children("*","MeshInstance3D",true,false):
		if not node.visible:continue
		found=true
		var mesh: Mesh=node.mesh
		var a := mesh.surface_get_arrays(0)
		check(a[Mesh.ARRAY_INDEX].size()/3<=5000,"道具预算")
		check(a[Mesh.ARRAY_TEX_UV].size()==a[Mesh.ARRAY_VERTEX].size() and a[Mesh.ARRAY_TANGENT].size()>0,"完整UV与切线")
		check(absf(mesh.get_aabb().position.y)<.001 and mesh.get_aabb().size.y<.81,"底部原点与碰撞高度兼容")
		var mat := node.get_active_material(0) as StandardMaterial3D
		for prop in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture"]:
			var tex := mat.get(prop) as Texture2D
			check(tex!=null and tex.get_width()==1024 and tex.get_height()==1024,"1K "+prop)
	check(found,"加载实际草药模型")
	var player := PlayerController.new()
	var inventory := Inventory.new()
	add_child(inventory)
	player.inventory=inventory
	herb.respawn_time=.2
	herb._on_interacted(player)
	herb._on_interacted(player)
	await get_tree().process_frame
	check(inventory.get_material_count("forest_herb")==1,"重复交互只发一次材料")
	check(not herb.visual.visible and herb.shape_node.disabled and herb.interactable.collision_layer==0,"采集后隐藏并禁用交互碰撞")
	await get_tree().create_timer(.3).timeout
	check(herb.visual.visible and not herb.shape_node.disabled and herb.interactable.collision_layer==16,"刷新恢复显示与交互")
	herb._on_interacted(player)
	check(inventory.get_material_count("forest_herb")==2,"刷新后可以再次采集")
	await get_tree().create_timer(.3).timeout
	herb.respawn_time=20
	player.free()
	if "--preview-herb" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		add_child(camera)
		camera.position=herb.global_position+Vector3(1.1,1.05,1.45)
		camera.look_at(herb.global_position+Vector3(0,.35,0))
		camera.fov=48
		camera.current=true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/prop/herb_in_forest.png")==OK,"真实森林截图")
	print("HERB_VERIFY: ",checks," checks; errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)
