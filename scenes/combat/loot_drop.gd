class_name LootDrop
extends Area3D
## LootDrop（世界掉落物）
## 职责：发光物品模型 + 玩家靠近自动拾取；稀有以上光效与音效更明显。
## 支持类型：gold（金币）/ item（装备）/ material（材料）/ echo（回响）。

var entry: Dictionary = {}

var _picked := false
var _bob_time := 0.0

@onready var visual: Node3D = $Visual
@onready var light: OmniLight3D = $Light


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1  # 只感应玩家（player_body 第 2 层）
	body_entered.connect(_on_body_entered)


## 由 LootSystem 调用：设置掉落内容并生成视觉。
func setup(loot_entry: Dictionary) -> void:
	entry = loot_entry
	var color := _entry_color(loot_entry)
	_build_visual(color, _entry_rank(loot_entry))
	light.light_color = color
	light.light_energy = 0.6 if _entry_rank(loot_entry) < 2 else 1.4


func _process(delta: float) -> void:
	_bob_time += delta
	if visual != null:
		visual.position.y = 0.35 + sin(_bob_time * 2.5) * 0.08
		visual.rotate_y(delta * 1.2)


func _on_body_entered(body: Node3D) -> void:
	if _picked or body == null:
		return
	var player := body as PlayerController
	if player == null:
		return
	_picked = true
	var text := _pickup(player)
	var color := _entry_color(entry)
	ComboNotifier.show_text(get_parent(), global_position + Vector3.UP * 1.4, text, color, 40)
	ComboNotifier.play_beep(self, global_position, 900.0 if _entry_rank(entry) >= 2 else 600.0)
	queue_free()


## ---- 内部 ----

func _pickup(player: PlayerController) -> String:
	var kind := str(entry.get("type", ""))
	var item_id := str(entry.get("item_id", ""))
	match kind:
		"gold":
			var amount := int(entry.get("amount", 1))
			player.inventory.add_gold(amount)
			return "获得金币 ×%d" % amount
		"material":
			var quantity := int(entry.get("quantity", 1))
			player.inventory.add_material(item_id, quantity)
			return "获得材料：%s ×%d" % [_display_name(item_id), quantity]
		"echo":
			if player.echo_system != null:
				player.echo_system.collect_echo(item_id)
			return "获得回响：%s" % _display_name(item_id)
		_:
			var item := DataRegistry.get_item(item_id)
			if item != null:
				player.inventory.add_item(item)
			return "获得：%s" % _display_name(item_id)


func _display_name(item_id: String) -> String:
	var item := DataRegistry.get_item(item_id)
	if item != null:
		return item.display_name
	var echo := DataRegistry.get_echo(item_id)
	if echo != null:
		return echo.display_name
	return item_id


func _entry_color(loot_entry: Dictionary) -> Color:
	match str(loot_entry.get("type", "")):
		"gold":
			return Color(1.0, 0.85, 0.3)
		"echo":
			var echo := DataRegistry.get_echo(str(loot_entry.get("item_id", "")))
			if echo != null:
				return echo.visual_theme_color
			return Color(0.7, 0.85, 1.0)
		_:
			var item := DataRegistry.get_item(str(loot_entry.get("item_id", "")))
			if item != null:
				return ItemQuality.color_for(item.quality)
			return Color.WHITE


func _entry_rank(loot_entry: Dictionary) -> int:
	match str(loot_entry.get("type", "")):
		"echo":
			return 3
		"gold":
			return 0
		_:
			var item := DataRegistry.get_item(str(loot_entry.get("item_id", "")))
			if item != null:
				return ItemQuality.rank_for(item.quality)
			return 0


func _build_visual(color: Color, rank: int) -> void:
	if visual == null:
		return
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12 if rank < 2 else 0.16
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	mesh_instance.mesh = mesh
	visual.add_child(mesh_instance)
