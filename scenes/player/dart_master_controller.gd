class_name DartMasterController
extends Node
## 第三人称飞镖师：移动、经验成长、三选一强化、回响蓄力及同数值AI影分身。
const UPGRADE_IDS := ["count", "speed", "damage", "move", "duration"]
const MODEL := "res://art/models/player/dart_master.glb"
var player: PlayerController
var combat: DartCombat
var hud: SurvivorHUD
var visual: Node3D
var animator: AnimationPlayer
var motion := DartAnimator.new()
var ranks := {"count":0,"speed":0,"damage":0,"move":0,"duration":0}
var pending_choices := 0
var offered: Array = []
var echo_value := 0.0
var windup := 0.0
var ultimate_left := 0.0
var ultimate_total := 10.0
var clones: Array[ShadowClone] = []
var marked: Dictionary = {}
var kills := 0
var animation_lock := 0.0
var yaw := 0.0
var pitch := -0.30
var knockback := Vector3.ZERO
var queued_attack := 0.0
var queued_direction := Vector3.FORWARD
var facing_angle := PI
var _feedback_time := 0.0
var jump_buffer := 0.0
var coyote_left := 0.0

func dart_count() -> int: return 6 + int(ranks.count) * 2
func orbit_radius() -> float: return 2.2 + int(ranks.count) * 0.35
func attack_interval() -> float: return 0.12 + 0.63 * pow(0.86, int(ranks.speed))
func attack_damage() -> float: return (18.0 + (player.stats.level-1) * 2.0) * (1.0 + int(ranks.damage) * 0.25)
func move_speed() -> float: return 6.5 * (1.0 + int(ranks.move) * 0.08)
func ultimate_duration() -> float: return 10.0 + int(ranks.duration) * 2.0

