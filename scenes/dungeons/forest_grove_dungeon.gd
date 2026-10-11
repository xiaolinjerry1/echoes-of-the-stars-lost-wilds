extends Node3D
## 林间秘境（微型秘境）
## 职责：60×60 封闭林间空地：入口 → 两波近战小怪 → 秘境宝箱 → 圆形 BOSS 竞技场（4 石柱）
## → 出口。规则：进入竞技场后关门开战（BOSS 血条 + 出场震动）；BOSS 死亡后出口开启、
## 展示首通横幅；reset_dungeon() 供死亡后重置（管理器通过重新加载实现）。

signal boss_defeated(first_clear: bool)
signal waves_cleared()

## 主世界模式：区域整体实例化在森林内，共用天空、玩家、物理与导航。
@export var main_world_mode := false

const ARENA_CENTER := Vector3(0.0, 0.0, -5.0)
const ENTRANCE_POSITION := Vector3(0.0, 0.2, 25.0)
const EXIT_POSITION := Vector3(0.0, 0.2, -25.5)
const HALF_SIZE := 30.0
const WALL_HEIGHT := 6.0
const PILLAR_RADIUS := 13.0
const WAVE1_POSITIONS := [
	Vector3(-3.0, 0.1, 16.0), Vector3(3.0, 0.1, 16.0), Vector3(0.0, 0.1, 19.0),
]
const WAVE2_POSITIONS := [
	Vector3(-3.0, 0.1, 2.0), Vector3(3.0, 0.1, 2.0), Vector3(0.0, 0.1, -1.0),
]

var _nav_ready := false
var _waves_cleared := false
var _boss_dead := false
var _wave_index := 0
var _wave_enemies: Array[Node] = []
var _boss: Node3D
var _gate_body: StaticBody3D
var _gate_visual: Node3D
var _exit_body: StaticBody3D
var _exit_visual: Node3D
var _exit_interactable: Interactable
var _boss_panel: Control
var _boss_bar: ProgressBar
var _clear_banner: Label


func _ready() -> void:
	_build_ground_and_walls()
	_build_decorations()
	_build_pillars()
	_build_gate()
	_build_exit()
	_build_chest()
	_build_boss()
	_build_ui()
	_build_arena_trigger()
	_spawn_wave()
	if main_world_mode:
		add_to_group("main_world_grove")
		_nav_ready = true
		return
	var nav := get_node_or_null("NavRegion") as NavigationRegion3D
	if nav != null:
		nav.bake_finished.connect(_on_nav_baked)
		nav.bake_navigation_mesh(true)


func is_ready_for_player() -> bool:
	return _nav_ready


func get_entrance_position() -> Vector3:
	return to_global(ENTRANCE_POSITION)


func get_exit_position() -> Vector3:
	return to_global(EXIT_POSITION)


func is_cleared() -> bool:
	return _boss_dead


func is_waves_cleared() -> bool:
	return _waves_cleared


func get_boss() -> Node3D:
	return _boss


func is_gate_closed() -> bool:
	return _gate_body != null and _gate_body.collision_layer != 0


func is_exit_open() -> bool:
	return _exit_body != null and _exit_body.collision_layer == 0


## ---- 构建 ----


func _nav_root() -> Node3D:
	var nav := get_node_or_null("NavRegion") as NavigationRegion3D
	return nav if nav != null else self


