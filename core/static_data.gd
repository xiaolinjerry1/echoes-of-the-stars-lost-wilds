class_name StaticData
extends Resource
## StaticData（静态数据基类）
## 职责：所有静态定义资源（职业/精灵/技能/回响/物品等）的公共基类。
## 只描述「是什么」（id、显示名等），不保存运行时状态
## （生命值、冷却、装备状态等属于具体运行时实例）。

## 内部唯一标识（英文小写 + 下划线，例如 warrior）。
@export var id: String = ""

## 玩家可见名称（中文，与内部 id 分离）。
@export var display_name: String = ""
