class_name SpiritEntity
extends Node3D
## SpiritEntity（精灵视觉实体）
## 职责：精灵的跟随表现（平滑滞后 + 漂浮 + 自转）、模型装载、
## 击退位移与效果特效播放。无碰撞体、无血条，不会死亡。

const FOLLOW_SPEED := 6.0
const FLOAT_AMPLITUDE := 0.06
const FLOAT_SPEED := 2.2
const SPIN_SPEED := 0.8
const KNOCK_SPEED := 5.0
const KNOCK_DAMP := 4.0

## 跟随目标（通常是 Player 的 SpiritMount）
var follow_target: Node3D = null

var _model_root: Node3D = null
var _placeholder: MeshInstance3D = null
var _float_time := 0.0
var _knock_velocity := Vector3.ZERO
var _is_knocked := false
var _motion = preload("res://scenes/actors/asset_animation.gd").new()


func _ready() -> void:
	_model_root = $ModelRoot
	_placeholder = $ModelRoot/Placeholder


## 装载精灵模型；model_path 不存在时保留发光球占位并按定位染色。
func setup_model(spirit_data: SpiritData) -> void:
	if _model_root == null:
		return
	if spirit_data != null and not spirit_data.model_path.is_empty() and ResourceLoader.exists(spirit_data.model_path):
		var packed := load(spirit_data.model_path) as PackedScene
		if packed != null:
			for child in _model_root.get_children():
				if child != _placeholder:
					child.queue_free()
			var model := packed.instantiate()
			_model_root.add_child(model)
			_motion = preload("res://scenes/actors/asset_animation.gd").new()
			_motion.bind(model, spirit_data.model_path.get_file().get_basename())
			if _placeholder != null:
				_placeholder.visible = false
			return
	if _placeholder != null:
		_placeholder.visible = true
		var sphere := _placeholder.mesh as SphereMesh
		if sphere != null:
			var material := sphere.material as StandardMaterial3D
			if material != null:
				material = material.duplicate() as StandardMaterial3D
				sphere.material = material
				var color := _placeholder_color(spirit_data)
				material.albedo_color = color
				material.emission = color


func _placeholder_color(spirit_data: SpiritData) -> Color:
	if spirit_data == null:
		return Color(1.0, 0.85, 0.45)
	match spirit_data.role:
		"heal":
			return Color(1.0, 0.85, 0.45)
		"damage":
			return Color(1.0, 0.45, 0.15)
		_:
			return Color(0.55, 0.65, 0.8)


func _physics_process(delta: float) -> void:
	if _is_knocked:
		global_position += _knock_velocity * delta
		_knock_velocity = _knock_velocity.move_toward(Vector3.ZERO, KNOCK_DAMP * delta)
		return
	if follow_target != null and follow_target.is_inside_tree():
		global_position = global_position.lerp(follow_target.global_position, clampf(FOLLOW_SPEED * delta, 0.0, 1.0))


func _process(delta: float) -> void:
	if _motion.current != "idle" and _motion.finished(): _motion.play("idle")
	_motion.advance(delta, _motion.current == "idle")
	_float_time += delta
	if _model_root != null:
		_model_root.position.y = sin(_float_time * FLOAT_SPEED) * FLOAT_AMPLITUDE
		_model_root.rotate_y(SPIN_SPEED * delta)


## 播放效果反馈（按效果类型着色的粒子爆裂占位）。
func play_effect(effect_type: String) -> void:
	_motion.play("shield" if effect_type == "damage_reduction" else effect_type, true)
	var color := Color(1, 1, 1)
	match effect_type:
		"heal":
			color = Color(0.5, 1.0, 0.55)
		"shield":
			color = Color(1.0, 0.95, 0.7)
		"attack":
			color = Color(1.0, 0.55, 0.2)
		"damage_reduction":
			color = Color(0.6, 0.75, 1.0)
		"taunt":
			color = Color(0.7, 0.7, 0.75)
	HitEffect.spawn_burst(self, global_position, color, 14, 2.2)


## 被击退：朝来源反方向弹开（由 SpiritCompanion 控制回归时机）。
func apply_knockback(from_position: Vector3) -> void:
	_motion.play("hit", true)
	var direction := global_position - from_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	_knock_velocity = direction.normalized() * KNOCK_SPEED
	_is_knocked = true


func end_knockback() -> void:
	_is_knocked = false
	_knock_velocity = Vector3.ZERO


func is_knocked_back() -> bool:
	return _is_knocked
