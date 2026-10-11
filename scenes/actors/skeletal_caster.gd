class_name SkeletalCaster
extends BaseEnemy
## 施法怪共用骨骼播放：AI时钟对齐施法，冻结停姿势，控制中断，骨骼倒地。
var cast_windup_time := 0.8
var _cast_fired := false
var _animation_player: AnimationPlayer
var _clips: Dictionary = {}
var _visual_clip: StringName = &""
var _flinch_time := 0.0
var _movement_speed := 0.0

func _ready() -> void:
	super._ready()
	visual.rotation.y = PI
	for node in visual.find_children("*", "AnimationPlayer", true, false):
		_animation_player = node
		break
	if _animation_player == null:
		return
	_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name in _animation_player.get_animation_list():
		var short_name := String(name).get_slice("/",String(name).get_slice_count("/")-1).trim_prefix(model_path.get_file().get_basename()+"_")
		_clips[StringName(short_name)] = name
	_play_visual(&"idle")

func _play_visual(clip: StringName, restart := false) -> void:
	if _animation_player == null or not _clips.has(clip):return
	if _visual_clip == clip and not restart:return
	_visual_clip = clip
	if restart:_animation_player.stop(true)
	_animation_player.play(_clips[clip],0.0 if clip in [&"cast",&"summon",&"death"] else 0.1)
	_animation_player.advance(0)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_skeletal_animation(delta)

func _update_skeletal_animation(delta: float) -> void:
	if _animation_player == null:return
	if state == State.DEAD:
		_play_visual(&"death")
		_animation_player.advance(delta)
		return
	if status.has_effect(StatusEffects.FROZEN):return
	_flinch_time = maxf(0,_flinch_time-delta)
	if state == State.ATTACK:
		_play_visual(_attack_visual_clip())
		var time := _state_time * 0.8 / cast_windup_time if _state_time <= cast_windup_time else 0.8 + _state_time - cast_windup_time
		_animation_player.seek(minf(time,1.4),true)
		return
	elif state == State.STAGGERED:
		_play_visual(&"stagger")
	elif _flinch_time > 0:
		_play_visual(&"hit")
	else:
		_movement_speed = lerpf(_movement_speed,Vector2(velocity.x,velocity.z).length(),1-exp(-delta*12))
		var moving := _movement_speed > (0.10 if _visual_clip in [&"walk",&"backstep"] else 0.25)
		var backwards := velocity.dot(global_transform.basis.z) > 0.15
		_play_visual((&"backstep" if backwards else &"walk") if moving else &"idle")
	var speed := clampf(_movement_speed/1.4,0.5,2.0) if _visual_clip in [&"walk",&"backstep"] else 1.0
	_animation_player.advance(delta*speed)
	if _visual_clip in [&"idle",&"walk",&"backstep",&"stagger"] and not _animation_player.is_playing():
		_play_visual(_visual_clip,true)

func _attack_visual_clip() -> StringName:
	return &"cast"

func _on_attack_aborted() -> void:
	_cast_fired = false

func take_damage(amount: float, attacker: Node = null) -> void:
	super.take_damage(amount,attacker)
	if state != State.DEAD and state != State.ATTACK and not status.has_effect(StatusEffects.FROZEN):
		_flinch_time = 0.45
		_play_visual(&"hit",true)

func _play_death_visual() -> float:
	if _animation_player == null:return super._play_death_visual()
	_play_visual(&"death",true)
	return 2.0
