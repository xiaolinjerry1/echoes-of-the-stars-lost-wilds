class_name DartCombat
extends Node3D
## 共享飞镖战斗：实际环绕飞镖依次投出并归航；玩家和分身读取同一成长数据。
var controller: Node
var actor: Node3D
var darts: Array[Node3D] = []
var angle := 0.0
var cooldown := 0.0
var hit_times: Dictionary = {}
var volley_count := 0
var feedback_times: Dictionary = {}
var launch_queue: Array[DartProjectile] = []
var launch_direction := Vector3.FORWARD
var launch_point := Vector3.ZERO
var launch_timer := 0.0
func busy() -> bool:
	return not launch_queue.is_empty() or darts.any(func(d): return d.flight != DartProjectile.Flight.ORBIT)
const MODEL := "res://art/models/prop/shadow_dart.glb"

func setup(owner_actor: Node3D, growth: Node) -> void:
	actor = owner_actor
	controller = growth
	rebuild()

func rebuild() -> void:
	# 保留已有实体及在途状态，强化数量只补充新槽位。
	while darts.size() < controller.dart_count():
		var dart := DartProjectile.new()
		dart.combat = self
		dart.slot = darts.size()
		add_child(dart)
		darts.append(dart)
	while darts.size() > controller.dart_count():
		var dart: Node3D = darts.pop_back()
		launch_queue.erase(dart)
		dart.queue_free()
	_place_darts()

func recall() -> void:
	launch_queue.clear()
	cooldown=0.0
	launch_timer=0.0
	for dart in darts:
		dart.top_level=false
		dart.flight=DartProjectile.Flight.ORBIT
		dart.remove_from_group("dart_projectile")
		dart.trail.emitting=false
	_place_darts()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not is_instance_valid(actor):
		return
	cooldown = maxf(0.0, cooldown - delta)
	if controller.player.is_dead():
		recall()
		return
	if controller.windup>0.0: return
	launch_timer -= delta
	if not launch_queue.is_empty() and launch_timer <= 0.0:
		var dart: DartProjectile = launch_queue.pop_front()
		dart.throw((launch_point-dart.global_position).normalized())
		launch_timer = clampf(controller.attack_interval()/maxi(6,darts.size()),0.025,0.09)
		SurvivorAudio.play(actor.get_parent(),"dart_volley",dart.global_position)
	var old_positions: Array[Vector3] = []
	for dart in darts:
		old_positions.append(dart.global_position)
	angle = fposmod(angle + delta * 2.4 / controller.attack_interval(), TAU)
	_place_darts()
	var now := Time.get_ticks_msec() * 0.001
	for target in get_tree().get_nodes_in_group("enemy"):
		if not alive(target) or actor.global_position.distance_to(target.global_position) > controller.orbit_radius() + 3.0:
			continue
		var center: Vector3 = hit_center(target)
		var reach := 0.7
		if bool(target.get("elite")):
			reach = 1.3
		if str(target.get("enemy_id")) == "moss_crown_beast":
			reach = 2.3
		for i in darts.size():
			if darts[i].flight != DartProjectile.Flight.ORBIT: continue
			var key := "%d:%d" % [target.get_instance_id(), i]
			if now - float(hit_times.get(key, -100.0)) < controller.attack_interval():
				continue
			var closest := Geometry3D.get_closest_point_to_segment(center, old_positions[i], darts[i].global_position)
			if closest.distance_to(center) <= reach:
				var query := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP,center,1)
				if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
				hit_times[key] = now
				strike(target, controller.attack_damage(), false)
	if hit_times.size() > 600:
		for key in hit_times.keys():
			if now - float(hit_times[key]) > 5.0:
				hit_times.erase(key)

func _place_darts() -> void:
	for i in darts.size():
		if darts[i].flight != DartProjectile.Flight.ORBIT: continue
		var a := angle + TAU * i / darts.size()
		darts[i].position = Vector3(cos(a) * controller.orbit_radius(), 1.0, sin(a) * controller.orbit_radius())
		darts[i].rotation = Vector3(PI / 2.0, a, a * 3.0)

func launch(direction: Vector3, released := false) -> bool:
	if busy() or (cooldown > 0.0 and not released) or controller.player.is_dead(): return false
	if not released: cooldown = controller.attack_interval()
	volley_count += 1
	launch_direction = direction.normalized()
	var origin := actor.global_position+Vector3.UP*1.1
	launch_point=origin+launch_direction*18.0
	var best := 0.96
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not alive(enemy):continue
		var offset := hit_center(enemy)-origin
		if offset.length()<28.0 and offset.length()>0.1 and offset.normalized().dot(launch_direction)>best:
			var ray := PhysicsRayQueryParameters3D.create(origin,hit_center(enemy),1)
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
			best=offset.normalized().dot(launch_direction)
			launch_point=hit_center(enemy)
	launch_timer = 0.0
	for dart in darts: launch_queue.append(dart as DartProjectile)
	return true

func strike(target: Node, amount: float, thrown: bool) -> void:
	if controller.player.is_dead() or not alive(target):
		return
	controller.mark_target(target)
	var before: float=target.get("current_health")
	target.call("take_damage", amount, controller.player)
	var dealt := before-float(target.get("current_health"))
	if dealt<=0.0:return
	SurvivorAudio.play(target.get_parent(),"dart_hit",hit_center(target),-18.0)
	var now := Time.get_ticks_msec()*0.001
	var id := target.get_instance_id()
	if now-float(feedback_times.get(id,-100.0))>0.1:
		feedback_times[id]=now
		CombatImpact.spawn(target.get_parent(),hit_center(target),(hit_center(target)-actor.global_position).normalized(),thrown)
		if thrown and actor == controller.player: controller.player.add_camera_shake(0.025,0.10)
		DamageNumber.spawn(target.get_parent(),hit_center(target)+Vector3.UP*0.3,dealt,false,Color(0.75,0.82,1.0))
	controller.on_hit(thrown)

static func alive(target: Node) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and int(target.get("state")) != 5 and float(target.get("current_health")) > 0.0

static func hit_center(target: Node3D) -> Vector3:
	var height := 3.3 if str(target.get("enemy_id"))=="dread_wyvern" else (2.3 if str(target.get("enemy_id"))=="moss_crown_beast" else minf(1.1,float(target.get("health_bar_height"))*0.5))
	return target.global_position+Vector3.UP*height
