extends Area3D
## SafeZone（营地安全区）
## 职责：玩家进入营地范围时把复活点设为营地篝火（死亡后回到营地），并提示安全区。

func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var camp := get_parent()
	if camp != null and camp.has_method("get_campfire_position"):
		body.call("set_respawn_point", camp.call("get_campfire_position"))
	var session := get_tree().get_first_node_in_group("game_session") as GameSession
	if session != null:
		var camps: Array = session.world_data.get("unlocked_camps", [])
		if not camps.has("windmill_camp"):
			camps.append("windmill_camp")
			session.world_data["unlocked_camps"] = camps
	if body.has_method("show_combat_feedback"):
		body.call("show_combat_feedback", "进入营地（安全区）：死亡后将在篝火处复活", Color(0.6, 0.9, 0.6))
