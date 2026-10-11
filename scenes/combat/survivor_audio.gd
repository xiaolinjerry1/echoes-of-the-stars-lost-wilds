class_name SurvivorAudio
extends RefCounted
## 飞刃、命中、结印与升级的短音效，密集战斗按类别限制重复播放。
static var last_times: Dictionary = {}
static func play(parent: Node, sound: String, point: Vector3, volume := -13.0) -> void:
	var now := Time.get_ticks_msec()*0.001
	if now-float(last_times.get(sound,-100.0))<0.08:return
	last_times[sound]=now
	var audio := AudioStreamPlayer3D.new()
	audio.process_mode=Node.PROCESS_MODE_ALWAYS
	audio.stream=load("res://audio/sfx/"+sound+".wav")
	audio.bus="SFX";audio.volume_db=volume;audio.max_distance=35.0
	audio.pitch_scale=randf_range(0.97,1.03)
	parent.add_child(audio);audio.global_position=point
	audio.finished.connect(audio.queue_free);audio.play()
