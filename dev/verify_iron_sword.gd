extends SceneTree
## 验证铁剑导入后的 PBR 贴图、网格和第一人称武器挂接，不访问存档。

var _mesh_count := 0
var _errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _inspect(node: Node) -> void:
	if node is MeshInstance3D:
		_mesh_count += 1
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null:
				_errors.append("Missing PBR material: " + str(node.name))
				continue
			for property in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture"]:
				var texture := material.get(property) as Texture2D
				if texture == null:
					_errors.append("Missing " + property + ": " + str(node.name))
				elif texture.get_width() != 1024 or texture.get_height() != 1024:
					_errors.append("Unexpected resolution: " + property)
			if not material.normal_enabled or not material.ao_enabled:
				_errors.append("Normal or AO disabled: " + str(node.name))
	for child in node.get_children():
		_inspect(child)


func _run() -> void:
	var packed := load("res://art/models/player/iron_sword.glb") as PackedScene
	if packed == null:
		push_error("Iron sword GLB import failed")
		quit(1)
		return
	var sword := packed.instantiate()
	_inspect(sword)
	sword.free()
	if _mesh_count != 4:
		_errors.append("Expected 4 sword parts; got " + str(_mesh_count))
	var fp_packed := load("res://scenes/player/fp_arms.tscn") as PackedScene
	if fp_packed == null:
		_errors.append("First-person arms scene failed to load")
	else:
		var fp := fp_packed.instantiate()
		if fp.get_node_or_null("WeaponMount/IronSword") == null:
			_errors.append("WeaponMount/IronSword missing")
		fp.free()
	for error in _errors:
		push_error(error)
	print("IRON_SWORD_VERIFY: ", JSON.stringify({"meshes": _mesh_count, "errors": _errors, "passed": _errors.is_empty()}))
	quit(0 if _errors.is_empty() else 1)
