extends Node3D
## 挂接 Blender 瀑布资产、播放水幕UV，维护通往秘境的碰撞通道与潭水潮湿区。
@export var model_cliff_path := "res://art/models/scenery/waterfall_cliff.glb"
const POND_RADIUS := 5.8
var _flow_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	_add_asset(model_cliff_path, "Cliff", Vector3(0, 0, -7))
	for side in [-1.0, 1.0]:
		_add_body(Vector3(4.6, 5.5, 3.4), Vector3(side * 4.3, 2.75, -7))
	_add_body(Vector3(4.0, 2.5, 3.4), Vector3(0, 4.9, -7))
	var water_y := TerrainBuilder.pond_water_height() - global_position.y
	var curtain := _add_asset("res://art/models/scenery/waterfall_curtain.glb", "Curtain", Vector3(0, water_y, -5.1))
	var pond := _add_asset("res://art/models/scenery/waterfall_pond.glb", "Pond", Vector3(0, water_y, 0.4))
	_setup_water(curtain, true)
	_setup_water(pond, false)
	var zone := Area3D.new()
	zone.name = "PondWetZone"
	zone.set_script(load("res://scenes/world/water_zone.gd"))
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = POND_RADIUS - 0.2
	cylinder.height = 0.9
	shape.shape = cylinder
	shape.position = Vector3(0, water_y - 0.4, 0.4)
	zone.add_child(shape)
	add_child(zone)

func _add_asset(path: String, node_name: String, offset: Vector3) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("瀑布资产缺失：" + path)
		return null
	var model := packed.instantiate() as Node3D
	model.name = node_name
	model.position = offset
	add_child(model)
	return model

func _add_body(size: Vector3, offset: Vector3) -> void:
	var body := PropFactory.static_body(size, offset)
	body.add_to_group("nav_source")
	add_child(body)

func _setup_water(model: Node3D, flowing: bool) -> void:
	if model == null:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
			mat.render_priority = 2 if flowing else 1
			mesh.set_surface_override_material(surface, mat)
			if flowing:
				_flow_materials.append(mat)

func _process(delta: float) -> void:
	for material in _flow_materials:
		material.uv1_offset.y = fposmod(material.uv1_offset.y - delta * 0.35, 1.0)
