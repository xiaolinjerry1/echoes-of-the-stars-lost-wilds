extends RefCounted
## Blender 动作播放适配：手动时钟、短名称映射及循环，不修改共享动画资源。
var player: AnimationPlayer
var clips: Dictionary = {}
var current := ""
var elapsed := 0.0

func bind(root: Node, prefix: String) -> void:
	for node in root.find_children("*", "AnimationPlayer", true, false):
		player = node
		break
	if player == null: return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key in player.get_animation_list():
		var short := String(key).get_slice("/", String(key).get_slice_count("/") - 1)
		short = short.trim_prefix(prefix + "_").trim_prefix("MossCrown_")
		clips[short] = key
	play("idle")

func play(clip: String, restart := false) -> void:
	if player == null or not clips.has(clip): return
	if current == clip and not restart: return
	current = clip
	elapsed = 0.0
	player.play(clips[clip], 0.0 if restart else 0.10)
	player.advance(0.0)

func advance(delta: float, loop := false) -> void:
	if player == null or not clips.has(current): return
	elapsed += delta
	var duration := player.get_animation(clips[current]).length
	if duration <= 0: return
	if loop and elapsed >= duration:
		elapsed = fmod(elapsed, duration)
		player.play(clips[current], 0.0)
		player.seek(elapsed, true)
	else:
		player.advance(delta)

func finished() -> bool:
	return player == null or not clips.has(current) or elapsed >= player.get_animation(clips[current]).length
