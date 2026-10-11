extends Node3D
## 新战斗表现的真实 Forward+ 场景截图。
var session: GameSession
func _ready() -> void: call_deferred("run")
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/previews/player/"+name+".png")
func run() -> void:
	session=(load("res://scenes/app/game_session.tscn") as PackedScene).instantiate()
	add_child(session);AppFlow.game_session=session;session.initialize("dart_master")
	await get_tree().create_timer(4.0).timeout
	var p := session.get_player()
	var c := p.survivor
	for enemy in get_tree().get_nodes_in_group("enemy"):enemy.set_physics_process(false)
	for director in session.find_children("*","HordeDirector",true,false):director.enabled=false
	var preview_boss: BaseEnemy=get_tree().get_first_node_in_group("moss_crown_beast")
	p.global_position=preview_boss.global_position+Vector3(0,0,18)
	p.global_position.y=TerrainBuilder.height_at(p.global_position.x,p.global_position.z)+0.05
	c.yaw=0;c.pitch=-0.35
	p.camera_pivot.spring_length=4.5
	var wolf := (load("res://scenes/actors/base_enemy.tscn") as PackedScene).instantiate() as BaseEnemy
	wolf.set_script(load("res://scenes/actors/melee_chaser.gd"));add_child(wolf)
	wolf.global_position=p.global_position+Vector3(0,0,-9)
	wolf.global_position.y=TerrainBuilder.height_at(wolf.global_position.x,wolf.global_position.z)
	wolf.set_physics_process(false);wolf.current_health=10000
	await get_tree().create_timer(0.3).timeout
	c.combat.launch((DartCombat.hit_center(wolf)-p.global_position-Vector3.UP).normalized())
	await get_tree().create_timer(0.25).timeout
	await capture("dart_chain_in_forest")
	CombatImpact.spawn(self,DartCombat.hit_center(wolf),Vector3.FORWARD,true)
	await get_tree().create_timer(0.06).timeout
	await capture("dart_impact_in_forest")
	await get_tree().create_timer(1.4).timeout
	await capture("dart_return_in_forest")
	var key := InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true;Input.parse_input_event(key)
	await get_tree().create_timer(0.3).timeout
	await capture("dart_jump_in_forest")
	key=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=false;Input.parse_input_event(key)
	await get_tree().create_timer(0.6).timeout
	var beast: BaseEnemy=get_tree().get_first_node_in_group("moss_crown_beast")
	p.global_position=beast.global_position+Vector3(0,0,14)
	c.yaw=0;c.pitch=-0.35
	await get_tree().create_timer(0.3).timeout
	BossGroundWave.spawn(beast,beast.global_position,0.0,9.0,0.0)
	BossGroundWave.spawn(beast,beast.global_position,0.35,10.0,0.0)
	HitEffect.spawn_burst(self,beast.global_position+Vector3.UP*0.3,Color(0.7,0.6,0.35),60,6.0)
	await get_tree().create_timer(0.55).timeout
	await capture("boss_layered_shockwaves")
	for offset in [Vector3(-3,0,9),Vector3(0,0,9),Vector3(3,0,9)]:
		BossGroundWave.spawn(beast,beast.global_position+offset,0.1,2.2,0.0,true)
	await get_tree().create_timer(0.5).timeout
	await capture("boss_root_fields")
	AppFlow.game_session=null;session.queue_free()
	await get_tree().process_frame;get_tree().quit()