func setup(owner_player: PlayerController) -> void:
	player = owner_player
	visual = (load(MODEL) as PackedScene).instantiate()
	player.get_node("Visual").add_child(visual)
	animator = visual.find_child("AnimationPlayer",true,false) as AnimationPlayer
	motion.setup(visual)
	player.get_node("Visual").rotation.y=PI
	if animator != null:
		for key in animator.get_animation_list():
			if key.ends_with("_idle") or key.ends_with("_run") or key.ends_with("_walk"):
				animator.get_animation(key).loop_mode=Animation.LOOP_LINEAR
	combat = DartCombat.new()
	player.add_child(combat)
	combat.setup(player,self)
	hud = player.get_node("HUD") as SurvivorHUD
	hud.setup(self)
	player.stats.level_up.connect(_level_up)
	player.camera_pivot.add_excluded_object(player.get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	play_animation("idle")

func tick(delta: float) -> void:
	if Input.is_action_just_pressed("jump") and not hud.panel_open(): jump_buffer = 0.16
	if queued_attack>0.0:
		queued_attack-=delta
		if queued_attack<=0.0 and not player.is_dead() and not player.has_effect("frozen") and not player.has_effect("stunned"):
			combat.launch(queued_direction,true)
	animation_lock = maxf(0.0, animation_lock-delta)
	_feedback_time = maxf(0.0,_feedback_time-delta)
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			_spawn_clones()
	elif ultimate_left > 0.0:
		ultimate_left = maxf(0.0,ultimate_left-delta)
		echo_value = 100.0 * ultimate_left / ultimate_total
		if ultimate_left <= 0.0:
			end_ultimate()
	for id in marked.keys():
		marked[id] = float(marked[id]) - delta
		if float(marked[id]) <= 0.0:
			marked.erase(id)
	if not player.is_dead() and not player.has_effect("frozen") and not player.has_effect("stunned") and Input.is_action_pressed("attack") and not hud.panel_open() and windup <= 0.0:
		fire()

func move(delta: float) -> void:
	if player.is_dead():
		return
	var input := Input.get_vector("move_left","move_right","move_forward","move_back")
	if player.dialogue_active:input=Vector2.ZERO
	var direction := Vector3(input.x,0,input.y).rotated(Vector3.UP,yaw)
	if player.has_effect("rooted") or player.has_effect("frozen") or player.has_effect("stunned"):
		direction = Vector3.ZERO
	var speed := move_speed() * (0.4 if windup > 0.0 else 1.0) * (0.65 if player.has_effect("chilled") else 1.0)
	player.velocity.x = move_toward(player.velocity.x,direction.x*speed,delta*40) + knockback.x
	player.velocity.z = move_toward(player.velocity.z,direction.z*speed,delta*40) + knockback.z
	knockback = knockback.move_toward(Vector3.ZERO,delta*25)
	var was_on_floor := player.is_on_floor()
	if Input.is_action_just_pressed("jump") and not hud.panel_open(): jump_buffer = 0.16
	coyote_left = 0.10 if was_on_floor else maxf(0.0,coyote_left-delta)
	jump_buffer = maxf(0.0,jump_buffer-delta)
	var blocked := player.dialogue_active or player.has_effect("rooted") or player.has_effect("frozen") or player.has_effect("stunned")
	if jump_buffer>0.0 and coyote_left>0.0 and not blocked:
		player.velocity.y = 8.4
		jump_buffer = 0.0
		coyote_left = 0.0
		motion.play("jump")
	elif not was_on_floor: player.velocity.y -= player.gravity*delta
	else: player.velocity.y = -0.5
	player.move_and_slide()
	if player.is_on_floor() and not was_on_floor:motion.land()
	motion.tick(Vector2(player.velocity.x,player.velocity.z).length(),move_speed(),delta,attack_interval())
	if direction.length_squared() > 0.01 and animation_lock<=0.0:
		facing_angle=atan2(-direction.x,-direction.z)+PI
	player.get_node("Visual").rotation.y = lerp_angle(player.get_node("Visual").rotation.y,facing_angle,delta*14)
	if animation_lock <= 0.0:
		play_animation("run" if direction.length_squared() > 0.01 else "idle")
	player.camera_pivot.rotation = Vector3(pitch,yaw,0)
	if bool(SettingsService.get_setting("display/enable_camera_effects",true)) and player._shake_time_left>0.0:
		player._shake_time_left=maxf(0.0,player._shake_time_left-delta)
		player.camera.h_offset=sin(Time.get_ticks_msec()*0.055)*player._shake_strength
	else:player.camera.h_offset=0.0
	if player.global_position.y < -20.0:
		player.global_position = WorldLayout.CAMPFIRE + Vector3(0,1,2)

func input(event: InputEvent) -> void:
	if hud.panel_open(): return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * float(SettingsService.get_setting("input/mouse_sensitivity"))
		pitch = clampf(pitch - event.relative.y * float(SettingsService.get_setting("input/mouse_sensitivity")),-0.85,0.35)
	if event.is_action_pressed("defend"): activate_ultimate()
	if event.is_action_pressed("interact"): interact()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: player.camera_pivot.spring_length = maxf(3.0,player.camera_pivot.spring_length-0.5)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: player.camera_pivot.spring_length = minf(9.0,player.camera_pivot.spring_length+0.5)

func fire() -> void:
	if combat.busy() or combat.cooldown>0.0 or queued_attack>0.0:return
	var direction := -player.camera.global_basis.z
	var closest: Node3D
	var best := 0.90
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not DartCombat.alive(enemy): continue
		var offset: Vector3 = DartCombat.hit_center(enemy) - player.camera.global_position
		var dot := direction.dot(offset.normalized())
		if offset.length() < 40.0 and dot > best:
			best = dot
			closest = enemy
	if closest != null:
		direction = (DartCombat.hit_center(closest) - player.global_position - Vector3.UP*1.1).normalized()
	else:
		var query := PhysicsRayQueryParameters3D.create(player.camera.global_position,player.camera.global_position + direction*150.0,1)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		var aim_point: Vector3 = hit.get("position",player.camera.global_position+direction*150.0)
		direction = (aim_point-player.global_position-Vector3.UP*1.1).normalized()
	queued_direction=direction
	queued_attack=0.18*minf(1.0,attack_interval()/0.6)
	combat.cooldown=attack_interval()
	play_animation("cast",0.40)
	facing_angle=atan2(-direction.x,-direction.z)+PI

func mark_target(target: Node) -> void: marked[target.get_instance_id()] = 12.0
func on_hit(thrown: bool) -> void:
	if ultimate_left <= 0.0 and windup <= 0.0: echo_value = minf(100.0,echo_value+(3.0 if thrown else 2.0))

func activate_ultimate() -> bool:
	if player.is_dead() or player.has_effect("frozen") or player.has_effect("stunned") or windup > 0.0 or ultimate_left > 0.0: return false
	if echo_value < 100.0:
		player.show_combat_feedback("回响尚未充满 · 命中敌人积蓄能量",Color(0.65,0.7,1))
		return false
	windup = 0.45
	queued_attack=0.0
	SurvivorAudio.play(player.get_parent(),"shadow_cast",player.global_position,-10.0)
	play_animation("ultimate",0.65)
	player.show_combat_feedback("奥义·影分身之术",Color(0.75,0.65,1))
	return true

func _spawn_clones() -> void:
	ultimate_total = ultimate_duration()
	ultimate_left = ultimate_total
	ShadowBurst.spawn(player.get_parent(),player.global_position)
	for i in 3:
		var clone := ShadowClone.new()
		clone.controller = self
		clone.index = i
		player.get_parent().add_child(clone)
		var a := TAU*i/3.0
		clone.global_position = player.global_position + Vector3(cos(a)*1.3,0.1,sin(a)*1.3)
		var map := player.get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map)>0:
			var safe := NavigationServer3D.map_get_closest_point(map,clone.global_position)
			if safe.distance_to(clone.global_position)<3.0:clone.global_position=safe+Vector3.UP*0.1
		clones.append(clone)
		ShadowBurst.spawn(player.get_parent(),clone.global_position)

