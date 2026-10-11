extends Node3D
## 批量验证剩余资产完整性，以及巨兽新招式的前摇、闪避、单次命中和失衡中断。
var errors: Array[String] = []
var checks := 0
class Target:
	extends Node3D
	var hits := 0
	var effects: Dictionary = {}
	func take_damage(_amount: float, _source: Node = null) -> void: hits += 1
	func apply_external_knockback(_direction: Vector3, _force: float) -> void: pass
	func add_camera_shake(_strength: float, _duration: float) -> void: pass
	func apply_effect(id: String, duration: float, _power := 1.0) -> void: effects[id] = duration
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors.append(label); push_error(label)
func _ready() -> void: call_deferred("run")
func run() -> void:
	var entries := {
		"campfire":"scenery", "windmill":"scenery", "windmill_blades":"scenery", "dungeon_gate":"scenery", "dungeon_pillar":"scenery", "frost_edge":"player",
		"glow_wisp":"spirit", "flame_crystal":"spirit", "stone_guardian":"spirit", "boss_sprout":"boss", "moss_crown_beast":"boss"}
	if "--logic-only" in OS.get_cmdline_user_args(): entries.clear()
	for asset in entries:
		var model := (load("res://art/models/" + entries[asset] + "/" + asset + ".glb") as PackedScene).instantiate()
		add_child(model)
		var skinned: bool = entries[asset] in ["spirit", "boss"]
		var triangles := 0
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = node.mesh
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				triangles += arrays[Mesh.ARRAY_INDEX].size()/3
				check(arrays[Mesh.ARRAY_TEX_UV] != null and arrays[Mesh.ARRAY_TEX_UV].size() > 0, asset + " UV")
				var material := node.get_active_material(surface) as StandardMaterial3D
				if material.resource_name == "Campfire_Flame": continue
				for prop in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture"]:
					var tex := material.get(prop) as Texture2D
					check(tex != null and tex.get_width() == (2048 if skinned else 1024), asset + " " + prop)
				if skinned: check(node.skin != null and arrays[Mesh.ARRAY_WEIGHTS].size() > 0, asset + " 蒙皮")
		check(triangles <= (10000 if skinned else 5000), asset + " 面数预算")
		if skinned:
			var motion = preload("res://scenes/actors/asset_animation.gd").new()
			motion.bind(model, asset)
			check(motion.player != null, asset + " 动画播放器")
			var expected := ["idle", "walk", "death", "hit", "sweep", "charge", "summon", "stomp", "slam", "tail", "roots"] if asset == "moss_crown_beast" else ["idle", "walk", "attack", "heal", "shield", "taunt", "hit", "death"]
			for clip in expected: check(motion.clips.has(clip), asset + " " + clip)
			motion.play("idle"); motion.advance(5, true)
			check(motion.elapsed < 3, asset + " 待机循环")
		for path in ["res://art/source/" + asset + ".blend", "res://art/previews/" + entries[asset] + "/" + asset + ".png"]:
			check(FileAccess.file_exists(path), asset + " 归档")
		model.queue_free()
	await get_tree().process_frame
	for id in ["glow_wisp", "flame_crystal", "stone_guardian"]:
		var spirit := (load("res://scenes/player/spirit_entity.tscn") as PackedScene).instantiate() as SpiritEntity
		add_child(spirit)
		spirit.setup_model(load("res://data/spirits/" + id + ".tres"))
		check(spirit._motion.player != null and not spirit._placeholder.visible, id + " 实体挂接")
		var effect := "heal" if id == "glow_wisp" else ("attack" if id == "flame_crystal" else "taunt")
		spirit.play_effect(effect); spirit._process(.2)
		check(spirit._motion.current == effect, id + " 效果播放对应动作")
		spirit._process(2); spirit._process(0)
		check(spirit._motion.current == "idle", id + " 动作结束回到待机")
		spirit.apply_knockback(Vector3.ONE)
		check(spirit._motion.current == "hit" and spirit.is_knocked_back(), id + " 击退受击")
		spirit.end_knockback(); spirit.queue_free()
	var camp := (load("res://scenes/world/camp.tscn") as PackedScene).instantiate()
	add_child(camp)
	var blades: Node3D = camp.get("_blades")
	check(blades != null, "风车转轴已绑定")
	var initial_angle := blades.rotation.z
	camp._process(.2)
	check(blades.rotation.z > initial_angle, "风车运行时旋转")
	var fire := camp.find_child("Campfire", true, false)
	var fire_players := fire.find_children("*", "AnimationPlayer", true, false)
	check(fire_players.size() == 1 and fire_players[0].is_playing(), "篝火播放Blender动画")
	check(fire.find_children("*", "GPUParticles3D", true, false).is_empty(), "新篝火不叠加旧方片粒子")
	if not fire_players.is_empty():
		var animation_player := fire_players[0] as AnimationPlayer
		var flame := fire.find_child("Flame0", true, false) as Node3D
		check(flame != null, "火焰卡片存在")
		if flame != null:
			animation_player.seek(0, true)
			var original_scale := flame.scale
			animation_player.seek(.3, true)
			check(not flame.scale.is_equal_approx(original_scale), "火焰实际形变")
	camp.queue_free()
	var target := Target.new()
	add_child(target); target.add_to_group("player")
	var beast = load("res://scenes/dungeons/boss_moss_crown_beast.tscn").instantiate()
	add_child(beast); beast.set_physics_process(false)
	beast.position = Vector3(100, 0, 100); beast.set_arena_center(beast.position)
	for clip in ["stomp", "slam", "tail", "roots"]:
		target.position = beast.position + Vector3(0, 0, 4 if clip == "tail" else -4.5)
		beast.force_extra(clip)
		var before := target.hits
		beast._run_skill(float(beast.EXTRA_SKILLS[clip].windup) - 0.01)
		check(target.hits == before, clip + " 前摇不伤害")
		beast._run_skill(0.02)
		check(target.hits == before + 1, clip + " 生效一次")
		beast._run_skill(0.1)
		check(target.hits == before + 1, clip + " 收招不重复")
	check(target.effects.has("rooted"), "根须施加束缚")
	target.position = beast.position + Vector3(0, 0, -6)
	beast.force_extra("roots")
	target.position.x += 5
	var hits_before := target.hits
	beast._run_skill(1.31)
	check(target.hits == hits_before, "离开锁定落点可避开根须")
	target.position = beast.position + Vector3(0, 1.5, -5)
	beast.force_extra("stomp"); beast._run_skill(1.11)
	check(target.hits == hits_before, "跳跃避开地面震波")
	beast.force_extra("slam")
	beast.boss.add_stagger(beast.boss.stagger_max)
	check(beast._skill == 0 and beast._extra_warning == null, "失衡取消技能及预警")
	beast._run_skill(2)
	check(target.hits == hits_before, "中断后不补发伤害")
	target.remove_from_group("player")
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	add_child(player); player.set_physics_process(false)
	player.global_position = beast.global_position + Vector3(0, 0, -5.5)
	player.rotation.y = PI
	await get_tree().physics_frame
	await get_tree().physics_frame
	var nearby: Array = player.combat._query_cone_targets(2.6, 120)
	check(nearby.has(beast.hit_area), "在巨兽头前可近战命中，无中心距离误判")
	player.rotation.y = 0
	check(not player.combat._query_cone_targets(2.6, 120).has(beast.hit_area), "背向巨兽不能命中")
	player.queue_free()
	beast.queue_free(); target.queue_free()
	print("REMAINING_ASSETS_VERIFY: ", checks, " checks; errors=", errors)
	for child in get_children(): child.queue_free()
	for frame in 4: await get_tree().process_frame
	get_tree().quit(0 if errors.is_empty() else 1)
