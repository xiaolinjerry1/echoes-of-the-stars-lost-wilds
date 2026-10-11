class_name ComboNotifier
extends RefCounted
## ComboNotifier（组合技反馈工具，纯静态）
## 职责：组合触发与 BOSS 失衡等关键战斗事件的世界飘字与辨识提示音；
## 声音为代码生成（无外部音频资产），供 ComboSystem / BossComponent 调用。

const LIFETIME := 1.1
const RISE := 1.0


## 组合触发反馈：世界飘字 + 音效。
static func trigger_combo(combo_name: String, world_position: Vector3, parent: Node) -> void:
	var display := str(ComboSystem.DISPLAY_NAMES.get(combo_name, combo_name))
	var color: Color = ComboSystem.COLORS.get(combo_name, Color.WHITE)
	show_text(parent, world_position + Vector3.UP * 0.8, "%s！" % display, color, 72)
	play_beep(parent, world_position, _combo_frequency(combo_name))


## 世界飘字（大号、描边、上飘淡出后自释放）。
static func show_text(parent: Node, world_position: Vector3, text: String, color: Color, font_size := 64) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = font_size
	label.pixel_size = 0.004
	label.outline_size = 20
	label.outline_modulate = Color(0, 0, 0, 0.8)
	parent.add_child(label)
	label.global_position = world_position
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", world_position + Vector3.UP * RISE, LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, LIFETIME).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


## 播放提示音（代码生成的短促正弦音）。
static func play_beep(parent: Node, world_position: Vector3, freq: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = make_beep(freq, 0.18)
	player.bus = "SFX"
	parent.add_child(player)
	player.global_position = world_position
	player.play()
	parent.get_tree().create_timer(0.8).timeout.connect(player.queue_free)


## 代码生成提示音（占位，无外部音频资产）。
static func make_beep(freq: float, duration: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / mix_rate
		var attack := minf(float(i) / (mix_rate * 0.02), 1.0)
		var release := 1.0 - float(i) / sample_count
		var sample := sin(TAU * freq * t) * attack * release * 0.35
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


static func _combo_frequency(combo_name: String) -> float:
	match combo_name:
		ComboSystem.COMBO_SHATTER:
			return 1245.0
		ComboSystem.COMBO_ARC_SPREAD:
			return 880.0
		ComboSystem.COMBO_FIRE_SPREAD:
			return 620.0
		ComboSystem.COMBO_WEAKPOINT:
			return 1480.0
	return 990.0
