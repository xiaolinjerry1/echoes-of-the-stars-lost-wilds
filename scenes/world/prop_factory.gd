class_name PropFactory
extends RefCounted
## PropFactory（道具占位工厂）
## 职责：统一生成场景道具的占位几何与材质，并在 Blender glb 就绪后无缝替换：
## model_node() 优先加载 model_path 指向的 glb，缺失时退回程序化占位。

static func material(color: Color, roughness := 0.85, metallic := 0.0, emission := Color.BLACK, emission_energy := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


static func box(size: Vector3, color: Color, position := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = position
	return node


static func cylinder(radius: float, height: float, color: Color, position := Vector3.ZERO, top_radius := -1.0, segments := 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = position
	return node


static func sphere(radius: float, color: Color, position := Vector3.ZERO) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = position
	return node


## 优先返回 glb 模型实例（模型自带 PBR），缺失时返回 fallback 占位。
static func model_node(model_path: String, fallback: Node3D) -> Node3D:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return fallback
	var packed := load(model_path) as PackedScene
	if packed == null:
		return fallback
	var wrapper := Node3D.new()
	wrapper.add_child(packed.instantiate())
	return wrapper


## 带碰撞的静态障碍（用于树木/岩石之外的建筑占位）。
static func static_body(box_size: Vector3, position := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box_size
	shape.shape = box_shape
	body.add_child(shape)
	return body


## 可交互区域（附 Interactable 组件与盒型触发范围）。
static func interactable(interact_text: String, trigger_size: Vector3, offset := Vector3.ZERO) -> Interactable:
	var area := Interactable.new()
	area.name = "Interactable"
	area.interact_text = interact_text
	area.position = offset
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = trigger_size
	shape.shape = box_shape
	area.add_child(shape)
	return area
