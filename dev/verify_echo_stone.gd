extends Node3D
## 验证回响碑PBR、实例发光隔离、收藏状态同步及观测台实景。
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
	var packed := load("res://scenes/world/echo_stone.tscn") as PackedScene
	var first := packed.instantiate()
	var second := packed.instantiate()
	add_child(first)
	add_child(second)
	second.position.x=4
	first.set_process(false)
	second.set_process(false)
	await get_tree().process_frame
	var meshes := first.get_node("EchoVisual").find_children("*","MeshInstance3D",true,false)
	check(meshes.size()==1,"Blender单网格挂接")
	var instance := meshes[0] as MeshInstance3D
	var arrays := instance.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_INDEX].size()/3<=5000,"面数预算")
	check(arrays[Mesh.ARRAY_TEX_UV].size()>0 and arrays[Mesh.ARRAY_TANGENT].size()>0,"完整UV与切线")
	var mat := instance.get_active_material(0) as StandardMaterial3D
	for prop in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture","emission_texture"]:
		var tex := mat.get(prop) as Texture2D
		check(tex!=null and tex.get_width()==1024 and tex.get_height()==1024,"1K "+prop)
	check(instance.get_aabb().size.y>1.7 and instance.get_aabb().size.y<1.9,"与原1.8米碰撞高度兼容")
	check(not first.stone_body.visible and not first.rune_ring.visible,"旧占位隐藏")
	var other: StandardMaterial3D=second._find_glow_material()
	var source := instance.mesh.surface_get_material(0) as StandardMaterial3D
	check(mat!=other and mat!=source,"发光材质独立于其他实例和缓存")
	var source_energy := source.emission_energy_multiplier
	check(is_equal_approx(mat.emission_energy_multiplier,.6),"未收集弱光")
	first._set_collected(true)
	check(is_equal_approx(mat.emission_energy_multiplier,4.0) and first.stone_light.visible,"共鸣点亮模型与灯光")
	check(first.interactable.interact_text=="已共鸣","共鸣提示")
	check(is_equal_approx(other.emission_energy_multiplier,.6) and is_equal_approx(source.emission_energy_multiplier,source_energy),"其他实例与缓存未被点亮")
	# Simulate the existing saved payload being applied without collecting rewards or writing saves.
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	add_child(player)
	player.position=Vector3(30,10,30)
	player.set_physics_process(false)
	player.echo_system.collected_echoes.append("frost_lamp_scholar")
	second._sync_collected_state()
	check(second._collected and second.stone_light.visible and is_equal_approx(other.emission_energy_multiplier,4),"读取收藏后恢复亮起状态")
	player.echo_system.collected_echoes.clear()
	second._sync_collected_state()
	check(not second._collected and not second.stone_light.visible and second.interactable.interact_text=="触碰回响碑","恢复未收藏状态")
	player.queue_free()
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	if "--preview-echo" in OS.get_cmdline_user_args():
		var forest := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
		add_child(forest)
		var elapsed := 0.0
		while (not forest.is_world_ready() or forest.nav_region.is_baking()) and elapsed<40:
			await get_tree().create_timer(.2).timeout
			elapsed+=.2
		check(forest.is_world_ready(),"实景森林就绪")
		var stone := forest.find_child("EchoStone",true,false) as Node3D
		var camera := Camera3D.new()
		add_child(camera)
		camera.position=stone.global_position+Vector3(2.3,2,4.1)
		camera.look_at(stone.global_position+Vector3(0,.8,0))
		camera.fov=53
		camera.current=true
		for lit in [false,true]:
			stone._set_collected(lit)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var suffix := "lit" if lit else "idle"
			check(get_viewport().get_texture().get_image().save_png("res://art/previews/scenery/echo_stone_"+suffix+"_in_forest.png")==OK,"实景截图 "+suffix)
	FileAccess.open("res://dev/art_work/echo_stone/godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"\t"))
	print("ECHO_STONE_VERIFY: ",checks.size()," checks; errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)
