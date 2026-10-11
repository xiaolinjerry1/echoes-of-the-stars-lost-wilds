extends Node3D
## EnemySpawn（敌人刷新点）
## 职责：按 enemy_type 生成怪物（子类脚本在 _ready 配置数值）；精英附加 BossComponent。
## 供分块加载/卸载控制怪物存续；MVP 常驻。

@export var enemy_type := "wolf"
@export var patrol_radius := 8.0
@export var spawn_count := 1
@export var spawn_scatter := 3.0

const SCRIPT_PATHS := {
	"wolf": "res://scenes/actors/melee_chaser.gd",
	"mage": "res://scenes/actors/ranged_caster.gd",
	"boar": "res://scenes/actors/charger.gd",
	"elite_boar": "res://scenes/actors/charger.gd",
	"shaman": "res://scenes/actors/support.gd",
}


func _ready() -> void:
	var packed := load("res://scenes/actors/base_enemy.tscn") as PackedScene
	var script_path := str(SCRIPT_PATHS.get(enemy_type, SCRIPT_PATHS["wolf"]))
	var enemy_script := load(script_path) as Script
	if packed == null or enemy_script == null:
		push_error("EnemySpawn: 无法加载怪物资源 %s" % enemy_type)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for i in spawn_count:
		var enemy := packed.instantiate() as Node3D
		enemy.name = "%s_%s%d" % [name, enemy_type, i + 1]
		enemy.set_script(enemy_script)
		if enemy_type == "elite_boar":
			enemy.set("elite", true)
			enemy.set("loot_table", "elite_enemy")
			var boss_script := load("res://scenes/actors/boss_component.gd") as Script
			if boss_script != null:
				var boss := Node.new()
				boss.set_script(boss_script)
				enemy.add_child(boss)
		var offset := Vector3(rng.randf_range(-spawn_scatter, spawn_scatter), 0, rng.randf_range(-spawn_scatter, spawn_scatter))
		var global_pos := global_position + offset
		global_pos.y = TerrainBuilder.height_at(global_pos.x, global_pos.z) + 0.1
		enemy.set("spawn_position", global_pos)
		enemy.set("patrol_radius", patrol_radius)
		enemy.position = to_local(global_pos)
		add_child.call_deferred(enemy)
