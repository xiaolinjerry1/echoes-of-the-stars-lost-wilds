class_name InventoryPanel
extends Control
## InventoryPanel（背包/装备面板）
## 职责：五装备槽 + 30 格背包 + 物品详情与装备对比（属性升降着色）+
## 右键菜单（装备/卸下/锁定/出售/分解）+ 一键整理 + 批量分解 + 金币/材料显示。
## 由玩家按 Tab 开关。

const GRID_COLUMNS := 6
const SLOT_BUTTON_NAMES := {
	"helmet": "SlotHelmet",
	"chest": "SlotChest",
	"gloves": "SlotGloves",
	"weapon": "SlotWeapon",
	"accessory": "SlotAccessory",
}

var _player: PlayerController = null
var _inventory: Inventory = null
var _equipment: EquipmentSystem = null
var _selected_index := -1
var _menu_index := -1
var _menu_slot := ""
var _slot_buttons: Dictionary = {}
var _grid_buttons: Array = []
var _menu: PopupMenu = null

@onready var grid: GridContainer = $Frame/Grid
@onready var detail_title: Label = $Frame/DetailTitle
@onready var detail_text: RichTextLabel = $Frame/DetailText
@onready var gold_label: Label = $Frame/GoldLabel
@onready var material_label: Label = $Frame/MaterialLabel


## 由 PlayerController 在 _ready 时调用。
func setup(player: PlayerController) -> void:
	_player = player
	_inventory = player.inventory
	_equipment = player.equipment
	_build_equipment_slots()
	_build_grid()
	_build_context_menu()
	$Frame/SortButton.pressed.connect(_on_sort_pressed)
	$Frame/BatchButton.pressed.connect(_on_batch_pressed)
	_inventory.inventory_changed.connect(refresh)
	_equipment.equipment_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _inventory == null or _equipment == null:
		return
	# 装备槽（品质颜色 + 边框形状）
	for slot in EquipmentSystem.SLOTS:
		var button: Button = _slot_buttons.get(slot)
		if button == null:
			continue
		var item := _equipment.get_equipped(slot)
		var enhance := _equipment.get_equipped_enhance(slot)
		if item == null:
			button.text = "%s：空" % EquipmentSystem.SLOT_NAMES[slot]
			button.add_theme_stylebox_override("normal", ItemQuality.make_style(ItemQuality.COMMON, Color(0.07, 0.08, 0.11, 0.9)))
			button.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		else:
			var suffix := " +%d" % enhance if enhance > 0 else ""
			button.text = "%s：%s%s" % [EquipmentSystem.SLOT_NAMES[slot], item.display_name, suffix]
			button.add_theme_stylebox_override("normal", ItemQuality.make_style(item.quality))
			button.add_theme_color_override("font_color", ItemQuality.color_for(item.quality).lerp(Color.WHITE, 0.3))
	# 背包格
	for i in _grid_buttons.size():
		var button: Button = _grid_buttons[i]
		var entry := _inventory.get_entry(i)
		if entry.is_empty():
			button.text = ""
			button.add_theme_stylebox_override("normal", ItemQuality.make_style(ItemQuality.COMMON, Color(0.07, 0.08, 0.11, 0.75)))
			button.add_theme_color_override("font_color", Color.WHITE)
			continue
		var item: ItemData = entry["item_data"]
		var lock_mark := "[锁]" if bool(entry["locked"]) else ""
		var enh_mark := "+%d " % int(entry["enhance_level"]) if int(entry["enhance_level"]) > 0 else ""
		button.text = "%s%s%s" % [enh_mark, item.display_name, lock_mark]
		button.add_theme_stylebox_override("normal", ItemQuality.make_style(item.quality))
		button.add_theme_color_override("font_color", ItemQuality.color_for(item.quality).lerp(Color.WHITE, 0.3))
	gold_label.text = "金币：%d" % _inventory.gold
	material_label.text = _build_material_text()
	_refresh_detail()


