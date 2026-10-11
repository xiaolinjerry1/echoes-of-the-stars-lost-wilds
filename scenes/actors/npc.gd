class_name Npc
extends StaticBody3D
## Npc（NPC 通用脚本）
## 职责：可交互 NPC；按优先级推进对话——可交付任务 > 可接任务 > 服务 >
## 日常闲聊；头顶显示「！/？」任务标记；单次对话控制在 3-6 句内。

@export var npc_id := "npc"
@export var display_name := "村民"
@export var npc_color := Color(0.5, 0.6, 0.8)
@export_file("*.glb") var model_path := ""
## 服务列表: "quest_giver" / "shop" / "forge" / "inn"
@export var services: Array[String] = []
## 商店物品 id 列表（商店功能后续轮次接入）
@export var shop_items: Array[String] = []
## 日常闲聊池（每次随机取 2-3 句）
@export var idle_lines: Array[String] = []

@onready var interactable: Interactable = $Interactable
@onready var marker_label: Label3D = $MarkerLabel
@onready var visual: Node3D = $Visual
@onready var name_label: Label3D = $NameLabel

var _marker_timer := 0.0
var _current_marker := ""
var _animation_player: AnimationPlayer
var _clips: Dictionary = {}
var _visual_clip := ""
var _conversation_player: PlayerController


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	name_label.text = display_name
	_load_character()


func _process(delta: float) -> void:
	_update_character(delta)
	# 0.5 秒节流刷新头顶标记
	_marker_timer -= delta
	if _marker_timer > 0.0:
		return
	_marker_timer = 0.5
	_update_marker()


## 五名已命名NPC使用独立Blender角色，未知ID继续使用原占位。
func _load_character() -> void:
	var asset := "npc_" + npc_id
	var path := model_path if not model_path.is_empty() else "res://art/models/player/" + asset + ".glb"
	if not ResourceLoader.exists(path):
		_tint_visual()
		return
	for child in visual.get_children():
		if child is Node3D:child.hide()
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.name = "CharacterModel"
	model.rotation.y = PI
	visual.add_child(model)
	for node in model.find_children("*","AnimationPlayer",true,false):
		_animation_player = node
		break
	if _animation_player != null:
		_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for full_name in _animation_player.get_animation_list():
			var short_name := String(full_name).get_slice("/",String(full_name).get_slice_count("/")-1).trim_prefix(asset+"_")
			_clips[short_name]=full_name
		_play_character("wounded" if npc_id=="wounded_ranger" else "idle")


func _play_character(clip: String, restart := false) -> void:
	if _animation_player==null or not _clips.has(clip):return
	if _visual_clip==clip and not restart:return
	_visual_clip=clip
	_animation_player.play(_clips[clip],.12)
	_animation_player.advance(0)


func _update_character(delta: float) -> void:
	if _animation_player==null:return
	var talking := is_instance_valid(_conversation_player) and _conversation_player.is_dialogue_active()
	var clip := "talk" if talking else ("wounded" if npc_id=="wounded_ranger" else "idle")
	_play_character(clip)
	_animation_player.advance(delta)
	if not _animation_player.is_playing():_play_character(clip,true)


func _tint_visual() -> void:
	var body := visual.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var mesh := body.mesh as CapsuleMesh
	if mesh == null:
		return
	var material := mesh.material as StandardMaterial3D
	if material == null:
		return
	material = material.duplicate() as StandardMaterial3D
	mesh.material = material
	material.albedo_color = npc_color


func _update_marker() -> void:
	var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	var marker := ""
	if quest_manager != null:
		marker = quest_manager.get_npc_marker(npc_id)
	if marker == _current_marker:
		return
	_current_marker = marker
	marker_label.text = marker
	marker_label.visible = not marker.is_empty()
	if marker == "！":
		marker_label.modulate = Color(1.0, 0.9, 0.3)
	elif marker == "？":
		marker_label.modulate = Color(1.0, 0.6, 0.2)


func _on_interacted(player: Node) -> void:
	var player_controller := player as PlayerController
	if player_controller == null or player_controller.is_dialogue_active():
		return
	_conversation_player = player_controller
	var quest_manager := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	if quest_manager == null:
		_idle_talk(player_controller)
		return
	# 任何交互都计入 talk 类目标（如「与受伤的巡林者对话」）
	quest_manager.notify_event("talk", npc_id, 1)
	# 1/2. 可交付任务（主线优先）
	var turn_ins := quest_manager.get_turn_in_quests_for_npc(npc_id)
	if not turn_ins.is_empty():
		_start_turn_in(player_controller, quest_manager, turn_ins[0])
		return
	# 3. 可接取任务
	var offers := quest_manager.get_available_quests_for_npc(npc_id)
	if not offers.is_empty():
		_start_offer(player_controller, quest_manager, offers[0])
		return
	# 4. 服务（商店/锻造/旅店占位）
	if not services.is_empty():
		player_controller.start_dialogue(display_name, _service_lines())
		return
	# 5. 日常闲聊
	_idle_talk(player_controller)


func _start_offer(player: PlayerController, quest_manager: QuestManager, quest: QuestData) -> void:
	var lines: Array = quest.offer_lines.duplicate()
	lines.append("（接受任务：%s）" % quest.display_name)
	var quest_id := quest.id
	var quest_name := quest.display_name
	player.start_dialogue(display_name, lines, func() -> void:
		if quest_manager.accept_quest(quest_id):
			player.show_combat_feedback("接受任务：%s" % quest_name, Color(1.0, 0.9, 0.5)))


func _start_turn_in(player: PlayerController, quest_manager: QuestManager, quest: QuestData) -> void:
	var lines: Array = quest.complete_lines.duplicate()
	lines.append("（任务完成：%s）" % quest.display_name)
	var quest_id := quest.id
	var quest_name := quest.display_name
	player.start_dialogue(display_name, lines, func() -> void:
		if quest_manager.turn_in_quest(quest_id):
			player.show_combat_feedback("任务完成：%s" % quest_name, Color(1.0, 0.85, 0.4))
		else:
			player.show_combat_feedback("这个任务已经完成过了", Color(0.8, 0.8, 0.8)))


func _service_lines() -> Array:
	var lines: Array = []
	if services.has("shop"):
		lines.append("想买点什么？我的货都是从林子里淘来的。")
	if services.has("forge"):
		lines.append("强化装备？炉子还没生起来，回头再来。")
	if services.has("inn"):
		lines.append("住店吗？床铺还空着。")
	if lines.is_empty():
		lines.append("需要帮忙吗？")
	return lines


func _idle_talk(player: PlayerController) -> void:
	var pool: Array = idle_lines
	if pool.is_empty():
		pool = ["今天天气不错。"]
	var count := mini(randi_range(2, 3), pool.size())
	var start := randi() % pool.size()
	var lines: Array = []
	for i in count:
		lines.append(pool[(start + i) % pool.size()])
	player.start_dialogue(display_name, lines)
