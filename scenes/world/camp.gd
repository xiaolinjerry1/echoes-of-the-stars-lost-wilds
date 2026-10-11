extends Node3D
## 营地（风车营地，安全区）
## 职责：运行时搭建营地（风车地标/篝火/帐篷/小屋/锻造台/仓库/告示板/快速旅行点）、
## 放置 4 名 NPC、安全区复活点与篝火休息；模型就绪后由 model_* 导出路径替换占位。

@export var windmill_model_path := "res://art/models/scenery/windmill.glb"
@export var windmill_blades_model_path := "res://art/models/scenery/windmill_blades.glb"
@export var campfire_model_path := "res://art/models/scenery/campfire.glb"
@export var tent_model_path := "res://art/models/scenery/tent.glb"
@export var crate_model_path := "res://art/models/prop/storage_crate.glb"
@export var forge_model_path := "res://art/models/prop/camp_forge.glb"
@export var hut_model_path := "res://art/models/scenery/hut.glb"

const NPCS := [
	{
		"id": "elin", "name": "艾琳", "color": Color(0.85, 0.70, 0.42),
		"pos": Vector3(-5, 0, 2), "services": [],
		"lines": ["营地的风车又转了一整天。", "东边森林最近不太平，巡林者还没回来。"],
	},
	{
		"id": "tom", "name": "汤姆", "color": Color(0.50, 0.66, 0.52),
		"pos": Vector3(3, 0, 5), "services": ["shop"],
		"lines": ["补给品都在仓库里码着，你随便看看。", "草药在大路边上就有，别踩坏了。"],
	},
	{
		"id": "mara", "name": "玛拉", "color": Color(0.72, 0.56, 0.78),
		"pos": Vector3(4, 0, -4), "services": ["inn"],
		"lines": ["篝火边睡一觉，伤口好得快。", "夜里林子里的声音，别一个人听太久。"],
	},
	{
		"id": "glen", "name": "格伦", "color": Color(0.60, 0.62, 0.72),
		"pos": Vector3(7, 0, -6), "services": ["forge"],
		"lines": ["炉火正旺，在这里休整一下再出发吧。", "不断磨练飞刃，升级后选择适合你的能力。"],
	},
]

var campfire_pos := WorldLayout.CAMPFIRE

var _fire_light: OmniLight3D
var _blades: Node3D
var _hour_label: Label3D


func _ready() -> void:
	_build_windmill()
	_build_campfire()
	_build_tents()
	_build_hut()
	_build_forge()
	_build_storage()
	_build_notice_board()
	_build_fast_travel()
	_spawn_npcs()
	_build_safe_zone()


func _process(delta: float) -> void:
	if _blades != null:
		_blades.rotation.z += delta * 0.45


func get_campfire_position() -> Vector3:
	return campfire_pos


## ---- 建筑 ----


func _build_windmill() -> void:
	var root := Node3D.new()
	root.name = "Windmill"
	root.position = WorldLayout.CAMP + Vector3(-15, 0, 13)
	add_child(root)
	var fallback := Node3D.new()
	fallback.add_child(PropFactory.cylinder(2.3, 8.6, Color(0.74, 0.70, 0.62), Vector3(0, 4.3, 0), 1.9, 12))
	fallback.add_child(PropFactory.cylinder(2.1, 1.7, Color(0.42, 0.30, 0.20), Vector3(0, 9.4, 0), 0.5, 12))
	fallback.add_child(PropFactory.box(Vector3(0.6, 1.0, 0.05), Color(0.35, 0.25, 0.16), Vector3(0, 0.5, 2.3)))
	root.add_child(PropFactory.model_node(windmill_model_path, fallback))
	var blades_root := Node3D.new()
	blades_root.name = "Blades"
	_blades = blades_root
	blades_root.position = Vector3(0, 9.6, 2.5)
	root.add_child(blades_root)
	var blade_fallback := Node3D.new()
	for i in 4:
		var blade := PropFactory.box(Vector3(0.22, 4.6, 0.08), Color(0.60, 0.48, 0.32))
		blade.position = Vector3(0, 2.6, 0)
		var pivot := Node3D.new()
		pivot.rotation.z = i * PI * 0.5
		pivot.add_child(blade)
		blade_fallback.add_child(pivot)
	blade_fallback.add_child(PropFactory.sphere(0.35, Color(0.35, 0.26, 0.18)))
	blades_root.add_child(PropFactory.model_node(windmill_blades_model_path, blade_fallback))
	var body := PropFactory.static_body(Vector3(4.0, 10.0, 4.0), Vector3(0, 5.0, 0))
	body.add_to_group("nav_source")
	root.add_child(body)
	root.add_child(PropFactory.interactable("风车（营地地标）", Vector3(4.5, 4.0, 4.5), Vector3(0, 1.5, 2.6)))


