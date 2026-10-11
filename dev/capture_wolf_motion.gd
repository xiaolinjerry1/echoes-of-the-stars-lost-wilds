extends Node3D
## 野狼运动验收：固定侧视相机 + 棋盘地面 + 真实位移，输出步态条带图与触地滑移指标。
## 只读取 Blender 资产与 MeleeChaser，不改动任何游戏数据。

const OUT_DIR := "res://dev/art_work/wolf_motion"
const COLUMNS := 4
const ROWS := 3
const FRAME_W := 480
const FRAME_H := 270
const SIM_DT := 1.0 / 60.0
const START_Z := 0.7

var _actor: MeleeChaser
var _skeleton: Skeleton3D
var _feet: Array[int] = []
var _foot_names: Array[String] = []
var _errors: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(FRAME_W, FRAME_H))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_world()
	_setup_wolf()
	await get_tree().process_frame
	await get_tree().process_frame
	for scenario in [
		{"name": "idle", "speed": 0.0, "stride": 6},
		{"name": "walk", "speed": 1.6, "stride": 3},
		{"name": "run", "speed": 3.5, "stride": 2},
	]:
		await _capture(String(scenario["name"]), float(scenario["speed"]), int(scenario["stride"]))
	print("WOLF_MOTION_CAPTURE ", JSON.stringify({"errors": _errors}))
	get_tree().quit(0 if _errors.is_empty() else 1)


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.45, 0.55, 0.65)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 26)
	ground.mesh = plane
	ground.material_override = _checker_material()
	ground.position = Vector3(0, 0, -4)
	add_child(ground)
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	camera.position = Vector3(7.5, 1.7, 0)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.current = true


func _checker_material() -> StandardMaterial3D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var dark := (int(x / 32) + int(y / 32)) % 2 == 0
			image.set_pixel(x, y, Color(0.3, 0.34, 0.32) if dark else Color(0.52, 0.56, 0.52))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.uv1_scale = Vector3(12, 26, 1)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.9
	return material


func _setup_wolf() -> void:
	var packed := load("res://scenes/actors/base_enemy.tscn") as PackedScene
	var wolf := packed.instantiate() as CharacterBody3D
	wolf.set_script(load("res://scenes/actors/melee_chaser.gd"))
	wolf.position = Vector3(0, 0, START_Z)
	add_child(wolf)
	wolf.set_physics_process(false)
	_actor = wolf as MeleeChaser
	await get_tree().process_frame
	_skeleton = _find_skeleton(_actor.visual)
	if _skeleton == null:
		_errors.append("未找到骨架")
		return
	for i in _skeleton.get_bone_count():
		var bone_name := _skeleton.get_bone_name(i)
		if bone_name.ends_with(".Foot"):
			_feet.append(i)
			_foot_names.append(bone_name)
	_debug_axes()


func _debug_axes() -> void:
	if _skeleton == null:
		return
	var head_index := _skeleton.find_bone("Head")
	var hips_index := _skeleton.find_bone("Hips")
	var head_dir := Vector3.ZERO
	if head_index >= 0 and hips_index >= 0:
		var head := _skeleton.get_bone_global_rest(head_index).origin
		var hips := _skeleton.get_bone_global_rest(hips_index).origin
		head_dir = (_skeleton.global_transform.basis * (head - hips)).normalized()
	var model_root := _actor.visual.get_child(0) as Node3D
	print("WOLF_AXES ", JSON.stringify({
		"actor_rotation_y": snappedf(_actor.rotation.y, 0.001),
		"visual_rotation_y": snappedf(_actor.visual.rotation.y, 0.001),
		"act_forward_-Z": _actor.global_transform.basis * Vector3(0, 0, -1),
		"head_to_hips_world": head_dir,
		"model_root_rotation_y": snappedf(model_root.rotation.y, 0.001) if model_root != null else null,
		"model_root_scale": model_root.scale if model_root != null else Vector3.ZERO,
	}))


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _capture(name: String, speed: float, capture_stride: int) -> void:
	_actor.global_position = Vector3(0, 0, START_Z)
	for i in 60:
		_step(speed)
	_actor.global_position = Vector3(0, 0, START_Z)
	var foot_positions: Array = []
	for i in _feet.size():
		foot_positions.append([])
	var montage := Image.create(FRAME_W * COLUMNS, FRAME_H * ROWS, false, Image.FORMAT_RGBA8)
	montage.fill(Color(0.1, 0.1, 0.12))
	var captured := 0
	for step in capture_stride * COLUMNS * ROWS:
		_step(speed)
		for f in _feet.size():
			foot_positions[f].append(_foot_world(f))
		if step % capture_stride == 0:
			await RenderingServer.frame_post_draw
			var frame := get_viewport().get_texture().get_image()
			frame.resize(FRAME_W, FRAME_H, Image.INTERPOLATE_BILINEAR)
			frame.convert(Image.FORMAT_RGBA8)
			var col := captured % COLUMNS
			var row := captured / COLUMNS
			montage.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(col * FRAME_W, row * FRAME_H))
			captured += 1
	var error := montage.save_png(OUT_DIR + "/" + name + "_strip.png")
	if error != OK:
		_errors.append(name + " 条带图保存失败")
	var report := _measure(speed, foot_positions)
	var report_file := FileAccess.open(OUT_DIR + "/" + name + "_metrics.json", FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t"))
	print("WOLF_MOTION ", name, " ", JSON.stringify(report))


func _step(speed: float) -> void:
	_actor.velocity = Vector3(0, 0, -speed)
	_actor.global_position += _actor.velocity * SIM_DT
	_actor._update_skeletal_animation(SIM_DT)


func _foot_world(index: int) -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_feet[index]).origin


func _measure(speed: float, foot_positions: Array) -> Dictionary:
	var result := {"body_speed": speed, "visual_clip": String(_actor._visual_clip), "playback_rate": snappedf(_actor._playback_rate, 0.001), "feet": {}}
	for f in _feet.size():
		var positions: Array = foot_positions[f]
		if positions.size() < 2:
			continue
		var lowest := INF
		for p in positions:
			lowest = minf(lowest, p.y)
		var contact_count := 0
		var signed_z := 0.0
		var contact_min := INF
		var contact_max := -INF
		for i in range(1, positions.size()):
			var a: Vector3 = positions[i - 1]
			var b: Vector3 = positions[i]
			var dz := (b.z - a.z) / SIM_DT
			var horizontal := Vector2(b.x - a.x, b.z - a.z).length() / SIM_DT
			if a.y < lowest + 0.012 and b.y < lowest + 0.012:
				contact_count += 1
				signed_z += dz
				contact_min = minf(contact_min, horizontal)
				contact_max = maxf(contact_max, horizontal)
		var contact_average := 0.0
		if contact_count > 0:
			contact_average = signed_z / contact_count
		result["feet"][_foot_names[f]] = {
			"contact_z_average": snappedf(contact_average, 0.01),
			"contact_speed_min": snappedf(contact_min, 0.01),
			"contact_speed_max": snappedf(contact_max, 0.01),
			"lowest_y": snappedf(lowest, 0.001),
			"contact_steps": contact_count,
		}
		if f == 0:
			var trace: Array = []
			for i in range(1, positions.size()):
				trace.append([snappedf((positions[i] as Vector3).y - lowest, 0.001), snappedf(((positions[i] as Vector3).z - (positions[i - 1] as Vector3).z) / SIM_DT, 0.01)])
			result["trace_front_l"] = trace
	return result
