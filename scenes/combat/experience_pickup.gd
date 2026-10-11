class_name ExperiencePickup
extends Node3D
## 击杀经验结晶：3.5米内自动吸附，领取一次后立即移出掉落集合。
var amount := 8
var collected := false
var age := 0.0
var visual: Node3D
static func spawn(parent: Node, point: Vector3, value: int) -> void:
	var pickup := ExperiencePickup.new()
	pickup.amount=value
	parent.add_child(pickup)
	point.y=TerrainBuilder.height_at(point.x,point.z)+0.55
	pickup.global_position=point
func _ready() -> void:
	add_to_group("experience_pickup")
	visual=(load("res://art/models/prop/experience_crystal.glb") as PackedScene).instantiate()
	add_child(visual)
	visual.scale=Vector3.ONE*0.45
func _physics_process(delta: float) -> void:
	age+=delta
	visual.rotation.y+=delta*1.8
	visual.position.y=sin(age*2.5)*0.08
	if collected:return
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player==null or player.is_dead():return
	var distance := global_position.distance_to(player.global_position+Vector3.UP*0.8)
	if distance<3.5 or age>45.0:
		global_position=global_position.move_toward(player.global_position+Vector3.UP*0.8,delta*12.0)
	if distance<0.65:
		collected=true
		remove_from_group("experience_pickup")
		player.survivor.add_experience(amount)
		queue_free()
