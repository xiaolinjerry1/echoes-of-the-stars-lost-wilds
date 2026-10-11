extends "res://scenes/actors/base_enemy.gd"
## 凶焰飞龙：森林原生飞行首领，巡航→锁定俯冲/口吐火球→落地收招，可受击与失衡。
## 飞行不使用地面导航；俯冲落点在前摇结束前锁定，每次只伤害一次，营地为安全区。
signal skill_used(skill_name: String)

enum Flight { PATROL, DIVE_WINDUP, DIVE, RECOVER, FIRE_WINDUP, FIRE, STAGGER }
const DIVE_WINDUP := 1.2
const DIVE_DURATION := 1.1
const RECOVERY := 3.2
const FIRE_WINDUP := 1.1
const DIVE_DAMAGE := 40.0
const FIRE_DAMAGE := 32.0
const LEASH_RADIUS := 62.0

var flight_state: Flight = Flight.PATROL
var nest_position := Vector3.ZERO
var _timer := 0.0
var _angle := 0.0
var _attack_cd := 5.0
var _next_dive := true
var _locked_target := Vector3.ZERO
var _dive_start := Vector3.ZERO
var _dive_end := Vector3.ZERO
var _dive_hit := false
var _warning: MeshInstance3D
var _death_timer := 0.0
var _hit_time := 0.0
var _motion = preload("res://scenes/actors/asset_animation.gd").new()

func _ready() -> void:
	enemy_id = "dread_wyvern"
	display_name = "凶焰飞龙"
	max_health = 1080.0
	attack_power = 28.0
	armor = 12.0
	elite = true
	detection_range = 48.0
	aggro_range = LEASH_RADIUS
	patrol_radius = 0.0
	model_path = "res://art/models/enemy/dread_wyvern.glb"
	health_bar_height = 7.0
	loot_table = "boss_wyvern"
	nest_position = Vector3(global_position.x, TerrainBuilder.height_at(global_position.x, global_position.z), global_position.z)
	super._ready()
	visual.rotation.y = PI
	_motion.bind(visual, "dread_wyvern")
	_motion.play("fly")
	var body := CapsuleShape3D.new()
	body.radius = 1.3
	body.height = 4.4
	$CollisionShape3D.shape = body
	$CollisionShape3D.position.y = 2.3
	var hit_box := BoxShape3D.new()
	hit_box.size = Vector3(3.0, 4.8, 8.0)
	$HitArea/CollisionShape3D.shape = hit_box
	$HitArea/CollisionShape3D.position = Vector3(0, 2.5, 0)
	if boss != null: boss.staggering_started.connect(_interrupt_attack)
	add_to_group("dread_wyvern")

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_death_timer += delta
		velocity = Vector3(0, -minf(22.0, _death_timer * 12.0), 0)
		move_and_slide()
		var floor_y := TerrainBuilder.height_at(global_position.x, global_position.z)
		if global_position.y < floor_y: global_position.y = floor_y
		_motion.advance(delta)
		return
	if status.has_effect(StatusEffects.FROZEN): return
	if boss != null and boss.is_staggered():
		flight_state = Flight.STAGGER
		_motion.play("stagger")
		var floor_y := TerrainBuilder.height_at(global_position.x, global_position.z) + 0.15
		global_position.y = move_toward(global_position.y, floor_y, delta * 12)
		_motion.advance(delta, true)
		return
	if flight_state == Flight.STAGGER:
		flight_state = Flight.RECOVER
		_timer = RECOVERY
		_motion.play("recover", true)
	var target := _get_player()
	if target != null and (target.get("_is_dead") == true or _horizontal_distance(target.global_position, nest_position) > LEASH_RADIUS): target = null
	# 越界/死亡/回营地立即取消已锁定攻击与预警，随后返回巢区。
	if target == null and flight_state in [Flight.DIVE_WINDUP, Flight.DIVE, Flight.FIRE_WINDUP, Flight.FIRE]:
		_interrupt_attack()
		flight_state = Flight.PATROL
		_attack_cd = 4
	_attack_cd = maxf(0, _attack_cd - delta)
	_hit_time = maxf(0, _hit_time - delta)
	match flight_state:
		Flight.PATROL:
			state = State.PATROL if target == null else State.CHASE
			_angle += delta * 0.24
			var orbit := nest_position + Vector3(cos(_angle) * 18, 11 + sin(_angle * 2), sin(_angle) * 18)
			var direction := orbit - global_position
			velocity = direction.normalized() * minf(8, direction.length() * 2)
			_face_direction(direction)
			move_and_slide()
			_motion.play("hit" if _hit_time > 0 else "fly")
			if target != null and _horizontal_distance(global_position, target.global_position) <= detection_range and _attack_cd <= 0:
				if _next_dive: start_dive(target)
				else: start_fireball(target)
				_next_dive = not _next_dive
		Flight.DIVE_WINDUP:
			_timer -= delta
			velocity = Vector3.ZERO
			if _timer <= 0:
				flight_state = Flight.DIVE
				_timer = DIVE_DURATION
				_dive_start = global_position
				var along := _locked_target - _dive_start
				along.y = 0
				if along.length_squared() < .01: along = -global_transform.basis.z
				_dive_end = _locked_target + along.normalized() * 5.0
				_dive_end.y = TerrainBuilder.height_at(_dive_end.x, _dive_end.z) + .15
				_clear_warning()
				_motion.play("dive", true)
		Flight.DIVE:
			_timer -= delta
			var progress := clampf(1.0 - _timer / DIVE_DURATION, 0, 1)
			var desired := _dive_start.lerp(_dive_end, progress)
			var previous := global_position
			velocity = (desired - global_position) / maxf(delta, .001)
			move_and_slide()
			# 扫过的路径只结算一次；地面目标必须在飞龙俯冲实际接近时才受伤。
			if target != null and not _dive_hit:
				var closest := Geometry3D.get_closest_point_to_segment(target.global_position + Vector3.UP, previous + Vector3.UP, global_position + Vector3.UP)
				if closest.distance_to(target.global_position + Vector3.UP) <= 3.3:
					target.take_damage(DIVE_DAMAGE, self)
					if target.has_method("apply_external_knockback"): target.apply_external_knockback(-global_transform.basis.z, 9)
					damage_dealt.emit(DIVE_DAMAGE, target)
					_dive_hit = true
			if _timer <= 0 or get_slide_collision_count() > 0:
				flight_state = Flight.RECOVER
				_timer = RECOVERY
				_attack_cd = 6.0
				velocity = Vector3.ZERO
				_motion.play("recover", true)
		Flight.RECOVER:
			_timer -= delta
			# 落地前1.8秒是近战输出窗口；随后张翼升空。
			if _timer < 1.4:
				global_position.y = move_toward(global_position.y, nest_position.y + 11, delta * 9)
				_motion.play("fly")
			if _timer <= 0: flight_state = Flight.PATROL
		Flight.FIRE_WINDUP:
			_timer -= delta
			velocity = Vector3.ZERO
			if _timer <= 0:
				flight_state = Flight.FIRE
				_timer = .6
				_motion.play("fire", true)
				preload("res://scenes/combat/wyvern_fireball.gd").spawn(get_parent(), get_mouth_position(), _locked_target, self, FIRE_DAMAGE)
				skill_used.emit("fireball_released")
		Flight.FIRE:
			_timer -= delta
			if _timer <= 0:
				flight_state = Flight.PATROL
				_attack_cd = 5
				_clear_warning()
	_motion.advance(delta, flight_state == Flight.PATROL and _hit_time <= 0)

