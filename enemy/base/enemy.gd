extends Area2D
class_name BaseEnemy

@export_category("Base Enemy")
@export var speed: float = 200.0
@export var hp: float = 1.0
@export var spawn_invulnerable_until_visible: bool = true
@export var hit_flash_duration: float = 0.08
@export var hit_flash_color: Color = Color(2.0, 2.0, 2.0, 1.0)
@export var movement_pattern: EnemyMovementPattern

@export_category("Item Drop")
@export var lootbox_drop_chance: float = 0.2
@export var lootbox_scene: PackedScene = preload("res://lootbox/lootbox_pickup.tscn")
@export var healing_drop_chance: float = 0.05
@export var healing_scene: PackedScene = preload("res://healing/healing_pickup.tscn")

@export_category("Death Effect")
@export var death_effect_scene: PackedScene = preload("res://enemy/base/enemy_death_effect.tscn")

var spawn_position: Vector2
var movement_elapsed: float = 0.0
var flash_tween: Tween
var flash_sprites: Array[Sprite2D] = []
var flash_original_modulates := {}
var spawn_invulnerability_active := false
var defeat_registered := false
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

func _enter_tree():
	spawn_position = global_position
	movement_elapsed = 0.0
	spawn_invulnerability_active = spawn_invulnerable_until_visible

func set_spawn_transform(spawn_global_position: Vector2) -> void:
	spawn_position = spawn_global_position
	global_position = spawn_global_position
	movement_elapsed = 0.0

func _process(delta):
	movement_elapsed += delta
	move(delta)
	combat(delta)

	if spawn_invulnerability_active and is_fully_inside_viewport():
		spawn_invulnerability_active = false
	
	if global_position.x < -100 or global_position.x > 1500 or global_position.y < -100 or global_position.y > 800:
		queue_free()

func move(delta):
	if movement_pattern != null:
		var visible_rect = get_viewport_rect()
		var visible_padding = get_collision_right_padding()
		global_position = movement_pattern.get_next_position(
			spawn_position,
			global_position,
			speed,
			movement_elapsed,
			delta,
			visible_rect.end.x,
			visible_padding
		)
		return

	global_position.x -= speed * delta

func combat(_delta):
	pass

func take_damage(amount: float = 1.0):
	if spawn_invulnerability_active:
		return

	hp -= amount
	play_hit_flash()
	if hp <= 0:
		die()

func die():
	register_enemy_kill()
	spawn_death_effect()
	spawn_lootbox_drop()
	spawn_heal_drop()
	queue_free()

func register_enemy_kill() -> void:
	if defeat_registered:
		return

	defeat_registered = true
	var current_scene = get_tree().current_scene
	if current_scene != null and current_scene.has_method("register_enemy_killed"):
		current_scene.register_enemy_killed()

func spawn_lootbox_drop() -> void:
	if lootbox_scene == null or get_parent() == null:
		return

	if randf() > lootbox_drop_chance:
		return

	var parent = get_parent()
	var drop_position = global_position
	var lootbox = lootbox_scene.instantiate()
	parent.call_deferred("add_child", lootbox)
	lootbox.set_deferred("global_position", drop_position)

func spawn_heal_drop() -> void:
	if healing_scene == null or get_parent() == null:
		return

	if randf() > healing_drop_chance:
		return

	var parent = get_parent()
	var drop_position = global_position
	var healing_pickup = healing_scene.instantiate()
	parent.call_deferred("add_child", healing_pickup)
	healing_pickup.set_deferred("global_position", drop_position)

func spawn_death_effect() -> void:
	if death_effect_scene == null or get_parent() == null:
		return

	var parent = get_parent()
	var effect_position = global_position
	var death_effect = death_effect_scene.instantiate()
	parent.call_deferred("add_child", death_effect)
	death_effect.set_deferred("global_position", effect_position)

func cache_flash_sprites(node: Node) -> void:
	if flash_sprites.is_empty():
		for child in node.get_children():
			if child is Sprite2D:
				var sprite := child as Sprite2D
				flash_sprites.append(sprite)
				flash_original_modulates[sprite] = sprite.modulate

			cache_flash_sprites(child)

func play_hit_flash() -> void:
	if flash_sprites.is_empty():
		cache_flash_sprites(self)

	if flash_sprites.is_empty():
		return

	if flash_tween != null and flash_tween.is_running():
		flash_tween.kill()

	flash_tween = create_tween()

	for sprite in flash_sprites:
		if not is_instance_valid(sprite):
			continue

		var original_modulate: Color = flash_original_modulates.get(sprite, Color.WHITE)
		sprite.modulate = hit_flash_color
		flash_tween.parallel().tween_property(sprite, "modulate", original_modulate, hit_flash_duration)

func is_fully_inside_viewport() -> bool:
	var visible_rect = get_viewport_rect()
	var screen_center = get_global_transform_with_canvas().origin

	if collision_shape != null:
		screen_center = collision_shape.get_global_transform_with_canvas().origin

	var extents = get_collision_extents()
	return (
		screen_center.x >= visible_rect.position.x + extents.x
		and screen_center.x <= visible_rect.end.x - extents.x
		and screen_center.y >= visible_rect.position.y + extents.y
		and screen_center.y <= visible_rect.end.y - extents.y
	)

func get_collision_extents() -> Vector2:
	if collision_shape == null or collision_shape.shape == null:
		return Vector2.ZERO

	var shape = collision_shape.shape
	if shape is RectangleShape2D:
		var rect_shape := shape as RectangleShape2D
		return rect_shape.size * 0.5

	if shape is CircleShape2D:
		var circle_shape := shape as CircleShape2D
		return Vector2.ONE * circle_shape.radius

	return Vector2.ONE * 16.0

func get_collision_right_padding() -> float:
	var extents = get_collision_extents()
	if collision_shape == null:
		return extents.x

	return extents.x + max(collision_shape.position.x, 0.0)
