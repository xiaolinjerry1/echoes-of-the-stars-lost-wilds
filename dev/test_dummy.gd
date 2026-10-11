extends StaticBody3D
## 开发用战斗假人（仅用于 dev/test_combat.tscn）
## 职责：承受伤害、挂状态效果（冻结/眩晕/寒意/灼烧等）、可被嘲讽与失衡；
## elite = true 时控制只减速；boss_mode = true 时改用 BossComponent 抗控
## （控制转为失衡积累，破绽期间承受伤害 +30%）。

@export var max_health := 300.0
## 假人攻击伤害（原始伤害，玩家侧还有护甲/格挡/精灵减伤）
@export var attack_damage := 10.0
## 攻击间隔（秒）
@export var attack_interval := 2.5
## 攻击距离（米）
@export var attack_range := 2.2
## 脱战多久后回满血（测试便利）
@export var regen_delay := 3.0
## 是否为精英（只吃减速，不吃冻结）
@export var elite := false
## 是否为 BOSS 假人（使用 BossComponent 抗控）
@export var boss_mode := false

var health := 0.0
var is_taunted := false

@onready var status: StatusEffectComponent = $StatusEffectComponent
@onready var boss: BossComponent = $BossComponent if boss_mode else null

var _attack_cd := 0.0
var _regen_cd := 0.0
var _stagger_time := 0.0


func _ready() -> void:
	health = max_health
	_attack_cd = attack_interval
	add_to_group("test_dummy")


func _process(delta: float) -> void:
	if _stagger_time > 0.0:
		_stagger_time -= delta
	_attack_cd -= delta
	if _can_attack():
		var player := get_tree().get_first_node_in_group("player")
		if player != null and global_position.distance_to(player.global_position) <= attack_range:
			_attack_cd = attack_interval
			player.call("take_damage", attack_damage, self)
	# 测试便利：脱战一段时间后回满血
	if health < max_health:
		_regen_cd += delta
		if _regen_cd >= regen_delay:
			health = max_health
			_regen_cd = 0.0
	else:
		_regen_cd = 0.0


func _can_attack() -> bool:
	if _attack_cd > 0.0 or _stagger_time > 0.0:
		return false
	if boss != null and boss.is_staggered():
		return false
	return not (status.has_effect(StatusEffects.STUN) or status.has_effect(StatusEffects.FROZEN))


## ---- 战斗接口（攻击者统一约定） ----

func take_damage(amount: float) -> void:
	# BOSS 破绽期间承受伤害加成
	if boss != null:
		amount *= boss.get_incoming_damage_multiplier()
	health = maxf(health - amount, 0.0)
	_regen_cd = 0.0
	print("[TestDummy] %s 受到 %.1f 伤害（剩余 %.1f）" % [name, amount, health])
	if health <= 0.0:
		health = max_health
		print("[TestDummy] %s 被击倒，重置满血（测试用）" % name)


func apply_effect(effect_id: String, duration: float, power := 1.0, source: Node = null) -> void:
	# BOSS：控制效果转为失衡积累
	if boss != null and boss.intercept_control(effect_id, source):
		print("[TestDummy] %s 控制被拦截 → 失衡 %.0f" % [name, boss.stagger_value])
		return
	status.apply_effect(effect_id, duration, power, source)


func remove_effect(effect_id: String) -> void:
	status.remove_effect(effect_id)


func has_effect(effect_id: String) -> bool:
	return status.has_effect(effect_id)


func get_effect_power(effect_id: String) -> float:
	return status.get_effect_power(effect_id)


## 供 DamageCalculator 读取目标属性（假人无护甲）。
func get_stats() -> Variant:
	return null


## 是否为精英（冰环等控制效果判定用）。
func is_elite() -> bool:
	return elite or boss_mode


## 被嘲讽（战吼/磐石守灵）：记录状态供测试检查。
func on_taunted(_source: Node, duration: float) -> void:
	is_taunted = true
	print("[TestDummy] %s 被嘲讽 %.1fs" % [name, duration])


## 被完美格挡：失衡，短暂无法行动。
func on_parried(duration: float) -> void:
	_stagger_time = duration
	print("[TestDummy] %s 被完美格挡，失衡 %.1fs" % [name, duration])


## 是否处于失衡（格挡）状态。
func is_staggered() -> bool:
	return _stagger_time > 0.0
