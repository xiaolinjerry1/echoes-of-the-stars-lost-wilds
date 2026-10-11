class_name RangedCaster
extends SkeletalCaster
## 远程施法者（森林法师）
## 行为：与玩家保持 8-12 米距离（太近后退、太远靠近），
## 蓄力 0.8s（有"蓄力…"预警与光效）后发射魔法弹（15 m/s）；施法计入群体预算。

const CAST_WINDUP := 0.8
const KEEP_MIN := 8.0
const KEEP_MAX := 12.0
## 距离过近时先拉开距离再施法
const MIN_CAST_DISTANCE := KEEP_MIN

var _cast_retry := 0.0


func _ready() -> void:
	enemy_id = "forest_mage"
	display_name = "森林法师"
	max_health = 42.0
	attack_power = 12.5
	armor = 0.0
	move_speed = 2.5
	attack_range = 15.0
	attack_cooldown = 2.2
	model_path = "res://art/models/enemy/forest_mage.glb"
	health_bar_height = 2.0
	super._ready()


func _update_state(delta: float) -> void:
	if _cast_retry > 0.0:
		_cast_retry -= delta
	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_kite(delta)
		State.ATTACK:
			_update_cast()
		State.RETURN:
			_update_return(delta)


## 风筝走位 + 施法决策。
func _kite(delta: float) -> void:
	var target := select_attack_target()
	if target == null:
		_enter_return()
		return
	if _check_leash(delta, target):
		return
	var distance := global_position.distance_to(target.global_position)
	if distance >= MIN_CAST_DISTANCE and distance <= detection_range and _attack_timer <= 0.0 and _cast_retry <= 0.0:
		if _try_acquire_cast():
			_begin_cast()
			return
		_cast_retry = 0.5
	# 距离保持
	if distance < KEEP_MIN:
		var away := global_position - target.global_position
		away.y = 0.0
		if away.length_squared() > 0.01:
			var facing := rotation.y
			_move_towards(global_position + away.normalized() * 2.0, delta)
			rotation.y = facing
			_face_direction(target.global_position - global_position)
	elif distance > KEEP_MAX:
		_move_towards(target.global_position, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_face_direction(target.global_position - global_position)


func _begin_cast() -> void:
	_enter_state(State.ATTACK)
	_play_windup_telegraph(Color(0.5, 0.9, 1.0), "蓄力…")
	HitEffect.spawn_burst(get_parent(), global_position + Vector3.UP * 1.5, Color(0.4, 1.0, 0.6), 6, 1.0)


func _update_cast() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var target := select_attack_target()
	if target != null:
		_face_direction(target.global_position - global_position)
	# 蓄力期间持续光效
	if randf() < 0.2:
		HitEffect.spawn_burst(get_parent(), global_position + Vector3.UP * 1.5, Color(0.4, 1.0, 0.6), 2, 0.8)
	if _state_time >= CAST_WINDUP and not _cast_fired:
		_cast_fired = true
		_fire_bolt()
		_attack_timer = attack_cooldown
	if _state_time >= CAST_WINDUP + 0.6:
		_enter_state(State.CHASE)
