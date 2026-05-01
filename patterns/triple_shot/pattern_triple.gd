extends Node2D

@export var spread_angle: float = 10.0

func fire(weapon_data: WeaponData, spawn_pos: Vector2):
	var angles = [-spread_angle, 0, spread_angle]
	
	for angle in angles:
		spawn_bullet(weapon_data, spawn_pos, angle)
	
	queue_free()

func spawn_bullet(weapon_data: WeaponData, spawn_pos: Vector2, angle_deg: float):
	var b = weapon_data.bullet_scene.instantiate()
	get_parent().add_child(b)
	b.global_position = spawn_pos
	
	var rad = deg_to_rad(angle_deg)
	if "direction" in b:
		b.direction = Vector2.RIGHT.rotated(rad)
	b.rotation = rad
