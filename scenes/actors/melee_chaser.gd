class_name MeleeChaser
extends BaseEnemy
## 近战追击者（野狼）
## 职责：野狼追击/咬击及 Blender 骨骼动画；0.4s 合颌命中，0.8s 完成收招。
## 动画只控制视觉；伤害由 AI 单次结算，冻结暂停姿势，眩晕中断咬击。

const ATTACK_WINDUP := 0.4
const ATTACK_DURATION := 0.8
const BACKSTEP_TIME := 0.3
const LOOP_CLIPS := [&"idle", &"walk", &"run", &"backstep", &"stagger"]

var _backstep_time := 0.0
var _bite_hit_applied := false
var _animation_player: AnimationPlayer
var _clips: Dictionary = {}
var _visual_clip: StringName = &""
var _flinch_time := 0.0
var _smoothed_speed := 0.0
var _gait: StringName = &"idle"
var _pending_gait: StringName = &"idle"
var _pending_gait_time := 0.0
var _playback_rate := 1.0


func _ready() -> void:
	enemy_id = "timber_wolf"
	display_name = "野狼"
	max_health = 54.0
	attack_power = 10.0
	armor = 2.0
	move_speed = 4.1
	attack_range = 2.0
	attack_cooldown = 1.3
	model_path = "res://art/models/enemy/timber_wolf.glb"
	health_bar_height = 1.6
	super._ready()
	_setup_skeletal_animation()


## 美术资产朝 +Z；兼容 BaseEnemy 当前朝 -Z 的移动方向定义。
func _setup_skeletal_animation() -> void:
	visual.rotation.y = PI
	_animation_player = _find_animation_player(visual)
	if _animation_player == null:
		return
	_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for full_name in _animation_player.get_animation_list():
		var short_name := StringName(String(full_name).get_slice("/", String(full_name).get_slice_count("/") - 1))
		_clips[short_name] = full_name
		# Imported resources may be shared by many enemies. Loop flags belong to this instance.
		var animation := _animation_player.get_animation(full_name)
		if short_name in LOOP_CLIPS and animation.loop_mode != Animation.LOOP_LINEAR:
			var library_name := String(full_name).get_slice("/", 0) if "/" in String(full_name) else ""
			var library := _animation_player.get_animation_library(library_name)
			var local_library := library.duplicate() as AnimationLibrary
			_animation_player.remove_animation_library(library_name)
			_animation_player.add_animation_library(library_name, local_library)
			var local_animation := animation.duplicate() as Animation
			local_animation.loop_mode = Animation.LOOP_LINEAR
			local_library.remove_animation(short_name)
			local_library.add_animation(short_name, local_animation)
	_play_visual(&"idle")


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _play_visual(clip: StringName, restart := false) -> void:
	if _animation_player == null or not _clips.has(clip):
		return
	if _visual_clip == clip and not restart:
		return
	if restart:
		# Playing the same clip again resumes its clock unless it is explicitly stopped.
		_animation_player.stop(true)
	var phase := -1.0
	if not restart and _visual_clip in [&"walk", &"run"] and clip in [&"walk", &"run"]:
		phase = fmod(_animation_player.current_animation_position / _animation_player.current_animation_length, 1.0)
	_visual_clip = clip
	# Bite seeks to authoritative AI time; no crossfade may delay its contact pose.
	_animation_player.play(_clips[clip], 0.0 if clip in [&"bite", &"death"] else 0.08)
	if phase >= 0.0:
		_animation_player.seek(phase * _animation_player.get_animation(_clips[clip]).length, true)
	_animation_player.advance(0.0)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_skeletal_animation(delta)


