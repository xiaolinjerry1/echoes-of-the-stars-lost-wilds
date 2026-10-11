class_name GameSession
extends Node3D
## 单主世界割草会话；旧RPG字段仅留作历史脚本兼容，不再初始化或参与玩法。
var selected_class_id := "dart_master"
var selected_spirit_id := ""
var spirit_level := 1
var collected_echoes: Array[String] = []
var prep_slots: Array[String] = ["",""]
var echo_energy := 0.0
var inventory_data: Dictionary = {}
var equipment_data: Dictionary = {}
var quest_data: Dictionary = {}
var starter_equipment_granted := true
var world_data: Dictionary = {}
var current_world_id := "forest"
var play_time := 0.0
var is_initialized := false
var _auto_save_timer := 0.0
func _ready() -> void: add_to_group("game_session")
func _process(delta: float) -> void:
	if not is_initialized:return
	play_time+=delta
	_auto_save_timer+=delta
	if _auto_save_timer>=300.0 and not is_in_combat():
		_auto_save_timer=0.0
		SaveService.request_auto_save("timer")
func get_player() -> PlayerController:
	return $Player.get_child(0) as PlayerController if $Player.get_child_count()>0 else null
func is_in_combat() -> bool:
	var player := get_player()
	if player==null:return false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if DartCombat.alive(enemy) and player.global_position.distance_to(enemy.global_position)<18.0:return true
	return false
func initialize(_class_id: String, _spirit_id := "", _level := 1) -> void:
	selected_class_id="dart_master"
	var world := (load("res://scenes/world/forest_entrance.tscn") as PackedScene).instantiate()
	$World.add_child(world)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	$Player.add_child(player)
	player.global_position=world.get_spawn_position()
	world.setup_player(player)
	var director := HordeDirector.new()
	world.add_child(director)
	director.player=player
	is_initialized=true
func collect_save_snapshot() -> Dictionary:
	var player := get_player()
	var day := get_tree().get_first_node_in_group("day_night")
	var weather := get_tree().get_first_node_in_group("weather")
	return {"gameplay_mode":"survivor","selected_class_id":"dart_master","world_data":world_data.duplicate(true),"play_time":play_time,"player_data":player.get_save_data() if player!=null else {},"survivor_data":player.survivor.get_save_data() if player!=null else {},"environment_data":{"world_time":day.get_save_data().get("world_time",8.0) if day!=null else 8.0,"weather_state":weather.get_save_data().get("weather_state","clear") if weather!=null else "clear"}}
func apply_saved_payload(payload: Dictionary) -> void:
	world_data=payload.get("world_data",{}).duplicate(true)
	play_time=float(payload.get("play_time",0.0))
	var player := get_player()
	if str(payload.get("gameplay_mode",""))=="survivor":
		player.apply_saved_data(payload.get("player_data",{}))
		player.survivor.load_save_data(payload.get("survivor_data",{}))
	else:
		player.show_combat_feedback("旧存档已转为飞镖师玩法，世界探索保留",Color(0.6,0.8,1))
	for chest in get_tree().get_nodes_in_group("chest"):
		if chest.has_method("apply_saved_state"):chest.apply_saved_state()
	var env: Dictionary=payload.get("environment_data",{})
	for group in ["day_night","weather"]:
		var node := get_tree().get_first_node_in_group(group)
		if node!=null:node.load_save_data(env)
func clear_session() -> void:
	get_tree().paused=false
	for child in get_children():child.queue_free()
	is_initialized=false
