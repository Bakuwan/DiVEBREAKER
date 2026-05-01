extends ProgressBar

func _ready() -> void:
	var player = %Player
	if player and player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)
		
		if "max_health" in player and "current_health" in player:
			max_value = player.max_health
			value = player.current_health

func _on_player_health_changed(new_health: float, max_health_val: float) -> void:
	max_value = max_health_val
	value = new_health
