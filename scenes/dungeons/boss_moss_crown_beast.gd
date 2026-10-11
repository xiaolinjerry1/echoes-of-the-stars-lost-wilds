extends "res://scenes/actors/base_enemy.gd"
## 苔冠巨兽（微型秘境 BOSS）
## 职责：大型七招式三阶段 BOSS；横扫（前摇0.6s / 7m 120° / 29伤害）、
## 直线冲撞（前摇 1s 红色预警线 / 15m / 命中 40 伤害；撞石柱→失衡直接满→6s 破绽）、
## 召唤嫩芽（60% 血量后解锁；嫩芽靠近回血 5%/s×3s）。
## 践踏、前掌重砸、背后甩尾与锁定落点的根须束缚，全部对齐骨骼动作并支持失衡中断。
## 抗控：由 BossComponent 将冻结/眩晕转为失衡；破绽期间无法行动、承伤 +30%。
## 阶段：100-60% / 60-30%（+20% 频率、解锁召唤）/ 30-0%（再 +30% 频率、冲撞后接挥击）。

signal skill_used(skill_name: String)

const PHASE2_THRESHOLD := 0.6
const PHASE3_THRESHOLD := 0.3
const SWEEP_RANGE := 7.0
const SWEEP_HALF_ANGLE := 60.0
const SWEEP_DAMAGE := 29.0
const SWEEP_WINDUP := 0.6
const SWEEP_COOLDOWN := 4.0
const CHARGE_SPEED := 10.0
const CHARGE_DISTANCE := 15.0
const CHARGE_DAMAGE := 40.0
const CHARGE_WINDUP := 1.0
const CHARGE_COOLDOWN := 10.0
const SUMMON_WINDUP := 0.5
const SUMMON_COOLDOWN := 15.0
const ARENA_RADIUS := 16.0

## 竞技场中心（由秘境场景设置）
var arena_center := Vector3.ZERO
## 是否已激活战斗
var fight_active := false
## 本次死亡是否为首通（供秘境场景判定首通横幅）
var just_first_cleared := false

var _skill := 0
var _skill_timer := 0.0
var _sweep_cd := SWEEP_COOLDOWN
var _charge_cd := CHARGE_COOLDOWN
var _summon_cd := SUMMON_COOLDOWN
var _charge_dir := Vector3.FORWARD
var _charge_traveled := 0.0
var _dust_clock := 0.0
var _charge_hit_player := false
var _last_phase := 1
var _telegraph_root: Node3D
var _charge_line: MeshInstance3D
var _sweep_wedge: MeshInstance3D


func _ready() -> void:
	enemy_id = "moss_crown_beast"
	display_name = "苔冠巨兽"
	max_health = 780.0
	attack_power = 20.0
	armor = 15.0
	move_speed = 2.5
	attack_range = 5.0
	detection_range = 60.0
	aggro_range = 60.0
	patrol_radius = 0.0
	elite = true
	loot_table = "boss_moss_crown"
	health_bar_height = 7.0
	model_path = "res://art/models/boss/moss_crown_beast.glb"
	super._ready()
	if not ResourceLoader.exists(model_path):
		visual.scale = Vector3(2.4, 1.8, 2.4)
	if nav_agent != null:
		nav_agent.radius = 2.2
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null:
		shape_node.scale = Vector3.ONE
		var body_shape := CapsuleShape3D.new()
		body_shape.radius = 2.0
		body_shape.height = 5.0
		shape_node.shape = body_shape
		shape_node.position.y = 2.5
	var hit_shape := get_node("HitArea/CollisionShape3D") as CollisionShape3D
	var hit_box := BoxShape3D.new()
	hit_box.size = Vector3(4.5, 5.2, 8.5)
	hit_shape.shape = hit_box
	hit_shape.position = Vector3(0, 2.6, 0)
	spawn_position = arena_center
	visual.rotation.y = PI
	_motion.bind(visual, "moss_crown_beast")
	if boss != null: boss.staggering_started.connect(_interrupt_skill)
	_build_telegraphs()
	add_to_group("moss_crown_beast")


