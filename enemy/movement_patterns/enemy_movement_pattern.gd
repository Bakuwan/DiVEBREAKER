extends Resource
class_name EnemyMovementPattern

enum MovementType {
	STRAIGHT,
	ADVANCE_AND_HOLD,
	ADVANCE_AND_WAVE
}

@export var movement_type: MovementType = MovementType.STRAIGHT
@export var move_in_distance: float = 180.0
@export var wave_amplitude: float = 32.0
@export var wave_frequency: float = 1.2

func get_next_position(
	spawn_position: Vector2,
	current_position: Vector2,
	move_speed: float,
	elapsed: float,
	delta: float,
	visible_right_edge: float = INF,
	visible_padding: float = 0.0
) -> Vector2:
	if movement_type == MovementType.STRAIGHT:
		return current_position + Vector2.LEFT * move_speed * delta

	if move_speed <= 0.0:
		return spawn_position

	var traveled_distance = spawn_position.x - current_position.x
	if traveled_distance < move_in_distance:
		var step = min(move_speed * delta, move_in_distance - traveled_distance)
		return current_position + Vector2.LEFT * step

	var hold_position_x = spawn_position.x - move_in_distance
	if visible_right_edge < INF:
		var max_visible_hold_x = visible_right_edge - visible_padding
		hold_position_x = min(hold_position_x, max_visible_hold_x)

	if movement_type == MovementType.ADVANCE_AND_HOLD:
		return Vector2(hold_position_x, spawn_position.y)

	var travel_time = move_in_distance / move_speed
	var wave_time = max(elapsed - travel_time, 0.0)
	var wave_offset_y = sin(wave_time * TAU * wave_frequency) * wave_amplitude
	return Vector2(hold_position_x, spawn_position.y + wave_offset_y)
