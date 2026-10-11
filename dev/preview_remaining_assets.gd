extends Node3D
## 在实际森林、营地和秘境中保存本批资产的兼容渲染截图，不修改玩家存档。
var camera: Camera3D
func _ready() -> void: call_deferred("run")
func capture(path: String, eye: Vector3, focus: Vector3, fov := 48.0) -> void:
	camera.position = eye
	camera.look_at(focus)
	camera.fov = fov
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " ", result)
func run() -> void:
	camera = Camera3D.new(); add_child(camera); camera.current = true
	if "--camp" in OS.get_cmdline_user_args():
		var forest := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
		add_child(forest)
		var elapsed := 0.0
		while (not forest.is_world_ready() or forest.nav_region.is_baking()) and elapsed < 50:
			await get_tree().create_timer(.2).timeout; elapsed += .2
		var fire := forest.find_child("Campfire", true, false) as Node3D
		var mill := forest.find_child("Windmill", true, false) as Node3D
		await capture("res://art/previews/scenery/campfire_in_camp.png", fire.global_position+Vector3(3,2.3,3.5), fire.global_position+Vector3(0,.6,0))
		await capture("res://art/previews/scenery/windmill_in_camp.png", mill.global_position+Vector3(12,13,10), mill.global_position+Vector3(0,6,0), 55)
		var gate := forest.find_child("DungeonEntrance", true, false) as Node3D
		await capture("res://art/previews/scenery/dungeon_gate_in_forest.png", gate.global_position+Vector3(5,3,9), gate.global_position+Vector3(0,2.4,0))
		var spot: Vector3 = fire.global_position+Vector3(0,1.3,4)
		for i in 3:
			var spirit := (load("res://scenes/player/spirit_entity.tscn") as PackedScene).instantiate()
			add_child(spirit); spirit.position=spot+Vector3((i-1)*1.1,0,0)
			spirit.setup_model(load("res://data/spirits/"+["glow_wisp","flame_crystal","stone_guardian"][i]+".tres"))
			spirit.set_process(false)
		await capture("res://art/previews/spirit/spirits_in_camp.png", spot+Vector3(2,1.0,5), spot+Vector3(0,.4,0))
	else:
		var dungeon := (load("res://scenes/dungeons/forest_grove_dungeon.tscn") as PackedScene).instantiate()
		add_child(dungeon)
		var elapsed := 0.0
		while not dungeon.is_ready_for_player() and elapsed < 50:
			await get_tree().create_timer(.2).timeout; elapsed += .2
		var beast = dungeon.get_boss()
		beast.set_physics_process(false); beast.rotation.y = PI
		var center: Vector3 = beast.global_position
		var npc := (load("res://art/models/player/npc_elin.glb") as PackedScene).instantiate() as Node3D
		add_child(npc); npc.position=center+Vector3(4.5,0,1.5)
		await capture("res://art/previews/boss/moss_crown_beast_in_arena.png",center+Vector3(12,8,15),center+Vector3(0,3,0),55)
		for clip in ["sweep","stomp","slam","tail","roots","summon","charge"]:
			beast._motion.play(clip, true)
			var animator: AnimationPlayer = beast._motion.player
			animator.seek(animator.current_animation_length*.55,true)
			await capture("res://art/previews/boss/moss_crown_"+clip+"_in_arena.png",center+Vector3(12,8,15),center+Vector3(0,3,0),55)
	for child in get_children(): child.queue_free()
	for frame in 4: await get_tree().process_frame
	get_tree().quit()