func _build_telegraphs() -> void:
	_telegraph_root = Node3D.new()
	_telegraph_root.name = "Telegraphs"
	add_child(_telegraph_root)
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(4.0, 0.04, CHARGE_DISTANCE)
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(1.0, 0.15, 0.1, 0.75)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.emission_enabled = true
	line_mat.emission = Color(1.0, 0.12, 0.08)
	line_mat.emission_energy_multiplier = 2.2
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mesh.material = line_mat
	_charge_line = MeshInstance3D.new()
	_charge_line.name = "ChargeLine"
	_charge_line.mesh = line_mesh
	_charge_line.visible = false
	_telegraph_root.add_child(_charge_line)
	# 扇形预警：朝前的 120° 三角扇（4 米半径）
	var wedge_mesh := _make_sweep_wedge_mesh()
	var wedge_mat := StandardMaterial3D.new()
	wedge_mat.albedo_color = Color(1.0, 0.55, 0.2, 0.4)
	wedge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wedge_mat.emission_enabled = true
	wedge_mat.emission = Color(1.0, 0.5, 0.15)
	wedge_mat.emission_energy_multiplier = 1.6
	wedge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wedge_mesh.surface_set_material(0, wedge_mat)
	_sweep_wedge = MeshInstance3D.new()
	_sweep_wedge.name = "SweepWedge"
	_sweep_wedge.mesh = wedge_mesh
	_sweep_wedge.visible = false
	_telegraph_root.add_child(_sweep_wedge)


## 生成朝 -Z 的 120° 扇形预警网格（半径 SWEEP_RANGE）。
func _make_sweep_wedge_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	for i in steps:
		var a0 := deg_to_rad(-SWEEP_HALF_ANGLE) + deg_to_rad(SWEEP_HALF_ANGLE * 2.0) * i / steps
		var a1 := deg_to_rad(-SWEEP_HALF_ANGLE) + deg_to_rad(SWEEP_HALF_ANGLE * 2.0) * (i + 1) / steps
		var p0 := Vector3(sin(a0) * SWEEP_RANGE, 0.0, -cos(a0) * SWEEP_RANGE)
		var p1 := Vector3(sin(a1) * SWEEP_RANGE, 0.0, -cos(a1) * SWEEP_RANGE)
		st.add_vertex(Vector3(0.0, 0.0, 0.0))
		st.add_vertex(p0)
		st.add_vertex(p1)
	st.generate_normals()
	return st.commit()


## 激活战斗（玩家进入竞技场时由秘境场景调用）。
func activate() -> void:
	if fight_active:
		return
	fight_active = true
	ComboNotifier.play_beep(self, global_position, 110.0)
	ComboNotifier.show_text(get_parent(), global_position + Vector3.UP * 3.2, "苔冠巨兽！", Color(1.0, 0.5, 0.3), 72)
	HitEffect.spawn_burst(get_parent(), global_position, Color(0.45, 0.6, 0.35), 48, 4.5)


func set_arena_center(center: Vector3) -> void:
	arena_center = center
	spawn_position = center


## 当前阶段（1/2/3：>60% / 30%-60% / ≤30%）。
func get_phase() -> int:
	var ratio := current_health / max_health
	if ratio > PHASE2_THRESHOLD:
		return 1
	if ratio > PHASE3_THRESHOLD:
		return 2
	return 3


## 冷却速度倍率（阶段 2 频率 +20%，阶段 3 再 +30%）。
func get_cooldown_speed() -> float:
	match get_phase():
		2:
			return 1.2
		3:
			return 1.2 * 1.3
	return 1.0


## 测试/调试：直接触发技能。
func force_sweep() -> void:
	_start_sweep()


func force_charge() -> void:
	_start_charge()


func force_summon() -> void:
	_start_summon()


