extends Node
## SettingsService（设置服务单例，Autoload）
## 职责：管理画面/音量/输入/辅助选项等偏好设置，与角色存档分离，
## 持久化到 user://settings.cfg；并提供游戏操作说明文本 game_help_text。

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "settings"

## 游戏说明文本（主菜单 / 设置面板展示用；替代强制新手教程）
const game_help_text := """【第三人称飞镖师】
WASD 移动 · 鼠标转动视角 · 滚轮调整镜头距离 · 空格跳跃
左键：环绕飞镖逐枚投出，命中/达到射程后飞回归位，无限循环。
右键：回响充满100时，结印发动「奥义·影分身之术」。
命中敌人提高回响；3个AI分身拥有相同形态、体型与攻击成长。
分身优先攻击对你有敌意、或你刚攻击过的敌人；基础持续10秒。
技能期间回响随时间耗尽，结束后重新通过命中积蓄。

【经验与成长】
击杀敌人掉落经验结晶，靠近自动收集；宝箱提供经验。
经验条满后升级，基础攻击自动增加，并从五种能力随机抽三种供选择：
飞镖数量（同时扩大环绕半径）/ 攻速 / 攻击力 / 移动速度 / 分身持续时间。
按1、2、3或点击卡片选择；连续升级会逐级选择。

【世界与交互】
E 交互 · M 地图 · Esc 暂停/存档/设置
营火回满生命；草药直接恢复60点生命。
营地是安全区域，离开后怪物会持续出现，密度逐渐上升。
巨兽在营地北方遗迹；巨大飞龙在东北方，地图标记「兽」「龙」。
死亡后返回营地，保留等级和已选强化，回响清空。
旧装备、精灵、回响收藏及回响碑已从当前玩法移除。

【开发快捷键】
F1 状态 · F2 回满生命 · F3 获得一级经验 · F4 充满回响
F5 回营地 · F6 昼夜 · F7 天气
"""

## 音频设置 key → 音频总线名 的映射
const AUDIO_BUS_BY_KEY := {
	"audio/master_volume": "Master",
	"audio/music_volume": "Music",
	"audio/sfx_volume": "SFX",
}

## 默认设置
const DEFAULTS := {
	"display/resolution": "1280x720",
	"display/window_mode": "windowed",
	"display/vsync_enabled": true,
	"display/enable_camera_effects": true,
	"display/fov": 90.0,
	"display/quality": "high",
	"display/motion_blur": true,
	"audio/master_volume": 1.0,
	"audio/music_volume": 0.8,
	"audio/sfx_volume": 0.9,
	"input/mouse_sensitivity": 0.002,
	"input/invert_y_axis": false,
	"accessibility/subtitles": true,
	"accessibility/subtitle_size": "中",
	"accessibility/colorblind_mode": "关闭",
	"accessibility/assist_mode": false,
	"accessibility/screen_shake_scale": 1.0,
}

var _settings: Dictionary = {}


func _ready() -> void:
	_load_from_disk()
	# AudioService 在本服务之后初始化，推迟到帧末同步已保存的音量
	call_deferred("_apply_audio_settings")


## 读取设置项：已保存值 > 内置默认值 > 调用方传入的 default_value。
func get_setting(key: String, default_value: Variant = null) -> Variant:
	if _settings.has(key):
		return _settings[key]
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	return default_value


## 写入设置项并立即持久化；音频类设置同步到 AudioService。
func set_setting(key: String, value: Variant) -> void:
	_settings[key] = value
	_apply_setting(key, value)
	_save_to_disk()


## 恢复全部默认设置并持久化。
func reset_to_default() -> void:
	_settings = DEFAULTS.duplicate(true)
	_apply_audio_settings()
	_save_to_disk()


## ---- 内部实现 ----

## 将音频设置同步到 AudioService（对方未就绪时跳过）。
func _apply_audio_settings() -> void:
	if AudioService == null:
		return
	for key: String in AUDIO_BUS_BY_KEY:
		AudioService.set_volume(AUDIO_BUS_BY_KEY[key], float(get_setting(key, 1.0)))


## 应用单项设置。
func _apply_setting(key: String, value: Variant) -> void:
	if AUDIO_BUS_BY_KEY.has(key) and AudioService != null:
		AudioService.set_volume(AUDIO_BUS_BY_KEY[key], float(value))


## 从磁盘加载设置（不存在或损坏时退回默认值）。
func _load_from_disk() -> void:
	_settings = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	if not cfg.has_section(SECTION):
		return
	for key in cfg.get_section_keys(SECTION):
		_settings[key] = cfg.get_value(SECTION, key)


## 将当前设置写入磁盘。
func _save_to_disk() -> void:
	var cfg := ConfigFile.new()
	for key: String in _settings:
		cfg.set_value(SECTION, key, _settings[key])
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_error("SettingsService: 无法保存设置（错误码 %d）" % err)
