extends Node
## AudioService（音频服务单例，Autoload）
## 职责：全局音乐切换、音量总线管理、公共提示音（UI 音效等）。
## 场景内 / 3D 音效由本地节点自行播放，本服务只做全局层。

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const SFX_POOL_SIZE := 8

var _music_player: AudioStreamPlayer = null
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
## 音效库：sfx_id → AudioStream（后续随资源接入填充）
var _sfx_library: Dictionary = {}


func _ready() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)

	for index in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.bus = BUS_SFX
		add_child(player)
		_sfx_pool.append(player)


## 播放/切换背景音乐（music_id 支持 res:// 资源路径，后续可扩展为音乐库 id）。
func play_music(music_id: String) -> void:
	var stream := _load_stream(music_id)
	if stream == null:
		push_warning("AudioService: 找不到音乐 %s" % music_id)
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()


## 停止背景音乐。
func stop_music() -> void:
	_music_player.stop()


## 播放公共音效（sfx_id 支持资源路径或已注册的音效库 id）。
func play_sfx(sfx_id: String) -> void:
	var stream := _load_stream(sfx_id)
	if stream == null:
		push_warning("AudioService: 找不到音效 %s" % sfx_id)
		return
	var player := _next_sfx_player()
	player.stream = stream
	player.play()


## 设置总线音量（value 为 0.0-1.0 的线性值）。
func set_volume(bus: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("AudioService: 音频总线不存在 %s" % bus)
		return
	var linear := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(index, linear <= 0.0001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


## ---- 内部实现 ----

## 保证音频总线存在（工程资源已带 Music/SFX，这里做兜底）。
func _ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
	return index


## 从音效库或 res:// 路径加载音频流。
func _load_stream(id: String) -> AudioStream:
	if _sfx_library.has(id):
		return _sfx_library[id] as AudioStream
	if ResourceLoader.exists(id):
		var resource := load(id)
		if resource is AudioStream:
			return resource as AudioStream
	return null


## 取下一个可用播放器（优先空闲，避免互相打断）。
func _next_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	var fallback := _sfx_pool[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_pool.size()
	return fallback
