extends Node3D
## 验证营地三顶帐篷的Blender材质、尺寸与既有导航碰撞。
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
	var tents := forest.find_children("Tent?","Node3D",true,false)
	check(tents.size()==3,"三顶帐篷保留")
	var spots := [Vector3(-8,0,-6),Vector3(-7,0,10),Vector3(8,0,5)]
	for tent in tents:
		var index := int(String(tent.name).trim_prefix("Tent"))-1
		check(tent.position.is_equal_approx(WorldLayout.CAMP+spots[index]),"原摆放 "+tent.name)
		var meshes := tent.find_children("*","MeshInstance3D",true,false)
		check(meshes.size()==1,"实际单网格 "+tent.name)
		for node in meshes:
			var mesh: Mesh=node.mesh
			var bounds := mesh.get_aabb()
			check(bounds.size.x<=3 and bounds.size.z<=3 and bounds.size.y<=2 and absf(bounds.position.y)<.001,"模型位于既有碰撞范围")
			var a := mesh.surface_get_arrays(0)
			check(a[Mesh.ARRAY_INDEX].size()/3<=5000 and a[Mesh.ARRAY_TEX_UV].size()==a[Mesh.ARRAY_VERTEX].size(),"预算与UV")
			var mat := node.get_active_material(0) as StandardMaterial3D
			for prop in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture"]:
				var tex := mat.get(prop) as Texture2D
				check(tex!=null and tex.get_width()==1024 and tex.get_height()==1024,"1K "+prop)
		var bodies := tent.find_children("*","StaticBody3D",true,false)
		check(bodies.size()==1 and bodies[0].is_in_group("nav_source") and bodies[0].collision_layer==1,"导航障碍保留")
		var shape := bodies[0].get_child(0) as CollisionShape3D
		check((shape.shape as BoxShape3D).size.is_equal_approx(Vector3(3,2,3)),"原碰撞尺寸")
	if "--preview-tent" in OS.get_cmdline_user_args() and not tents.is_empty():
		var camera := Camera3D.new()
		add_child(camera)
		camera.position=tents[0].global_position+Vector3(3.5,2.5,4.5)
		camera.look_at(tents[0].global_position+Vector3(0,.9,0))
		camera.fov=48
		camera.current=true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/scenery/tent_in_camp.png")==OK,"营地实景截图")
	print("TENT_VERIFY: ",checks," checks; errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)
