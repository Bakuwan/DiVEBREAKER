extends Node2D

@export var wave_angle: float = 14.0
@export var wave_shot_count: int = 5
@export var wave_delay: float = 0.06

static var sweep_forward := true

func fire(weapon_data: WeaponData, spawn_pos: Vector2):
	var current_sweep_forward = sweep_forward
	sweep_forward = not sweep_forward

	for i in range(wave_shot_count):
		var angle = get_wave_angle(i, current_sweep_forward)
		spawn_bullet(weapon_data, spawn_pos, angle)

		if i < wave_shot_count - 1 and wave_delay > 0.0:
			await get_tree().create_timer(wave_delay).timeout

	queue_free()

func get_wave_angle(index: int, current_sweep_forward: bool) -> float:
	if wave_shot_count <= 1:
		return 0.0

	var progress = float(index) / float(wave_shot_count - 1)
	var start_angle = -wave_angle
	var end_angle = wave_angle

	if not current_sweep_forward:
		start_angle = wave_angle
		end_angle = -wave_angle

	return lerp(start_angle, end_angle, progress)

func spawn_bullet(weapon_data: WeaponData, spawn_pos: Vector2, angle_deg: float):
	var b = weapon_data.bullet_scene.instantiate()
	get_parent().add_child(b)
	b.global_position = spawn_pos

	var rad = deg_to_rad(angle_deg)
	if "direction" in b:
		b.direction = Vector2.RIGHT.rotated(rad)
	b.rotation = rad
