class_name ItemData
extends StaticData
## ItemData（物品静态数据）
## 职责：定义装备/材料/消耗品的品级与属性加成。

## 物品类型: weapon / helmet / chest / gloves / accessory / material / consumable
@export var item_type := "material"
## 品质: common / uncommon / rare / epic
@export var quality := "common"
## 攻击强度加成
@export var attack_power := 0.0
## 护甲加成
@export var armor := 0.0
## 最大生命加成
@export var max_health_bonus := 0.0
## 暴击率加成
@export var crit_chance := 0.0
## 技能急速
@export var skill_haste := 0.0
## 专注恢复加成
@export var focus_regen_bonus := 0.0
## 回响相关效果描述
@export var echo_effect := ""
## 物品说明（玩家可见文本）
@export_multiline var description := ""
## 图标资源路径
@export var icon_path := ""
## 模型资源路径（Blender 导出的 glb）
@export var model_path := ""
