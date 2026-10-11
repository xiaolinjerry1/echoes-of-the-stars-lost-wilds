class_name TerrainBuilder
extends Node3D
## TerrainBuilder（森林地形生成器）
## 职责：程序化生成 256×256 米起伏草地：地形网格 + 高图碰撞、土路、
## 溪流水面与潮湿触发区、道路两侧留空；树木/岩石用 MultiMesh 实例化并附带树干障碍，
## 障碍与地形碰撞标记 nav_source 供导航烘焙。地面/道路材质与树木来自 Blender；保留地形高度和物理生成逻辑。

const GROUND_TILE_METERS := 4.0
const GRASS_MATERIAL_MODEL := "res://art/models/scenery/forest_grass.glb"
const DIRT_MATERIAL_MODEL := "res://art/models/scenery/forest_dirt.glb"

const GRID_STEP := 2.0
const SIDE_VERTS := 129
const CREEK_HALF_WIDTH := 2.4
const CREEK_SLOPE := 3.5
const CREEK_DEPTH := 1.0
const WATER_OFFSET := 0.5
const TREE_SEED := 20261001

var _terrain_heights := PackedFloat32Array()
var _creek_material: StandardMaterial3D

static var _road_samples: Array = []
static var _creek_samples: Array = []


## 基础起伏（不含道路/溪流/台地修正）。
static func base_height(x: float, z: float) -> float:
	var h := 0.0
	h += sin(x * 0.021 + 0.7) * cos(z * 0.017 - 0.4) * 2.6
	h += sin(x * 0.043 + 1.7) * sin(z * 0.031 + 0.6) * 1.1
	h += cos(x * 0.011 + 3.0) * sin(z * 0.009 + 1.0) * 3.0
	return h


## 最终地形高度（道路压平、溪流下切、兴趣点台地、营地平台）。
static func pond_water_height() -> float:
	return base_height(18.0, 58.0) - CREEK_DEPTH + WATER_OFFSET


static func height_at(x: float, z: float) -> float:
	_ensure_samples()
	var h := base_height(x, z)
	var road := WorldLayout.nearest_sample(_road_samples, x, z)
	var road_dist := float(road["dist"])
	if road_dist < 4.0:
		var t := clampf((road_dist - 2.2) / 1.8, 0.0, 1.0)
		h = lerpf(float(road["base_h"]), h, t)
	for pad in WorldLayout.PADS:
		var center: Vector3 = pad[0]
		var radius := float(pad[1])
		var d := Vector2(x - center.x, z - center.z).length()
		if d < radius + 6.0:
			var t := clampf((d - radius) / 6.0, 0.0, 1.0)
			h = lerpf(base_height(center.x, center.z), h, t)
	var creek := WorldLayout.nearest_sample(_creek_samples, x, z)
	var creek_dist := float(creek["dist"])
	if creek_dist < CREEK_SLOPE:
		var creek_floor := float(creek["base_h"]) - CREEK_DEPTH
		if creek_dist < CREEK_HALF_WIDTH:
			h = creek_floor
		else:
			var t := clampf((creek_dist - CREEK_HALF_WIDTH) / (CREEK_SLOPE - CREEK_HALF_WIDTH), 0.0, 1.0)
			h = lerpf(creek_floor, h, t)
	# 潭底与溪流水位相接；只改变瀑布前的浅盆地，洞口台地保持。
	var pond_dist := Vector2(x - 18.0, z - 56.4).length()
	if pond_dist < 7.0:
		var shore := smoothstep(5.8, 7.0, pond_dist)
		h = lerpf(minf(h, pond_water_height() - 0.65), h, shore)
	var camp_d := Vector2(x - WorldLayout.CAMP.x, z - WorldLayout.CAMP.z).length()
	if camp_d < WorldLayout.CAMP_RADIUS + 8.0:
		var t := clampf((camp_d - WorldLayout.CAMP_RADIUS) / 8.0, 0.0, 1.0)
		h = lerpf(0.0, h, t)
	# 原60m林间秘境与森林共用地面；方形台地外围6m缓坡，南北门连续可走。
	var grove_d := maxf(absf(x - WorldLayout.GROVE.x), absf(z - WorldLayout.GROVE.z))
	if grove_d < 36.0:
		h = lerpf(0.0, h, smoothstep(30.0, 36.0, grove_d))
	return h


