class_name BaseEnemy
extends CharacterBody3D
## BaseEnemy（怪物基类）
## 职责：所有怪物的通用能力——状态机（巡逻/追击/攻击/失衡/返回/死亡）、
## 导航移动与 AI 降频休眠、受击反馈/血条/死亡表现、状态效果与控制接口、
## 群体施法预算。子类只需在 _update_state(delta) 中实现行为差异。

signal enemy_died(enemy)
signal damage_dealt(amount: float, target: Node)

enum State { PATROL, CHASE, ATTACK, STAGGERED, RETURN, DEAD }

## 群体施法预算：同时最多允许施法的敌人数量
const MAX_CASTERS := 2
static var _cast_budget := 0

@export_group("身份")
@export var enemy_id := "enemy"
@export var display_name := "怪物"

@export_group("属性")
@export var max_health := 50.0
@export var attack_power := 8.0
@export var armor := 5.0
@export var move_speed := 3.5
@export var detection_range := 12.0
@export var attack_range := 2.0
@export var attack_cooldown := 1.5
## 超出该距离且持续 aggro_timer 秒后脱战
@export var aggro_range := 25.0
@export var aggro_timer := 5.0
## 精英标记（只吃减速等；方法 is_elite() 对应此变量）
@export var elite := false
## 失衡抗性（BOSS 预留）
@export var stagger_resistance := 0.0

@export_group("行为")
## 巡逻半径（出生点周围）
@export var patrol_radius := 10.0
## 模型路径（Blender 导出的 glb）；为空或缺失时用占位胶囊
@export var model_path := ""
## 血条高度
@export var health_bar_height := 1.9
## 掉落表 id（见 LootTables.LOOT_TABLES）
@export var loot_table := "normal_forest_enemy"

var current_health := 0.0
var state: State = State.PATROL
var spawn_position := Vector3.ZERO

var _target: Node3D = null
var _taunt_target: Node = null
var _taunt_timer := 0.0
var _attack_timer := 0.0
var _state_time := 0.0
var _leash_timer := 0.0
var _patrol_point := Vector3.ZERO
var _patrol_wait := 0.0
var _update_accum := 0.0
var _nav_last_target := Vector3.INF
var _casting_hold := false
var _flash_material: StandardMaterial3D = null
var _flash_tween: Tween = null

@onready var hit_area: Area3D = $HitArea
@onready var status: StatusEffectComponent = $StatusEffectComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: Node3D = $Visual
@onready var health_bar: Node3D = $HealthBar
@onready var health_fill: Sprite3D = $HealthBar/Fill
@onready var boss: BossComponent = get_node_or_null("BossComponent")


func _ready() -> void:
	spawn_position = global_position
	detection_range = maxf(detection_range,20.0)
	aggro_range = maxf(aggro_range,32.0)
	aggro_timer = maxf(aggro_timer,8.0)
	current_health = max_health
	state = State.PATROL
	add_to_group("enemy")
	collision_layer = 4        # actor_body（阻挡玩家）
	collision_mask = 1 | 2     # 世界 + 玩家
	if nav_agent != null:
		nav_agent.radius = 0.5
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
	_load_model()
	_setup_health_bar()
	# 攻击时机错开：随机初始偏移，避免群体同步释放
	_attack_timer = randf() * attack_cooldown
	_pick_patrol_point()


func _exit_tree() -> void:
	if _casting_hold:
		_release_cast()
		_casting_hold = false


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_update_accum += delta
	var interval := _compute_update_interval()
	if interval > 0.0 and _update_accum < interval:
		_apply_gravity_and_slide(delta)
		return
	var ai_delta := delta if interval <= 0.0 else _update_accum
	_update_accum = 0.0
	update_ai(ai_delta)


## AI 更新频率：>30 米每 0.5 秒更新一次；>45 米休眠（仅物理沉降），玩家靠近立即唤醒。
func _compute_update_interval() -> float:
	var player := _get_player()
	if player == null:
		return 0.0
	var distance := global_position.distance_to(player.global_position)
	if distance > 45.0:
		return 10.0
	if distance > 30.0:
		return 0.5
	return 0.0


