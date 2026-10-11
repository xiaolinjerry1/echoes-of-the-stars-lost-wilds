extends StaticBody3D
## GatherNode（采集点）
## 职责：可交互的采集植物；采集后进入材料背包并隐藏，一段时间后刷新。
## 视觉优先加载Blender草药模型，采集状态同步隐藏与交互，防止刷新前重复领取。

## 产出的材料 id
@export var material_id := "forest_herb"
## 每次采集数量
@export var amount := 1
## 刷新时间（秒）
@export var respawn_time := 20.0
## 显示名（采集提示用）
@export var display_name := "森林草药"
## 采集植物模型（Blender glb；缺失时用场景内程序化占位）
@export var model_path := "res://art/models/prop/herb.glb"

var _depleted := false

@onready var interactable: Interactable = $Interactable
@onready var visual: Node3D = $Visual
@onready var shape_node: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("gather_node")
	interactable.interacted.connect(_on_interacted)
	_load_model()


func _load_model() -> void:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return
	var packed := load(model_path) as PackedScene
	if packed == null:
		return
	for placeholder_name in ["Stem", "Leaves"]:
		var placeholder := visual.get_node_or_null(placeholder_name)
		if placeholder != null:
			placeholder.visible = false
	visual.add_child(packed.instantiate())


func _on_interacted(player: Node) -> void:
	if _depleted:
		return
	var player_controller := player as PlayerController
	if player_controller == null:
		return
	_depleted = true
	player_controller.stats.heal(60.0)
	player_controller.show_combat_feedback("草药恢复 60 点生命", Color(0.6, 1.0, 0.6))
	visual.visible = false
	shape_node.set_deferred("disabled", true)
	interactable.collision_layer = 0
	await get_tree().create_timer(respawn_time).timeout
	_depleted = false
	visual.visible = true
	shape_node.set_deferred("disabled", false)
	interactable.collision_layer = 1 << 4
