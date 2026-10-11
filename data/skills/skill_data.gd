class_name SkillData
extends StaticData
## SkillData（技能静态数据）
## 职责：定义一个技能/攻击的全部静态数值与标签，供战斗系统读取。
## 只描述「技能是什么」，运行时的冷却/前摇进度属于具体实例。

## 技能说明（玩家可见文本）
@export_multiline var description := ""
## 技能类型: melee / ranged / aoe / buff / defend
@export var skill_type := "melee"
## 冷却时间（秒）
@export var cooldown := 0.0
## 专注消耗
@export var focus_cost := 0.0
## 基础伤害
@export var damage_base := 0.0
## 伤害系数（乘以攻击强度）
@export var damage_coefficient := 0.0
## 生效距离 / 半径（米）
@export var range := 0.0
## 前摇时间（秒，0 为瞬发）
@export var cast_time := 0.0
## 战斗标签: physical / heavy / frost / fire / lightning / wind / mark / precise 等
@export var combat_tags: Array[String] = []
## 命中后施加的状态效果 id（空则无）
@export var status_effect := ""
## 状态效果持续时间（秒）
@export var status_duration := 0.0
## 图标资源路径
@export var icon_path := ""
## 命中特效场景路径
@export var effect_scene := ""