func _build_ground_and_walls() -> void:
	var nav_root := _nav_root()
	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.collision_layer = 1
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(60.0, 1.0, 60.0)
	ground_shape.shape = ground_box
	ground_shape.position = Vector3(0, -0.5, 0)
	ground_body.add_child(ground_shape)
	ground_body.add_to_group("nav_source")
	if not main_world_mode:
		nav_root.add_child(ground_body)
	else:
		ground_body.free()
	var ground_visual := PropFactory.box(Vector3(60.0, 1.0, 60.0), Color(0.34, 0.5, 0.26), Vector3(0, -0.5, 0))
	if main_world_mode: ground_visual.position.y += 0.025
	ground_visual.name = "GroundMesh"
	ground_visual.material_override = _blender_material("res://art/models/scenery/forest_dirt.glb", Vector3(15, 15, 15))
	add_child(ground_visual)
	# 围墙（北墙留出口门洞）
	var walls := [
		[Vector3(0, 3.0, 30.0), Vector3(60.0, WALL_HEIGHT, 2.0)],
		[Vector3(0, 3.0, -30.0), Vector3(60.0, WALL_HEIGHT, 2.0)],
		[Vector3(-30.0, 3.0, 0), Vector3(2.0, WALL_HEIGHT, 60.0)],
		[Vector3(30.0, 3.0, 0), Vector3(2.0, WALL_HEIGHT, 60.0)],
	]
	if main_world_mode:
		# 南门10m、北门6.4m：同一地面上的真正开口，不再通过传送入口。
		walls = [
			[Vector3(-17.5, 3, 30), Vector3(25, WALL_HEIGHT, 2)],
			[Vector3(17.5, 3, 30), Vector3(25, WALL_HEIGHT, 2)],
			[Vector3(-16.6, 3, -30), Vector3(26.8, WALL_HEIGHT, 2)],
			[Vector3(16.6, 3, -30), Vector3(26.8, WALL_HEIGHT, 2)],
			[Vector3(-30, 3, 0), Vector3(2, WALL_HEIGHT, 60)],
			[Vector3(30, 3, 0), Vector3(2, WALL_HEIGHT, 60)],
		]
	for wall in walls:
		var body := PropFactory.static_body(wall[1], wall[0])
		body.add_to_group("nav_source")
		nav_root.add_child(body)
		var along_z: bool = wall[1].z > wall[1].x
		var size: Vector3 = Vector3(wall[1].z, wall[1].y, wall[1].x) if along_z else wall[1]
		var wall_visual := _stone_wall(size, wall[0])
		if along_z: wall_visual.rotation.y = PI * .5
		add_child(wall_visual)
	if main_world_mode:
		var arch := PropFactory.model_node("res://art/models/scenery/dungeon_gate.glb", Node3D.new())
		arch.position = Vector3(0, 0, 30)
		arch.scale.x = 1.8
		add_child(arch)
		for side in [-1.0, 1.0]:
			var arch_body := PropFactory.static_body(Vector3(1.5, 4.2, 1.3), Vector3(side * 3.24, 2.1, 30))
			arch_body.add_to_group("nav_source")
			add_child(arch_body)
		var sign := Label3D.new()
		sign.text = "苔冠巨兽领地\n沿路进入 · 无需传送"
		sign.font_size = 64
		sign.position = Vector3(0, 7, 30)
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(sign)


func _build_decorations() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12121
	var spots := [
		Vector3(-22, 0, 20), Vector3(22, 0, 18), Vector3(-24, 0, -2), Vector3(24, 0, -4),
		Vector3(-18, 0, -22), Vector3(18, 0, -24), Vector3(-24, 0, 10), Vector3(24, 0, 8),
	]
	for i in spots.size():
		var rock := PropFactory.model_node("res://art/models/scenery/rock.glb", Node3D.new())
		rock.position = spots[i]
		rock.scale = Vector3.ONE * rng.randf_range(0.8, 1.4)
		add_child(rock)
	for i in 6:
		var angle := TAU * i / 6.0 + 0.3
		var pos := Vector3(cos(angle) * 26.0, 0, sin(angle) * 26.0)
		var tree := PropFactory.model_node("res://art/models/scenery/tree_a.glb", Node3D.new())
		tree.position = pos
		add_child(tree)


## 复用 Blender 已烘焙的材质，UV 缩放仅匹配运行时碰撞地面的米制尺寸。
func _blender_material(path: String, repeats: Vector3) -> Material:
	var sample := (load(path) as PackedScene).instantiate()
	var meshes := sample.find_children("*", "MeshInstance3D", true, false)
	var result: StandardMaterial3D
	if not meshes.is_empty():
		result = meshes[0].get_active_material(0).duplicate() as StandardMaterial3D
		result.uv1_scale = repeats
	sample.free()
	return result


