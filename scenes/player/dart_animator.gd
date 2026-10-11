class_name DartAnimator
extends RefCounted
## 连续走跑混合与上半身攻击叠加；下肢不中断，按实际速度标定步频。
var player: AnimationPlayer
var tree: AnimationTree
var names: Dictionary = {}
var terminal := false
func setup(model: Node3D) -> void:
	player=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if player==null:return
	for key in player.get_animation_list():
		for clip in ["idle","walk","run","cast","ultimate","hit","death","jump"]:
			if key==clip or key.ends_with("_"+clip):names[clip]=key
	for clip in ["idle","walk","run"]:
		if names.has(clip):player.get_animation(names[clip]).loop_mode=Animation.LOOP_LINEAR
	var blend := AnimationNodeBlendTree.new()
	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space=0.0;locomotion.max_space=1.0
	for i in 3:
		var animation := AnimationNodeAnimation.new()
		animation.animation=names.get(["idle","walk","run"][i],"")
		locomotion.add_blend_point(animation,[0.0,0.32,1.0][i])
	blend.add_node("Locomotion",locomotion)
	var rate := AnimationNodeTimeScale.new()
	blend.add_node("MotionRate",rate);blend.connect_node("MotionRate",0,"Locomotion")
	var previous := "MotionRate"
	for clip in ["jump","cast","ultimate","hit"]:
		var anim := AnimationNodeAnimation.new();anim.animation=names.get(clip,"")
		blend.add_node(clip+"Clip",anim)
		var shot_input: String = clip+"Clip"
		if clip=="cast":
			var cast_rate := AnimationNodeTimeScale.new()
			blend.add_node("castRate",cast_rate);blend.connect_node("castRate",0,shot_input);shot_input="castRate"
		var shot := AnimationNodeOneShot.new()
		shot.fadein_time=0.075;shot.fadeout_time=0.16;shot.filter_enabled=true
		if names.has(clip):
			var source := player.get_animation(names[clip])
			for i in source.get_track_count():
				var path := source.track_get_path(i)
				var bone := str(path.get_subname(0)) if path.get_subname_count()>0 else ""
				var leg := bone.begins_with("Thigh") or bone.begins_with("Shin") or bone.begins_with("Foot") or bone=="Hips"
				if not bone.is_empty() and ((clip=="jump" and leg) or (clip!="jump" and not leg and bone!="Root")):
					shot.set_filter_path(path,true)
		blend.add_node(clip,shot);blend.connect_node(clip,0,previous);blend.connect_node(clip,1,shot_input);previous=clip
	blend.connect_node("output",0,previous)
	tree=AnimationTree.new();model.add_child(tree)
	tree.anim_player=tree.get_path_to(player)
	tree.tree_root=blend
	tree.active=true

func tick(speed: float, maximum: float, delta: float, attack_interval := 0.75) -> void:
	if tree==null or terminal:return
	var weight := clampf(speed/maximum,0.0,1.0)
	var current: float=tree.get("parameters/Locomotion/blend_position")
	var blended := move_toward(current,weight,delta*6.0)
	tree.set("parameters/Locomotion/blend_position",blended)
	# Running foot support travels 1m over 0.26s; calibrate playback to physical speed.
	var authored := lerpf(0.0,0.762,blended/0.32) if blended<=0.32 else lerpf(0.762,3.85,(blended-0.32)/0.68)
	var desired := clampf(speed/maxf(0.1,authored),0.5,3.5) if speed>0.05 else 1.0
	var rate: float=tree.get("parameters/MotionRate/scale")
	tree.set("parameters/MotionRate/scale",move_toward(rate,desired,delta*8.0))
	tree.set("parameters/castRate/scale",0.6/minf(0.6,attack_interval))

func play(clip: String) -> void:
	if player==null:return
	if clip=="death":
		terminal=true;tree.active=false
		if names.has(clip):player.play(names[clip],0.10)
	elif clip in ["jump","cast","ultimate","hit"]:
		tree.set("parameters/"+clip+"/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	elif terminal:
		terminal=false;tree.active=true

func land() -> void:
	if tree!=null:tree.set("parameters/jump/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
