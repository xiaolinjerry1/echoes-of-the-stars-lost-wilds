class_name EchoPanel
extends Control
## EchoPanel（回响收藏面板）
## 职责：展示已收藏回响卡片与两个准备槽；点击准备槽选择位置、点击卡片装备；
## 显示能量与激活状态；未发现的回响显示为剪影。由玩家按 I 开关。

var _player: PlayerController = null
var _echo_system: EchoSystem = null
var _selected_slot := 0
var _card_buttons: Dictionary = {}

@onready var energy_label: Label = $Frame/EnergyLabel
@onready var slot_buttons: Array = [$Frame/Slot1Button, $Frame/Slot2Button]
@onready var card_list: HBoxContainer = $Frame/CardList


## 由 PlayerController 在 _ready 时调用。
func setup(player: PlayerController) -> void:
	_player = player
	_echo_system = player.echo_system
	for i in slot_buttons.size():
		(slot_buttons[i] as Button).pressed.connect(_on_slot_pressed.bind(i))
	refresh()


## 刷新能量、准备槽与回响卡片。
func refresh() -> void:
	if _echo_system == null:
		return
	var state_text := "未激活"
	if _echo_system.is_active():
		state_text = "激活中：%s（%.1fs）" % [_echo_system.get_active_echo_name(), _echo_system.active_timer]
	energy_label.text = "能量 %d / %d        %s" % [
		roundi(_echo_system.current_energy),
		roundi(_echo_system.max_energy),
		state_text,
	]
	for i in slot_buttons.size():
		var echo_id: String = _echo_system.prep_slots[i]
		var slot_name := "空"
		if not echo_id.is_empty():
			var data := DataRegistry.get_echo(echo_id)
			if data != null:
				slot_name = data.display_name
		var marker := "▶ " if i == _selected_slot else ""
		(slot_buttons[i] as Button).text = "%s准备槽 %d：%s" % [marker, i + 1, slot_name]
	_rebuild_cards()


func _rebuild_cards() -> void:
	for child in card_list.get_children():
		child.queue_free()
	_card_buttons.clear()
	for data in DataRegistry.get_all_echoes():
		var echo_data := data as EchoData
		if echo_data == null:
			continue
		if _echo_system.has_collected(echo_data.id):
			var button := Button.new()
			button.custom_minimum_size = Vector2(250, 340)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var skill_lines := ""
			for skill in echo_data.echo_skills:
				skill_lines += "\n\n· %s（CD %.1fs）\n%s" % [skill.display_name, skill.cooldown, skill.description]
			button.text = "%s\n「%s」\n\n记忆：%s%s" % [
				echo_data.display_name,
				echo_data.title,
				echo_data.memory_text,
				skill_lines,
			]
			button.tooltip_text = "点击装备到准备槽 %d" % (_selected_slot + 1)
			button.add_theme_color_override("font_color", echo_data.visual_theme_color.lerp(Color.WHITE, 0.35))
			button.pressed.connect(_on_card_pressed.bind(echo_data.id))
			card_list.add_child(button)
			_card_buttons[echo_data.id] = button
		else:
			var silhouette := Button.new()
			silhouette.custom_minimum_size = Vector2(250, 340)
			silhouette.disabled = true
			silhouette.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			silhouette.text = "？？？\n\n未发现的世界回响"
			card_list.add_child(silhouette)


func _on_slot_pressed(index: int) -> void:
	_selected_slot = index
	refresh()


func _on_card_pressed(echo_id: String) -> void:
	if _echo_system == null:
		return
	if _echo_system.equip_to_slot(_selected_slot, echo_id):
		refresh()
	elif _player != null:
		_player.show_combat_feedback("无法装备（激活中或战斗中）", Color(1.0, 0.7, 0.5))
