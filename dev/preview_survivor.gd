extends Node3D
## 真实森林第三人称、升级卡片及影分身实景截图。
var session: GameSession
func _ready() -> void:call_deferred("run")
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/previews/player/"+name+".png")
func run() -> void:
	session=(load("res://scenes/app/game_session.tscn") as PackedScene).instantiate()
	add_child(session);AppFlow.game_session=session
	session.initialize("dart_master")
	await get_tree().create_timer(4.0).timeout
	var p := session.get_player()
	p.global_position=WorldLayout.CAMP+Vector3(0,0.8,-31)
	p.global_position.y=TerrainBuilder.height_at(p.global_position.x,p.global_position.z)+0.1
	p.survivor.yaw=0.0
	p.survivor.pitch=-0.4
	for enemy in get_tree().get_nodes_in_group("enemy"):enemy.set_physics_process(false)
	for director in session.find_children("*","HordeDirector",true,false):director.enabled=false
	await get_tree().create_timer(1.0).timeout
	await capture("dart_master_in_forest")
	p.survivor.add_experience(24)
	await get_tree().process_frame
	await capture("dart_master_upgrade")
	p.survivor.choose_upgrade(str(p.survivor.offered[0]))
	p.survivor.echo_value=100.0
	p.survivor.activate_ultimate()
	await get_tree().create_timer(1.0).timeout
	await capture("dart_master_clones")
	p.survivor.end_ultimate()
	get_tree().paused=false;AppFlow.game_session=null
	session.queue_free();await get_tree().process_frame
	get_tree().quit()