## 详情 + 装备对比文本（属性上升绿色 / 下降红色，BBCode）。
func get_comparison_text(item: ItemData, enhance_level := 0) -> String:
	var lines: Array[String] = []
	if not item.description.is_empty():
		lines.append("[color=#bbbbbb]%s[/color]" % item.description)
	if not item.echo_effect.is_empty():
		lines.append("[color=#8fb7ff]%s[/color]" % item.echo_effect)
	lines.append("")
	lines.append("[b]属性对比[/b]（槽位：%s）" % EquipmentSystem.SLOT_NAMES.get(item.item_type, "无"))
	var equipped: ItemData = null
	var equipped_enh := 0
	if EquipmentSystem.SLOTS.has(item.item_type):
		equipped = _equipment.get_equipped(item.item_type)
		equipped_enh = _equipment.get_equipped_enhance(item.item_type)
	var mult_new := 1.0 + 0.1 * float(enhance_level)
	var mult_old := 1.0 + 0.1 * float(equipped_enh)
	lines.append(_compare_line("攻击强度", item.attack_power * mult_new, _stat_of(equipped, "attack_power") * mult_old))
	lines.append(_compare_line("护甲", item.armor * mult_new, _stat_of(equipped, "armor") * mult_old))
	lines.append(_compare_line("生命上限", item.max_health_bonus * mult_new, _stat_of(equipped, "max_health_bonus") * mult_old))
	lines.append(_compare_line("暴击率%", item.crit_chance * 100.0 * mult_new, _stat_of(equipped, "crit_chance") * 100.0 * mult_old))
	lines.append(_compare_line("技能急速%", item.skill_haste * 100.0 * mult_new, _stat_of(equipped, "skill_haste") * 100.0 * mult_old))
	lines.append(_compare_line("专注恢复", item.focus_regen_bonus * mult_new, _stat_of(equipped, "focus_regen_bonus") * mult_old))
	if not EquipmentSystem.SLOTS.has(item.item_type):
		lines.append("[color=#888888]（该物品不可装备）[/color]")
	return "\n".join(lines)


## ---- 内部：构建 ----

func _build_equipment_slots() -> void:
	for slot in EquipmentSystem.SLOTS:
		var button := $Frame.get_node(SLOT_BUTTON_NAMES[slot]) as Button
		if button == null:
			continue
		_slot_buttons[slot] = button
		button.pressed.connect(_on_equipment_slot_clicked.bind(slot))
		button.gui_input.connect(_on_equipment_slot_input.bind(slot))


func _build_grid() -> void:
	grid.columns = GRID_COLUMNS
	for i in _inventory.slot_count:
		var button := Button.new()
		button.custom_minimum_size = Vector2(84, 84)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_grid_clicked.bind(i))
		button.gui_input.connect(_on_grid_input.bind(i))
		grid.add_child(button)
		_grid_buttons.append(button)


func _build_context_menu() -> void:
	_menu = PopupMenu.new()
	_menu.add_item("装备", 0)
	_menu.add_item("卸下", 1)
	_menu.add_item("锁定/解锁", 2)
	_menu.add_item("出售", 3)
	_menu.add_item("分解", 4)
	_menu.id_pressed.connect(_on_menu_id_pressed)
	add_child(_menu)


## ---- 内部：交互 ----

func _on_grid_clicked(index: int) -> void:
	_selected_index = index
	_refresh_detail()


func _on_equipment_slot_clicked(slot: String) -> void:
	var item := _equipment.get_equipped(slot)
	if item == null:
		return
	detail_title.text = "%s（%s · 已装备）" % [item.display_name, ItemQuality.label_for(item.quality)]
	detail_title.add_theme_color_override("font_color", ItemQuality.color_for(item.quality))
	detail_text.text = get_comparison_text(item, _equipment.get_equipped_enhance(slot))


