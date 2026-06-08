extends Area2D

@export var speed: float = 360.0
@export var impact_damage: float = 1
@export var explosion_damage: float = 5
@export var explosion_radius: float = 100.0
@export var explosion_effect_scene: PackedScene = preload("res://bullet/explosive/explosion_effect.tscn")
@export var hit_sound: AudioStream = preload("res://assets/audio/explosion_hitsound.ogg")
@export var viewport_margin: float = 32.0

var direction: Vector2 = Vector2.RIGHT
var exploded := false

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position += direction * speed * delta
	rotation = direction.angle()

	if is_outside_visible_viewport():
		explode()

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy"):
		return

	if area.has_method("take_damage"):
		area.take_damage(impact_damage, hit_sound)

	explode(area)

func explode(primary_target: Area2D = null) -> void:
	if exploded:
		return

	exploded = true
	spawn_explosion_effect()
	damage_enemies_in_radius(primary_target)
	queue_free()

func spawn_explosion_effect() -> void:
	if explosion_effect_scene == null or get_parent() == null:
		return

	var parent = get_parent()
	var effect_position = global_position
	var effect = explosion_effect_scene.instantiate()
	parent.call_deferred("add_child", effect)
	effect.set_deferred("global_position", effect_position)

	if "max_radius" in effect:
		effect.max_radius = explosion_radius

func damage_enemies_in_radius(primary_target: Area2D = null) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Area2D):
			continue

		var enemy_area := enemy as Area2D
		if not is_instance_valid(enemy_area):
			continue

		if enemy_area == primary_target:
			continue

		if enemy_area.global_position.distance_to(global_position) > explosion_radius:
			continue

		if enemy_area.has_method("take_damage"):
			enemy_area.take_damage(explosion_damage, hit_sound)

func is_outside_visible_viewport() -> bool:
	var screen_position = get_global_transform_with_canvas().origin
	var visible_rect = get_viewport_rect().grow(viewport_margin)
	return not visible_rect.has_point(screen_position)
