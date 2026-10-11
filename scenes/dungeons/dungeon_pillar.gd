extends StaticBody3D
## 秘境石柱
## 职责：BOSS 冲锋撞柱时碎裂（碰撞禁用 + 碎块特效），60 秒后重生；
## 模型就绪后由 model_path 替换程序化占位。

@export var respawn_delay := 60.0
@export var model_path := "res://art/models/scenery/dungeon_pillar.glb"

var _shattered := false
var _debris: Node3D

@onready var visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("dungeon_pillar")
	add_to_group("nav_source")
	collision_layer = 1
	collision_mask = 0
	visual.add_child(PropFactory.model_node(model_path, _pillar_fallback()))


func _pillar_fallback() -> Node3D:
	var fallback := Node3D.new()
	fallback.add_child(PropFactory.cylinder(0.85, 0.6, Color(0.48, 0.47, 0.44), Vector3(0, 0.3, 0), 1.0, 10))
	fallback.add_child(PropFactory.cylinder(0.55, 4.0, Color(0.55, 0.54, 0.5), Vector3(0, 2.6, 0), 0.6, 10))
	fallback.add_child(PropFactory.box(Vector3(1.5, 0.5, 1.5), Color(0.44, 0.43, 0.4), Vector3(0, 4.85, 0)))
	return fallback


func is_shattered() -> bool:
	return _shattered


## 碎裂：禁用碰撞、隐藏柱体、生成碎块，延时重生。
func shatter() -> void:
	if _shattered:
		return
	_shattered = true
	collision_layer = 0
	visual.visible = false
	_spawn_debris()
	HitEffect.spawn_burst(get_parent(), global_position + Vector3.UP * 2.0, Color(0.7, 0.68, 0.6), 36, 4.5)
	ComboNotifier.play_beep(self, global_position + Vector3.UP * 2.0, 140.0)
	await get_tree().create_timer(respawn_delay).timeout
	respawn()


## 重生：恢复碰撞与柱体。
func respawn() -> void:
	if not _shattered:
		return
	_shattered = false
	collision_layer = 1
	visual.visible = true
	if _debris != null and is_instance_valid(_debris):
		_debris.queue_free()
		_debris = null
	HitEffect.spawn_burst(get_parent(), global_position + Vector3.UP * 1.5, Color(0.55, 0.75, 0.5), 20, 2.5)


func _spawn_debris() -> void:
	_debris = Node3D.new()
	_debris.name = "Debris"
	get_parent().add_child(_debris)
	_debris.global_position = global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261002
	for i in 8:
		var chunk := PropFactory.box(
			Vector3(rng.randf_range(0.25, 0.6), rng.randf_range(0.2, 0.45), rng.randf_range(0.25, 0.6)),
			Color(0.5, 0.49, 0.46)
		)
		var angle := rng.randf() * TAU
		chunk.position = Vector3(cos(angle) * rng.randf_range(0.4, 1.4), rng.randf_range(0.15, 0.6), sin(angle) * rng.randf_range(0.4, 1.4))
		chunk.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		_debris.add_child(chunk)
