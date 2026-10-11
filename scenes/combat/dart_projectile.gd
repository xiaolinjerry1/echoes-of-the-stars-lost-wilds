class_name DartProjectile
extends Node3D
## 同一把飞镖在环绕、投出、归航间切换，不生成攻击副本。
enum Flight { ORBIT, OUTBOUND, RETURN }
var combat: DartCombat
var slot := 0
var flight := Flight.ORBIT
var direction := Vector3.FORWARD
var age := 0.0
var damage := 0.0
var hit_ids: Dictionary = {}
var visual: Node3D
var trail: GPUParticles3D
func _ready() -> void:
	visual = (load(DartCombat.MODEL) as PackedScene).instantiate()
	add_child(visual)
	visual.scale = Vector3.ONE * 0.65
	var prefab := (load("res://art/models/prop/impact_shard.glb") as PackedScene).instantiate()
	var meshes := prefab.find_children("*","MeshInstance3D",true,false)
	trail=GPUParticles3D.new()
	trail.amount=10;trail.lifetime=0.16;trail.local_coords=false
	trail.draw_pass_1=(meshes[0] as MeshInstance3D).mesh
	prefab.free()
	var process := ParticleProcessMaterial.new()
	process.gravity=Vector3.ZERO
	process.scale_min=0.1;process.scale_max=0.2
	trail.process_material=process
	add_child(trail)
	trail.emitting=false
func throw(aim: Vector3) -> void:
	flight = Flight.OUTBOUND
	var pose := global_transform
	top_level = true
	global_transform = pose
	direction = aim.normalized()
	age = 0.0
	damage = combat.controller.attack_damage()
	hit_ids.clear()
	add_to_group("dart_projectile")
	trail.emitting=true
func orbit_point() -> Vector3:
	var a := combat.angle + TAU * slot / combat.darts.size()
	return combat.to_global(Vector3(cos(a)*combat.controller.orbit_radius(),1.0,sin(a)*combat.controller.orbit_radius()))
func _physics_process(delta: float) -> void:
	if not is_instance_valid(combat) or not is_instance_valid(combat.controller): return
	if combat.controller.player.is_dead():
		flight = Flight.ORBIT
		remove_from_group("dart_projectile")
	if flight == Flight.ORBIT:
		trail.emitting=false
		return
	age += delta
	var previous := global_position
	visual.rotation.z += delta * 28.0
	if flight == Flight.RETURN:
		var home := orbit_point()
		global_position = global_position.move_toward(home,delta*(38.0+combat.controller.move_speed())*minf(3.0,pow(0.75/combat.controller.attack_interval(),0.6)))
		if global_position.distance_to(home)<0.18:
			flight = Flight.ORBIT
			var pose := global_transform
			top_level = false
			global_transform = pose
			remove_from_group("dart_projectile")
		return
	var flight_speed := 28.0*minf(3.0,0.75/combat.controller.attack_interval())
	global_position += direction*flight_speed*delta
	var wall := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(previous,global_position,1))
	var end: Vector3 = wall.get("position",global_position)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not DartCombat.alive(enemy) or hit_ids.has(enemy.get_instance_id()): continue
		var center := DartCombat.hit_center(enemy)
		var reach := 1.0 if not bool(enemy.get("elite")) else 2.0
		if Geometry3D.get_closest_point_to_segment(center,previous,end).distance_to(center)<reach:
			hit_ids[enemy.get_instance_id()] = true
			combat.strike(enemy,damage,true)
			flight = Flight.RETURN
			break
	global_position = end
	if not wall.is_empty() or age>=18.0/flight_speed: flight = Flight.RETURN
