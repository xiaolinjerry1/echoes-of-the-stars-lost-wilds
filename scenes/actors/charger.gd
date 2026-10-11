class_name Charger
extends BaseEnemy
## 冲锋重型怪（苔牙野猪）
## 行为：缓慢追击；中距离时进入冲锋（1 秒预警：红环+文字+下蹲）→ 12 m/s 冲 10 米；
## 命中玩家造成大量伤害并击退；撞到墙壁/石柱则自身眩晕 3 秒（精英机制基础）。
## 普通攻击为前摇 0.6s 的重击。

const HEAVY_WINDUP := 0.6
const CHARGE_WINDUP := 1.0
const CHARGE_SPEED := 12.0
const CHARGE_DISTANCE := 10.0
const CHARGE_MIN_RANGE := 4.0
const CHARGE_MAX_RANGE := 12.0
const WALL_STUN_DURATION := 3.0

@export var charge_cooldown := 8.0

var _charge_cd := 0.0
var _charge_phase := 0  # 0 无 / 1 预警 / 2 冲锋
var _charge_dir := Vector3.ZERO
var _charge_traveled := 0.0
var _charge_hit_done := false
var _heavy_hit_done := false
var _recovery_time := 0.0
var _animation_player: AnimationPlayer
var _clips: Dictionary = {}
var _visual_clip := ""
var _flinch_time := 0.0
var _smooth_speed := 0.0


func _ready() -> void:
	enemy_id = "moss_boar"
	display_name = "苔牙野猪"
	max_health = 104.0
	attack_power = 18.0
	armor = 6.0
	move_speed = 2.8
	attack_range = 2.2
	attack_cooldown = 2.0
	model_path = "res://art/models/enemy/moss_boar.glb"
	health_bar_height = 1.3
	if elite:
		max_health = 310.0
		attack_power = 21.0
	super._ready()
	_setup_animation()


func _update_state(delta: float) -> void:
	if _charge_cd > 0.0:
		_charge_cd -= delta
	if _recovery_time > 0.0 and state == State.CHASE:
		_recovery_time = maxf(0.0, _recovery_time - delta)
		velocity.x = 0.0
		velocity.z = 0.0
		return
	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_update_attack(delta)
		State.RETURN:
			_update_return(delta)


func _chase(delta: float) -> void:
	var target := select_attack_target()
	if target == null:
		_enter_return()
		return
	if _check_leash(delta, target):
		return
	var distance := global_position.distance_to(target.global_position)
	if _charge_cd <= 0.0 and distance >= CHARGE_MIN_RANGE and distance <= CHARGE_MAX_RANGE:
		_begin_charge(target)
		return
	if distance <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		if _attack_timer <= 0.0:
			_begin_heavy_attack()
		return
	_move_towards(target.global_position, delta)


func _begin_heavy_attack() -> void:
	_charge_phase = 0
	_heavy_hit_done = false
	_enter_state(State.ATTACK)
	_play_visual("heavy", true)
	_play_windup_telegraph(Color(1.0, 0.4, 0.3), "重击！")


func _begin_charge(target: Node3D) -> void:
	_charge_phase = 1
	_charge_dir = target.global_position - global_position
	_charge_dir.y = 0.0
	_charge_dir = _charge_dir.normalized()
	_charge_traveled = 0.0
	_charge_hit_done = false
	_enter_state(State.ATTACK)
	_play_visual("charge_windup", true)
	# 醒目的冲锋预警：红环 + 文字 + 音效 + 下蹲蓄势
	RingEffect.spawn(get_parent(), global_position + Vector3.UP * 0.1, Color(1.0, 0.3, 0.2), 2.6)
	_play_windup_telegraph(Color(1.0, 0.3, 0.2), "冲锋预警！")


func _update_attack(delta: float) -> void:
	match _charge_phase:
		1:
			_update_charge_windup()
		2:
			_update_charge_dash(delta)
		_:
			_update_heavy_attack()


func _update_charge_windup() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _state_time >= CHARGE_WINDUP:
		# 预警结束时按玩家当前位置最终校准冲锋方向
		var target := select_attack_target()
		if target != null:
			_charge_dir = target.global_position - global_position
			_charge_dir.y = 0.0
			if _charge_dir.length_squared() > 0.0001:
				_charge_dir = _charge_dir.normalized()
		_charge_phase = 2
		_state_time = 0.0
		rotation.y = atan2(-_charge_dir.x, -_charge_dir.z)
		_play_visual("charge", true)


func _update_charge_dash(delta: float) -> void:
	velocity.x = _charge_dir.x * CHARGE_SPEED
	velocity.z = _charge_dir.z * CHARGE_SPEED
	_charge_traveled += CHARGE_SPEED * delta
	# 命中玩家：大量伤害 + 击退
	if not _charge_hit_done:
		var target := select_attack_target()
		if target != null and global_position.distance_to(target.global_position) <= 1.4:
			_charge_hit_done = true
			var amount := attack_power * 1.5
			if target.has_method("take_damage"):
				target.call("take_damage", amount, self)
			damage_dealt.emit(amount, target)
			if target.has_method("start_dash"):
				var push := target.global_position - global_position
				push.y = 0.0
				target.call("start_dash", push.normalized(), 4.0, 0.2)
			_end_charge()
			return
	# 撞墙/石柱：自身眩晕 3 秒
	if is_on_wall():
		apply_effect(StatusEffects.STUN, WALL_STUN_DURATION, 1.0)
		ComboNotifier.show_text(get_parent(), global_position + Vector3.UP * 2.0, "撞柱眩晕！", Color(1.0, 0.6, 0.3), 48)
		ComboNotifier.play_beep(self, global_position, 300.0)
		_end_charge()
		return
	if _charge_traveled >= CHARGE_DISTANCE:
		_end_charge()
		return
	# 冲锋超时兜底（理论上 10 米 / 12 m/s ≈ 0.83 秒）
	if _state_time >= 1.2:
		_end_charge()


