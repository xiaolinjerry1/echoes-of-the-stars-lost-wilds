extends Node3D
## 验证观测台Blender资产、碰撞对齐、回响碑台座和交互通路。
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
	check(forest.is_world_ready() and not forest.nav_region.is_baking(),"森林导航就绪")
	var obs := forest.find_child("Observatory",true,false) as Node3D
	check(obs!=null,"真实观测台存在")
	if obs==null:
		get_tree().quit(1)
		return
	for asset in ["Pillar0","BrokenPillar","FallenPillar","Altar","Wall0"]:
		var meshes := obs.get_node(asset).find_children("*","MeshInstance3D",true,false)
		check(meshes.size()==1,asset+"单网格")
		for node in meshes:
			var mesh: Mesh=node.mesh
			var arrays := mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_INDEX].size()/3<=5000,asset+"预算")
			check(arrays[Mesh.ARRAY_TEX_UV].size()>0 and arrays[Mesh.ARRAY_TANGENT].size()>0,asset+"UV及切线")
			var mat := node.get_active_material(0) as StandardMaterial3D
			for prop in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture"]:
				var tex := mat.get(prop) as Texture2D
				check(tex!=null and tex.get_width()==1024 and tex.get_height()==1024,asset+" 1K "+prop)
	for i in 6:
		var pillar := obs.get_node("Pillar%d" % i) as Node3D
		var body := obs.get_node("PillarBody%d" % i) as StaticBody3D
		var box: BoxShape3D=body.get_child(0).shape
		check(is_equal_approx(pillar.scale.y*3.6,box.size.y) and body.is_in_group("nav_source"),"柱%d高度与导航碰撞对齐" % i)
	var fallen := obs.get_node("FallenPillar") as Node3D
	var fallen_body := obs.get_node("FallenPillarBody") as Node3D
	check(is_equal_approx(fallen.rotation.y,fallen_body.rotation.y),"倒柱朝向与碰撞一致")
	var stone := forest.find_child("EchoStone",true,false) as Node3D
	check(stone!=null and stone.get("echo_id")=="frost_lamp_scholar","回响ID保留")
	check(is_equal_approx(stone.global_position.y-obs.global_position.y,.5),"回响碑底部与台座顶齐平")
	var area := forest.find_child("QuestAreaObservatory",true,false)
	check(area!=null and area.get("area_id")=="old_observatory","探索触发ID保留")
	var chest := forest.find_child("ChestObservatory",true,false) as Node3D
	check(chest!=null and chest.get("chest_id")=="chest_observatory","宝箱ID保留")
	var terrain: TerrainBuilder
	for node in forest.find_children("*","Node3D",true,false):
		if node is TerrainBuilder:terrain=node
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=.3
	capsule.height=1.8
	query.shape=capsule
	query.collision_mask=1
	var blocked: Array=[]
	for i in 29:
		var pos := obs.global_position+Vector3(0,0,9-i*.25)
		pos.y=terrain.surface_height_at(pos.x,pos.z)+1.04
		query.transform=Transform3D(Basis.IDENTITY,pos)
		if not get_world_3d().direct_space_state.intersect_shape(query).is_empty():blocked.append(i)
	check(blocked.is_empty(),"角色可从柱环南侧接近回响碑 "+str(blocked))
	var interaction := PhysicsRayQueryParameters3D.create(obs.global_position+Vector3(0,1.6,2),obs.global_position+Vector3(0,1.6,0),16)
	interaction.collide_with_areas=true
	interaction.collide_with_bodies=false
	var interaction_hit := get_world_3d().direct_space_state.intersect_ray(interaction)
	check(not interaction_hit.is_empty() and interaction_hit.collider==stone.get_node("Interactable"),"台座外可射线选中回响碑交互区")
	var ray := PhysicsRayQueryParameters3D.create(obs.global_position+Vector3(.9,2,0),obs.global_position+Vector3(.9,.3,0),1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and absf(hit.position.y-obs.global_position.y-.5)<.02,"台座顶面实际碰撞")
	if "--preview-observatory" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		add_child(camera)
		camera.position=obs.global_position+Vector3(0,12,15)
		camera.look_at(obs.global_position+Vector3(0,1.2,0))
		camera.fov=70
		camera.current=true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/scenery/observatory_in_forest.png")==OK,"森林实景截图")
	FileAccess.open("res://dev/art_work/stone_pillar/godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"\t"))
	print("OBSERVATORY_VERIFY: ",checks.size()," checks; errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)
