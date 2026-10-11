class_name SupportCaster
extends SkeletalCaster
## 支援怪（林间祭司）
## 行为：不主动追击，与玩家保持 10-14 米；周期性在受伤友军旁放置治疗图腾；
## 自身有弱远程攻击（伤害低，冷却 3 秒）；独立鹿角木面祭司模型与召唤动作。

const CAST_WINDUP := 0.6
const KEEP_MIN := 10.0
const KEEP_MAX := 14.0
const TOTEM_COOLDOWN := 10.0

@export var totem_scene: PackedScene = preload("res://scenes/actors/heal_totem.tscn")

var _totem_cd := 0.0
var _cast_retry := 0.0
var _summoning_totem := false


func _ready() -> void:
	enemy_id = "forest_shaman"
	display_name = "林间祭司"
	max_health = 46.0
	attack_power = 6.0
	armor = 0.0
	move_speed = 2.0
	attack_range = 12.0
	attack_cooldown = 3.0
	model_path = "res://art/models/enemy/forest_shaman.glb"
	health_bar_height = 2.45
	cast_windup_time = CAST_WINDUP
	super._ready()


func _update_state(delta: float) -> void:
	if _totem_cd > 0.0:
		_totem_cd -= delta
	if _cast_retry > 0.0:
		_cast_retry -= delta
	# 图腾优先：只要附近有受伤友军且冷却就绪（巡逻中也放置）
	if state != State.ATTACK and _totem_cd <= 0.0 and _ally_needs_heal():
		_enter_state(State.ATTACK)
		_summoning_totem = true
		_totem_cd = TOTEM_COOLDOWN
	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_support_behavior(delta)
		State.ATTACK:
			_update_cast()
		State.RETURN:
			_update_return(delta)


## 保持距离 + 弱远程攻击。
func _support_behavior(delta: float) -> void:
	var target := select_attack_target()
	if target == null:
		_enter_return()
		return
	if _check_leash(delta, target):
		return
	var distance := global_position.distance_to(target.global_position)
	if distance <= attack_range and _attack_timer <= 0.0 and _cast_retry <= 0.0:
		if _try_acquire_cast():
			_enter_state(State.ATTACK)
			_play_windup_telegraph(Color(0.6, 1.0, 0.6), "祈祷…")
			return
		_cast_retry = 0.5
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


func _update_cast() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var target := select_attack_target()
	if target != null:
		_face_direction(target.global_position - global_position)
	if _state_time >= CAST_WINDUP and not _cast_fired:
		_cast_fired = true
		if _summoning_totem:
			_place_totem()
		else:
			_fire_bolt()
		_attack_timer = attack_cooldown
	if _state_time >= CAST_WINDUP + 0.6:
		_enter_state(State.CHASE)


func _attack_visual_clip() -> StringName:
	return &"summon" if _summoning_totem else &"cast"


func _on_attack_aborted() -> void:
	super._on_attack_aborted()
	_summoning_totem = false


func _ally_needs_heal() -> bool:
	for ally in get_tree().get_nodes_in_group("enemy"):
		if ally == self or not (ally is BaseEnemy):
			continue
		var enemy := ally as BaseEnemy
		if enemy.state == State.DEAD:
			continue
		if enemy.current_health < enemy.max_health * 0.9 and global_position.distance_to(enemy.global_position) < 8.0:
			return true
	return false


func _place_totem() -> void:
	_totem_cd = TOTEM_COOLDOWN
	var parent := get_parent()
	if parent == null or totem_scene == null:
		return
	var totem := totem_scene.instantiate()
	parent.add_child(totem)
	(totem as Node3D).global_position = global_position
	ComboNotifier.show_text(parent, global_position + Vector3.UP * 1.8, "治疗图腾！", Color(0.5, 1.0, 0.55), 40)
	ComboNotifier.play_beep(self, global_position, 700.0)
