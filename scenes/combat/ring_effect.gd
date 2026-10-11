class_name RingEffect
extends MeshInstance3D
## RingEffect（地面圆环扩散特效）
## 职责：冰环等 AOE 的地面指示——从中心向外扩散并淡出的发光圆环，播完自动释放。

const LIFETIME := 0.5


## 在 parent 下生成一个扩散圆环；radius 为扩散到的最终半径（米）。
static func spawn(parent: Node, world_position: Vector3, color: Color, radius: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var effect := RingEffect.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.92
	mesh.outer_radius = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.85)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	effect.mesh = mesh
	parent.add_child(effect)
	effect.global_position = world_position
	effect.scale = Vector3(0.3, 0.05, 0.3)
	var tween := effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector3(radius, 0.05, radius), LIFETIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, LIFETIME).set_delay(0.15)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, LIFETIME).set_delay(0.15)
	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)