## 道路/溪流采样（懒加载缓存）。
static func _ensure_samples() -> void:
	if not _road_samples.is_empty():
		return
	for road in WorldLayout.ROADS:
		_road_samples.append_array(WorldLayout.sample_polyline(road, 3.0, base_height))
	_creek_samples = WorldLayout.sample_polyline(WorldLayout.CREEK, 2.0, base_height)


static func road_samples() -> Array:
	_ensure_samples()
	return _road_samples


static func creek_samples() -> Array:
	_ensure_samples()
	return _creek_samples


## 林区因子：北/东/西带为密林，中部与南部偏开阔。
static func forest_factor(x: float, z: float) -> float:
	var f := 0.0
	f += smoothstep(-30.0, -90.0, z) * 0.9
	f += smoothstep(42.0, 95.0, x) * 0.7
	f += smoothstep(-48.0, -100.0, x) * 0.8
	f += smoothstep(60.0, 110.0, z) * 0.35
	f += 0.12 * sin(x * 0.05) * cos(z * 0.06)
	return clampf(f, 0.0, 1.0)


func _ready() -> void:
	_build_terrain()
	_build_roads()
	_build_creek()
	_scatter_vegetation()
	_scatter_ground_grass()


## ---- 地形 ----


func _build_terrain() -> void:
	var heights := PackedFloat32Array()
	heights.resize(SIDE_VERTS * SIDE_VERTS)
	var forest_factor_map := PackedFloat32Array()
	forest_factor_map.resize(SIDE_VERTS * SIDE_VERTS)
	for zi in SIDE_VERTS:
		for xi in SIDE_VERTS:
			var x := -WorldLayout.HALF + xi * GRID_STEP
			var z := -WorldLayout.HALF + zi * GRID_STEP
			var h := height_at(x, z)
			heights[zi * SIDE_VERTS + xi] = h
			forest_factor_map[zi * SIDE_VERTS + xi] = forest_factor(x, z)
	_terrain_heights = heights
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass_light := Color(0.58, 0.72, 0.34)
	var grass_dark := Color(0.30, 0.48, 0.21)
	for zi in SIDE_VERTS - 1:
		for xi in SIDE_VERTS - 1:
			var p00 := _grid_vertex(xi, zi, heights)
			var p10 := _grid_vertex(xi + 1, zi, heights)
			var p01 := _grid_vertex(xi, zi + 1, heights)
			var p11 := _grid_vertex(xi + 1, zi + 1, heights)
			var f := (forest_factor_map[zi * SIDE_VERTS + xi] + forest_factor_map[(zi + 1) * SIDE_VERTS + xi + 1]) * 0.5
			var col := grass_light.lerp(grass_dark, f)
			_add_tri(st, p00, p10, p11, col)
			_add_tri(st, p00, p11, p01, col)
	st.generate_normals()
	var mesh := st.commit()
	var visual := MeshInstance3D.new()
	visual.name = "TerrainMesh"
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = _ground_material(GRASS_MATERIAL_MODEL, material)
	visual.mesh = mesh
	add_child(visual)
	# HeightMapShape3D 不会被 NavigationMesh 烘焙解析；用可视地形网格补足可行走面。
	visual.add_to_group("nav_source")

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var shape := CollisionShape3D.new()
	var height_shape := HeightMapShape3D.new()
	height_shape.map_width = SIDE_VERTS
	height_shape.map_depth = SIDE_VERTS
	var map_data := PackedFloat32Array()
	map_data.resize(SIDE_VERTS * SIDE_VERTS)
	for zi in SIDE_VERTS:
		for xi in SIDE_VERTS:
			map_data[zi * SIDE_VERTS + xi] = heights[zi * SIDE_VERTS + xi]
	height_shape.map_data = map_data
	shape.shape = height_shape
	# HeightMapShape3D 无间距参数：2 米格用 2× 缩放覆盖全图（±128m）
	shape.scale = Vector3(GRID_STEP, 1.0, GRID_STEP)
	body.add_child(shape)
	add_child(body)


func _grid_vertex(xi: int, zi: int, heights: PackedFloat32Array) -> Vector3:
	return Vector3(-WorldLayout.HALF + xi * GRID_STEP, heights[zi * SIDE_VERTS + xi], -WorldLayout.HALF + zi * GRID_STEP)


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for p in [a, b, c]:
		st.set_color(color)
		st.set_uv(Vector2(p.x, p.z) / GROUND_TILE_METERS)
		st.add_vertex(p)