func _update_skeletal_animation(delta: float) -> void:
	if _animation_player == null:
		return
	if state == State.DEAD:
		_play_visual(&"death")
		_animation_player.advance(delta)
		return
	if status.has_effect(StatusEffects.FROZEN):
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	_smoothed_speed = lerpf(_smoothed_speed, horizontal_speed, 1.0 - exp(-delta * 12.0))
	_flinch_time = maxf(0.0, _flinch_time - delta)
	if state == State.STAGGERED:
		_play_visual(&"stagger")
	elif state == State.ATTACK:
		_play_visual(&"bite")
		_animation_player.seek(minf(_state_time, ATTACK_DURATION), true)
		return
	elif _flinch_time > 0.0:
		_play_visual(&"hit")
	elif _backstep_time > 0.0:
		_play_visual(&"backstep")
	else:
		var desired: StringName = _gait
		match _gait:
			&"idle":
				if _smoothed_speed > 0.25:
					desired = &"run" if _smoothed_speed > 2.3 else &"walk"
			&"walk":
				if _smoothed_speed < 0.08:
					desired = &"idle"
				elif _smoothed_speed > 2.3:
					desired = &"run"
			&"run":
				if _smoothed_speed < 1.7:
					desired = &"idle" if _smoothed_speed < 0.08 else &"walk"
		if desired != _pending_gait:
			_pending_gait = desired
			_pending_gait_time = 0.0
		_pending_gait_time += delta
		if _pending_gait_time >= 0.12:
			_gait = desired
		_play_visual(_gait)
	# Match the authored stance travel to actual horizontal speed, including backsteps.
	var playback_rate := 1.0
	match _visual_clip:
		&"walk":
			playback_rate = clampf(_smoothed_speed / (0.88 / 1.2), 0.4, 2.2)
		&"run":
			playback_rate = clampf(_smoothed_speed / (1.04 / 0.6), 0.7, 2.1)
		&"backstep":
			playback_rate = clampf(_smoothed_speed / (0.88 / 0.6), 0.5, 2.0)
	_playback_rate = lerpf(_playback_rate, playback_rate, 1.0 - exp(-delta * 10.0))
	_animation_player.advance(delta * (_playback_rate if _visual_clip in [&"walk", &"run", &"backstep"] else 1.0))


func take_damage(amount: float, attacker: Node = null) -> void:
	var was_alive := state != State.DEAD
	super.take_damage(amount, attacker)
	if was_alive and state != State.DEAD and state != State.ATTACK and not status.has_effect(StatusEffects.FROZEN):
		_flinch_time = 0.4
		_play_visual(&"hit", true)


func _play_death_visual() -> float:
	if _animation_player == null or not _clips.has(&"death"):
		return super._play_death_visual()
	_play_visual(&"death", true)
	return 2.0


func _patrol(delta: float) -> void:
	var chase_speed := move_speed
	move_speed = minf(move_speed, 1.6)
	super._patrol(delta)
	move_speed = chase_speed


func _update_state(delta: float) -> void:
	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_update_attack()
		State.RETURN:
			_update_return(delta)


func _chase(delta: float) -> void:
	var target := select_attack_target()
	if target == null:
		_enter_return()
		return
	if _check_leash(delta, target):
		return
	# 攻击后冷却期后退半步
	if _backstep_time > 0.0:
		_backstep_time -= delta
		var away := global_position - target.global_position
		away.y = 0.0
		if away.length_squared() > 0.01:
			away = away.normalized()
			velocity.x = away.x * move_speed
			velocity.z = away.z * move_speed
			_face_direction(-away)
		return
	var distance := global_position.distance_to(target.global_position)
	if distance <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		_face_direction(target.global_position - global_position)
		if _attack_timer <= 0.0:
			_begin_melee_attack()
		return
	_move_towards(target.global_position, delta)


func _begin_melee_attack() -> void:
	_bite_hit_applied = false
	_flinch_time = 0.0
	_enter_state(State.ATTACK)
	_play_visual(&"bite", true)
	_play_windup_telegraph(Color(1.0, 0.45, 0.35), "吼！")


func _update_attack() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var target := select_attack_target()
	if target != null:
		_face_direction(target.global_position - global_position)
	if _state_time >= ATTACK_WINDUP and not _bite_hit_applied:
		_bite_hit_applied = true
		_perform_melee_hit(attack_range)
		_attack_timer = attack_cooldown
	if _state_time >= ATTACK_DURATION:
		_backstep_time = BACKSTEP_TIME
		_enter_state(State.CHASE)


func _on_attack_aborted() -> void:
	_bite_hit_applied = false
