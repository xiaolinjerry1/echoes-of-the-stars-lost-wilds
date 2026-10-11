extends "res://scenes/actors/base_enemy.gd"
## 嫩芽（BOSS 召唤物）
## 职责：不攻击，缓慢走向苔冠巨兽；抵达 2 米内后为其恢复生命
##（每秒 5% 最大生命，持续 3 秒，绿色连线）；可被玩家击杀。

var heal_target: Node3D = null

var _heal_time := 0.0
var _heal_tick := 0.0
var _beam: Node3D
var _motion = preload("res://scenes/actors/asset_animation.gd").new()


func _ready() -> void:
	enemy_id = "boss_sprout"
	display_name = "嫩芽"
	max_health = 20.0
	attack_power = 0.0
	armor = 0.0
	move_speed = 2.2
	attack_range = 1.0
	detection_range = 0.0
	aggro_range = 0.0
	patrol_radius = 0.0
	loot_table = "sprout"
	health_bar_height = 0.9
	model_path = "res://art/models/boss/boss_sprout.glb"
	super._ready()
	visual.rotation.y = PI
	_motion.bind(visual, "boss_sprout")
	if not ResourceLoader.exists(model_path):
		visual.scale = Vector3(0.6, 0.6, 0.6)
	add_to_group("boss_sprout")
	_build_beam()


func _build_beam() -> void:
	_beam = Node3D.new()
	_beam.name = "HealBeam"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.09
	mesh.height = 1.0
	mesh.radial_segments = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 1.0, 0.55, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.4, 1.0, 0.5)
	material.emission_energy_multiplier = 2.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	var beam_mesh := MeshInstance3D.new()
	beam_mesh.mesh = mesh
	beam_mesh.rotation_degrees.x = 90.0
	_beam.add_child(beam_mesh)
	_beam.visible = false
	add_child(_beam)


func _update_state(delta: float) -> void:
	if heal_target == null or not is_instance_valid(heal_target):
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if is_healing_target_dead():
		velocity.x = 0.0
		velocity.z = 0.0
		_beam.visible = false
		return
	if _heal_time > 0.0:
		_heal_target_tick(delta)
		return
	var distance := global_position.distance_to(heal_target.global_position)
	var healing_radius := 5.0 if heal_target.is_in_group("moss_crown_beast") else 2.0
	if distance > healing_radius:
		_move_towards(heal_target.global_position, delta)
		_face_direction(heal_target.global_position - global_position)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_heal_time = 3.0
		_heal_tick = 0.0
		_beam.visible = true
		ComboNotifier.show_text(get_parent(), global_position + Vector3.UP * 1.0, "嫩芽开始滋养苔冠巨兽！", Color(0.5, 1.0, 0.55), 38)


func is_healing_target_dead() -> bool:
	return int(heal_target.get("state")) == State.DEAD


func _heal_target_tick(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_heal_tick += delta
	_heal_time -= delta
	if _heal_tick >= 1.0:
		_heal_tick -= 1.0
		if heal_target.has_method("heal"):
			heal_target.call("heal", float(heal_target.get("max_health")) * 0.05)
		HitEffect.spawn_burst(get_parent(), global_position + Vector3.UP * 0.8, Color(0.5, 1.0, 0.55), 10, 1.6)
	_update_beam()
	if _heal_time <= 0.0:
		_beam.visible = false
		ComboNotifier.show_text(get_parent(), global_position + Vector3.UP * 1.0, "嫩芽枯萎了", Color(0.6, 0.75, 0.5), 34)
		die()


func _update_beam() -> void:
	if _beam == null or not _beam.visible:
		return
	var target_pos := heal_target.global_position + Vector3.UP * 0.8
	var to_target := target_pos - global_position
	var distance := to_target.length()
	if distance < 0.1:
		return
	_beam.global_position = global_position + to_target * 0.5
	_beam.look_at(target_pos, Vector3.UP)
	_beam.scale = Vector3(1.0, 1.0, distance)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD:
		_motion.advance(delta)
		return
	if status.has_effect(StatusEffects.FROZEN): return
	if state == State.STAGGERED:
		_motion.play("hit")
	else:
		_motion.play("heal" if _heal_time > 0 else ("walk" if Vector2(velocity.x, velocity.z).length() > 0.1 else "idle"))
	_motion.advance(delta, true)

func _play_death_visual() -> float:
	if _beam != null: _beam.visible = false
	if _motion.player == null: return super._play_death_visual()
	_motion.play("death", true)
	return 1.6
