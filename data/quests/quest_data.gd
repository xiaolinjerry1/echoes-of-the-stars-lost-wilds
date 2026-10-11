class_name QuestData
extends StaticData
## QuestData（任务静态数据）
## 职责：定义任务的目标、前置、给予/交付 NPC、奖励与剧本行。

@export_multiline var description := ""
## 任务类型: kill / collect / explore / escort / echo / elite
@export var quest_type := "kill"
## 是否主线（追踪 UI 单独显示）
@export var is_main := false
## 前置任务 id（全部完成后才可接取）
@export var prerequisites: Array[String] = []
## 接取 NPC id
@export var giver_npc := ""
## 交付 NPC id
@export var turn_in_npc := ""
## 目标列表：每个 { "type", "target_id", "count", "description" }
@export var objectives: Array = []
## 奖励：{ "gold": int, "exp": int, "items": [{ "item_id", "count" }], "echo_id": String }
@export var rewards: Dictionary = {}
## 完成后改变的世界状态 id
@export var world_state_changes: Array[String] = []
## 接取时的对话（2-4 句）
@export var offer_lines: Array[String] = []
## 交付时的对话（2-4 句）
@export var complete_lines: Array[String] = []
