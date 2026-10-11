class_name HordeDirector
extends Node3D
## 主世界刷怪节奏：离开安全营地后持续刷新，逐渐加密，最多45只额外敌人。
var player: PlayerController
var elapsed := 0.0
var timer := 1.0
var enabled := true
var rng := RandomNumberGenerator.new()
const LIMIT := 45
func _ready() -> void: rng.randomize()
func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(player) or player.is_dead():return
	if Vector2(player.global_position.x-WorldLayout.CAMP.x,player.global_position.z-WorldLayout.CAMP.z).length()<WorldLayout.CAMP_RADIUS+2:return
	elapsed+=delta;timer-=delta
	if timer>0:return
	for enemy in get_tree().get_nodes_in_group("horde_enemy"):
		if enemy.global_position.distance_to(player.global_position)>85.0:enemy.queue_free()
	timer=maxf(2.0,6.0-elapsed/90.0)
	var count := get_tree().get_nodes_in_group("horde_enemy").size()
	for i in mini(LIMIT-count,2+int(elapsed/90.0)):
		spawn_enemy()
func spawn_enemy() -> BaseEnemy:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map)==0:return null
	var point := Vector3.ZERO
	var valid := false
	for attempt in 8:
		var angle := rng.randf_range(0,TAU)
		var candidate := player.global_position+Vector3(cos(angle),0,sin(angle))*rng.randf_range(14.0,22.0)
		candidate.x=clampf(candidate.x,-120.0,120.0);candidate.z=clampf(candidate.z,-120.0,120.0)
		candidate.y=TerrainBuilder.height_at(candidate.x,candidate.z)
		point=NavigationServer3D.map_get_closest_point(map,candidate)
		if point.distance_to(candidate)<=3.0 and point.distance_to(player.global_position)>=10.0 and point.distance_to(WorldLayout.CAMP)>=WorldLayout.CAMP_RADIUS+3:
			valid=true;break
	if not valid:return null
	var enemy := (load("res://scenes/actors/base_enemy.tscn") as PackedScene).instantiate() as BaseEnemy
	var type := "wolf"
	if elapsed>45.0 and rng.randf()<0.25:type="boar"
	if elapsed>90.0 and rng.randf()<0.15:type="mage"
	enemy.set_script(load({"wolf":"res://scenes/actors/melee_chaser.gd","boar":"res://scenes/actors/charger.gd","mage":"res://scenes/actors/ranged_caster.gd"}[type]))
	enemy.position=to_local(point+Vector3.UP*0.1)
	enemy.spawn_position=point
	enemy.add_to_group("horde_enemy")
	add_child(enemy)
	enemy.detection_range=32.0
	enemy.aggro_range=40.0
	enemy.aggro_timer=12.0
	enemy._enter_combat(player)
	return enemy