func _build_campfire() -> void:
	var root := Node3D.new()
	root.name = "Campfire"
	root.position = campfire_pos
	add_child(root)
	var fallback := Node3D.new()
	for i in 10:
		var angle := TAU * i / 10.0
		fallback.add_child(PropFactory.sphere(0.26, Color(0.42, 0.40, 0.38), Vector3(cos(angle) * 0.95, 0.12, sin(angle) * 0.95)))
	for i in 3:
		var log_mesh := PropFactory.cylinder(0.12, 1.4, Color(0.30, 0.20, 0.12), Vector3(0, 0.18, 0))
		log_mesh.rotation = Vector3(0.4, TAU * i / 3.0, 0.0)
		fallback.add_child(log_mesh)
	var fire_model := PropFactory.model_node(campfire_model_path, fallback)
	root.add_child(fire_model)
	var fire_players := fire_model.find_children("*", "AnimationPlayer", true, false)
	if fire_players.is_empty():
		root.add_child(_make_flame_particles())
	else:
		for node in fire_players:
			var animator := node as AnimationPlayer
			for clip in animator.get_animation_list():
				if clip == "RESET": continue
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				animator.play(clip)
				break
	_fire_light = OmniLight3D.new()
	_fire_light.name = "FireLight"
	_fire_light.light_color = Color(1.0, 0.62, 0.30)
	_fire_light.light_energy = 2.4
	_fire_light.omni_range = 11.0
	_fire_light.position = Vector3(0, 1.1, 0)
	root.add_child(_fire_light)
	var cycle := get_tree().get_first_node_in_group("day_night")
	if cycle != null:
		cycle.call("register_fire_light", _fire_light)
	var interactable := PropFactory.interactable("休息（恢复并推进时间）", Vector3(3.2, 3.0, 3.2), Vector3(0, 1.0, 0))
	interactable.interacted.connect(_on_campfire_interacted)
	root.add_child(interactable)
	_hour_label = Label3D.new()
	_hour_label.name = "FireLabel"
	_hour_label.text = "营地篝火"
	_hour_label.font_size = 64
	_hour_label.pixel_size = 0.006
	_hour_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hour_label.position = Vector3(0, 2.3, 0)
	root.add_child(_hour_label)


func _make_flame_particles() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Flame"
	particles.amount = 24
	particles.lifetime = 1.1
	particles.position = Vector3(0, 0.35, 0)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 12.0
	process.initial_velocity_min = 0.8
	process.initial_velocity_max = 1.4
	process.gravity = Vector3(0, 0.6, 0)
	process.scale_min = 0.15
	process.scale_max = 0.32
	process.color = Color(1.0, 0.65, 0.25, 0.9)
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.34)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.6, 0.2)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.55, 0.15)
	flame_mat.emission_energy_multiplier = 3.0
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = flame_mat
	particles.draw_pass_1 = quad
	return particles


func _build_tents() -> void:
	var spots := [Vector3(-8, 0, -6), Vector3(-7, 0, 10), Vector3(8, 0, 5)]
	for i in spots.size():
		var tent := Node3D.new()
		tent.name = "Tent%d" % (i + 1)
		tent.position = WorldLayout.CAMP + spots[i]
		add_child(tent)
		var fallback := Node3D.new()
		fallback.add_child(PropFactory.cylinder(1.7, 1.9, Color(0.58, 0.50, 0.36), Vector3(0, 0.95, 0), 0.0, 3))
		fallback.add_child(PropFactory.box(Vector3(0.05, 0.9, 1.0), Color(0.28, 0.22, 0.15), Vector3(0, 0.4, 0.75)))
		tent.add_child(PropFactory.model_node(tent_model_path, fallback))
		var body := PropFactory.static_body(Vector3(3.0, 2.0, 3.0), Vector3(0, 1.0, 0))
		body.add_to_group("nav_source")
		tent.add_child(body)


func _build_hut() -> void:
	var hut := Node3D.new()
	hut.name = "Hut"
	hut.position = WorldLayout.CAMP + Vector3(11, 0, -8)
	add_child(hut)
	var fallback := Node3D.new()
	fallback.add_child(PropFactory.box(Vector3(4.4, 2.6, 3.4), Color(0.50, 0.38, 0.26), Vector3(0, 1.3, 0)))
	fallback.add_child(PropFactory.cylinder(2.6, 1.2, Color(0.36, 0.26, 0.16), Vector3(0, 3.1, 0), 0.0, 4))
	fallback.add_child(PropFactory.box(Vector3(0.9, 1.8, 0.1), Color(0.30, 0.22, 0.14), Vector3(0, 0.9, 1.75)))
	var model := PropFactory.model_node(hut_model_path, fallback)
	model.name = "HutVisual"
	if model != fallback:
		fallback.free()
	hut.add_child(model)
	var body := PropFactory.static_body(Vector3(4.6, 2.8, 3.6), Vector3(0, 1.4, 0))
	body.name = "HutCollision"
	body.add_to_group("nav_source")
	hut.add_child(body)


