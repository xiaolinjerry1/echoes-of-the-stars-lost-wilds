extends Node3D
## 开发用任务系统测试场
## 职责：运行时异步烘焙导航网格；布置 4 NPC + 受伤巡林者、采集点、任务区域、
## 回响碑与任务目标怪，供完整任务流程（接取→进度→交付→奖励）测试。

func _ready() -> void:
	var region := get_node_or_null("NavRegion") as NavigationRegion3D
	if region != null:
		region.bake_finished.connect(func() -> void:
			print("[TestQuests] 导航网格已烘焙：多边形 %d" % region.navigation_mesh.get_polygon_count()))
		region.bake_navigation_mesh()
	print("[TestQuests] 任务测试场就绪（营地在出生点附近）")