## 每帧 AI（子类覆盖 _update_state 实现行为差异）。
func update_ai(delta: float) -> void:
	_state_time += delta
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _taunt_timer > 0.0:
		_taunt_timer -= delta
	# 控制状态（冻结/眩晕）：停止行动
	if status.has_effect(StatusEffects.FROZEN) or status.has_effect(StatusEffects.STUN):
		if state != State.STAGGERED:
			_enter_state(State.STAGGERED)
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity_and_slide(delta)
		return
	if state == State.STAGGERED:
		if _target != null:
			_enter_state(State.CHASE)
		else:
			_enter_state(State.PATROL)
	_update_state(delta)
	_apply_gravity_and_slide(delta)


## 子类实现：按 state 分派行为。
func _update_state(_delta: float) -> void:
	pass


## ---- 共享行为 ----

## 巡逻：出生点附近随机走动；发现玩家后进入战斗。
func _patrol(delta: float) -> void:
	var player := _get_player()
	if player != null and global_position.distance_to(player.global_position) <= detection_range:
		_enter_combat(player)
		return
	if _patrol_wait > 0.0:
		_patrol_wait -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		return
	_move_towards(_patrol_point, delta)
	if global_position.distance_to(_patrol_point) < 0.8:
		_patrol_wait = randf_range(1.0, 2.5)
		_pick_patrol_point()


func _pick_patrol_point() -> void:
	var angle := randf() * TAU
	var radius := randf() * patrol_radius
	_patrol_point = spawn_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


## 脱战返回出生点；路上重新发现玩家会再次进入战斗。
func _update_return(delta: float) -> void:
	var player := _get_player()
	if player != null and global_position.distance_to(player.global_position) <= detection_range * 0.8:
		_enter_combat(player)
		return
	_move_towards(spawn_position, delta)
	if global_position.distance_to(spawn_position) < 1.0:
		_target = null
		_enter_state(State.PATROL)
		_pick_patrol_point()


## 目标失效/追丢时返回。
func _enter_return() -> void:
	_target = null
	_enter_state(State.RETURN)


## 进入战斗；附近巡逻中的同伴会被呼叫（仇恨传播）。
func _enter_combat(attacker: Node) -> void:
	if attacker is Node3D:
		_target = attacker as Node3D
	elif _target == null:
		_target = _get_player()
	_leash_timer = 0.0
	if state == State.PATROL or state == State.RETURN:
		_enter_state(State.CHASE)
	for ally in get_tree().get_nodes_in_group("enemy"):
		if ally == self or not (ally is BaseEnemy):
			continue
		var enemy_ally := ally as BaseEnemy
		if enemy_ally.state == State.PATROL and global_position.distance_to(enemy_ally.global_position) < 8.0:
			enemy_ally._enter_combat(attacker if attacker != null else _get_player())


## 选择攻击目标：被嘲讽时固定为嘲讽者，否则为当前目标/玩家。
func select_attack_target() -> Node3D:
	if _taunt_timer > 0.0 and _taunt_target != null and is_instance_valid(_taunt_target) and _taunt_target is Node3D:
		return _taunt_target as Node3D
	if _target != null and is_instance_valid(_target):
		return _target
	return _get_player()


## 脱战检查（追击时调用）：超出仇恨范围并计时结束 → 返回；返回 true 表示已脱战。
func _check_leash(delta: float, target: Node3D) -> bool:
	if global_position.distance_to(target.global_position) > aggro_range:
		_leash_timer += delta
		if _leash_timer >= aggro_timer:
			_enter_return()
			return true
	else:
		_leash_timer = 0.0
	return false


## ---- 移动与导航 ----

## 朝世界坐标点移动（导航优先；无导航网格时退化为直线）。
func _move_towards(point: Vector3, _delta: float) -> void:
	var direction := _get_move_direction(point)
	if direction.length_squared() > 0.0001:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		_face_direction(direction)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _get_move_direction(point: Vector3) -> Vector3:
	if nav_agent != null and _is_navigation_ready():
		if _nav_repath_needed(point):
			nav_agent.target_position = point
		if not nav_agent.is_navigation_finished():
			var next := nav_agent.get_next_path_position()
			var dir := next - global_position
			dir.y = 0.0
			if dir.length_squared() > 0.01:
				return dir.normalized()
	var direct := point - global_position
	direct.y = 0.0
	if direct.length_squared() < 0.01:
		return Vector3.ZERO
	return direct.normalized()


