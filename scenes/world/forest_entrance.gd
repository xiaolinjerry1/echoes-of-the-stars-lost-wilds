extends Node3D
## 森林区域主场景（森林入口）
## 职责：组装地形/导航/分块流式加载/营地与兴趣点/昼夜/天气；管理玩家出生点；
## GameSession 实例化本场景、先启动分块加载，全部就绪后烘焙导航，再绑定玩家。

@onready var streamer: WorldStreamer = $NavRegion/Streamer
@onready var day_night: DayNightCycle = $DayNight
@onready var weather: WeatherSystem = $Weather
@onready var nav_region: NavigationRegion3D = $NavRegion

var _player: Node3D


func _ready() -> void:
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map,0.1)
	var grove := (load("res://scenes/world/main_world_grove.tscn") as PackedScene).instantiate() as Node3D
	grove.position = WorldLayout.GROVE
	nav_region.add_child(grove)
	var wyvern := (load("res://scenes/actors/dread_wyvern.tscn") as PackedScene).instantiate() as Node3D
	wyvern.position = WorldLayout.WYVERN_NEST + Vector3(0, 12, 0)
	nav_region.add_child(wyvern)
	nav_region.bake_finished.connect(_on_nav_baked)
	streamer.all_loaded.connect(_on_all_chunks_loaded)
	streamer.setup(null, WorldLayout.CHUNKS.keys())
	print("[ForestEntrance] 森林世界已生成（256×256 m），分块加载已启动")


func _on_all_chunks_loaded() -> void:
	print("[ForestEntrance] 分块内容全部就绪，开始烘焙导航网格")
	nav_region.bake_navigation_mesh(true)


func _on_nav_baked() -> void:
	print("[ForestEntrance] 导航网格烘焙完成：多边形 %d" % nav_region.navigation_mesh.get_polygon_count())


## 玩家就绪后调用：绑定流式加载与天气跟随。
func setup_player(player: Node3D) -> void:
	_player = player
	streamer.setup(player, WorldLayout.CHUNKS.keys())
	weather.set_player(player)
	var controller := player as PlayerController
	if controller != null and not controller.stats.died.is_connected(_reset_grove_after_death):
		controller.stats.died.connect(_reset_grove_after_death)


## 死亡仍在森林营地复活；等玩家离开战斗位置后复位场地，不切换世界。
func _reset_grove_after_death() -> void:
	await get_tree().create_timer(3.5).timeout
	var grove := get_node_or_null("NavRegion/MainWorldGrove")
	if grove != null: grove.reset_dungeon()


## 玩家出生点（营地篝火旁）。
func get_spawn_position() -> Vector3:
	return WorldLayout.CAMPFIRE + Vector3(0.0, 0.4, 2.5)


func is_world_ready() -> bool:
	return streamer.is_world_ready()


func get_camp_position() -> Vector3:
	return WorldLayout.CAMP
