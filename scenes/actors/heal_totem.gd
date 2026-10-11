class_name HealTotem
extends StaticBody3D
## HealTotem（治疗图腾）
## 职责：支援怪放置的图腾，持续 5 秒；每秒治疗 6 米内友军 5% 最大生命；
## 拥有 20 点生命，可被玩家优先破坏，到期或破坏时消失。

@export var max_health := 20.0
## 持续时间（秒）
@export var duration := 5.0
## 治疗半径（米）
@export var heal_radius := 6.0
## 每秒治疗比例（最大生命）
@export var heal_ratio_per_second := 0.05
## 模型路径（Blender 导出）
@export var model_path := "res://art/models/prop/heal_totem.glb"

var health := 0.0

var _life := 0.0
var _heal_accum := 0.0

@onready var visual: Node3D = $Visual


func _ready() -> void:
	health = max_health
	collision_layer = 4 | 8  # actor_body（阻挡） + hit_area（可被攻击）
	collision_mask = 0
	add_to_group("heal_totem")
	_load_model()
	ComboNotifier.play_beep(self, global_position, 760.0)


func _process(delta: float) -> void:
	_life += delta
	if _life >= duration:
		_expire()
		return
	_heal_accum += delta
	if _heal_accum >= 1.0:
		_heal_accum -= 1.0
		_heal_pulse()


func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	ComboNotifier.play_beep(self, global_position, 200.0)
	if health <= 0.0:
		ComboNotifier.show_text(get_parent(), global_position + Vector3.UP * 1.3, "图腾被破坏！", Color(0.9, 0.6, 0.4), 40)
		HitEffect.spawn_burst(get_parent(), global_position + Vector3.UP * 0.8, Color(0.5, 1.0, 0.55), 26, 3.0)
		queue_free()


## ---- 内部实现 ----

func _load_model() -> void:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return
	var packed := load(model_path) as PackedScene
	if packed != null:
		visual.add_child(packed.instantiate())


func _heal_pulse() -> void:
	for ally in get_tree().get_nodes_in_group("enemy"):
		if not (ally is BaseEnemy):
			continue
		var enemy := ally as BaseEnemy
		if enemy.global_position.distance_to(global_position) > heal_radius:
			continue
		if enemy.current_health >= enemy.max_health:
			continue
		enemy.heal(enemy.max_health * heal_ratio_per_second)
		HitEffect.spawn_burst(get_parent(), enemy.global_position + Vector3.UP, Color(0.5, 1.0, 0.55), 6, 1.2)


func _expire() -> void:
	HitEffect.spawn_burst(get_parent(), global_position + Vector3.UP * 0.8, Color(0.5, 1.0, 0.55), 10, 1.6)
	queue_free()
