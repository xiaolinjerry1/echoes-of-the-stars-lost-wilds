class_name DayNightCycle
extends Node
## DayNightCycle（昼夜循环）
## 职责：40 分钟一昼夜，驱动太阳角度/颜色/能量与环境环境光；
## 夜晚保留足够环境亮度（不黑）；营火/灯光在夜晚增强；支持休息跳时。

signal time_advanced(hours: float)

@export var day_length_seconds := 2400.0
@export var start_hours := 8.0
@export var sun_path: NodePath
@export var environment_path: NodePath

## 当前时刻（0-24）
var hours := 8.0
## 太阳基础能量（天气系统在其上做乘法）
var sun_base_energy := 1.2
## 基础雾密度（天气系统在其上加值）
var base_fog_density := 0.0025

var _sun: DirectionalLight3D
var _env: WorldEnvironment
var _fire_lights: Array[OmniLight3D] = []
var _fire_base_energy: Dictionary = {}


func _ready() -> void:
	add_to_group("day_night")
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_env = get_node_or_null(environment_path) as WorldEnvironment
	if _env != null and _env.environment != null:
		base_fog_density = _env.environment.fog_density
	hours = start_hours
	_apply()


func _process(delta: float) -> void:
	advance(delta / maxf(day_length_seconds, 1.0) * 24.0)


func advance(delta_hours: float) -> void:
	hours = fposmod(hours + delta_hours, 24.0)
	_apply()
	time_advanced.emit(hours)


func set_time_of_day(value: float) -> void:
	hours = fposmod(value, 24.0)
	_apply()
	time_advanced.emit(hours)


func get_hours() -> float:
	return hours


func is_night() -> bool:
	return hours < 6.0 or hours >= 19.5


## 注册夜间增强的灯光（营火/锻造炉等）。
func register_fire_light(light: OmniLight3D) -> void:
	if light == null or _fire_base_energy.has(light):
		return
	_fire_lights.append(light)
	_fire_base_energy[light] = light.light_energy
	_apply_fire_lights()


## ---- 存档接口 ----


func get_save_data() -> Dictionary:
	return {"world_time": hours}


func load_save_data(data: Dictionary) -> void:
	set_time_of_day(float(data.get("world_time", 8.0)))


func _apply() -> void:
	var day_factor := clampf(sin((hours - 6.0) / 12.0 * PI), 0.0, 1.0)
	var dusk := maxf(clampf(1.0 - absf(hours - 6.5) / 1.5, 0.0, 1.0), clampf(1.0 - absf(hours - 18.5) / 1.5, 0.0, 1.0))
	sun_base_energy = lerpf(0.04, 1.25, day_factor)
	if _sun != null:
		# DirectionalLight3D沿-Z照射；白天X必须为负，太阳才能从上方照向地面。
		var solar_elevation := sin((hours - 6.0) / 12.0 * PI) * 90.0
		_sun.rotation = Vector3(deg_to_rad(-solar_elevation), deg_to_rad(-30.0), 0.0)
		_sun.light_energy = sun_base_energy
		var day_color := Color(1.0, 0.97, 0.90)
		var night_color := Color(0.55, 0.65, 0.95)
		var dusk_color := Color(1.0, 0.62, 0.35)
		var color := night_color.lerp(day_color, day_factor)
		_sun.light_color = color.lerp(dusk_color, dusk * 0.7)
	if _env != null and _env.environment != null:
		_env.environment.ambient_light_energy = lerpf(0.22, 0.55, day_factor)
		_env.environment.background_energy_multiplier = lerpf(0.35, 1.0, day_factor)
		_env.environment.fog_light_color = Color(0.60, 0.68, 0.80).lerp(Color(0.75, 0.85, 0.95), day_factor)
	_apply_fire_lights()


func _apply_fire_lights() -> void:
	var night := clampf(1.0 - sin((hours - 6.0) / 12.0 * PI) * 2.2, 0.0, 1.0)
	for light in _fire_lights:
		if not is_instance_valid(light):
			continue
		var base := float(_fire_base_energy.get(light, 1.5))
		light.light_energy = base * lerpf(0.35, 1.15, night)