func end_ultimate() -> void:
	queued_attack=0.0
	windup = 0.0
	ultimate_left = 0.0
	echo_value = 0.0
	for clone in clones:
		if is_instance_valid(clone):
			if clone.is_inside_tree():ShadowBurst.spawn(player.get_parent(),clone.global_position)
			clone.queue_free()
	clones.clear()

func add_experience(amount: int) -> void:
	if player.is_dead(): return
	player.stats.add_exp(amount)
	hud.refresh()

func _level_up(_level: int) -> void:
	pending_choices += 1
	SurvivorAudio.play(player.get_parent(),"survivor_level",player.global_position,-10.0)
	player.stats.heal(25.0)
	if offered.is_empty(): roll_choices()
	hud.show_choices()

func roll_choices() -> void:
	offered = UPGRADE_IDS.duplicate()
	offered.shuffle()
	offered = offered.slice(0,3)

func choose_upgrade(id: String) -> bool:
	if pending_choices <= 0 or not offered.has(id): return false
	ranks[id] = int(ranks[id]) + 1
	pending_choices -= 1
	combat.rebuild()
	for clone in clones:
		if is_instance_valid(clone): clone.combat.rebuild()
	offered.clear()
	if pending_choices > 0:
		roll_choices()
		hud.show_choices()
	else:
		hud.close_panel()
	return true

func play_animation(clip: String, lock := 0.0) -> void:
	if motion.tree != null:
		motion.play(clip)
		animation_lock=maxf(animation_lock,lock)
		return
	if animator == null: return
	for key in animator.get_animation_list():
		if key == clip or key.ends_with("_"+clip) or key.ends_with("/"+clip):
			if animator.current_animation != key or lock > 0.0:
				animator.play(key,0.12)
			animation_lock = maxf(animation_lock,lock)
			return

func interact() -> void:
	var best := nearest_interactable()
	if best != null: best.interacted.emit(player)

func nearest_interactable() -> Interactable:
	var best: Interactable
	var distance := 3.0
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable and node.collision_layer != 0:
			var d := player.global_position.distance_to(node.global_position)
			if d < distance: best = node; distance = d
	return best

func get_save_data() -> Dictionary:
	return {"ranks":ranks.duplicate(),"pending_choices":pending_choices,"offered":offered.duplicate(),"echo_value":echo_value if ultimate_left <= 0.0 and windup <= 0.0 else 0.0,"kills":kills,"yaw":yaw,"pitch":pitch}

func load_save_data(data: Dictionary) -> void:
	end_ultimate()
	var saved: Dictionary = data.get("ranks",{})
	for id in UPGRADE_IDS: ranks[id] = clampi(int(saved.get(id,0)),0,100)
	pending_choices = clampi(int(data.get("pending_choices",0)),0,100)
	offered = data.get("offered",[]).duplicate()
	if offered.size() != 3 or not offered.all(func(id): return UPGRADE_IDS.has(id)) or offered[0] == offered[1] or offered[1] == offered[2] or offered[0] == offered[2]:
		offered.clear()
		if pending_choices > 0: roll_choices()
	echo_value = clampf(float(data.get("echo_value",0)),0.0,100.0)
	kills = maxi(0,int(data.get("kills",0)))
	yaw = float(data.get("yaw",0))
	pitch = clampf(float(data.get("pitch",-0.3)),-0.85,0.35)
	combat.rebuild()
	combat.recall()
	jump_buffer=0.0
	coyote_left=0.0
	if pending_choices > 0: hud.show_choices()
