class_name WeatherSystem
extends Node
## WeatherSystem（简易天气）
## 职责：晴天/多云薄雾/小雨三种状态，权重渐变过渡（避免光照跳变）；
## 太阳能量与环境雾密度在昼夜系统基础上叠加；雨天启用雨粒子并对玩家区域施加潮湿感。
## 调试：F6（weather_cycle）循环切换；E2E 直接调用 set_weather_state()。

signal weather_changed(state)

const STATE_CLEAR := "clear"
const STATE_CLOUDY := "cloudy"
const STATE_RAIN := "rain"
const STATE_ORDER := ["clear", "cloudy", "rain"]

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var player_path: NodePath
@export var blend_seconds := 8.0

var current_state := STATE_CLEAR

var _blend := {"clear": 1.0, "cloudy": 0.0, "rain": 0.0}
var _targets := {"clear": 1.0, "cloudy": 0.0, "rain": 0.0}
var _sun: DirectionalLight3D
var _env: WorldEnvironment
var _player: Node3D
var _day_night: Node
var _rain: GPUParticles3D


func _ready() -> void:
	add_to_group("weather")
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_env = get_node_or_null(environment_path) as WorldEnvironment
	_player = get_node_or_null(player_path) as Node3D
	_day_night = get_tree().get_first_node_in_group("day_night")
	_build_rain()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weather_cycle"):
		var index := STATE_ORDER.find(current_state)
		set_weather_state(STATE_ORDER[(index + 1) % STATE_ORDER.size()])


func set_weather_state(state: String) -> void:
	if not _targets.has(state):
		return
	current_state = state
	for key in _targets.keys():
		_targets[key] = 1.0 if key == state else 0.0
	weather_changed.emit(state)


## 绑定玩家（雨幕跟随玩家头顶）。
func set_player(player: Node3D) -> void:
	_player = player


func get_weather_state() -> String:
	return current_state


## ---- 存档接口 ----


func get_save_data() -> Dictionary:
	return {"weather_state": current_state}


func load_save_data(data: Dictionary) -> void:
	var state := str(data.get("weather_state", STATE_CLEAR))
	set_weather_state(state)
	_snap_to(state)


## 立即切换到目标权重（读档时不播放渐变）。
func _snap_to(state: String) -> void:
	for key in _targets.keys():
		_targets[key] = 1.0 if key == state else 0.0
		_blend[key] = float(_targets[key])
	_apply()


func _process(delta: float) -> void:
	var step := delta / maxf(blend_seconds, 0.1)
	var changed := false
	for key in _blend.keys():
		var before := float(_blend[key])
		_blend[key] = move_toward(before, float(_targets[key]), step)
		if not is_equal_approx(before, float(_blend[key])):
			changed = true
	if not changed:
		return
	_apply()
	if _rain != null and _player != null:
		_rain.position = _player.global_position + Vector3(0, 16.0, 0)


func _apply() -> void:
	var sun_mult := float(_blend["clear"]) * 1.0 + float(_blend["cloudy"]) * 0.72 + float(_blend["rain"]) * 0.5
	if _sun != null:
		var base := 1.2
		if _day_night != null:
			base = float(_day_night.get("sun_base_energy"))
		_sun.light_energy = base * sun_mult
	if _env != null and _env.environment != null:
		var base_fog := 0.0025
		if _day_night != null:
			base_fog = float(_day_night.get("base_fog_density"))
		_env.environment.fog_enabled = true
		_env.environment.fog_density = base_fog + float(_blend["cloudy"]) * 0.010 + float(_blend["rain"]) * 0.026
	if _rain != null:
		_rain.emitting = float(_blend["rain"]) > 0.35


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 700
	_rain.lifetime = 1.2
	_rain.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 30, 80))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, -1, 0)
	process.spread = 4.0
	process.initial_velocity_min = 14.0
	process.initial_velocity_max = 18.0
	process.gravity = Vector3(0, -6, 0)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(34, 1, 34)
	_rain.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.015, 0.5, 0.015)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.75, 0.85, 1.0, 0.6)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = drop_mat
	_rain.draw_pass_1 = drop
	_rain.emitting = false
	add_child(_rain)