## 只复用 Blender 导出样片的材质；不把样片网格放入世界或导航。
func _ground_material(model_path: String, fallback: Material) -> Material:
	if not ResourceLoader.exists(model_path):
		return fallback
	var packed := load(model_path) as PackedScene
	if packed == null:
		return fallback
	var instance := packed.instantiate()
	var imported_mesh := _find_mesh_instance(instance)
	instance.free()
	if imported_mesh == null or imported_mesh.get_surface_count() == 0:
		return fallback
	var imported := imported_mesh.surface_get_material(0)
	return fallback if imported == null else imported


## ---- 道路 ----


func _build_roads() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for road in WorldLayout.ROADS:
		var samples := WorldLayout.sample_polyline(road, 0.4, base_height)
		_build_ribbon(st, samples, 2.2, 0.06, Color(0.45, 0.36, 0.26))
	st.generate_normals()
	var mesh := st.commit()
	var visual := MeshInstance3D.new()
	visual.name = "RoadMesh"
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = _ground_material(DIRT_MATERIAL_MODEL, material)
	visual.mesh = mesh
	add_child(visual)


## 与TerrainMesh的三角剖分一致；贴花按实际网格高度贴地，避免穿过插值后的地面。
func surface_height_at(x: float, z: float) -> float:
	var gx := clampf((x + WorldLayout.HALF) / GRID_STEP, 0.0, SIDE_VERTS - 1.00001)
	var gz := clampf((z + WorldLayout.HALF) / GRID_STEP, 0.0, SIDE_VERTS - 1.00001)
	var xi := int(gx)
	var zi := int(gz)
	var tx := gx - xi
	var tz := gz - zi
	var h00 := _terrain_heights[zi * SIDE_VERTS + xi]
	var h10 := _terrain_heights[zi * SIDE_VERTS + xi + 1]
	var h01 := _terrain_heights[(zi + 1) * SIDE_VERTS + xi]
	var h11 := _terrain_heights[(zi + 1) * SIDE_VERTS + xi + 1]
	if tx >= tz:
		return h00 + (h10 - h00) * tx + (h11 - h10) * tz
	return h00 + (h11 - h01) * tx + (h01 - h00) * tz


## 相邻段共享截面；横向细分后贴合网格，UV继续使用Blender的软边材质。
func _build_ribbon(st: SurfaceTool, samples: Array, half_width: float, lift: float, color: Color, width_steps: int = 12) -> void:
	var sections: Array = []
	var traveled := 0.0
	for i in samples.size():
		var center: Vector2 = samples[i]["pos"]
		var before: Vector2 = samples[maxi(i-1,0)]["pos"]
		var after: Vector2 = samples[mini(i+1,samples.size()-1)]["pos"]
		var direction := (after-before).normalized()
		var normal := Vector2(-direction.y,direction.x) * half_width
		if i > 0:
			traveled += center.distance_to(before)
		var points: Array[Vector3] = []
		for k in width_steps+1:
			var pos := center + normal * (1.0-2.0*float(k)/width_steps)
			points.append(Vector3(pos.x,surface_height_at(pos.x,pos.y)+lift,pos.y))
		sections.append({"points":points,"v":traveled/GROUND_TILE_METERS})
	for i in sections.size()-1:
		for k in width_steps:
			var corners := [sections[i].points[k],sections[i].points[k+1],sections[i+1].points[k],sections[i+1].points[k+1]]
			var u0 := float(k)/width_steps
			var u1 := float(k+1)/width_steps
			var uvs := [Vector2(u0,sections[i].v),Vector2(u1,sections[i].v),Vector2(u0,sections[i+1].v),Vector2(u1,sections[i+1].v)]
			for index in [0,3,2,0,1,3]:
				st.set_color(color)
				st.set_uv(uvs[index])
				st.add_vertex(corners[index])


## ---- 溪流/水面/潮湿区 ----


## 播放Blender波纹贴图：仅滚动沿河UV，材质本身在Blender制作。
func _process(delta: float) -> void:
	if _creek_material != null:
		_creek_material.uv1_offset.y = fposmod(_creek_material.uv1_offset.y - delta * 0.025, 1.0)


