extends Node3D
## 秘境入口（石门/洞穴）
## 职责：检查进入条件（required_quest），满足时按 E 进入秘境（委托 DungeonManager），
## 否则提示所需任务；独立运行时发出 enter_requested 信号。

signal enter_requested(dungeon_scene_path: String, required_quest: String, entrance_position: Vector3)

@export var dungeon_scene_path := "res://scenes/dungeons/forest_grove_dungeon.tscn"
@export var required_quest := "q_frost_trial"
@export var gate_model_path := "res://art/models/scenery/dungeon_gate.glb"

var _interactable: Interactable


func _ready() -> void:
	add_to_group("dungeon_entrance")
	_build_gate()
	_interactable = PropFactory.interactable("进入秘境", Vector3(4.0, 3.4, 4.0), Vector3(0, 1.4, 1.4))
	_interactable.interacted.connect(_on_interacted)
	add_child(_interactable)


func _build_gate() -> void:
	var fallback := Node3D.new()
	for side in [-1.0, 1.0]:
		fallback.add_child(PropFactory.box(Vector3(1.1, 4.0, 1.1), Color(0.44, 0.44, 0.46), Vector3(side * 2.0, 2.0, 0)))
	fallback.add_child(PropFactory.box(Vector3(5.4, 0.9, 1.2), Color(0.40, 0.40, 0.42), Vector3(0, 4.2, 0)))
	var dark := PropFactory.box(Vector3(3.2, 3.6, 0.4), Color(0.04, 0.05, 0.06), Vector3(0, 1.8, 0.2))
	var dark_mat := dark.material_override as StandardMaterial3D
	dark_mat.emission_enabled = true
	dark_mat.emission = Color(0.05, 0.12, 0.09)
	fallback.add_child(dark)
	for side in [-1.0, 1.0]:
		var glow := PropFactory.sphere(0.14, Color(0.5, 0.9, 0.6), Vector3(side * 1.3, 3.1, -0.4))
		var glow_mat := glow.material_override as StandardMaterial3D
		glow_mat.emission_enabled = true
		glow_mat.emission = Color(0.4, 0.9, 0.55)
		glow_mat.emission_energy_multiplier = 2.0
		fallback.add_child(glow)
	var model := PropFactory.model_node(gate_model_path, fallback)
	# 洞顶净高3.65m；保持门洞宽度，把拱顶装配到岩壁下方。
	model.scale.y = 0.6
	add_child(model)
	var body := PropFactory.static_body(Vector3(0.8, 2.4, 1.2), Vector3(-1.8, 1.2, 0))
	var body2 := PropFactory.static_body(Vector3(0.8, 2.4, 1.2), Vector3(1.8, 1.2, 0))
	body.add_to_group("nav_source")
	body2.add_to_group("nav_source")
	add_child(body)
	add_child(body2)


func can_enter() -> bool:
	if required_quest.is_empty():
		return true
	var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	if quest_manager == null:
		return false
	return quest_manager.is_quest_completed(required_quest)


func _process(_delta: float) -> void:
	if _interactable == null:
		return
	_interactable.interact_text = "进入秘境" if can_enter() else "查看石门"


func _on_interacted(player: Node) -> void:
	var player_controller := player as PlayerController
	if player_controller == null:
		return
	if not can_enter():
		var quest := DataRegistry.get_quest(required_quest)
		var quest_name := quest.display_name if quest != null else required_quest
		player_controller.show_combat_feedback("石门纹丝不动——需要先完成「%s」" % quest_name, Color(0.85, 0.78, 0.6))
		return
	player_controller.show_combat_feedback("推开石门……", Color(0.6, 0.85, 0.7))
	var manager := get_tree().get_first_node_in_group("dungeon_manager")
	if manager != null:
		manager.call("enter_dungeon", dungeon_scene_path, required_quest, global_position)
	else:
		enter_requested.emit(dungeon_scene_path, required_quest, global_position)