func _build_forge() -> void:
	var forge := Node3D.new()
	forge.name = "Forge"
	# 炉体原位置与小屋石基交叠，向西北让出操作和通行空间。
	forge.position = WorldLayout.CAMP + Vector3(6, 0, -10)
	add_child(forge)
	var fallback := Node3D.new()
	fallback.add_child(PropFactory.cylinder(0.4, 0.55, Color(0.35, 0.28, 0.20), Vector3(0, 0.27, 0), -1.0, 8))
	fallback.add_child(PropFactory.box(Vector3(0.55, 0.18, 0.28), Color(0.28, 0.30, 0.33), Vector3(0, 0.78, 0)))
	fallback.add_child(PropFactory.box(Vector3(1.5, 1.1, 1.2), Color(0.40, 0.36, 0.34), Vector3(1.6, 0.55, 0)))
	var model := PropFactory.model_node(forge_model_path, fallback)
	model.name = "ForgeVisual"
	if model != fallback:
		model.position.x = 0.8
		fallback.free()
	forge.add_child(model)
	var hearth_body := PropFactory.static_body(Vector3(1.55, 2.69, 1.3), Vector3(1.6, 1.345, 0))
	hearth_body.name = "HearthCollision"
	hearth_body.add_to_group("nav_source")
	forge.add_child(hearth_body)
	var anvil_body := PropFactory.static_body(Vector3(1.35, 1.05, 0.85), Vector3(-0.15, 0.525, 0))
	anvil_body.name = "AnvilCollision"
	anvil_body.add_to_group("nav_source")
	forge.add_child(anvil_body)
	var glow := OmniLight3D.new()
	glow.name = "ForgeGlow"
	glow.light_color = Color(1.0, 0.55, 0.25)
	glow.light_energy = 1.6
	glow.omni_range = 4.0
	glow.position = Vector3(1.6, 1.2, 0)
	forge.add_child(glow)
	var cycle := get_tree().get_first_node_in_group("day_night")
	if cycle != null:
		cycle.call("register_fire_light", glow)
	var interactable := PropFactory.interactable("营地炉火", Vector3(2.6, 2.4, 2.6), Vector3(0, 0.9, 0))
	interactable.interacted.connect(_on_forge_interacted)
	forge.add_child(interactable)


func _build_storage() -> void:
	var storage := Node3D.new()
	storage.name = "Storage"
	storage.position = WorldLayout.CAMP + Vector3(1, 0, 8)
	add_child(storage)
	var fallback := Node3D.new()
	fallback.add_child(PropFactory.box(Vector3(1.0, 0.8, 0.9), Color(0.46, 0.34, 0.22), Vector3(0, 0.4, 0)))
	fallback.add_child(PropFactory.box(Vector3(1.04, 0.12, 0.94), Color(0.36, 0.26, 0.16), Vector3(0, 0.86, 0)))
	var model := PropFactory.model_node(crate_model_path, fallback)
	model.name = "StorageVisual"
	if model != fallback:
		fallback.free()
	storage.add_child(model)
	var body := PropFactory.static_body(Vector3(1.08, 0.94, 1.0), Vector3(0, 0.47, 0))
	body.name = "StorageCollision"
	body.add_to_group("nav_source")
	storage.add_child(body)
	var interactable := PropFactory.interactable("打开仓库", Vector3(1.8, 1.6, 1.8), Vector3(0, 0.8, 0))
	interactable.interacted.connect(_on_storage_interacted)
	storage.add_child(interactable)


func _build_notice_board() -> void:
	var board := Node3D.new()
	board.name = "NoticeBoard"
	board.position = WorldLayout.CAMP + Vector3(-2, 0, 6)
	add_child(board)
	board.add_child(PropFactory.cylinder(0.08, 1.8, Color(0.40, 0.30, 0.20), Vector3(-0.6, 0.9, 0), -1.0, 6))
	board.add_child(PropFactory.cylinder(0.08, 1.8, Color(0.40, 0.30, 0.20), Vector3(0.6, 0.9, 0), -1.0, 6))
	board.add_child(PropFactory.box(Vector3(1.7, 1.0, 0.08), Color(0.55, 0.42, 0.28), Vector3(0, 1.5, 0)))
	var interactable := PropFactory.interactable("查看告示板", Vector3(2.2, 2.2, 1.6), Vector3(0, 1.3, 0))
	interactable.interacted.connect(_on_board_interacted)
	board.add_child(interactable)


