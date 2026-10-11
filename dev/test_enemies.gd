extends Node3D
## 开发用怪物 AI 测试场
## 职责：运行时异步烘焙导航网格，供怪物 NavigationAgent3D 寻路；
## 观察四种怪物的巡逻/追击/攻击/脱战行为与冲锋预警。
## 注：烘焙失败/未完成时怪物自动退化为直线移动（不影响逻辑测试）。

func _ready() -> void:
	var region := get_node_or_null("NavRegion") as NavigationRegion3D
	if region == null:
		return
	region.bake_finished.connect(func() -> void:
		print("[TestEnemies] 导航网格已烘焙：多边形 %d" % region.navigation_mesh.get_polygon_count()))
	region.bake_navigation_mesh()
	print("[TestEnemies] 导航烘焙已提交（异步）")