func _build_creek() -> void:
	var samples := WorldLayout.sample_polyline(WorldLayout.CREEK, 0.25, base_height)
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.35, 0.6, 0.75, 0.55)
	fallback.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_creek_material = _ground_material("res://art/models/scenery/creek_water.glb", fallback).duplicate() as StandardMaterial3D
	# 两层透明材质需要固定顺序，避免较大的河岸包围盒把水面覆盖。
	_creek_material.render_priority = 1
	var bank_st := SurfaceTool.new()
	bank_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_ribbon(bank_st, samples, 3.8, 0.065, Color.WHITE, 24)
	bank_st.generate_normals()
	var bank := MeshInstance3D.new()
	bank.name = "CreekBank"
	bank.mesh = bank_st.commit()
	bank.material_override = _ground_material("res://art/models/scenery/creek_bank.glb", fallback)
	bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bank)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections: Array = []
	var distance := 0.0
	for i in samples.size():
		var center: Vector2 = samples[i]["pos"]
		var before: Vector2 = samples[maxi(0,i-1)]["pos"]
		var after: Vector2 = samples[mini(samples.size()-1,i+1)]["pos"]
		var direction := (after-before).normalized()
		var normal := Vector2(-direction.y,direction.x) * 2.2
		if i > 0:distance += center.distance_to(before)
		var level := float(samples[i]["base_h"]) - CREEK_DEPTH + WATER_OFFSET
		sections.append({"left":Vector3(center.x+normal.x,level,center.y+normal.y),"right":Vector3(center.x-normal.x,level,center.y-normal.y),"v":distance/GROUND_TILE_METERS})
	for i in sections.size()-1:
		var corners := [sections[i].left,sections[i].right,sections[i+1].left,sections[i+1].right]
		var uvs := [Vector2(0,sections[i].v),Vector2(1,sections[i].v),Vector2(0,sections[i+1].v),Vector2(1,sections[i+1].v)]
		for index in [0,3,2,0,1,3]:
			st.set_uv(uvs[index])
			st.add_vertex(corners[index])
	st.generate_normals()
	var water := MeshInstance3D.new()
	water.name = "CreekWater"
	water.material_override = _creek_material
	water.mesh = st.commit()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	var wet_samples := creek_samples()
	var zone := Area3D.new()
	zone.name = "WaterZone"
	zone.set_script(load("res://scenes/world/water_zone.gd"))
	for i in wet_samples.size()-1:
		var a: Vector2 = wet_samples[i]["pos"]
		var b: Vector2 = wet_samples[i+1]["pos"]
		var mid := (a+b)*0.5
		var length := a.distance_to(b)
		if length<0.5:continue
		var level := (float(wet_samples[i]["base_h"])+float(wet_samples[i+1]["base_h"]))*0.5-CREEK_DEPTH+WATER_OFFSET
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4.4, 0.9, length+0.5)
		shape.shape = box
		shape.position = Vector3(mid.x,level-0.4,mid.y)
		shape.rotation.y = atan2(b.x-a.x,b.y-a.y)
		zone.add_child(shape)
	add_child(zone)
	_scatter_river_pebbles(samples)