## 批量摆放已完成的 Blender 石墙模块，保持原围挡碰撞与开闭逻辑。
func _stone_wall(size: Vector3, center: Vector3) -> MultiMeshInstance3D:
	var sample := (load("res://art/models/scenery/observatory_wall.glb") as PackedScene).instantiate()
	var mesh: Mesh = sample.find_children("*", "MeshInstance3D", true, false)[0].mesh
	var bounds := mesh.get_aabb()
	var columns := maxi(1, ceili(size.x / bounds.size.x))
	var rows := maxi(1, ceili(size.y / bounds.size.y))
	var piece_scale := Vector3(size.x / columns / bounds.size.x, size.y / rows / bounds.size.y, size.z / bounds.size.z)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = columns * rows
	for row in rows:
		for column in columns:
			var offset := Vector3(-size.x*.5 + column*size.x/columns, -size.y*.5 + row*size.y/rows, -size.z*.5) - bounds.position * piece_scale
			batch.set_instance_transform(row*columns+column, Transform3D(Basis.from_scale(piece_scale), offset))
	var result := MultiMeshInstance3D.new()
	result.multimesh = batch
	result.position = center
	sample.free()
	return result


func _build_pillars() -> void:
	var pillar_scene := load("res://scenes/dungeons/dungeon_pillar.tscn") as PackedScene
	var nav_root := _nav_root()
	for i in 4:
		var angle := deg_to_rad(45.0 + i * 90.0)
		var pos := ARENA_CENTER + Vector3(cos(angle) * PILLAR_RADIUS, 0.0, sin(angle) * PILLAR_RADIUS)
		if pillar_scene != null:
			var pillar := pillar_scene.instantiate() as Node3D
			pillar.name = "Pillar%d" % (i + 1)
			nav_root.add_child(pillar)
			pillar.global_position = to_global(pos)


func _build_gate() -> void:
	_gate_visual = Node3D.new()
	_gate_visual.name = "ArenaGate"
	_gate_visual.position = Vector3(0.0, 0.0, 12.0)
	add_child(_gate_visual)
	for side in [-1.0, 1.0]:
		_gate_visual.add_child(_stone_wall(Vector3(7.6, 4.8, 0.7), Vector3(side * 3.9, 2.4, 0)))
	_gate_body = PropFactory.static_body(Vector3(16.0, 4.8, 1.0), Vector3(0.0, 2.4, 12.0))
	_gate_body.name = "ArenaGateBody"
	add_child(_gate_body)
	_set_gate_closed(false)


func _set_gate_closed(closed: bool) -> void:
	if _gate_body != null:
		_gate_body.collision_layer = 1 if closed else 0
	if _gate_visual != null:
		_gate_visual.visible = closed


func _build_exit() -> void:
	_exit_visual = Node3D.new()
	_exit_visual.name = "ExitDoor"
	_exit_visual.position = Vector3(0.0, 0.0, -28.4)
	add_child(_exit_visual)
	for side in [-1.0, 1.0]:
		_exit_visual.add_child(_stone_wall(Vector3(3.0, 5.0, 0.8), Vector3(side * 1.55, 2.5, 0)))
	_exit_body = PropFactory.static_body(Vector3(6.4, 5.0, 1.0), Vector3(0.0, 2.5, -28.4))
	_exit_body.name = "ExitDoorBody"
	add_child(_exit_body)
	_exit_interactable = PropFactory.interactable("离开林间遗迹" if main_world_mode else "离开秘境", Vector3(5.0, 3.4, 4.0), Vector3(0.0, 1.4, 0.0))
	_exit_interactable.position = EXIT_POSITION
	_exit_interactable.interacted.connect(_on_exit_interacted)
	add_child(_exit_interactable)


