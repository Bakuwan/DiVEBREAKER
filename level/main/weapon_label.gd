extends Label

@export var prefix_text: String = "Weapon: "
@export var fallback_text: String = "Unknown"

func _ready() -> void:
	var player = %Player
	if player == null:
		return

	if player.has_signal("weapon_changed"):
		player.weapon_changed.connect(_on_player_weapon_changed)

	if "current_weapon" in player and player.current_weapon != null:
		_on_player_weapon_changed(player.current_weapon)
	else:
		text = prefix_text + fallback_text

func _on_player_weapon_changed(new_weapon: WeaponData) -> void:
	if new_weapon == null:
		text = prefix_text + fallback_text
		return

	text = prefix_text + new_weapon.weapon_name
