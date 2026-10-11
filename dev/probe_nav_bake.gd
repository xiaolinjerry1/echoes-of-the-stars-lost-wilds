extends Node3D
## 隔离测试：静态碰撞体与可视网格混合烘焙；HeightMapShape3D 不会产出导航多边形。

var _region: NavigationRegion3D


func _ready() -> void:
	call_deferred("_run")


func _flat_mesh(width: int, depth: int) -> PackedFloat32Array:
	var data := PackedFloat32Array()
	data.resize(width * depth)
	data.fill(0.0)
	return data


func _add_box_body(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.add_to_group("nav_source")
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, -size.y * 0.5, 0)
	body.add_child(col)
	parent.add_child(body)


func _add_plane_mesh(parent: Node3D, at: Vector3, size: Vector2) -> void:
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	mesh_instance.mesh = plane
	mesh_instance.position = at
	mesh_instance.add_to_group("nav_source")
	parent.add_child(mesh_instance)


func _run() -> void:
	var heightmap_body := StaticBody3D.new()
	heightmap_body.collision_layer = 1
	heightmap_body.add_to_group("nav_source")
	var height_shape := HeightMapShape3D.new()
	height_shape.map_width = 129
	height_shape.map_depth = 129
	height_shape.map_data = _flat_mesh(129, 129)
	var height_col := CollisionShape3D.new()
	height_col.shape = height_shape
	height_col.scale = Vector3(2, 1, 2)
	heightmap_body.add_child(height_col)
	add_child(heightmap_body)

	_add_box_body(self, Vector3(300, 0, 0), Vector3(60, 1, 60))
	_add_plane_mesh(self, Vector3(600, 0, 0), Vector2(60, 60))

	_region = NavigationRegion3D.new()
	var nav := NavigationMesh.new()
	nav.cell_size = 0.5
	nav.cell_height = 0.1
	nav.agent_height = 2.0
	nav.agent_radius = 0.5
	nav.agent_max_climb = 0.4
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH
	nav.geometry_collision_mask = 1
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav.geometry_source_group_name = "nav_source"
	_region.navigation_mesh = nav
	add_child(_region)
	await get_tree().process_frame
	_region.bake_navigation_mesh(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var vertices := _region.navigation_mesh.get_vertices()
	var hm_y := PackedFloat32Array()
	var box_y := PackedFloat32Array()
	var mesh_y := PackedFloat32Array()
	for vertex in vertices:
		if absf(vertex.x) < 70.0 and absf(vertex.z) < 70.0:
			hm_y.append(vertex.y)
		if absf(vertex.x - 300.0) < 70.0 and absf(vertex.z) < 70.0:
			box_y.append(vertex.y)
		if absf(vertex.x - 600.0) < 70.0 and absf(vertex.z) < 70.0:
			mesh_y.append(vertex.y)
	print("NAV_BAKE_TEST2 polygons=%d vertices=%d" % [_region.navigation_mesh.get_polygon_count(), vertices.size()])
	print("NAV_BAKE_TEST2 高图碰撞顶点=%d" % hm_y.size())
	print("NAV_BAKE_TEST2 方块碰撞顶点=%d y=%s" % [box_y.size(), str(box_y.slice(0, mini(4, box_y.size())))])
	print("NAV_BAKE_TEST2 平面网格顶点=%d y=%s" % [mesh_y.size(), str(mesh_y.slice(0, mini(4, mesh_y.size())))])
	get_tree().quit(0)