func _is_navigation_ready() -> bool:
	var map := nav_agent.get_navigation_map()
	return map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0


## 只在目标移动超过 2 米或行进失败时重算路径（性能优化）。
func _nav_repath_needed(point: Vector3) -> bool:
	if _nav_last_target == Vector3.INF:
		_nav_last_target = point
		return true
	if point.distance_to(_nav_last_target) > 2.0:
		_nav_last_target = point
		return true
	if nav_agent.is_navigation_finished() and global_position.distance_to(point) > 1.5:
		_nav_last_target = point
		return true
	return false


func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_ry := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_ry, 0.15)


func _apply_gravity_and_slide(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()


## ---- 战斗接口 ----

func take_damage(amount: float, attacker: Node = null) -> void:
	if state == State.DEAD:
		return
	var final := DamageCalculator.apply_armor(amount, armor)
	if boss != null:
		final *= boss.get_incoming_damage_multiplier()
	current_health = maxf(current_health - final, 0.0)
	_update_health_bar()
	_flash_hit()
	if not (attacker is PlayerController and attacker.survivor_mode):
		ComboNotifier.play_beep(self, global_position + Vector3.UP * 1.2, 180.0)
	# 受击后退 + 进入战斗
	if attacker is Node3D:
		var away := global_position - (attacker as Node3D).global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			velocity += away.normalized() * 1.2
	_enter_combat(attacker)
	if current_health <= 0.0:
		die()


func heal(amount: float) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	current_health = minf(current_health + amount, max_health)
	_update_health_bar()


func apply_effect(effect_id: String, duration: float, power := 1.0, source: Node = null) -> void:
	if boss != null and boss.intercept_control(effect_id, source):
		return
	status.apply_effect(effect_id, duration, power, source)


func remove_effect(effect_id: String) -> void:
	status.remove_effect(effect_id)


func has_effect(effect_id: String) -> bool:
	return status.has_effect(effect_id)


func get_effect_power(effect_id: String) -> float:
	return status.get_effect_power(effect_id)


func get_stats() -> Variant:
	return self


func is_elite() -> bool:
	return elite


func is_staggered() -> bool:
	return state == State.STAGGERED


func on_taunted(source: Node, duration: float) -> void:
	_taunt_target = source
	_taunt_timer = duration
	if source is Node3D:
		_target = source as Node3D


func on_parried(duration: float) -> void:
	apply_effect(StatusEffects.STUN, duration, 1.0)


## 施法者命中后回报战报（EnemyBolt 调用）。
func notify_damage_dealt(amount: float, target: Node) -> void:
	damage_dealt.emit(amount, target)


## ---- 死亡 ----

func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	current_health = 0.0
	_update_health_bar()
	if _casting_hold:
		_release_cast()
		_casting_hold = false
	enemy_died.emit(self)
	hit_area.set_deferred("monitoring", false)
	hit_area.set_deferred("monitorable", false)
	hit_area.set_deferred("collision_layer", 0)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_drop_loot()
	# 任务系统：击杀事件
	var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	if quest_manager != null:
		quest_manager.notify_event("kill", enemy_id, 1)
	# 世界进度：记录精英/首领击杀（供存档）
	if elite:
		var session := get_tree().get_first_node_in_group("game_session") as GameSession
		if session != null:
			var killed: Dictionary = session.world_data.get("killed_elite", {})
			killed[enemy_id] = true
			session.world_data["killed_elite"] = killed
	health_bar.visible = false
	# 死亡表现：旋转倒下 + 缩小消失；精英更大特效
	var fx_color := Color(0.9, 0.7, 0.4) if not elite else Color(1.0, 0.6, 0.2)
	HitEffect.spawn_burst(get_parent(), global_position + Vector3.UP, fx_color, 60 if elite else 24, 5.0 if elite else 3.0)
	ComboNotifier.play_beep(self, global_position, 220.0)
	var death_duration := _play_death_visual()
	await get_tree().create_timer(death_duration).timeout
	queue_free()


## 已绑定角色可覆盖为骨骼死亡动画；其他怪物保留原来的回退表现。
func _play_death_visual() -> float:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "rotation:z", deg_to_rad(90.0), 0.5)
	tween.tween_property(visual, "scale", Vector3(0.05, 0.05, 0.05), 1.2).set_delay(0.4)
	return 2.0