func _end_charge() -> void:
	_charge_phase = 0
	velocity.x = 0.0
	velocity.z = 0.0
	_charge_cd = charge_cooldown
	_attack_timer = attack_cooldown
	_enter_state(State.CHASE)
	# Leaving ATTACK runs the shared abort cleanup; establish recovery afterwards.
	_recovery_time = 0.4
	_play_visual("recover", true)


func _update_heavy_attack() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var target := select_attack_target()
	if target != null:
		_face_direction(target.global_position - global_position)
	if _state_time >= HEAVY_WINDUP and not _heavy_hit_done:
		_heavy_hit_done = true
		_perform_melee_hit(attack_range, 1.2)
		_attack_timer = attack_cooldown
	if _state_time >= 1.0:
		_enter_state(State.CHASE)


## 被控制/打断时复位冲锋状态。
func _on_attack_aborted() -> void:
	if _charge_phase != 0:
		_charge_phase = 0
		_charge_cd = charge_cooldown
	_heavy_hit_done = false
	_recovery_time = 0.0


## Blender +Z 正面适配 AI -Z；仅改变实例的动画循环配置。
func _setup_animation() -> void:
	visual.rotation.y = PI
	var players := visual.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_animation_player = players[0] as AnimationPlayer
	_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for library_name in _animation_player.get_animation_library_list():
		var library := _animation_player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		_animation_player.remove_animation_library(library_name)
		_animation_player.add_animation_library(library_name, library)
	for name in _animation_player.get_animation_list():
		var clip := String(name).get_file().trim_prefix("Boar_")
		_clips[clip] = name
		if clip in ["idle", "walk", "run", "charge", "stagger"]:
			_animation_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	_play_visual("idle")

func _play_visual(clip: String, restart := false) -> void:
	if _animation_player == null or not _clips.has(clip) or (_visual_clip == clip and not restart):
		return
	var phase := -1.0
	if not restart and _visual_clip in ["walk", "run"] and clip in ["walk", "run"]:
		phase = fmod(_animation_player.current_animation_position / _animation_player.current_animation_length, 1.0)
	if restart:
		_animation_player.stop(true)
	_visual_clip = clip
	_animation_player.play(_clips[clip], 0.0 if clip in ["heavy", "charge_windup", "charge", "death"] else 0.10)
	if phase >= 0.0:
		_animation_player.seek(phase * _animation_player.get_animation(_clips[clip]).length, true)
	_animation_player.advance(0.0)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_animation(delta)

func _update_animation(delta: float) -> void:
	if _animation_player == null:
		return
	if state == State.DEAD:
		_play_visual("death")
		_animation_player.advance(delta)
		return
	if status.has_effect(StatusEffects.FROZEN):
		return
	_smooth_speed = lerpf(_smooth_speed, Vector2(velocity.x, velocity.z).length(), 1.0 - exp(-delta * 10.0))
	_flinch_time = maxf(0.0, _flinch_time - delta)
	if state == State.STAGGERED:
		_play_visual("stagger")
	elif state == State.ATTACK:
		if _charge_phase == 2:
			_play_visual("charge")
		else:
			_play_visual("charge_windup" if _charge_phase == 1 else "heavy")
			_animation_player.seek(minf(_state_time, 1.0), true)
			return
	elif _recovery_time > 0.0:
		_play_visual("recover")
	elif _flinch_time > 0.0:
		_play_visual("hit")
	else:
		var clip := "idle" if _smooth_speed < 0.1 else "walk"
		if _smooth_speed > (1.6 if _visual_clip == "run" else 2.0):
			clip = "run"
		_play_visual(clip)
	var rate := 1.0
	if _visual_clip == "walk":
		rate = clampf(_smooth_speed / (0.8 / 1.2), 0.3, 3.0)
	elif _visual_clip == "run":
		rate = clampf(_smooth_speed / (0.92 / 0.6), 0.5, 2.5)
	_animation_player.advance(delta * rate)

func _patrol(delta: float) -> void:
	var speed := move_speed
	move_speed = minf(speed, 1.2)
	super._patrol(delta)
	move_speed = speed

func take_damage(amount: float, attacker: Node = null) -> void:
	super.take_damage(amount, attacker)
	if state not in [State.DEAD, State.ATTACK, State.STAGGERED] and not status.has_effect(StatusEffects.FROZEN):
		_flinch_time = 0.4
		_play_visual("hit", true)

func _play_death_visual() -> float:
	if _animation_player == null:
		return super._play_death_visual()
	_play_visual("death", true)
	return 2.0
