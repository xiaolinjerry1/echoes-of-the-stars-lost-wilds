class_name EchoData
extends StaticData
## EchoData（回响静态数据）
## 职责：定义一份英灵回响的称号、记忆、主题色与两个临时技能。

## 英灵称号
@export var title := ""
## 一段简短英灵记忆
@export_multiline var memory_text := ""
## 来源地点
@export var source_location := ""
## 视觉主题色
@export var visual_theme_color := Color.WHITE
## 回响技能（两个临时技能）
@export var echo_skills: Array[SkillData] = []
## 与基础职业互动的战斗标签
@export var combat_tag := ""
## 升级等级数
@export var upgrade_levels := 5
## 图标资源路径
@export var icon_path := ""