## 掉落：按掉落表在尸体位置生成可拾取掉落物（必得 + 独立概率装备/材料）。
func _drop_loot() -> void:
	var owner_player := get_tree().get_first_node_in_group("player") as PlayerController
	if owner_player != null and owner_player.survivor_mode:
		owner_player.survivor.kills += 1
		var reward := 120 if enemy_id == "dread_wyvern" else (100 if enemy_id == "moss_crown_beast" else (25 if elite else 8))
		ExperiencePickup.spawn(get_parent(),global_position,reward)
		return


func _try_acquire_cast() -> bool:
	if _cast_budget >= MAX_CASTERS:
		return false
	_cast_budget += 1
	_casting_hold = true
	return true

func _release_cast() -> void:
	_cast_budget = maxi(_cast_budget - 1, 0)


## ---- 内部 ----

func _enter_state(new_state: State) -> void:
	if state == new_state:
		return
	var left_attack := state == State.ATTACK and new_state != State.ATTACK
	state = new_state
	_state_time = 0.0
	if left_attack:
		_on_attack_aborted()
		if _casting_hold:
			_release_cast()
			_casting_hold = false


## 攻击被打断时的子类清理钩子（冲锋/施法状态复位）。
func _on_attack_aborted() -> void:
	pass


func _get_player() -> Node3D:
	var found := get_tree().get_first_node_in_group("player") as Node3D
	if found == null:
		return null
	# 营地安全区：玩家在营地内时怪物不索敌
	if found.global_position.distance_to(WorldLayout.CAMP) < WorldLayout.CAMP_RADIUS:
		return null
	return found


func _perform_melee_hit(reach: float, damage_scale := 1.0) -> void:
	var target := select_attack_target()
	if target == null:
		return
	if global_position.distance_to(target.global_position) > reach + 0.8:
		return
	var amount := attack_power * damage_scale
	if target.has_method("take_damage"):
		target.call("take_damage", amount, self)
	damage_dealt.emit(amount, target)


func _fire_bolt(damage_scale := 1.0) -> void:
	var target := select_attack_target()
	if target == null:
		return
	var origin := global_position + Vector3.UP * 1.3
	EnemyBolt.spawn(get_parent(), origin, target, attack_power * damage_scale, self)


## 攻击预警（文字 + 音效），让玩家看懂怪物要做什么。
func _play_windup_telegraph(color := Color(1.0, 0.4, 0.3), text := "!") -> void:
	ComboNotifier.show_text(get_parent(), global_position + Vector3.UP * (health_bar_height + 0.4), text, color, 44)
	ComboNotifier.play_beep(self, global_position, 520.0)


func _load_model() -> void:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		_add_placeholder()
		return
	var packed := load(model_path) as PackedScene
	if packed == null:
		_add_placeholder()
		return
	visual.add_child(packed.instantiate())


func _add_placeholder() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.2
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.3, 0.3)
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.6
	visual.add_child(mesh_instance)


func _setup_health_bar() -> void:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	for sprite_name in ["Bg", "Fill"]:
		var sprite := health_bar.get_node_or_null(sprite_name) as Sprite3D
		if sprite != null:
			sprite.texture = texture
	health_bar.position.y = health_bar_height
	_update_health_bar()


func _update_health_bar() -> void:
	if health_fill == null or max_health <= 0.0:
		return
	var ratio := clampf(current_health / max_health, 0.0, 1.0)
	health_fill.scale.x = 0.45 * maxf(ratio, 0.001)
	health_fill.position.x = 0.45 * (ratio - 1.0)
	if ratio < 0.3:
		health_fill.modulate = Color(0.9, 0.15, 0.1)
	elif elite:
		health_fill.modulate = Color(0.9, 0.6, 0.2)
	else:
		health_fill.modulate = Color(0.85, 0.25, 0.2)


## 受击闪白（material_overlay 叠加，淡出）。
func _flash_hit() -> void:
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.albedo_color = Color(1, 1, 1, 0.0)
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for child in visual.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_overlay = _flash_material
	_flash_material.albedo_color.a = 0.7
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_material, "albedo_color:a", 0.0, 0.15)
