extends StaticBody3D
## EchoStone（回响碑）
## 职责：可交互的世界回响获取点。首次交互播放英灵记忆幻象并收藏回响，
## 之后石碑亮起星光纹路、提示已共鸣，不可重复获取。

## 该石碑代表的回响 id
@export var echo_id := "frost_lamp_scholar"
## 记忆幻象时长（秒）
@export var memory_duration := 5.0
## 石碑模型（Blender glb；缺失时用场景内程序化占位）
@export var model_path := "res://art/models/scenery/echo_stone.glb"

@onready var interactable: Interactable = $Interactable
@onready var rune_ring: MeshInstance3D = $RuneRing
@onready var stone_light: OmniLight3D = $StoneLight
@onready var stone_body: MeshInstance3D = $StoneBody

var _collected := false
var _vision_playing := false
var _glow_materials: Array[StandardMaterial3D] = []
var _sync_elapsed := 0.0


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	stone_light.visible = false
	_load_model()
	_apply_glow(false)
	call_deferred("_sync_collected_state")


## 场景先于玩家加载、读档和返回森林时，同步已收藏状态。
func _process(delta: float) -> void:
	_sync_elapsed += delta
	if _sync_elapsed >= 0.5:
		_sync_elapsed = 0.0
		_sync_collected_state()


func _sync_collected_state() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player != null and player.echo_system != null:
		_set_collected(player.echo_system.has_collected(echo_id))


func _set_collected(value: bool) -> void:
	if _collected == value:
		return
	_collected = value
	interactable.interact_text = "已共鸣" if value else "触碰回响碑"
	stone_light.visible = value
	_apply_glow(value)


## 加载 glb 模型并隐藏程序化占位。
func _load_model() -> void:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return
	var packed := load(model_path) as PackedScene
	if packed == null:
		return
	var visual := packed.instantiate()
	visual.name = "EchoVisual"
	add_child(visual)
	# 每个碑实例持有独立材质，避免点亮一座时污染其他碑或缓存资源。
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for i in instance.mesh.get_surface_count():
			var source := instance.mesh.surface_get_material(i) as StandardMaterial3D
			if source != null and source.emission_enabled:
				var material := source.duplicate() as StandardMaterial3D
				instance.set_surface_override_material(i, material)
				_glow_materials.append(material)
	stone_body.visible = false
	rune_ring.visible = false


func _on_interacted(player: Node) -> void:
	if _vision_playing:
		return
	var player_controller := player as PlayerController
	if player_controller == null:
		return
	var echo_system := player_controller.echo_system
	if echo_system == null:
		return
	if echo_system.has_collected(echo_id):
		_set_collected(true)
		player_controller.show_combat_feedback("这段记忆已经与你共鸣", Color(0.6, 0.8, 1.0))
		return
	var echo_data := DataRegistry.get_echo(echo_id)
	if echo_data == null:
		push_error("EchoStone: 找不到回响数据 %s" % echo_id)
		return
	# 英灵记忆幻象 → 收藏 → 亮起纹路
	_vision_playing = true
	await player_controller.play_memory_vision(echo_data, memory_duration)
	_vision_playing = false
	if not is_instance_valid(player_controller) or not is_instance_valid(echo_system):
		return
	echo_system.collect_echo(echo_id)
	player_controller.show_combat_feedback("获得回响：%s" % echo_data.display_name, echo_data.visual_theme_color)
	_set_collected(true)


## 亮起 / 熄灭星光纹路（优先调节 glb 上的发光材质，退回占位圆环）。
func _apply_glow(lit: bool) -> void:
	if not _glow_materials.is_empty():
		for material in _glow_materials:
			material.emission_energy_multiplier = 4.0 if lit else 0.6
		return
	var mesh := rune_ring.mesh.duplicate() as TorusMesh
	if mesh == null:
		return
	rune_ring.mesh = mesh
	var material := mesh.material as StandardMaterial3D
	if material == null:
		return
	material = material.duplicate() as StandardMaterial3D
	mesh.material = material
	material.emission_energy_multiplier = 4.0 if lit else 0.6


## 查找模型上带自发光的材质（回响碑纹路）。
func _find_glow_material() -> StandardMaterial3D:
	return _glow_materials[0] if not _glow_materials.is_empty() else null
