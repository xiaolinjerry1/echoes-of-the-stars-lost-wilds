class_name ShadowClone
extends CharacterBody3D
## 同模型、同体型、同成长数据的影分身；优先攻击本体标记/正在追击本体的敌人。
var controller: DartMasterController
var index := 0
var combat: DartCombat
var visual: Node3D
var animator: AnimationPlayer
var motion := DartAnimator.new()
var agent: NavigationAgent3D
var target: Node3D
var think := 0.0
var anim_lock := 0.0
var current_health := 200.0
var max_health := 200.0
var release_left := 0.0
var release_direction := Vector3.FORWARD
var facing_angle := PI

func _ready() -> void:
	add_to_group("shadow_clone")
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	visual = (load(DartMasterController.MODEL) as PackedScene).instantiate()
	add_child(visual)
	animator = visual.find_child("AnimationPlayer",true,false)
	motion.setup(visual)
	if animator != null:
		for key in animator.get_animation_list():
			if key.ends_with("_idle") or key.ends_with("_run"):animator.get_animation(key).loop_mode=Animation.LOOP_LINEAR
	max_health = controller.player.stats.max_health
	current_health = controller.player.stats.current_health
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 1.4
	add_child(agent)
	combat = DartCombat.new()
	add_child(combat)
	combat.setup(self,controller)
	play("idle")

func choose_target() -> Node3D:
	var best_score := -INF
	var best: Node3D
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not DartCombat.alive(enemy): continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance > 32.0: continue
		var hostility := int(enemy.get("state")) in [1,2]
		var priority := controller.marked.has(enemy.get_instance_id()) or hostility
		var score := (1000.0 if priority else 0.0) - distance
		if score > best_score: best_score = score; best = enemy
	return best

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or controller.player.is_dead() or controller.ultimate_left <= 0.0:
		queue_free()
		return
	think -= delta
	if release_left>0.0:
		release_left-=delta
		if release_left<=0.0:combat.launch(release_direction,true)
	anim_lock = maxf(0.0,anim_lock-delta)
	if think <= 0.0:
		think = 0.2
		target = choose_target()
		var destination: Vector3 = target.global_position if is_instance_valid(target) else controller.player.global_position + Vector3(cos(index*TAU/3),0,sin(index*TAU/3))*3.0
		agent.target_position = destination
	var direction := Vector3.ZERO
	if is_instance_valid(target):
		var distance := global_position.distance_to(target.global_position)
		if distance > controller.orbit_radius()*0.8:
			direction = agent.get_next_path_position()-global_position
		if distance < 28.0:
			var aim := (DartCombat.hit_center(target)-global_position-Vector3.UP*1.1).normalized()
			var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.1,DartCombat.hit_center(target),1)
			if not combat.busy() and combat.cooldown<=0.0 and release_left<=0.0 and get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				release_left=0.18*minf(1.0,controller.attack_interval()/0.6);release_direction=aim;combat.cooldown=controller.attack_interval()
				play("cast")
				anim_lock = 0.4
				facing_angle=atan2(-aim.x,-aim.z)+PI
	else:
		if global_position.distance_to(controller.player.global_position) > 4.0: direction = agent.get_next_path_position()-global_position
	direction.y = 0.0
	direction = direction.normalized()
	velocity.x = direction.x*controller.move_speed()
	velocity.z = direction.z*controller.move_speed()
	if not is_on_floor(): velocity.y -= 25.0*delta
	move_and_slide()
	motion.tick(Vector2(velocity.x,velocity.z).length(),controller.move_speed(),delta,controller.attack_interval())
	if anim_lock <= 0.0:
		play("run" if direction.length_squared()>0.01 else "idle")
		if direction.length_squared()>0.01:facing_angle=atan2(-direction.x,-direction.z)+PI
	visual.rotation.y=lerp_angle(visual.rotation.y,facing_angle,delta*12)
	if global_position.distance_to(controller.player.global_position)>45.0 or global_position.y < -15:
		global_position = controller.player.global_position+Vector3(1+index,0.5,0)

func take_damage(amount: float, _source: Node = null) -> float:
	var final := DamageCalculator.apply_armor(amount,controller.player.stats.armor)
	current_health = maxf(0.0,current_health-final)
	if current_health <= 0.0: queue_free()
	return final

func play(clip: String) -> void:
	if motion.tree != null:
		motion.play(clip)
		return
	if animator == null: return
	for key in animator.get_animation_list():
		if key.ends_with("_"+clip) or key == clip:
			if animator.current_animation != key: animator.play(key,0.12)
			return
