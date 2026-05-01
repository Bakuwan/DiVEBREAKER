extends Node2D

@export var burst_count: int = 3
@export var burst_delay: float = 0.08

func fire(weapon_data: WeaponData, spawn_pos: Vector2):
	for i in range(burst_count):
		spawn_bullet(weapon_data, spawn_pos)

		if i < burst_count - 1 and burst_delay > 0.0:
			await get_tree().create_timer(burst_delay).timeout

	queue_free()

func spawn_bullet(weapon_data: WeaponData, spawn_pos: Vector2):
	var b = weapon_data.bullet_scene.instantiate()
	get_parent().add_child(b)
	b.global_position = spawn_pos
