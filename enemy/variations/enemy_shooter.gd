extends BaseEnemy
class_name EnemyShooter

@export_category("Shooter Combat")
@export var bullet_scene: PackedScene = preload("res://bullet/enemy/enemy_bullet.tscn")
@export var fire_rate: float = 1.5
@export var bullet_speed: float = 400.0
@export var shoot_direction: Vector2 = Vector2.LEFT

var fire_timer: float = 0.0

func _ready() -> void:
	fire_timer = fire_rate

func combat(delta: float) -> void:
	if bullet_scene != null:
		fire_timer -= delta
		if fire_timer <= 0.0:
			shoot()
			fire_timer = fire_rate

func shoot() -> void:
	if bullet_scene == null:
		return

	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	b.global_position = global_position
	
	if "direction" in b:
		b.direction = shoot_direction
	if "speed" in b:
		b.speed = bullet_speed