func _on_grid_input(event: InputEvent, index: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
		if _inventory.get_entry(index).is_empty():
			return
		_menu_index = index
		_menu_slot = ""
		_menu.position = DisplayServer.mouse_get_position()
		_menu.popup()


func _on_equipment_slot_input(event: InputEvent, slot: String) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
		if _equipment.get_equipped(slot) == null:
			return
		_menu_index = -1
		_menu_slot = slot
		_menu.position = DisplayServer.mouse_get_position()
		_menu.popup()


func _on_menu_id_pressed(id: int) -> void:
	if _menu_slot != "":
		if id == 1:
			_unequip_slot(_menu_slot)
		_menu_slot = ""
		refresh()
		return
	if _menu_index < 0:
		return
	var entry := _inventory.get_entry(_menu_index)
	if entry.is_empty():
		return
	match id:
		0:
			if _equipment.equip_from_inventory(_inventory, _menu_index):
				_selected_index = -1
			elif _player != null:
				_player.show_combat_feedback("该物品无法装备", Color(1.0, 0.8, 0.5))
		2:
			_inventory.lock_item(_menu_index, not bool(entry["locked"]))
		3:
			var price := _inventory.sell(_menu_index)
			if price > 0 and _player != null:
				_player.show_combat_feedback("出售获得 %d 金币" % price, Color(1.0, 0.85, 0.4))
			_selected_index = -1
		4:
			var result := _inventory.dismantle(_menu_index)
			if not result.is_empty() and _player != null:
				_player.show_combat_feedback("分解获得回响尘 ×%d" % int(result.get("echo_dust", 0)), ItemQuality.color_for(ItemQuality.RARE))
			_selected_index = -1
	refresh()


func _unequip_slot(slot: String) -> void:
	var item := _equipment.get_equipped(slot)
	if item == null:
		return
	var enhance := _equipment.get_equipped_enhance(slot)
	if _inventory.add_item(item, 1, enhance):
		_equipment.unequip_item(slot)
	elif _player != null:
		_player.show_combat_feedback("背包已满，无法卸下", Color(1.0, 0.6, 0.5))


func _on_sort_pressed() -> void:
	_inventory.sort_items()
	_selected_index = -1
	refresh()


func _on_batch_pressed() -> void:
	var count := _inventory.batch_dismantle_low_quality(ItemQuality.RANK_UNCOMMON)
	if _player != null:
		_player.show_combat_feedback("批量分解 %d 件（未锁定的低品质）" % count, ItemQuality.color_for(ItemQuality.RARE))
	refresh()


## ---- 内部：展示 ----

func _refresh_detail() -> void:
	if _selected_index < 0:
		detail_title.text = "未选择物品"
		detail_title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		detail_text.text = "点击背包物品查看详情与装备对比\n右键物品：装备 / 锁定 / 出售 / 分解"
		return
	var entry := _inventory.get_entry(_selected_index)
	if entry.is_empty():
		_selected_index = -1
		_refresh_detail()
		return
	var item: ItemData = entry["item_data"]
	detail_title.text = "%s（%s）" % [item.display_name, ItemQuality.label_for(item.quality)]
	detail_title.add_theme_color_override("font_color", ItemQuality.color_for(item.quality))
	detail_text.text = get_comparison_text(item, int(entry.get("enhance_level", 0)))


func _build_material_text() -> String:
	var parts: Array[String] = ["材料："]
	if _inventory.materials.is_empty():
		parts.append("无")
	else:
		for material_id in _inventory.materials:
			var data := DataRegistry.get_item(str(material_id))
			var material_name := data.display_name if data != null else str(material_id)
			parts.append("%s ×%d" % [material_name, int(_inventory.materials[material_id])])
	return "   ".join(parts)


func _stat_of(item: ItemData, stat_name: String) -> float:
	if item == null:
		return 0.0
	return float(item.get(stat_name))


func _compare_line(label: String, new_value: float, old_value: float) -> String:
	var diff := new_value - old_value
	if absf(diff) < 0.001:
		return "%s：%.1f（不变）" % [label, new_value]
	var color := "#4cd137" if diff > 0.0 else "#ff6b5b"
	var diff_text := "+%.1f" % diff if diff > 0.0 else "%.1f" % diff
	return "%s：%.1f  [color=%s]%s[/color]" % [label, new_value, color, diff_text]