func take_damage(amount: float, attacker: Node = null) -> void:
	super.take_damage(amount, attacker)
	if state != State.DEAD and flight_state == Flight.PATROL:
		_hit_time = .5
		_motion.play("hit", true)

func start_dive(target: Node3D) -> void:
	if state == State.DEAD or target == null: return
	_clear_warning()
	flight_state = Flight.DIVE_WINDUP
	state = State.ATTACK
	_timer = DIVE_WINDUP
	_dive_hit = false
	_locked_target = target.global_position
	_locked_target.y = TerrainBuilder.height_at(_locked_target.x, _locked_target.z) + .15
	_face_direction(_locked_target - global_position)
	_motion.play("dive_windup", true)
	_make_warning(_locked_target, 3.3)
	_play_windup_telegraph(Color(1,.3,.08), "飞龙俯冲！离开红圈")
	skill_used.emit("dive")

func start_fireball(target: Node3D) -> void:
	if state == State.DEAD or target == null: return
	_clear_warning()
	flight_state = Flight.FIRE_WINDUP
	state = State.ATTACK
	_timer = FIRE_WINDUP
	_locked_target = target.global_position + Vector3.UP
	_face_direction(_locked_target - global_position)
	_motion.play("fire_windup", true)
	_make_warning(Vector3(_locked_target.x, TerrainBuilder.height_at(_locked_target.x, _locked_target.z)+.1, _locked_target.z), 2.2)
	_play_windup_telegraph(Color(1,.5,.1), "飞龙吐火球！")
	skill_used.emit("fireball")

func get_mouth_position() -> Vector3:
	var skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		var skeletons := visual.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty(): skeleton = skeletons[0]
	if skeleton != null:
		var index := skeleton.find_bone("Head")
		if index >= 0:
			return skeleton.to_global(skeleton.get_bone_global_pose(index).origin) - global_transform.basis.z * 1.0
	return global_position - global_transform.basis.z * 4.1 + Vector3.UP * 4

func _make_warning(point: Vector3, radius: float) -> void:
	_warning = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius-.1
	ring.outer_radius = radius
	ring.rings = 48
	ring.ring_segments = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1,.12,.02,.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material = mat
	_warning.mesh = ring
	get_parent().add_child(_warning)
	_warning.global_position = point
	_warning.scale.y = .1

func _clear_warning() -> void:
	if is_instance_valid(_warning): _warning.queue_free()
	_warning = null

func _interrupt_attack() -> void:
	_clear_warning()
	velocity = Vector3.ZERO
	flight_state = Flight.PATROL
	_attack_cd = 5

func _play_death_visual() -> float:
	_interrupt_attack()
	_motion.play("death", true)
	return 3.5

func _drop_loot() -> void:
	var owner_player := get_tree().get_first_node_in_group("player") as PlayerController
	if owner_player != null and owner_player.survivor_mode:
		owner_player.survivor.kills += 1
		var reward := 120 if enemy_id == "dread_wyvern" else (100 if enemy_id == "moss_crown_beast" else (25 if elite else 8))
		ExperiencePickup.spawn(get_parent(),global_position,reward)
		return


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x, a.z-b.z).length()

func _exit_tree() -> void:
	_clear_warning()
	super._exit_tree()
