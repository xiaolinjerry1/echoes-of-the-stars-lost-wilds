extends StaticBody3D
## Chest（宝箱）
## 职责：可交互宝箱：首次开启播放开盖动画并生成掉落物；开启状态写入
## GameSession.world_data.chests_opened（存档持久化），不可重复领取；稀有宝箱带光效。
## 视觉：优先加载 Blender glb（子节点名为 Lid 的部件做开盖动画），缺失时用程序化占位。

@export var chest_id := "chest"
@export var loot_table := "chest_normal"
@export var rare := false
@export var model_path := "res://art/models/prop/chest.glb"

var _opened := false
var _lid: Node3D
var _light: OmniLight3D


func _ready() -> void:
	add_to_group("chest")
	collision_layer = 1
	collision_mask = 0
	_build_visual()
	_build_collision()
	_build_interactable()
	apply_saved_state()


func is_chest_opened() -> bool:
	return _opened


func get_chest_id() -> String:
	return chest_id


## 从会话恢复开启状态（分块加载/读档时调用）。
func apply_saved_state() -> void:
	var session := _session()
	if session == null:
		return
	var opened: Array = session.world_data.get("chests_opened", [])
	if opened.has(chest_id):
		_opened = true
		_set_opened_visual()


func _build_visual() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var fallback := Node3D.new()
	fallback.name = "Fallback"
	fallback.add_child(PropFactory.box(Vector3(0.95, 0.45, 0.6), Color(0.44, 0.31, 0.19), Vector3(0, 0.225, 0)))
	var lid_pivot := Node3D.new()
	lid_pivot.name = "Lid"
	lid_pivot.position = Vector3(0, 0.45, -0.3)
	lid_pivot.add_child(PropFactory.box(Vector3(0.99, 0.2, 0.64), Color(0.50, 0.36, 0.22), Vector3(0, 0.1, 0.3)))
	fallback.add_child(lid_pivot)
	var trim_color := Color(0.62, 0.52, 0.22)
	var trim_emission := Color.BLACK
	if rare:
		trim_color = Color(0.55, 0.75, 0.95)
		trim_emission = Color(0.35, 0.65, 1.0)
	var trim := PropFactory.box(Vector3(1.0, 0.08, 0.64), trim_color, Vector3(0, 0.44, 0))
	var trim_mat := trim.material_override as StandardMaterial3D
	if trim_emission != Color.BLACK:
		trim_mat.emission_enabled = true
		trim_mat.emission = trim_emission
		trim_mat.emission_energy_multiplier = 1.6
	fallback.add_child(trim)
	fallback.add_child(PropFactory.box(Vector3(0.1, 0.42, 0.62), trim_color, Vector3(0, 0.22, 0)))
	visual.add_child(PropFactory.model_node(model_path, fallback))
	_lid = visual.find_child("Lid", true, false) as Node3D
	if rare:
		_light = OmniLight3D.new()
		_light.name = "RareGlow"
		_light.light_color = Color(0.5, 0.8, 1.0)
		_light.light_energy = 1.6
		_light.omni_range = 6.0
		_light.position = Vector3(0, 0.8, 0)
		add_child(_light)


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.05, 0.75, 0.7)
	shape.shape = box
	shape.position = Vector3(0, 0.36, 0)
	add_child(shape)


func _build_interactable() -> void:
	var interactable := PropFactory.interactable("打开宝箱", Vector3(2.0, 1.8, 1.8), Vector3(0, 0.7, 0))
	interactable.interacted.connect(_on_interacted)
	add_child(interactable)


func _on_interacted(player: Node) -> void:
	var player_controller := player as PlayerController
	if player_controller == null:
		return
	if _opened:
		player_controller.show_combat_feedback("宝箱已经打开了", Color(0.7, 0.7, 0.7))
		return
	_opened = true
	_record_opened()
	_play_open_animation()
	player_controller.survivor.add_experience(80 if rare else 40)
	player_controller.show_combat_feedback("打开了宝箱", Color(1.0, 0.9, 0.5))


func _record_opened() -> void:
	var session := _session()
	if session == null:
		return
	var opened: Array = session.world_data.get("chests_opened", [])
	if not opened.has(chest_id):
		opened.append(chest_id)
	session.world_data["chests_opened"] = opened


func _play_open_animation() -> void:
	if _lid == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_lid, "rotation:x", deg_to_rad(-105.0), 0.5)


func _set_opened_visual() -> void:
	if _lid != null:
		_lid.rotation.x = deg_to_rad(-105.0)
	if _light != null:
		_light.light_energy = 0.5


func _session() -> GameSession:
	return get_tree().get_first_node_in_group("game_session") as GameSession
