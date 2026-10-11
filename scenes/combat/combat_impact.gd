class_name CombatImpact
extends Node3D
## Blender 火花碎片的短促命中反馈；限制同时存在数量，避免群体攻击堆积。
var age := 0.0
var shards: Array[Node3D] = []
var velocities: Array[Vector3] = []
var intensity := 1.0
var flash: Node3D
static func spawn(parent: Node, point: Vector3, direction: Vector3, thrown: bool) -> void:
	if parent.get_tree().get_nodes_in_group("combat_impact").size()>=48: return
	var effect := CombatImpact.new()
	parent.add_child(effect)
	effect.global_position = point
	effect.add_to_group("combat_impact")
	effect.intensity=1.6 if thrown else 0.9
	effect.flash=(load("res://art/models/prop/boss_shock_ring.glb") as PackedScene).instantiate()
	effect.add_child(effect.flash)
	effect.flash.quaternion=Quaternion(Vector3.UP,-direction.normalized())
	effect.flash.scale=Vector3.ONE*0.15
	var packed := load("res://art/models/prop/impact_shard.glb") as PackedScene
	for i in (9 if thrown else 5):
		var shard := packed.instantiate() as Node3D
		effect.add_child(shard)
		shard.scale = Vector3.ONE*(1.25 if thrown else 0.8)
		var velocity := (Vector3(randf_range(-1,1),randf_range(-0.4,1.3),randf_range(-1,1))-direction*0.6).normalized()*randf_range(3.0,6.0)
		shard.quaternion = Quaternion(Vector3.UP,velocity.normalized())
		effect.shards.append(shard)
		effect.velocities.append(velocity)
func _process(delta: float) -> void:
	age += delta
	flash.visible=age<0.13
	flash.scale=Vector3.ONE*(0.15+age*2.2)
	for i in shards.size():
		shards[i].position += velocities[i]*delta
		velocities[i].y -= delta*8.0
		shards[i].scale = Vector3.ONE*intensity*maxf(0.0,1.0-age/0.28)
	if age>=0.28: queue_free()
