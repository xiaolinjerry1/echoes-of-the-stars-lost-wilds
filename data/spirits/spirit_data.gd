class_name SpiritData
extends StaticData
## SpiritData（精灵静态数据）
## 职责：定义精灵同伴的定位、模型、被动/自动效果与成长系数。

## 精灵说明（玩家可见文本）
@export_multiline var description := ""
## 定位: heal / damage / defense
@export var role := "damage"
## 模型资源路径（Blender 导出的 glb）
@export var model_path := ""
## 悬浮动画名
@export var float_animation := ""
## 特效预制路径
@export var effect_prefab := ""

## ---- 治疗型 ----
## 被动治疗间隔（秒，0 则无）
@export var passive_heal_interval := 0.0
## 每次恢复生命
@export var passive_heal_amount := 0.0

## ---- 护盾/救命型 ----
## 触发紧急护盾的血量比例（0 则无）
@export var emergency_shield_threshold := 0.0
## 护盾值
@export var emergency_shield_amount := 0.0
## 紧急护盾冷却（秒）
@export var emergency_shield_cooldown := 0.0

## ---- 攻击型 ----
## 自动攻击间隔（秒，0 则无）
@export var auto_attack_interval := 0.0
## 自动攻击伤害
@export var auto_attack_damage := 0.0
## 自动攻击距离
@export var auto_attack_range := 0.0

## ---- 增益/减伤/嘲讽 ----
## 给玩家的火焰伤害加成比例
@export var flame_damage_bonus := 0.0
## 给玩家的减伤比例
@export var damage_reduction := 0.0
## 嘲讽范围（0 则无）
@export var taunt_range := 0.0
## 嘲讽冷却（秒）
@export var taunt_cooldown := 0.0
## 每级效果提升比例
@export var growth_coefficient := 0.0
## HUD 图标路径
@export var hud_icon := ""
