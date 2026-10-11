extends Node3D
## 验证六个人形资产、施法命中时序/冻结中断、祭司图腾及NPC角色映射。
var checks: Array[String]=[]
var errors: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks.append(label)
	if not ok:
		errors.append(label)
		push_error(label)
func _ready() -> void:call_deferred("run")
func count_bolts() -> int:
	var count := 0
	for node in get_children():
		if node is EnemyBolt:count+=1
	return count
func enemy(script_path: String,offset: Vector3) -> BaseEnemy:
	var node := (load("res://scenes/actors/base_enemy.tscn") as PackedScene).instantiate()
	node.set_script(load(script_path))
	add_child(node)
	node.position=offset
	node.set_physics_process(false)
	return node
func run() -> void:
	for asset in ["forest_mage","npc_elin","npc_tom","npc_mara","npc_glen","npc_wounded_ranger"]:
		var category := "enemy" if asset=="forest_mage" else "player"
		var model := (load("res://art/models/"+category+"/"+asset+".glb") as PackedScene).instantiate()
		add_child(model)
		var skeletons := model.find_children("*","Skeleton3D",true,false)
		check(skeletons.size()==1 and skeletons[0].get_bone_count()==22,asset+" 22骨")
		var players := model.find_children("*","AnimationPlayer",true,false)
		check(players.size()==1,asset+"动画播放器")
		var animation := players[0] as AnimationPlayer
		var count := 0
		for clip in animation.get_animation_list():
			if String(clip).contains(asset+"_"):count+=1
		check(count==10,asset+"独立10动作")
		for node in model.find_children("*","MeshInstance3D",true,false):
			var mesh: Mesh=node.mesh
			var arrays := mesh.surface_get_arrays(0)
			check(node.skin!=null and arrays[Mesh.ARRAY_BONES].size()>0 and arrays[Mesh.ARRAY_WEIGHTS].size()>0,asset+"蒙皮权重")
			check(arrays[Mesh.ARRAY_INDEX].size()/3<10000,asset+"面数预算")
			var material := node.get_active_material(0) as StandardMaterial3D
			for prop in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture"]:
				var tex := material.get(prop) as Texture2D
				check(tex!=null and tex.get_width()==2048 and tex.get_height()==2048,asset+" 2K "+prop)
		model.queue_free()
	await get_tree().process_frame
	var target := Node3D.new()
	add_child(target)
	target.position=Vector3(0,0,-10)
	var mage := enemy("res://scenes/actors/ranged_caster.gd",Vector3.ZERO) as RangedCaster
	mage._target=target
	check(mage._animation_player!=null and mage._clips.has(&"cast"),"森林法师使用骨骼施法")
	check(is_equal_approx(mage.visual.rotation.y,PI),"+Z模型兼容AI朝向")
	mage._begin_cast()
	mage._state_time=.79
	mage._update_cast()
	check(count_bolts()==0,"0.8秒前不发射")
	mage._state_time=.8
	mage._update_cast()
	mage._update_skeletal_animation(0)
	check(count_bolts()==1 and is_equal_approx(mage._animation_player.current_animation_position,.8),"0.8秒单次发射与动画对齐")
	mage._state_time=1.0
	mage._update_cast()
	check(count_bolts()==1 and mage.state==BaseEnemy.State.ATTACK,"收招期间不重复发射")
	mage._state_time=1.41
	mage._update_cast()
	check(mage.state==BaseEnemy.State.CHASE,"完整收招后恢复追击")
	mage._begin_cast()
	mage._state_time=.3
	mage._update_skeletal_animation(0)
	var time := mage._animation_player.current_animation_position
	mage.status.apply_effect(StatusEffects.FROZEN,2,1)
	mage._update_skeletal_animation(.2)
	check(is_equal_approx(time,mage._animation_player.current_animation_position),"冻结保留当前骨骼姿势")
	mage.update_ai(.1)
	check(mage.state==BaseEnemy.State.STAGGERED and not mage._cast_fired,"控制打断施法")
	mage.status.remove_effect(StatusEffects.FROZEN)
	mage._enter_state(BaseEnemy.State.CHASE)
	mage.current_health=10
	var support := enemy("res://scenes/actors/support.gd",Vector3(3,0,0)) as SupportCaster
	support._target=target
	support._update_state(0)
	check(support._summoning_totem and support.state==BaseEnemy.State.ATTACK,"祭司治疗进入施法动作")
	support._state_time=.6
	support._update_cast()
	check(support._cast_fired and support._totem_cd>0,"祭司0.6秒施放图腾")
	mage.state=BaseEnemy.State.DEAD
	mage._play_death_visual()
	mage._update_skeletal_animation(.8)
	check(mage._visual_clip==&"death" and mage.visual.scale.is_equal_approx(Vector3.ONE),"骨骼倒地不缩放模型")
	var npcs: Array=[]
	for id in ["elin","tom","mara","glen","wounded_ranger"]:
		var npc := (load("res://scenes/actors/npc.tscn") as PackedScene).instantiate() as Npc
		npc.npc_id=id
		npc.display_name={"elin":"艾琳","tom":"汤姆","mara":"玛拉","glen":"格伦","wounded_ranger":"受伤巡林者"}[id]
		add_child(npc)
		npc.position=Vector3(npcs.size()*1.65,0,5)
		npc.set_process(false)
		check(npc.visual.has_node("CharacterModel") and not npc.visual.get_node("Body").visible,id+"已替换占位")
		check(npc._visual_clip==("wounded" if id=="wounded_ranger" else "idle"),id+"对应待机")
		var player := PlayerController.new()
		player.dialogue_active=true
		npc._conversation_player=player
		npc._update_character(.2)
		check(npc._visual_clip=="talk",id+"交谈动作")
		player.dialogue_active=false
		npc._update_character(.2)
		check(npc._visual_clip==("wounded" if id=="wounded_ranger" else "idle"),id+"交谈结束恢复")
		player.free()
		npcs.append(npc)
	if "--preview-humanoids" in OS.get_cmdline_user_args():
		for child in get_children():
			if child not in npcs:child.queue_free()
		await get_tree().process_frame
		var light := DirectionalLight3D.new()
		add_child(light)
		light.rotation_degrees=Vector3(-45,-30,0)
		light.light_energy=1.2
		var environment := WorldEnvironment.new()
		environment.environment=Environment.new()
		environment.environment.background_mode=Environment.BG_COLOR
		environment.environment.background_color=Color(.12,.16,.21)
		environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color=Color(.65,.75,.9)
		environment.environment.ambient_light_energy=.7
		add_child(environment)
		var camera := Camera3D.new()
		add_child(camera)
		camera.position=Vector3(3.3,1.6,-4)
		camera.look_at(Vector3(3.3,1.1,5))
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=4.8
		camera.current=true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://art/previews/player/npc_lineup.png")==OK,"NPC阵列截图")
	FileAccess.open("res://dev/art_work/humanoid_cast/godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"\t"))
	print("HUMANOID_VERIFY: ",checks.size()," checks; errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)
