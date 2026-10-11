class_name FPArms
extends Node3D
## 第一人称手臂：播放 Blender 骨骼动作，将武器挂在右手插槽；维护换装和回响接口。
## 伤害/前摇由 CombatManager 决定；动画不调用伤害，也不移动玩家或摄像机。

@onready var weapon_mount: Node3D = $WeaponMount
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _clips: Dictionary = {}
var _blocking := false
var _current_clip := ""
var _arm_materials: Array[StandardMaterial3D] = []
var _weapon_model_path := ""
var _weapon_glowing := false
var _glove_tint := Color(0.55, 0.55, 0.58)
var _weapon_glow_material: StandardMaterial3D

func _ready() -> void:
	var model := $WarriorArms
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if skeletons.is_empty() or players.is_empty():
		push_error("FPArms: 手臂资产缺少骨架或动画")
		return
	_skeleton = skeletons[0] as Skeleton3D
	_animation_player = players[0] as AnimationPlayer
	_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	for full_name in _animation_player.get_animation_list():
		var short_name := String(full_name).get_file().trim_prefix("FP_")
		_clips[short_name] = full_name
	# Duplicate animation libraries before changing loop flags shared by imported instances.
	for library_name in _animation_player.get_animation_library_list():
		var local := _animation_player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		_animation_player.remove_animation_library(library_name)
		_animation_player.add_animation_library(library_name, local)
	for clip in ["idle", "block"]:
		if _clips.has(clip):
			_animation_player.get_animation(_clips[clip]).loop_mode = Animation.LOOP_LINEAR
	_attach_weapon()
	_collect_arm_materials()
	_animation_player.animation_finished.connect(_on_animation_finished)
	_play("idle")

func _attach_weapon() -> void:
	var bone := _skeleton.find_bone("Weapon.R")
	if bone < 0:
		push_error("FPArms: 缺少右手武器插槽")
		return
	var rest := global_transform.affine_inverse() * _skeleton.global_transform * _skeleton.get_bone_global_rest(bone)
	var desired := Transform3D(Basis(Vector3.RIGHT, -atan(0.1)), rest.origin)
	var socket := BoneAttachment3D.new()
	socket.name = "RightHandSocket"
	_skeleton.add_child(socket)
	socket.bone_name = "Weapon.R"
	weapon_mount.reparent(socket, false)
	weapon_mount.transform = rest.affine_inverse() * desired

func _collect_arm_materials() -> void:
	for node in $WarriorArms.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.skin == null:
			continue # The sword is now under the skeleton too; do not tint its materials as gloves.
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if source != null:
				var material := source.duplicate() as StandardMaterial3D
				mesh_instance.set_surface_override_material(surface, material)
				_arm_materials.append(material)

func set_echo_rune(color: Color, enabled: bool) -> void:
	for material in _arm_materials:
		material.emission_enabled = enabled
		material.emission = color
		material.emission_energy_multiplier = 0.35

func set_glove_tint(color: Color) -> void:
	_glove_tint = color
	for material in _arm_materials:
		# Preserve the baked palette at the historical default tint; equipment applies a relative tint.
		material.albedo_color = Color(color.r / 0.55, color.g / 0.55, color.b / 0.58, 1.0)

func get_glove_tint() -> Color:
	return _glove_tint

func set_weapon_model(model_path: String, glow := false) -> void:
	if model_path == _weapon_model_path and glow == _weapon_glowing and weapon_mount != null and weapon_mount.get_child_count() > 0:
		return
	_weapon_model_path = model_path
	_weapon_glowing = glow
	if weapon_mount == null:
		return
	for child in weapon_mount.get_children():
		weapon_mount.remove_child(child)
		child.queue_free()
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return
	var packed := load(model_path) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate()
	weapon_mount.add_child(model)
	if glow:
		_apply_weapon_glow(model)

func get_weapon_model_path() -> String:
	return _weapon_model_path

func is_weapon_glowing() -> bool:
	return _weapon_glowing

func _apply_weapon_glow(model: Node) -> void:
	if _weapon_glow_material == null:
		_weapon_glow_material = StandardMaterial3D.new()
		_weapon_glow_material.albedo_color = Color(0.5, 0.75, 1.0, 0.22)
		_weapon_glow_material.emission_enabled = true
		_weapon_glow_material.emission = Color(0.45, 0.75, 1.0)
		_weapon_glow_material.emission_energy_multiplier = 1.6
		_weapon_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_weapon_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_apply_overlay_recursive(model, _weapon_glow_material)

func _apply_overlay_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = material
	for child in node.get_children():
		_apply_overlay_recursive(child, material)

func _play(clip: String, restart := false) -> void:
	if _animation_player == null or not _clips.has(clip):
		return
	if _current_clip == clip and not restart:
		return
	if restart and _current_clip == clip:
		_animation_player.stop(true)
	_current_clip = clip
	# Short attacks have .1s contact: use the authored anticipation with no delaying crossfade.
	_animation_player.play(_clips[clip], 0.08 if clip in ["idle", "block", "hit"] else 0.0)
	_animation_player.advance(0.0)

func _on_animation_finished(_name: StringName) -> void:
	_play("block" if _blocking else "idle")

func play_attack_animation(combo_index: int = 1) -> void:
	_play("attack_%d" % clampi(combo_index, 1, 3), true)

func play_skill_animation(skill_id: String) -> void:
	_play(skill_id.trim_prefix("warrior_"), true)

func play_block_animation() -> void:
	_blocking = true
	_play("block")

func play_idle_animation() -> void:
	_blocking = false
	# Releasing block must not cancel an ongoing attack/skill.
	if _current_clip in ["block", "idle", "hit"]:
		_play("idle")

func play_hit_reaction() -> void:
	if _current_clip in ["idle", "block", "hit"]:
		_play("hit", true)
