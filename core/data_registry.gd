extends Node
## DataRegistry（静态数据注册表单例，Autoload）
## 职责：启动时递归扫描 res://data/ 下所有静态定义资源（.tres/.res），
## 按类型分表存储并提供查询。只保存静态定义，不保存任何实例状态
## （生命值、冷却、装备状态等属于具体运行时实例）。

const DATA_ROOT := "res://data/"
const RESOURCE_EXTENSIONS := [".tres", ".res"]

const TABLE_CLASSES := "classes"
const TABLE_SPIRITS := "spirits"
const TABLE_SKILLS := "skills"
const TABLE_ECHOES := "echoes"
const TABLE_ITEMS := "items"
const TABLE_QUESTS := "quests"

## 分类表：表名 → { id → StaticData }
var _tables: Dictionary = {}


func _ready() -> void:
	load_all()


## 重新加载 res://data/ 下全部静态数据（热重载 / 工具脚本可用）。
func load_all() -> void:
	_tables.clear()
	for table_name in [TABLE_CLASSES, TABLE_SPIRITS, TABLE_SKILLS, TABLE_ECHOES, TABLE_ITEMS, TABLE_QUESTS]:
		_tables[table_name] = {}
	_register_file("res://data/classes/dart_master.tres")
	print("DataRegistry: 已加载 职业=%d 精灵=%d 技能=%d 回响=%d 物品=%d 任务=%d" % [
		get_all_classes().size(),
		get_all_spirits().size(),
		get_all_skills().size(),
		get_all_echoes().size(),
		get_all_items().size(),
		get_all_quests().size(),
	])


## ---- 查询接口（找不到时打印错误并返回 null） ----

## 查询职业定义。
## 注意：不能命名为 get_class —— 它与 Object.get_class() 冲突，
## 引擎禁止签名不匹配的重写，故使用 get_class_def。
func get_class_def(id: String) -> ClassData:
	return _get_entry(TABLE_CLASSES, id) as ClassData


func get_spirit(id: String) -> SpiritData:
	return _get_entry(TABLE_SPIRITS, id) as SpiritData


func get_skill(id: String) -> SkillData:
	return _get_entry(TABLE_SKILLS, id) as SkillData


func get_echo(id: String) -> EchoData:
	return _get_entry(TABLE_ECHOES, id) as EchoData


func get_item(id: String) -> ItemData:
	return _get_entry(TABLE_ITEMS, id) as ItemData


func get_quest(id: String) -> QuestData:
	return _get_entry(TABLE_QUESTS, id) as QuestData


## ---- 列表接口 ----

func get_all_classes() -> Array:
	return _get_all(TABLE_CLASSES)


func get_all_spirits() -> Array:
	return _get_all(TABLE_SPIRITS)


func get_all_skills() -> Array:
	return _get_all(TABLE_SKILLS)


func get_all_echoes() -> Array:
	return _get_all(TABLE_ECHOES)


func get_all_items() -> Array:
	return _get_all(TABLE_ITEMS)


func get_all_quests() -> Array:
	return _get_all(TABLE_QUESTS)


## ---- 内部实现 ----

func _get_entry(table_name: String, id: String) -> StaticData:
	var table: Dictionary = _tables.get(table_name, {})
	if not table.has(id):
		push_error("DataRegistry: 找不到 %s 表中的 id「%s」" % [table_name, id])
		return null
	return table[id] as StaticData


func _get_all(table_name: String) -> Array:
	var table: Dictionary = _tables.get(table_name, {})
	return table.values()


## 递归扫描目录，收集 .tres/.res
func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("DataRegistry: 无法打开数据目录 %s" % dir_path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(path)
		elif _is_resource_file(entry):
			_register_file(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _is_resource_file(file_name: String) -> bool:
	for extension in RESOURCE_EXTENSIONS:
		if file_name.ends_with(extension):
			return true
	return false


func _register_file(path: String) -> void:
	var resource := load(path)
	if resource == null or not (resource is StaticData):
		push_warning("DataRegistry: %s 不是有效的静态数据资源" % path)
		return
	var data := resource as StaticData
	if data.id.is_empty():
		push_warning("DataRegistry: %s 缺少 id，已跳过" % path)
		return
	_put_entry(_resolve_table(data), data)
	# 职业与回响内嵌的技能一并索引，保证 get_skill(id) 可查到
	if data is ClassData:
		var class_data := data as ClassData
		_index_embedded_skill(class_data.basic_attack)
		for skill in class_data.class_skills:
			_index_embedded_skill(skill)
	elif data is EchoData:
		for skill in (data as EchoData).echo_skills:
			_index_embedded_skill(skill)


## 按资源类型决定所属表；未知类型按所在目录名兜底。
func _resolve_table(data: StaticData) -> String:
	if data is ClassData:
		return TABLE_CLASSES
	if data is SpiritData:
		return TABLE_SPIRITS
	if data is SkillData:
		return TABLE_SKILLS
	if data is EchoData:
		return TABLE_ECHOES
	if data is ItemData:
		return TABLE_ITEMS
	if data is QuestData:
		return TABLE_QUESTS
	var relative := data.resource_path.trim_prefix(DATA_ROOT)
	var category := relative.get_slice("/", 0)
	return category if not category.is_empty() else "misc"


func _index_embedded_skill(skill: SkillData) -> void:
	if skill == null:
		return
	if skill.id.is_empty():
		push_warning("DataRegistry: 内嵌技能缺少 id，已跳过")
		return
	_put_entry(TABLE_SKILLS, skill)


func _put_entry(table_name: String, data: StaticData) -> void:
	if not _tables.has(table_name):
		_tables[table_name] = {}
	var table: Dictionary = _tables[table_name]
	if table.has(data.id):
		push_warning("DataRegistry: %s 表中 id 重复：%s" % [table_name, data.id])
	table[data.id] = data
