extends Node2D

func fire(weapon_data: WeaponData, spawn_pos: Vector2):
	var b = weapon_data.bullet_scene.instantiate()
	get_parent().add_child(b)
	b.global_position = spawn_pos
	
	queue_free()
