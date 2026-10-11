extends "res://dev/verify_humanoid_cast.gd"
## 验证独立祭司、召唤动作、图腾完整材质及治疗/破坏/到期逻辑。
func run() -> void:
	var target := Node3D.new()
	add_child(target)
	target.position=Vector3(0,0,-11)
	var shaman := enemy("res://scenes/actors/support.gd",Vector3.ZERO) as SupportCaster
	shaman._target=target
	check(shaman.model_path.ends_with("forest_shaman.glb"),"祭司独立模型")
	check(shaman._clips.size()==11 and shaman._clips.has(&"summon"),"11动作含独立召唤")
	var skeletons := shaman.visual.find_children("*","Skeleton3D",true,false)
	check(skeletons.size()==1 and skeletons[0].get_bone_count()==22,"祭司22骨")
	for node in shaman.visual.find_children("*","MeshInstance3D",true,false):
		if node.skin==null:continue
		var arrays: Array=node.mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_INDEX].size()/3<10000 and arrays[Mesh.ARRAY_WEIGHTS].size()>0,"祭司预算与蒙皮")
		verify_material(node.get_active_material(0),2048,"祭司")
	var ally := enemy("res://scenes/actors/ranged_caster.gd",Vector3(3,0,0))
	ally.current_health=10
	shaman._update_state(0)
	shaman._state_time=.59
	shaman._update_cast()
	shaman._update_skeletal_animation(0)
	check(shaman._visual_clip==&"summon" and get_tree().get_nodes_in_group("heal_totem").is_empty(),"0.6秒前召唤蓄力不生成图腾")
	shaman._state_time=.6
	shaman._update_cast()
	shaman._update_skeletal_animation(0)
	check(is_equal_approx(shaman._animation_player.current_animation_position,.8),"召唤动作命中点对齐")
	var totems := get_tree().get_nodes_in_group("heal_totem")
	check(totems.size()==1,"单次召唤图腾")
	var totem := totems[0] as HealTotem
	totem.set_process(false)
	shaman._state_time=.9
	shaman._update_cast()
	check(get_tree().get_nodes_in_group("heal_totem").size()==1,"收招不重复召唤")
	for node in totem.visual.find_children("*","MeshInstance3D",true,false):
		verify_material(node.get_active_material(0),1024,"图腾")
		var mat := node.get_active_material(0) as StandardMaterial3D
		check(mat.emission_enabled and mat.emission_texture!=null,"Blender图腾发光贴图")
	var before := ally.current_health
	totem._heal_pulse()
	check(is_equal_approx(ally.current_health,before+ally.max_health*.05),"6米内每次治疗5%")
	ally.position.x=7
	before=ally.current_health
	totem._heal_pulse()
	check(is_equal_approx(ally.current_health,before),"范围外不治疗")
	totem.take_damage(20)
	check(totem.is_queued_for_deletion(),"20伤害破坏图腾")
	await get_tree().process_frame
	shaman._state_time=1.21
	shaman._update_cast()
	check(shaman.state==BaseEnemy.State.CHASE and not shaman._summoning_totem,"收招后清理召唤状态")
	shaman._enter_state(BaseEnemy.State.ATTACK)
	shaman._summoning_totem=true
	shaman._state_time=.3
	shaman._update_skeletal_animation(0)
	var pose_time := shaman._animation_player.current_animation_position
	shaman.status.apply_effect(StatusEffects.FROZEN,2,1)
	shaman._update_skeletal_animation(.2)
	check(is_equal_approx(pose_time,shaman._animation_player.current_animation_position),"冻结保持召唤姿势")
	shaman.update_ai(.1)
	check(not shaman._summoning_totem and shaman.state==BaseEnemy.State.STAGGERED,"冻结中断召唤")
	shaman.status.remove_effect(StatusEffects.FROZEN)
	shaman._enter_state(BaseEnemy.State.ATTACK)
	shaman._update_skeletal_animation(0)
	check(shaman._visual_clip==&"cast","普通攻击使用独立施法动作")
	shaman._state_time=.6
	shaman._update_cast()
	check(count_bolts()==1,"普通攻击发射一次")
	var expired := shaman.totem_scene.instantiate() as HealTotem
	add_child(expired)
	expired.set_process(false)
	expired._process(5.01)
	check(expired.is_queued_for_deletion(),"图腾5秒到期")
	if "--preview-shaman" in OS.get_cmdline_user_args():
		for child in get_children():
			if child!=shaman:child.queue_free()
		await get_tree().process_frame
		shaman._enter_state(BaseEnemy.State.PATROL)
		shaman._play_visual(&"idle",true)
		var display_totem := shaman.totem_scene.instantiate() as HealTotem
		add_child(display_totem)
		display_totem.position=Vector3(-1,0,0)
		display_totem.set_process(false)
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
		camera.position=Vector3(-2,1.8,-5)
		camera.look_at(Vector3(-.4,1.1,0))
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=3.2
		camera.current=true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/enemy/forest_shaman_in_game.png")==OK,"祭司图腾合照")
	print("SHAMAN_VERIFY: ",checks.size()," checks; errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)

func verify_material(material: Material,resolution: int,label: String) -> void:
	var mat := material as StandardMaterial3D
	for prop in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture"]:
		var tex := mat.get(prop) as Texture2D
		check(tex!=null and tex.get_width()==resolution and tex.get_height()==resolution,label+" "+prop)
