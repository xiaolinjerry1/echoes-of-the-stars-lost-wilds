extends Node3D
## 验证宝箱贴图、真实盖转轴、开盖和会话恢复；不写玩家存档。
var errors: Array[String]=[]
var checks := 0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func _ready() -> void:call_deferred("run")
func run() -> void:
	var session := GameSession.new()
	session.add_to_group("game_session")
	# Use a plain session data object without running world setup or autosave.
	add_child(session)
	session.set_process(false)
	var chest := (load("res://scenes/world/chest.tscn") as PackedScene).instantiate()
	chest.chest_id="art_verify_only"
	add_child(chest)
	check(chest._lid!=null and chest._lid.name=="Lid","真实GLB盖节点")
	check(chest._lid.position.is_equal_approx(Vector3(0,.49,-.30)),"盖转轴在后缘")
	var meshes := chest.get_node("Visual").find_children("*","MeshInstance3D",true,false)
	check(meshes.size()==2,"箱体和盖分离")
	var tris := 0
	for node in meshes:
		var mesh: Mesh=node.mesh
		var arrays := mesh.surface_get_arrays(0)
		tris+=arrays[Mesh.ARRAY_INDEX].size()/3
		check(arrays[Mesh.ARRAY_TEX_UV].size()>0 and arrays[Mesh.ARRAY_TANGENT].size()>0,"UV与切线")
		var mat := node.get_active_material(0) as StandardMaterial3D
		for prop in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture"]:
			var tex := mat.get(prop) as Texture2D
			check(tex!=null and tex.get_width()==1024 and tex.get_height()==1024,"1K "+prop)
	check(tris<=5000,"道具面数预算")
	var point_closed: Vector3=chest._lid.to_global(Vector3(0,.05,.60))
	chest._play_open_animation()
	await get_tree().create_timer(.7).timeout
	check(is_equal_approx(chest._lid.rotation.x,deg_to_rad(-105)),"开盖角度")
	check(chest._lid.to_global(Vector3(0,.05,.60)).y>point_closed.y+.3,"盖前缘向上开启")
	chest._record_opened()
	chest._record_opened()
	check(session.world_data.get("chests_opened",[]).count("art_verify_only")==1,"开启记录无重复")
	chest._lid.rotation.x=0
	chest.apply_saved_state()
	check(chest.is_chest_opened() and is_equal_approx(chest._lid.rotation.x,deg_to_rad(-105)),"存档状态恢复开盖")
	if "--preview-chest" in OS.get_cmdline_user_args():
		var second := (load("res://scenes/world/chest.tscn") as PackedScene).instantiate()
		second.chest_id="art_closed"
		add_child(second)
		second.position.x=1.4
		var light := DirectionalLight3D.new()
		add_child(light)
		light.rotation_degrees=Vector3(-45,-30,0)
		light.light_energy=1.2
		var env := WorldEnvironment.new()
		env.environment=Environment.new()
		env.environment.background_mode=Environment.BG_COLOR
		env.environment.background_color=Color(.12,.16,.21)
		env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color=Color(.65,.75,.9)
		env.environment.ambient_light_energy=.7
		add_child(env)
		var camera := Camera3D.new()
		add_child(camera)
		camera.position=Vector3(2.5,2.2,4)
		camera.look_at(Vector3(.7,.4,0))
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=3.5
		camera.current=true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/prop/chest_in_game.png")==OK,"游戏内开闭截图")
	print("CHEST_VERIFY: ",checks," checks; errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)
