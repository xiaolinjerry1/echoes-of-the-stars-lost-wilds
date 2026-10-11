class_name ClassData
extends StaticData
## ClassData（职业静态数据）
## 职责：定义职业的基础属性、武器类型、基础攻击与三个主职业技能。

## 职业说明（玩家可见文本）
@export_multiline var description := ""
## 基础最大生命
@export var max_health := 100.0
## 基础最大专注
@export var max_focus := 100.0
## 专注每秒恢复
@export var focus_regen := 5.0
## 基础攻击强度
@export var base_attack_power := 10.0
## 基础护甲
@export var armor := 0.0
## 武器类型: sword_shield / staff / bow / mace
@export var weapon_type := "sword_shield"
## 新角色实际装备的初始武器。
@export var starting_weapon_id := ""
## 基础攻击（内嵌技能数据）
@export var basic_attack: SkillData = null
## 三个主职业技能
@export var class_skills: Array[SkillData] = []
## 被动节点（MVP 先留空数组）
@export var passive_nodes: Array = []
## HUD 主题色
@export var hud_color := Color.WHITE
## 图标资源路径
@export var icon_path := ""