func _set_exit_open(open: bool) -> void:
	if _exit_body != null:
		_exit_body.collision_layer = 0 if open else 1
	if _exit_visual != null:
		_exit_visual.visible = not open
	if _exit_interactable != null:
		_exit_interactable.interact_text = ("沿门洞回到森林" if main_world_mode else "离开秘境") if open else "石门紧闭"


func _build_chest() -> void:
	var chest_scene := load("res://scenes/world/chest.tscn") as PackedScene
	if chest_scene == null:
		return
	var chest := chest_scene.instantiate() as Node3D
	chest.name = "DungeonChest"
	chest.set("chest_id", "chest_dungeon")
	chest.set("loot_table", "dungeon_chest")
	chest.set("rare", true)
	chest.position = Vector3(-15.0, 0.1, 12.0)
	add_child(chest)


func _build_boss() -> void:
	var boss_scene := load("res://scenes/dungeons/boss_moss_crown_beast.tscn") as PackedScene
	if boss_scene == null:
		return
	_boss = boss_scene.instantiate() as Node3D
	_boss.name = "MossCrownBeast"
	_boss.position = ARENA_CENTER + Vector3(0, 0.2, 0)
	add_child(_boss)
	_boss.call("set_arena_center", to_global(ARENA_CENTER))
	_boss.connect("enemy_died", _on_boss_died)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "DungeonUI"
	ui.layer = 5
	add_child(ui)
	_boss_panel = ColorRect.new()
	_boss_panel.name = "BossPanel"
	_boss_panel.color = Color(0.08, 0.06, 0.06, 0.72)
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.position = Vector2(-220, 14)
	_boss_panel.size = Vector2(440, 56)
	_boss_panel.visible = false
	ui.add_child(_boss_panel)
	var name_label := Label.new()
	name_label.name = "BossName"
	name_label.text = "苔冠巨兽"
	name_label.position = Vector2(0, 4)
	name_label.size = Vector2(440, 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_panel.add_child(name_label)
	_boss_bar = ProgressBar.new()
	_boss_bar.name = "BossBar"
	_boss_bar.position = Vector2(16, 30)
	_boss_bar.size = Vector2(408, 16)
	_boss_bar.max_value = 600.0
	_boss_bar.value = 600.0
	_boss_bar.show_percentage = false
	_boss_panel.add_child(_boss_bar)
	_clear_banner = Label.new()
	_clear_banner.name = "ClearBanner"
	_clear_banner.text = "林间巨兽已击败！" if main_world_mode else "秘境首通！"
	_clear_banner.add_theme_font_size_override("font_size", 72)
	_clear_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_clear_banner.set_anchors_preset(Control.PRESET_CENTER)
	_clear_banner.position = Vector2(-220, -60)
	_clear_banner.size = Vector2(440, 120)
	_clear_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clear_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clear_banner.visible = false
	ui.add_child(_clear_banner)


func _build_arena_trigger() -> void:
	var trigger := Area3D.new()
	trigger.name = "ArenaTrigger"
	trigger.collision_layer = 64
	trigger.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(16.0, 5.0, 5.0)
	shape.shape = box
	shape.position = Vector3(0.0, 2.0, 8.5)
	trigger.add_child(shape)
	trigger.body_entered.connect(_on_arena_trigger)
	add_child(trigger)


## ---- 波次 ----


func _spawn_wave() -> void:
	_wave_index += 1
	var positions: Array = WAVE1_POSITIONS if _wave_index == 1 else WAVE2_POSITIONS
	var base := load("res://scenes/actors/base_enemy.tscn") as PackedScene
	var wolf_script := load("res://scenes/actors/melee_chaser.gd") as Script
	for i in positions.size():
		var enemy := base.instantiate() as Node3D
		enemy.name = "Wave%dEnemy%d" % [_wave_index, i + 1]
		enemy.set_script(wolf_script)
		enemy.set("spawn_position", to_global(positions[i]))
		enemy.set("patrol_radius", 4.0)
		enemy.position = positions[i]
		enemy.connect("enemy_died", _on_wave_enemy_died)
		add_child(enemy)
		_wave_enemies.append(enemy)
	if not main_world_mode:
		ComboNotifier.show_text(self, to_global(ARENA_CENTER + Vector3(0, 2.0, 24.0)), "第 %d 波敌人出现了！" % _wave_index, Color(1.0, 0.6, 0.4), 52)


func _on_wave_enemy_died(enemy: Node) -> void:
	_wave_enemies.erase(enemy)
	if not _wave_enemies.is_empty() or _waves_cleared:
		return
	if _wave_index < 2:
		_spawn_wave()
	else:
		_waves_cleared = true
		waves_cleared.emit()
		ComboNotifier.show_text(self, to_global(Vector3(0, 2.0, 10.0)), "前路已清空", Color(0.6, 0.9, 0.6), 56)


## ---- 战斗 ----


func _on_arena_trigger(body: Node3D) -> void:
	if not body.is_in_group("player") or _boss_dead:
		return
	if _boss != null and is_instance_valid(_boss):
		_boss.call("activate")
	_set_gate_closed(true)
	_boss_panel.visible = true
	body.call("add_camera_shake", 0.05, 0.5)
	HitEffect.spawn_burst(self, to_global(ARENA_CENTER + Vector3.UP), Color(0.5, 0.55, 0.4), 30, 3.0)
	print("[Dungeon] BOSS 战音乐切换（占位：待接入音频资产）")


func _on_boss_died(_enemy: Node) -> void:
	if _boss_dead:
		return
	_boss_dead = true
	_set_gate_closed(false)
	_set_exit_open(true)
	_boss_panel.visible = false
	var first_clear := false
	if _boss != null and is_instance_valid(_boss):
		first_clear = bool(_boss.get("just_first_cleared"))
	if first_clear:
		_show_clear_banner()
	boss_defeated.emit(first_clear)


func _show_clear_banner() -> void:
	_clear_banner.visible = true
	await get_tree().create_timer(3.5).timeout
	_clear_banner.visible = false


func _on_exit_interacted(player: Node) -> void:
	var player_controller := player as PlayerController
	if player_controller == null:
		return
	if not _boss_dead:
		player_controller.show_combat_feedback("石门紧闭——先击败苔冠巨兽", Color(0.85, 0.78, 0.6))
		return
	if main_world_mode:
		player_controller.show_combat_feedback("石门已开，直接步行返回森林", Color(0.6, 0.85, 0.7))
		return
	var manager := get_tree().get_first_node_in_group("dungeon_manager")
	if manager != null:
		manager.call("exit_dungeon")


## ---- 重置（玩家死亡后由管理器重新加载实现；本方法供测试与重复挑战） ----


func reset_dungeon() -> void:
	for enemy in _wave_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_wave_enemies.clear()
	for sprout in get_tree().get_nodes_in_group("boss_sprout"):
		if is_instance_valid(sprout) and is_ancestor_of(sprout):
			sprout.queue_free()
	if _boss != null and is_instance_valid(_boss):
		_boss.queue_free()
	_wave_index = 0
	_waves_cleared = false
	_boss_dead = false
	_set_gate_closed(false)
	_set_exit_open(false)
	_boss_panel.visible = false
	_clear_banner.visible = false
	_build_boss()
	_spawn_wave()


func _process(_delta: float) -> void:
	if _boss_panel == null or not _boss_panel.visible:
		return
	if _boss == null or not is_instance_valid(_boss):
		_boss_panel.visible = false
		return
	_boss_bar.max_value = float(_boss.get("max_health"))
	_boss_bar.value = float(_boss.get("current_health"))


func _on_nav_baked() -> void:
	_nav_ready = true
	var nav := get_node_or_null("NavRegion") as NavigationRegion3D
	if nav != null:
		print("[Dungeon] 导航网格烘焙完成：多边形 %d" % nav.navigation_mesh.get_polygon_count())