func _update_state(delta: float) -> void:
	if not fight_active:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if boss != null and boss.is_staggered():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var speed := get_cooldown_speed()
	_sweep_cd = maxf(_sweep_cd - delta * speed, 0.0)
	_charge_cd = maxf(_charge_cd - delta * speed, 0.0)
	_summon_cd = maxf(_summon_cd - delta * speed, 0.0)
	for key in _extra_cooldowns: _extra_cooldowns[key] = maxf(0, float(_extra_cooldowns[key]) - delta * speed)
	_check_phase_change()
	if _skill != 0:
		_run_skill(delta)
		return
	var player := _get_player()
	if player == null:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var relative := player.global_position - global_position
	if relative.length() < 7.0 and relative.dot(global_transform.basis.z) > 1.0 and float(_extra_cooldowns["tail"]) <= 0:
		_start_extra("tail")
		return
	_face_direction(relative)
	var distance := global_position.distance_to(player.global_position)
	if get_phase() >= 2 and _summon_cd <= 0.0:
		_start_summon()
		return
	if get_phase() >= 2 and distance > 6.0 and float(_extra_cooldowns["roots"]) <= 0:
		_start_extra("roots")
		return
	if distance < 8.0:
		for key in ["stomp", "slam"]:
			if float(_extra_cooldowns[key]) <= 0:
				_start_extra(key)
				return
	if _charge_cd <= 0.0 and distance > 9.0:
		_start_charge()
		return
	if _sweep_cd <= 0.0 and distance <= SWEEP_RANGE + 1.2:
		_start_sweep()
		return
	if distance > attack_range:
		_move_towards(player.global_position, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _start_sweep() -> void:
	_skill = 1
	_skill_timer = SWEEP_WINDUP
	velocity.x = 0.0
	velocity.z = 0.0
	_sweep_wedge.visible = true
	_play_windup_telegraph(Color(1.0, 0.55, 0.2), "横扫!")
	_motion.play("sweep", true)
	_motion_rate = 0.88 / SWEEP_WINDUP
	skill_used.emit("sweep")


func _start_charge() -> void:
	var player := _get_player()
	if player == null:
		return
	_skill = 3
	_skill_timer = CHARGE_WINDUP
	_charge_hit_player = false
	_charge_traveled = 0.0
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.01:
		_charge_dir = to_player.normalized()
	_charge_line.visible = true
	var line_start := global_position + _charge_dir * (CHARGE_DISTANCE * 0.5 + 1.5)
	_charge_line.global_position = Vector3(line_start.x, global_position.y + 0.07, line_start.z)
	_charge_line.rotation.y = atan2(_charge_dir.x, _charge_dir.z)
	_play_windup_telegraph(Color(1.0, 0.2, 0.15), "冲撞!")
	_motion.play("charge_windup", true)
	_motion_rate = 1.0
	skill_used.emit("charge")


func _start_summon() -> void:
	_skill = 5
	_skill_timer = SUMMON_WINDUP
	velocity.x = 0.0
	velocity.z = 0.0
	_play_windup_telegraph(Color(0.4, 1.0, 0.4), "召唤!")
	_motion.play("summon", true)
	_motion_rate = 0.99 / SUMMON_WINDUP
	skill_used.emit("summon")


func _run_skill(delta: float) -> void:
	_skill_timer -= delta
	match _skill:
		1:
			velocity.x = 0.0
			velocity.z = 0.0
			if _skill_timer <= 0.0:
				_sweep_wedge.visible = false
				_do_sweep()
				_motion_rate = 1.0
				_sweep_cd = SWEEP_COOLDOWN
				_skill = 2
				_skill_timer = 0.8
		2:
			if _skill_timer <= 0.0:
				if _combo_left>0:
					_combo_left -= 1
					var target := _get_player()
					if target!=null: _face_direction(target.global_position-global_position)
					_start_extra("slam",true)
				else: _skill = 0
		3:
			velocity.x = 0.0
			velocity.z = 0.0
			if _skill_timer <= 0.0:
				_charge_line.visible = false
				_skill = 4
				_motion.play("charge", true)
		4:
			_run_charge(delta)
		5:
			velocity.x = 0.0
			velocity.z = 0.0
			if _skill_timer <= 0.0:
				_do_summon()
				_summon_cd = SUMMON_COOLDOWN
				_skill = 2
				_skill_timer = 0.8
				_motion_rate = 1.0
		6:
			velocity.x = 0
			velocity.z = 0
			if _skill_timer <= 0:
				_resolve_extra()
				_clear_extra_warning()
				_skill = 2
				_skill_timer = 0.9
				_motion_rate = 1.0
	_clamp_arena()


func _run_charge(delta: float) -> void:
	_dust_clock-=delta
	if _dust_clock<=0.0:
		_dust_clock=0.16
		HitEffect.spawn_burst(get_parent(),global_position+Vector3.UP*0.15,Color(0.65,0.5,0.3),8,2.8)
	velocity.x = _charge_dir.x * CHARGE_SPEED
	velocity.z = _charge_dir.z * CHARGE_SPEED
	_charge_traveled += CHARGE_SPEED * delta
	for pillar in get_tree().get_nodes_in_group("dungeon_pillar"):
		if pillar is Node3D and not bool(pillar.call("is_shattered")):
			if global_position.distance_to((pillar as Node3D).global_position) < 3.3:
				pillar.call("shatter")
				_hit_pillar()
				return
	var player := _get_player()
	if not _charge_hit_player and player != null:
		if global_position.distance_to(player.global_position) < 3.0:
			_charge_hit_player = true
			player.take_damage(CHARGE_DAMAGE, self)
			var push := player.global_position - global_position
			push.y = 0.0
			player.call("apply_external_knockback", push.normalized(), 12.0)
			player.call("add_camera_shake", 0.06, 0.4)
			HitEffect.spawn_burst(get_parent(), player.global_position + Vector3.UP, Color(1.0, 0.5, 0.3), 24, 3.5)
			_end_charge()
			return
	if _charge_traveled >= CHARGE_DISTANCE or global_position.distance_to(arena_center) > ARENA_RADIUS - 4.5:
		_end_charge()


func _end_charge() -> void:
	_skill = 2
	_skill_timer = 0.8
	_motion.play("recover", true)
	velocity.x = 0.0
	velocity.z = 0.0
	_charge_cd = CHARGE_COOLDOWN
	if get_phase() == 3:
		_start_sweep()


func _hit_pillar() -> void:
	_skill = 0
	velocity.x = 0.0
	velocity.z = 0.0
	_charge_cd = CHARGE_COOLDOWN
	HitEffect.spawn_burst(get_parent(), global_position + Vector3.UP * 1.5, Color(0.8, 0.75, 0.6), 40, 5.0)
	ComboNotifier.play_beep(self, global_position, 90.0)
	if boss != null:
		boss.add_stagger(boss.stagger_max)


func _do_sweep() -> void:
	var player := _get_player()
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	HitEffect.spawn_burst(get_parent(), global_position + forward * 2.0 + Vector3.UP * 0.4, Color(1.0, 0.6, 0.25), 26, 4.0)
	ComboNotifier.play_beep(self, global_position, 160.0)
	if player == null:
		return
	for i in 10:
		var a := deg_to_rad(-60.0+i*120.0/9)
		CombatImpact.spawn(get_parent(),global_position+forward.rotated(Vector3.UP,a)*5.5+Vector3.UP*1.2,forward,true)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > SWEEP_RANGE:
		return
	var angle := rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle > SWEEP_HALF_ANGLE:
		return
	player.take_damage(SWEEP_DAMAGE, self)
	player.call("apply_external_knockback", to_player.normalized(), 7.0)
	player.call("add_camera_shake", 0.05, 0.3)


func _do_summon() -> void:
	var sprout_scene := load("res://scenes/dungeons/boss_sprout.tscn") as PackedScene
	if sprout_scene == null:
		return
	for i in 2:
		var sprout := sprout_scene.instantiate() as Node3D
		var angle := randf() * TAU
		var radius := randf_range(10.0, 14.0)
		var pos := arena_center + Vector3(cos(angle) * radius, 0.1, sin(angle) * radius)
		sprout.position = get_parent().to_local(pos)
		sprout.set("heal_target", self)
		get_parent().add_child(sprout)
		HitEffect.spawn_burst(get_parent(), pos, Color(0.45, 1.0, 0.5), 20, 2.5)
	ComboNotifier.show_text(get_parent(), global_position + Vector3.UP * 3.2, "苔冠巨兽召唤了嫩芽！", Color(0.5, 1.0, 0.55), 48)


func _check_phase_change() -> void:
	var phase := get_phase()
	if phase == _last_phase:
		return
	_last_phase = phase
	_extra_cooldowns.stomp=minf(float(_extra_cooldowns.stomp),1.0)
	_extra_cooldowns.slam=minf(float(_extra_cooldowns.slam),2.5)
	_extra_cooldowns.roots=minf(float(_extra_cooldowns.roots),2.0)
	_summon_cd=minf(_summon_cd,4.0)
	if phase == 2:
		ComboNotifier.show_text(get_parent(), global_position + Vector3.UP * 3.2, "苔冠巨兽开始召唤嫩芽！", Color(1.0, 0.75, 0.35), 50)
	elif phase == 3:
		ComboNotifier.show_text(get_parent(), global_position + Vector3.UP * 3.2, "苔冠巨兽暴怒了！", Color(1.0, 0.45, 0.25), 54)


func _clamp_arena() -> void:
	var offset := global_position - arena_center
	offset.y = 0.0
	if offset.length() > ARENA_RADIUS - 4.0:
		var clamped := arena_center + offset.normalized() * (ARENA_RADIUS - 4.0)
		global_position = Vector3(clamped.x, global_position.y, clamped.z)


## BOSS 死亡：首通奖励（霜灯学者回响 / 已拥有则回响尘×5）+ 崩塌特效。
func die() -> void:
	if state == State.DEAD:
		return
	_interrupt_skill()
	velocity = Vector3.ZERO
	var player := _get_player() as PlayerController
	if player != null:
		player.add_camera_shake(0.08, 0.6)
	HitEffect.spawn_burst(get_parent(), global_position + Vector3.UP * 1.5, Color(0.45, 0.7, 0.35), 80, 6.0)
	var session := get_tree().get_first_node_in_group("game_session") as GameSession
	if session != null and not bool(session.world_data.get("dungeon_first_clear", false)):
		session.world_data["dungeon_first_clear"] = true
		just_first_cleared = true
		_grant_first_clear(player)
	if session != null:
		var events: Array = session.world_data.get("completed_events", [])
		if not events.has("dungeon_grove_cleared"):
			events.append("dungeon_grove_cleared")
			session.world_data["completed_events"] = events
	super.die()


func _grant_first_clear(player: PlayerController) -> void:
	if player.survivor_mode:
		player.show_combat_feedback("苔冠巨兽已击败 · 收集经验继续强化",Color(0.7,1,0.8))
		return
	if player == null:
		return
	var echo_system := player.echo_system
	if echo_system != null and not echo_system.has_collected("frost_lamp_scholar"):
		echo_system.collect_echo("frost_lamp_scholar")
		player.show_combat_feedback("击败苔冠巨兽！获得回响：霜灯学者", Color(0.6, 0.8, 1.0))
	else:
		player.inventory.add_material("echo_dust", 5)
		player.show_combat_feedback("击败苔冠巨兽！获得回响尘×5", Color(0.6, 0.8, 1.0))


# 新招式共用前摇、锁定落点、单次判定和收招；颜色指示沿用既有战斗预警。
const EXTRA_SKILLS := {
	"stomp": {"windup": 1.1, "cooldown": 8.0, "radius": 9.0, "damage": 24.0, "label": "践踏震波"},
	"slam": {"windup": 1.0, "cooldown": 7.0, "radius": 2.5, "damage": 32.0, "label": "前掌重砸"},
	"tail": {"windup": 0.95, "cooldown": 9.0, "radius": 7.0, "damage": 26.0, "label": "转身甩尾"},
	"roots": {"windup": 1.3, "cooldown": 13.0, "radius": 2.2, "damage": 12.0, "label": "根须束缚"},
}
var _extra_cooldowns := {"stomp": 5.0, "slam": 3.0, "tail": 2.0, "roots": 7.0}
var _extra_skill := ""
var _combo_left := 0
var _locked_position := Vector3.ZERO
var _extra_warning: MeshInstance3D
var _motion = preload("res://scenes/actors/asset_animation.gd").new()
var _motion_rate := 1.0

func force_extra(clip: String) -> void:
	if EXTRA_SKILLS.has(clip) and state != State.DEAD: _start_extra(clip)

func _start_extra(clip: String, continuation := false) -> void:
	if not continuation: _combo_left = 1 if clip=="slam" and get_phase()>=2 else 0
	_clear_extra_warning()
	_extra_skill = clip
	var spec: Dictionary = EXTRA_SKILLS[clip]
	_skill = 6
	_skill_timer = float(spec.windup)
	_extra_cooldowns[clip] = float(spec.cooldown)
	velocity.x = 0
	velocity.z = 0
	_locked_position = global_position
	if clip == "slam": _locked_position -= global_transform.basis.z * 4.5
	if clip == "roots":
		var target := _get_player()
		if target != null: _locked_position = target.global_position
	_locked_position.y = global_position.y + 0.08
	_motion.play(clip, true)
	_motion_rate = (2.0 if clip in ["stomp", "roots"] else 1.8) * 0.55 / float(spec.windup)
	_play_windup_telegraph(Color(0.9, 0.55, 0.15), String(spec.label) + "！")
	# 静止范围标记锁定到世界位置，前摇期间不追踪玩家。
	_extra_warning = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = float(spec.radius) - 0.12
	ring.outer_radius = float(spec.radius)
	ring.rings = 48
	ring.ring_segments = 8
	ring.material = _charge_line.mesh.material
	_extra_warning.mesh = ring
	if clip == "tail":
		var rear_wedge := _make_sweep_wedge_mesh()
		rear_wedge.surface_set_material(0, _charge_line.mesh.material)
		_extra_warning.mesh = rear_wedge
	get_parent().add_child(_extra_warning)
	_extra_warning.global_position = _locked_position
	_extra_warning.scale.y = 0.2
	if clip == "tail": _extra_warning.global_rotation.y = global_rotation.y + PI
	if clip=="roots":
		var side := global_transform.basis.x*3.4
		for offset in [Vector3.ZERO,side,-side]:
			BossGroundWave.spawn(self,_locked_position+offset,float(spec.windup),2.2,12.0,true)
	skill_used.emit(clip)

func _resolve_extra() -> void:
	var spec: Dictionary = EXTRA_SKILLS[_extra_skill]
	if _extra_skill=="stomp":
		BossGroundWave.spawn(self,_locked_position,0.0,9.0,24.0)
		if get_phase()>=2: BossGroundWave.spawn(self,_locked_position,1.0,10.0,16.0)
		return
	if _extra_skill=="roots": return
	for i in 12:
		var radial := Vector3(cos(i*TAU/12),0,sin(i*TAU/12))
		if _extra_skill=="tail":radial=global_transform.basis.z.rotated(Vector3.UP,lerpf(-PI/3.0,PI/3.0,i/11.0))
		CombatImpact.spawn(get_parent(),_locked_position+radial*float(spec.radius)+Vector3.UP*0.5,Vector3.DOWN,true)
	BossGroundWave.spawn(self,_locked_position,0.0,float(spec.radius),0.0)
	RingEffect.spawn(get_parent(), _locked_position, Color(0.7, 0.65, 0.25), float(spec.radius))
	var target := _get_player()
	if target == null: return
	var offset := target.global_position - _locked_position
	var height := offset.y
	offset.y = 0
	if offset.length() > float(spec.radius): return
	if _extra_skill == "tail" and offset.normalized().dot(global_transform.basis.z) < cos(deg_to_rad(SWEEP_HALF_ANGLE)): return
	if _extra_skill == "stomp" and height > 0.8: return
	target.take_damage(float(spec.damage), self)
	if _extra_skill == "roots": target.call("apply_effect", "rooted", 1.5, 1.0)
	else: target.call("apply_external_knockback", offset.normalized(), 6.0)
	target.call("add_camera_shake", 0.05, 0.3)

func _clear_extra_warning() -> void:
	if is_instance_valid(_extra_warning): _extra_warning.queue_free()
	_extra_warning = null

func _interrupt_skill() -> void:
	_combo_left=0
	if is_inside_tree():
		for hazard in get_tree().get_nodes_in_group("boss_hazard"):
			if hazard.boss==self: hazard.queue_free()
	_skill = 0
	_skill_timer = 0
	_clear_extra_warning()
	if _charge_line != null: _charge_line.visible = false
	if _sweep_wedge != null: _sweep_wedge.visible = false
	velocity.x = 0
	velocity.z = 0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD:
		_motion.advance(delta)
		return
	if boss != null and boss.is_staggered():
		_motion.play("stagger")
		_motion.advance(delta, true)
		return
	if _skill == 0:
		_motion.play("walk" if Vector2(velocity.x, velocity.z).length() > 0.1 else "idle")
		_motion_rate = maxf(0.2, Vector2(velocity.x, velocity.z).length() / 1.43) if _motion.current == "walk" else 1.0
	elif _skill == 4:
		_motion_rate = 2.5
	_motion.advance(delta * _motion_rate, _skill == 0 or _skill == 4)

func _play_death_visual() -> float:
	if _motion.player == null: return super._play_death_visual()
	_motion.play("death", true)
	return 2.0

func _exit_tree() -> void:
	_clear_extra_warning()
