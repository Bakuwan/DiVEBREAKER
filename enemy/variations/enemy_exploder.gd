extends BaseEnemy
class_name EnemyExploder

@export_category("Exploder Combat")
@export var bullet_scene: PackedScene = preload("res://bullet/enemy/enemy_bullet.tscn")
@export var bullet_count: int = 8
@export var bullet_speed: float = 300.0

func die() -> void:
	var parent = get_parent()
	var explosion_origin = global_position

	register_enemy_kill()
	spawn_death_effect()
	spawn_lootbox_drop()
	spawn_heal_drop()

	if bullet_scene != null and parent != null:
		var angle_step = 360.0 / bullet_count
		
		for i in range(bullet_count):
			var b = bullet_scene.instantiate()
			b.position = explosion_origin
			parent.call_deferred("add_child", b)
			
			var rad = deg_to_rad(i * angle_step)
			if "direction" in b:
				b.direction = Vector2.RIGHT.rotated(rad)
			if "speed" in b:
				b.speed = bullet_speed
				
	queue_free()
