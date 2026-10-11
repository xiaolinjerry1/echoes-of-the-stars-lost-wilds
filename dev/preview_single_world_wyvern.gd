extends Node3D
## 主世界实景验收：整片林间遗迹及飞龙飞行/俯冲/吐火姿态，不读写玩家存档。
var camera: Camera3D
class Target:
	extends Node3D
	func take_damage(_amount: float,_source: Node=null) -> void: pass
	func apply_external_knockback(_direction: Vector3,_force: float) -> void: pass
func capture(path: String,eye: Vector3,focus: Vector3,fov:=55.0) -> void:
	camera.global_position=eye
	camera.look_at(focus)
	camera.fov=fov
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	print("CAPTURE ",path," ",get_viewport().get_texture().get_image().save_png(path))
func _ready() -> void: call_deferred("run")
func run() -> void:
	camera=Camera3D.new()
	add_child(camera)
	camera.current=true
	var forest=(load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
	add_child(forest)
	var elapsed:=0.0
	while (not forest.is_world_ready() or forest.nav_region.is_baking()) and elapsed<100:
		await get_tree().create_timer(.2).timeout
		elapsed+=.2
	for enemy in get_tree().get_nodes_in_group("enemy"):enemy.set_physics_process(false)
	forest.day_night.set_time_of_day(10)
	var grove: Node3D=forest.get_node("NavRegion/MainWorldGrove")
	var beast=grove.get_boss()
	beast.rotation.y=PI
	await capture("res://art/previews/scenery/grove_in_main_world.png",grove.global_position+Vector3(24,35,55),grove.global_position+Vector3(0,1,-3),65)
	await capture("res://art/previews/scenery/grove_walk_in_entrance.png",WorldLayout.GROVE_ENTRANCE+Vector3(0,1.8,12),grove.global_position+Vector3(0,2.7,-4),75)
	var dragon=forest.get_node("NavRegion/DreadWyvern")
	var nest: Vector3=dragon.nest_position
	dragon.global_position=nest+Vector3(0,13,0)
	dragon.rotation.y=PI
	dragon._motion.play("fly",true)
	dragon._motion.advance(.25)
	await capture("res://art/previews/enemy/dread_wyvern_in_forest.png",dragon.global_position+Vector3(20,7,28),dragon.global_position+Vector3(0,2.5,0),52)
	await capture("res://art/previews/enemy/dread_wyvern_head.png",dragon.global_position+Vector3(4,5,11),dragon.global_position+Vector3(0,3.6,3.3),40)
	var target:=Target.new()
	add_child(target)
	target.add_to_group("player")
	target.global_position=nest+Vector3(0,.2,15)
	var warrior=(load("res://art/models/player/npc_elin.glb") as PackedScene).instantiate() as Node3D
	add_child(warrior)
	warrior.global_position=target.global_position
	dragon.start_fireball(target)
	for frame in 70:dragon._physics_process(1.0/60)
	for ball in get_tree().get_nodes_in_group("wyvern_fireball"):ball.set_physics_process(false)
	await capture("res://art/previews/enemy/dread_wyvern_fireball.png",nest+Vector3(18,12,30),nest+Vector3(0,8,5),52)
	for ball in get_tree().get_nodes_in_group("wyvern_fireball"):ball.queue_free()
	dragon._clear_warning()
	dragon.global_position=nest+Vector3(0,.5,5)
	dragon.rotation.y=PI
	dragon._motion.play("dive",true)
	dragon._motion.advance(.55)
	await capture("res://art/previews/enemy/dread_wyvern_dive.png",nest+Vector3(16,7,23),nest+Vector3(0,2.5,8),55)
	for child in get_children():child.queue_free()
	for frame in 4:await get_tree().process_frame
	get_tree().quit()