## Blender河床碎石的轻量实例；不增加行走障碍。
func _scatter_river_pebbles(samples: Array) -> void:
	var mesh := _scenery_mesh("res://art/models/scenery/river_pebbles.glb", null)
	if mesh == null:return
	var placements: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED+73
	for i in range(1,samples.size()-1,6):
		var a: Vector2=samples[i]["pos"]
		var b: Vector2=samples[i+1]["pos"]
		var direction := (b-a).normalized()
		var normal := Vector2(-direction.y,direction.x)
		for side in [-1.0,1.0]:
			var point: Vector2 = a+normal*float(side)*rng.randf_range(.7,3.0)
			var scale_factor := rng.randf_range(.6,1.3)
			var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_factor)
			placements.append(Transform3D(basis,Vector3(point.x,surface_height_at(point.x,point.y)+.07,point.y)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = placements.size()
	for i in placements.size():mm.set_instance_transform(i,placements[i])
	var visual := MultiMeshInstance3D.new()
	visual.name = "RiverPebbles"
	visual.multimesh = mm
	add_child(visual)


## ---- 植被/岩石 ----


func _scatter_vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var conifer := PackedVector3Array()
	var broadleaf := PackedVector3Array()
	var rock_spots := PackedVector3Array()
	for gx in range(-124, 125, 6):
		for gz in range(-124, 125, 6):
			var x := float(gx) + rng.randf_range(-2.5, 2.5)
			var z := float(gz) + rng.randf_range(-2.5, 2.5)
			if rng.randf() > 0.16 + forest_factor(x, z) * 0.5:
				continue
			if WorldLayout.near_road(road_samples(), x, z, 4.5):
				continue
			if Vector2(x - WorldLayout.CAMP.x, z - WorldLayout.CAMP.z).length() < WorldLayout.CAMP_RADIUS + 3.0:
				continue
			if WorldLayout.nearest_poi_distance(x, z) < 3.0:
				continue
			if float(WorldLayout.nearest_sample(creek_samples(), x, z)["dist"]) < 3.6:
				continue
			var spot := Vector3(x, 0, z)
			if rng.randf() < 0.5:
				conifer.append(spot)
			else:
				broadleaf.append(spot)
	for gx in range(-120, 121, 9):
		for gz in range(-120, 121, 9):
			if rng.randf() > 0.14:
				continue
			var x := float(gx) + rng.randf_range(-3.0, 3.0)
			var z := float(gz) + rng.randf_range(-3.0, 3.0)
			if WorldLayout.near_road(road_samples(), x, z, 3.0):
				continue
			if Vector2(x - WorldLayout.CAMP.x, z - WorldLayout.CAMP.z).length() < WorldLayout.CAMP_RADIUS:
				continue
			if float(WorldLayout.nearest_sample(creek_samples(), x, z)["dist"]) < 3.0:
				continue
			rock_spots.append(Vector3(x, 0, z))
	_place_multimesh("ConiferMesh", _scenery_mesh("res://art/models/scenery/tree_a.glb", _make_tree_mesh(true)), conifer, rng, 0.9, 1.4, 0.36)
	_place_multimesh("BroadleafMesh", _scenery_mesh("res://art/models/scenery/tree_b.glb", _make_tree_mesh(false)), broadleaf, rng, 0.85, 1.3, 0.34)
	_place_multimesh("RockMesh", _scenery_mesh("res://art/models/scenery/rock.glb", _make_rock_mesh()), rock_spots, rng, 0.6, 1.6, 0.0)


## Blender 草簇仅作装饰；独立随机源不改变树木/怪物路径，无物理或导航负担。
func _scatter_ground_grass() -> void:
	var mesh := _scenery_mesh("res://art/models/scenery/grass_tuft.glb", null)
	if mesh == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED + 17
	var placements: Array[Transform3D] = []
	for gx in range(-124, 125, 4):
		for gz in range(-124, 125, 4):
			if placements.size() >= 2200 or rng.randf() > 0.60:
				continue
			var x := float(gx) + rng.randf_range(-1.5, 1.5)
			var z := float(gz) + rng.randf_range(-1.5, 1.5)
			if WorldLayout.near_road(road_samples(), x, z, 2.7):
				continue
			if float(WorldLayout.nearest_sample(creek_samples(), x, z)["dist"]) < 3.6:
				continue
			if Vector2(x-WorldLayout.CAMP.x, z-WorldLayout.CAMP.z).length() < WorldLayout.CAMP_RADIUS:
				continue
			if WorldLayout.nearest_poi_distance(x, z) < 12.0:
				continue
			var scale_factor := rng.randf_range(0.65, 1.25)
			var basis := Basis(Vector3.UP, rng.randf()*TAU).scaled(Vector3.ONE*scale_factor)
			placements.append(Transform3D(basis, Vector3(x, height_at(x,z)-0.02, z)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = placements.size()
	for i in placements.size():
		multimesh.set_instance_transform(i, placements[i])
	var visual := MultiMeshInstance3D.new()
	visual.name = "GroundGrass"
	visual.multimesh = multimesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)


## 优先取 Blender glb 的首个网格用于 MultiMesh（自带 PBR 材质）；缺失时退回程序化网格。
func _scenery_mesh(model_path: String, fallback: ArrayMesh) -> ArrayMesh:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return fallback
	var packed := load(model_path) as PackedScene
	if packed == null:
		return fallback
	var instance := packed.instantiate()
	var mesh := _find_mesh_instance(instance)
	instance.free()
	return fallback if mesh == null else mesh


func _find_mesh_instance(node: Node) -> ArrayMesh:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			return mesh
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


func _place_multimesh(node_name: String, mesh: ArrayMesh, spots: PackedVector3Array, rng: RandomNumberGenerator, min_scale: float, max_scale: float, obstacle_radius: float) -> void:
	if spots.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = spots.size()
	var obstacles := StaticBody3D.new()
	obstacles.name = node_name + "Obstacles"
	obstacles.collision_layer = 1
	obstacles.collision_mask = 0
	obstacles.add_to_group("nav_source")
	for i in spots.size():
		var spot := spots[i]
		var scale_factor := rng.randf_range(min_scale, max_scale)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale_factor, scale_factor, scale_factor))
		var y := height_at(spot.x, spot.z) - 0.15
		multimesh.set_instance_transform(i, Transform3D(basis, Vector3(spot.x, y, spot.z)))
		if obstacle_radius > 0.0:
			var shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = obstacle_radius * scale_factor
			cylinder.height = 3.0 * scale_factor
			shape.shape = cylinder
			shape.position = Vector3(spot.x, y + cylinder.height * 0.5, spot.z)
			obstacles.add_child(shape)
		elif scale_factor > 1.15:
			var shape := CollisionShape3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = 0.9 * scale_factor
			shape.shape = sphere
			shape.position = Vector3(spot.x, y + 0.5 * scale_factor, spot.z)
			obstacles.add_child(shape)
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	# glb 资产自带材质；程序化占位网格才用顶点色材质
	if not _scenery_has_glb(node_name):
		instance.material_override = _veg_material()
	add_child(instance)
	add_child(obstacles)


func _scenery_has_glb(node_name: String) -> bool:
	match node_name:
		"ConiferMesh":
			return ResourceLoader.exists("res://art/models/scenery/tree_a.glb")
		"BroadleafMesh":
			return ResourceLoader.exists("res://art/models/scenery/tree_b.glb")
		"RockMesh":
			return ResourceLoader.exists("res://art/models/scenery/rock.glb")
	return false


func _veg_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	return material


## 合成树网格（树干 + 树冠，顶点色区分材质）。
func _make_tree_mesh(conifer: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.bottom_radius = 0.3
	trunk.top_radius = 0.2
	trunk.height = 4.2
	trunk.radial_segments = 6
	_append_primitive(st, trunk, Vector3(0.0, 2.1, 0.0), Color(0.33, 0.23, 0.15))
	if conifer:
		var layers := [
			[2.4, 2.6, 3.4], [1.9, 2.4, 4.9], [1.35, 2.2, 6.3],
		]
		var greens := [Color(0.20, 0.42, 0.18), Color(0.24, 0.48, 0.21), Color(0.28, 0.53, 0.24)]
		for i in layers.size():
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = layers[i][0]
			cone.height = layers[i][1]
			cone.radial_segments = 8
			_append_primitive(st, cone, Vector3(0.0, layers[i][2], 0.0), greens[i])
	else:
		var blobs := [
			[1.9, Vector3(0.30, 5.0, 0.0)], [1.5, Vector3(0.45, 6.2, 0.0)], [1.4, Vector3(0.25, 4.4, 0.0)],
		]
		for blob in blobs:
			var sphere := SphereMesh.new()
			sphere.radius = blob[0]
			sphere.height = blob[0] * 2.0 * 0.75
			sphere.radial_segments = 8
			sphere.rings = 5
			_append_primitive(st, sphere, blob[1], Color(0.27, 0.50, 0.22))
	st.generate_normals()
	return st.commit()


func _make_rock_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blobs := [
		[1.0, Vector3(0, 0.45, 0)], [0.6, Vector3(0.7, 0.35, 0.3)], [0.5, Vector3(-0.6, 0.3, -0.2)],
	]
	for blob in blobs:
		var sphere := SphereMesh.new()
		sphere.radius = blob[0]
		sphere.height = blob[0] * 1.3
		sphere.radial_segments = 7
		sphere.rings = 4
		_append_primitive(st, sphere, blob[1], Color(0.45, 0.44, 0.42))
	st.generate_normals()
	return st.commit()


## 将基础网格平移合并进 SurfaceTool，并填入统一顶点色。
func _append_primitive(st: SurfaceTool, mesh: Mesh, offset: Vector3, color: Color) -> void:
	var source := mesh.surface_get_arrays(0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	for v in source[Mesh.ARRAY_VERTEX]:
		verts.append((v as Vector3) + offset)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = source[Mesh.ARRAY_NORMAL]
	arrays[Mesh.ARRAY_INDEX] = source[Mesh.ARRAY_INDEX]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var part := ArrayMesh.new()
	part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.append_from(part, 0, Transform3D())
