class_name RuntimeComponent
extends Node
## RuntimeComponent（运行时组件基类）
## 职责：所有挂在实体（玩家 / 怪物 / NPC）上的运行时组件的公共基类，
## 通过 owner_entity 反向引用所属实体，组件自行管理自身的运行状态。

## 所属实体（组件加入场景树后由实体注入）。
@export var owner_entity: Node = null
