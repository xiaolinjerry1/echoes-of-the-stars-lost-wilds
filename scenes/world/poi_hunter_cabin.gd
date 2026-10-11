extends Node3D
## 挂接Blender猎人木屋、残墙和断栅栏，维护建筑碰撞与周边任务通行。
@export var model_path := "res://art/models/scenery/hunter_cabin.glb"

func _ready() -> void:
	_add_model(model_path, "CabinVisual", Vector3.ZERO)
	_add_body("CabinCollision", Vector3(4.6, 3.0, 3.8), Vector3(0, 1.5, 0))
	var wall := _add_model("res://art/models/scenery/hunter_broken_wall.glb", "BrokenWallVisual", Vector3(5.6, 0, -1.5))
	wall.rotation.y = 0.7
	var body := _add_body("BrokenWallCollision", Vector3(3.0, 1.3, 0.6), Vector3(5.6, 0.65, -1.5))
	body.rotation.y = 0.7
	_add_model("res://art/models/scenery/hunter_fence.glb", "FenceVisual", Vector3(-3.2, 0, 3.6))
	for x in [-4.45, -1.95]:
		_add_body("FenceCollision", Vector3(2.0, 1.1, 0.35), Vector3(x, 0.55, 3.6))

func _add_model(path: String, node_name: String, offset: Vector3) -> Node3D:
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.name = node_name
	model.position = offset
	add_child(model)
	return model

func _add_body(node_name: String, size: Vector3, offset: Vector3) -> StaticBody3D:
	var body := PropFactory.static_body(size, offset)
	body.name = node_name
	body.add_to_group("nav_source")
	add_child(body)
	return body
