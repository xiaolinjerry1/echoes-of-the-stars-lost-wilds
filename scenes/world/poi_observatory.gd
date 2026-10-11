extends Node3D
## 挂接Blender观测台遗迹资产，保持柱环布局、回响碑台座和导航碰撞。
@export var model_pillar_path := "res://art/models/scenery/stone_pillar.glb"
const PILLAR_RADIUS := 6.5

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11068
	for i in 6:
		var angle := TAU * i / 6.0
		var height := 3.0 + rng.randf_range(-0.2, 0.5)
		var offset := Vector3(cos(angle)*PILLAR_RADIUS,0,sin(angle)*PILLAR_RADIUS)
		var pillar := _model(model_pillar_path,"Pillar%d" % i,offset)
		pillar.scale.y = height / 3.6
		_body("PillarBody%d" % i,Vector3(1.28,height,1.28),offset+Vector3(0,height/2,0))
	_model("res://art/models/scenery/observatory_pillar_broken.glb","BrokenPillar",Vector3(2.2,0,7.4))
	_body("BrokenPillarBody",Vector3(1.22,1.3,1.22),Vector3(2.2,.65,7.4))
	var yaw := rng.randf_range(0.0,TAU)
	_model("res://art/models/scenery/observatory_pillar_fallen.glb","FallenPillar",Vector3(9.2,0,2.4)).rotation.y = yaw
	_body("FallenPillarBody",Vector3(3.3,.94,.94),Vector3(9.2,.47,2.4)).rotation.y = yaw
	var walls := [[Vector3(-10.5,0,-3),.5],[Vector3(7.5,0,-8),-.6],[Vector3(-3,0,10.5),1.3]]
	for i in walls.size():
		var offset: Vector3 = walls[i][0]
		_model("res://art/models/scenery/observatory_wall.glb","Wall%d" % i,offset).rotation.y = walls[i][1]
		_body("WallBody%d" % i,Vector3(3.65,1.35,.6),offset+Vector3(0,.675,0)).rotation.y = walls[i][1]

func _model(path: String, node_name: String, offset: Vector3) -> Node3D:
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.name = node_name
	model.position = offset
	add_child(model)
	return model

func _body(node_name: String, size: Vector3, offset: Vector3) -> StaticBody3D:
	var body := PropFactory.static_body(size,offset)
	body.name = node_name
	body.add_to_group("nav_source")
	add_child(body)
	return body

func _step(radius: float, height: float, y: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.position.y = y
	body.add_child(shape)
	add_child(body)