func _build_fast_travel() -> void:
	var point := Node3D.new()
	point.name = "FastTravel"
	point.position = WorldLayout.CAMP + Vector3(-1, 0, -9)
	add_child(point)
	point.add_child(PropFactory.cylinder(1.2, 0.25, Color(0.52, 0.52, 0.55), Vector3(0, 0.12, 0), 1.0, 8))
	point.add_child(PropFactory.cylinder(0.18, 1.6, Color(0.60, 0.62, 0.68), Vector3(0, 0.9, 0), 0.12, 8))
	var crystal := PropFactory.cylinder(0.22, 0.5, Color(0.55, 0.85, 1.0), Vector3(0, 1.9, 0), 0.0, 6)
	var crystal_mat := crystal.material_override as StandardMaterial3D
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.4, 0.75, 1.0)
	crystal_mat.emission_energy_multiplier = 2.5
	point.add_child(crystal)
	var interactable := PropFactory.interactable("快速旅行点", Vector3(2.4, 2.6, 2.4), Vector3(0, 1.2, 0))
	interactable.interacted.connect(_on_fast_travel_interacted)
	point.add_child(interactable)


func _spawn_npcs() -> void:
	var npc_scene := load("res://scenes/actors/npc.tscn") as PackedScene
	if npc_scene == null:
		push_error("营地：无法加载 npc.tscn")
		return
	for cfg in NPCS:
		var npc := npc_scene.instantiate() as Node3D
		npc.name = "Npc" + str(cfg["id"]).capitalize()
		npc.position = WorldLayout.CAMP + cfg["pos"]
		npc.set("npc_id", cfg["id"])
		npc.set("display_name", cfg["name"])
		npc.set("npc_color", cfg["color"])
		npc.set("idle_lines", cfg["lines"])
		npc.set("services", cfg["services"])
		add_child(npc)
		npc.look_at(Vector3(campfire_pos.x, npc.global_position.y, campfire_pos.z))


func _build_safe_zone() -> void:
	var zone := Area3D.new()
	zone.name = "SafeZone"
	zone.set_script(load("res://scenes/world/safe_zone.gd"))
	zone.position = WorldLayout.CAMP
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = WorldLayout.CAMP_RADIUS
	cylinder.height = 24.0
	shape.shape = cylinder
	shape.position = Vector3(0, 6, 0)
	zone.add_child(shape)
	add_child(zone)


## ---- 交互 ----


func _on_campfire_interacted(player: Node) -> void:
	var player_controller := player as PlayerController
	if player_controller == null:
		return
	player_controller.stats.heal(player_controller.stats.max_health)
	player_controller.set_respawn_point(campfire_pos)
	var cycle := get_tree().get_first_node_in_group("day_night")
	var hours := 8.0
	if cycle != null:
		hours = float(cycle.call("get_hours"))
		if hours >= 5.0 and hours < 17.0:
			cycle.call("set_time_of_day", 20.0)
			player_controller.show_combat_feedback("你休息到了夜晚（20:00）", Color(0.65, 0.75, 1.0))
		else:
			cycle.call("set_time_of_day", 6.0)
			player_controller.show_combat_feedback("你休息到了清晨（06:00）", Color(1.0, 0.9, 0.6))


func _on_forge_interacted(player: Node) -> void:
	var player_controller := player as PlayerController
	if player_controller == null:
		return
	player_controller.show_combat_feedback("飞刃随等级成长，升级后选择三种能力中的一项。", Color(1.0, 0.75, 0.5))


func _on_storage_interacted(player: Node) -> void:
	var player_controller := player as PlayerController
	if player_controller == null:
		return
	player_controller.show_combat_feedback("营地储备充足，野外草药可以直接恢复生命。", Color(0.8, 0.8, 0.9))


func _on_board_interacted(player: Node) -> void:
	var player_controller := player as PlayerController
	if player_controller == null:
		return
	var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	var lines: Array = []
	if quest_manager != null:
		for quest in DataRegistry.get_all_quests():
			if quest_manager.can_accept(quest.id):
				lines.append("【可接取】%s —— %s" % [quest.display_name, quest.description])
			elif quest_manager.is_quest_completed(quest.id):
				lines.append("【已完成】%s" % quest.display_name)
	if lines.is_empty():
		lines.append("离开营地击杀怪物，收集经验升级。左键齐射，命中充满回响后右键召唤影分身。")
	lines.append("巨兽警报：营地北方约60米有林间遗迹，沿北行土路穿过石拱门。地图与罗盘标记「兽」。")
	lines.append("飞龙警报：东北方出现巨大凶焰飞龙，地图与罗盘标记「龙」。留意俯冲红圈与火球，俯冲落地后可反击。")
	player_controller.start_dialogue("营地告示板", lines)


func _on_fast_travel_interacted(player: Node) -> void:
	var player_controller := player as PlayerController
	if player_controller == null:
		return
	player_controller.show_combat_feedback("快速旅行点：目前仅营地可用（MVP 占位）", Color(0.6, 0.85, 1.0))
