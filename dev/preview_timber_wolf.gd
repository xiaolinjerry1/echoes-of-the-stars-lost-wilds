extends Node3D
## Godot 渲染验收：只加载 Blender 资产，以基础运行时光照保存关键姿势，不修改游戏世界。

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.16, 0.22)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.72, 0.8, 1.0)
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_color = Color(1.0, 0.88, 0.74)
	key.light_energy = 1.7
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 130, 0)
	fill.light_color = Color(0.65, 0.79, 1.0)
	fill.light_energy = 0.8
	add_child(fill)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(2.8, 2.0, -3.7)
	camera.look_at(Vector3(0, 0.72, 0.07))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.25
	camera.current = true
	var wolf := (load("res://art/models/enemy/timber_wolf.glb") as PackedScene).instantiate() as Node3D
	add_child(wolf)
	wolf.rotation.y = PI
	var player := wolf.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await get_tree().process_frame
	for entry in [["idle", 0.0, "idle"], ["bite", 0.3, "bite_windup"], ["bite", 0.4, "bite_hit"], ["death", 1.2, "death"]]:
		var clip := StringName(entry[0])
		player.play(clip, 0.0)
		player.seek(float(entry[1]), true)
		player.advance(0.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "res://dev/art_work/timber_wolf/godot_" + String(entry[2]) + ".png"
		var error := image.save_png(path)
		if error != OK:
			push_error("Wolf preview save failed: " + path)
			get_tree().quit(1)
			return
	print("WOLF_GPU_PREVIEW_OK")
	get_tree().quit()
