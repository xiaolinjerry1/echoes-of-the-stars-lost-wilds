class_name ShadowBurst
extends Node3D
## 使用Blender飞镖网格播放影身聚散；仅运行时位移和淡出，不创建占位美术。
static func spawn(parent: Node, point: Vector3) -> void:
	var burst := ShadowBurst.new()
	parent.add_child(burst)
	burst.global_position=point
func _ready() -> void:
	for i in 8:
		var model := (load(DartCombat.MODEL) as PackedScene).instantiate() as Node3D
		add_child(model);model.scale=Vector3.ONE*0.16
		var angle := TAU*i/8.0
		model.position=Vector3(cos(angle)*0.2,0.8,sin(angle)*0.2)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(model,"position",Vector3(cos(angle)*1.8,1.4+sin(angle)*0.3,sin(angle)*1.8),0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(model,"rotation",Vector3(PI,angle,TAU*2),0.7)
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface).duplicate() as StandardMaterial3D
				if material==null:continue
				material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
				mesh.set_surface_override_material(surface,material)
				tween.tween_property(material,"albedo_color:a",0.0,0.6).set_delay(0.1)
	await get_tree().create_timer(0.75,false).timeout
	queue_free()
