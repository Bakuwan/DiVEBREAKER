extends Area2D

@export var speed: float = 420.0
@export var damage: float = 3
@export var turn_speed: float = 4.0
@export var homing_duration: float = 0.35
@export var viewport_margin: float = 32.0

var direction: Vector2 = Vector2.RIGHT
var target_enemy: Node2D
var homing_time_left: float = 0.0

func _ready() -> void:
	homing_time_left = homing_duration
	target_enemy = find_closest_enemy()

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	update_homing(delta)
	position += direction * speed * delta
	rotation = direction.angle()

	if is_outside_visible_viewport():
		queue_free()

func update_homing(delta: float) -> void:
	if homing_time_left <= 0.0:
		return

	homing_time_left = max(homing_time_left - delta, 0.0)
	update_direction(delta)

func update_direction(delta: float) -> void:
	if not is_instance_valid(target_enemy):
		return

	var desired_direction = (target_enemy.global_position - global_position).normalized()
	if desired_direction == Vector2.ZERO:
		return

	var turn_amount = turn_speed * delta
	direction = direction.normalized().slerp(desired_direction, min(turn_amount, 1.0)).normalized()

func find_closest_enemy() -> Node2D:
	var closest_enemy: Node2D
	var closest_distance := INF

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node2D):
			continue

		var enemy_node := enemy as Node2D
		if not is_instance_valid(enemy_node):
			continue

		var distance = global_position.distance_squared_to(enemy_node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy_node

	return closest_enemy

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy"):
		return

	if area.has_method("take_damage"):
		area.take_damage(damage)

	queue_free()

func is_outside_visible_viewport() -> bool:
	var screen_position = get_global_transform_with_canvas().origin
	var visible_rect = get_viewport_rect().grow(viewport_margin)
	return not visible_rect.has_point(screen_position)
