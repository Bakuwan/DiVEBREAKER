extends BaseEnemy
class_name BossMain

signal boss_started(max_hp: float, boss_name: String)
signal boss_health_changed(current_hp: float, max_hp: float)
signal boss_defeated()
signal boss_intro_finished
signal boss_defeat_started()
signal boss_defeat_finished()

@export_category("Boss Identity")
@export var boss_name: String = "when the dive is freedom"
@export var max_hp: float = 80.0
@export var phase_two_threshold: float = 0.5

@export_category("Boss Intro")
@export var intro_speed: float = 150.0
@export var combat_move_speed: float = 180.0
@export var top_hold_position_x_min: float = 440.0
@export var top_hold_position_x_max: float = 540.0
@export var top_hold_position_y_min: float = 90.0
@export var top_hold_position_y_max: float = 130.0
@export var bottom_hold_position_x_min: float = 440.0
@export var bottom_hold_position_x_max: float = 540.0
@export var bottom_hold_position_y_min: float = 230.0
@export var bottom_hold_position_y_max: float = 270.0
@export var hold_position_duration: float = 1.15
@export var hold_attack_windup: float = 0.2

@export_category("Boss Attacks")
@export var bullet_scene: PackedScene = preload("res://bullet/enemy/enemy_bullet.tscn")
@export var anchor_bullet_scene: PackedScene = preload("res://bullet/boss/BulletBoss.tscn")

@export var bullet_speed: float = 260.0
@export var aimed_shot_cooldown: float = 0.8
@export var spread_shot_cooldown: float = 1.5
@export var five_shot_cooldown: float = 1.8

@export var burst_fire_count: int = 5
@export var burst_fire_delay: float = 0.12
@export var burst_fire_cooldown: float = 1.5

@export var anchor_bullet_cooldown: float = 2.6
@export var spread_angle: float = 12.0
@export var five_shot_spread_angle: float = 10.0
@export var anchor_bullet_count: int = 3
@export var anchor_bullet_angle_step: float = 18.0
@export var anchor_bullet_center_angle_min: float = 155.0
@export var anchor_bullet_center_angle_max: float = 205.0
@export var anchor_bullet_speed: float = 220.0
@export var anchor_bullet_damage: float = 14.0
@export var bullet_hell_center_position: Vector2 = Vector2(500.0, 180.0)
@export var bullet_hell_phase_two_cycle_threshold: int = 12
@export var bullet_hell_windup: float = 0.4
@export var bullet_hell_pulse_count: int = 8
@export var bullet_hell_pulse_interval: float = 0.3
@export var bullet_hell_bullet_count: int = 8
@export var bullet_hell_bullet_speed: float = 210.0
@export var bullet_hell_angle_offset_step: float = 11.25
@export var bullet_hell_pattern_gap: float = 0.5
@export var bullet_hell_fan_pulse_count: int = 8
@export var bullet_hell_fan_pulse_interval: float = 0.3
@export var bullet_hell_fan_bullet_count: int = 9
@export var bullet_hell_fan_angle_step: float = 9.0
@export var bullet_hell_fan_sweep_angle: float = 20.0
@export var bullet_hell_fan_bullet_speed: float = 230.0
@export var bullet_hell_fan_safe_lane_half_width: float = 1.0
@export var bullet_hell_tracking_burst_count: int = 8
@export var bullet_hell_tracking_burst_interval: float = 0.2
@export var bullet_hell_tracking_spread_angle: float = 14.0
@export var bullet_hell_tracking_bullet_speed: float = 250.0
@export var bullet_hell_invul_pulse_speed: float = 7.0
@export var bullet_hell_invul_color: Color = Color(1.0, 0.92, 0.35, 1.0)

@export_category("Boss Defeat")
@export var defeat_dialog_lines: Array[String] = ["This is truly my glorious crown..."]
@export var defeat_dialog_line_duration: float = 1.4
@export var defeat_explosion_scene: PackedScene = preload("res://bullet/explosive/explosion_effect.tscn")
@export var defeat_explosion_count: int = 6
@export var defeat_explosion_interval: float = 0.15
@export var defeat_slowmo_scale: float = 0.2
@export var defeat_slowmo_duration: float = 0.2
@export var boss_bonus_score: int = 0

var current_hp: float = 0.0
var current_phase: int = 1
var intro_complete := false
var attack_timer := 0.0
var attack_index := 0
var intro_target_position := Vector2(500.0, 180.0)
var current_hold_target_position: Vector2 = Vector2.ZERO
var is_holding_position := false
var hold_timer := 0.0
var move_up_next := true
var special_attack_active := false
var special_attack_target_position: Vector2 = Vector2.ZERO
var bullet_hell_invulnerable := false
var phase_two_attack_cycle_count := 0
var combat_enabled := false
var defeat_active := false

@onready var target_player: Node2D = get_tree().get_first_node_in_group("player") as Node2D

func _ready() -> void:
	hp = max_hp
	current_hp = max_hp
	lootbox_drop_chance = 0.0
	healing_drop_chance = 0.0
	attack_timer = aimed_shot_cooldown
	combat_enabled = false
	defeat_active = false

func start_intro(target_position: Vector2) -> void:
	intro_target_position = target_position
	intro_complete = false
	combat_enabled = false
	attack_timer = aimed_shot_cooldown
	attack_index = 0
	phase_two_attack_cycle_count = 0
	current_hold_target_position = target_position
	is_holding_position = false
	hold_timer = 0.0
	move_up_next = true

func move(delta: float) -> void:
	if defeat_active:
		return

	if not intro_complete:
		global_position = global_position.move_toward(intro_target_position, intro_speed * delta)
		if global_position.distance_to(intro_target_position) <= 2.0:
			global_position = intro_target_position
			intro_complete = true
			spawn_invulnerability_active = false
			current_hold_target_position = get_random_hold_target(true)
			hold_timer = 0.0
			is_holding_position = false
			move_up_next = false
			attack_timer = 0.0
			boss_intro_finished.emit()
			return

	if not combat_enabled:
		return

	if special_attack_active:
		update_special_attack_movement(delta)
		update_bullet_hell_invulnerability_visual(delta)
		return

	reset_bullet_hell_invulnerability_visual()
	update_combat_movement(delta)

func combat(delta: float) -> void:
	if defeat_active or not intro_complete or not combat_enabled or special_attack_active:
		return

	if not is_holding_position:
		return

	attack_timer -= delta
	if attack_timer > 0.0:
		return

	if current_phase == 1:
		execute_phase_one_attack()
	else:
		if phase_two_attack_cycle_count >= bullet_hell_phase_two_cycle_threshold:
			phase_two_attack_cycle_count = 0
			fire_bullet_hell_attack()
			return

		execute_phase_two_attack()

func take_damage(amount: float = 1.0):
	if defeat_active or spawn_invulnerability_active or bullet_hell_invulnerable or not intro_complete or not combat_enabled:
		return

	hp -= amount
	current_hp = max(hp, 0.0)
	play_hit_flash()
	update_phase()
	boss_health_changed.emit(current_hp, max_hp)

	if hp <= 0.0:
		die()

func die():
	if defeat_active:
		return

	defeat_active = true
	combat_enabled = false
	special_attack_active = false
	bullet_hell_invulnerable = false
	reset_bullet_hell_invulnerability_visual()
	register_enemy_kill()

	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	boss_defeat_started.emit()
	call_deferred("_run_defeat_sequence")

func update_phase() -> void:
	if current_phase == 1 and current_hp <= max_hp * phase_two_threshold:
		current_phase = 2
		attack_index = 0
		attack_timer = 0.0
		phase_two_attack_cycle_count = 0
		call_deferred("trigger_phase_two_transition")

func trigger_phase_two_transition() -> void:
	if defeat_active or not is_inside_tree() or hp <= 0.0 or not combat_enabled:
		return

	if special_attack_active:
		return

	fire_bullet_hell_attack()

func update_special_attack_movement(delta: float) -> void:
	global_position = global_position.move_toward(special_attack_target_position, combat_move_speed * delta)
	if global_position.distance_to(special_attack_target_position) <= 2.0:
		global_position = special_attack_target_position

func update_combat_movement(delta: float) -> void:
	var target_position = current_hold_target_position

	if is_holding_position:
		global_position = target_position
		hold_timer -= delta
		if hold_timer <= 0.0:
			is_holding_position = false
			current_hold_target_position = get_next_hold_target_position()
		return

	global_position = global_position.move_toward(target_position, combat_move_speed * delta)
	if global_position.distance_to(target_position) <= 2.0:
		global_position = target_position
		is_holding_position = true
		hold_timer = hold_position_duration
		attack_timer = min(attack_timer, hold_attack_windup)

func get_next_hold_target_position() -> Vector2:
	var next_target_position = get_random_hold_target(false)
	if move_up_next:
		next_target_position = get_random_hold_target(true)

	move_up_next = not move_up_next
	return next_target_position

func get_random_hold_target(use_top_region: bool) -> Vector2:
	if use_top_region:
		return Vector2(
			randf_range(top_hold_position_x_min, top_hold_position_x_max),
			randf_range(top_hold_position_y_min, top_hold_position_y_max)
		)

	return Vector2(
		randf_range(bottom_hold_position_x_min, bottom_hold_position_x_max),
		randf_range(bottom_hold_position_y_min, bottom_hold_position_y_max)
	)

func execute_phase_one_attack() -> void:
	match attack_index % 8:
		0:
			fire_aimed_shot()
			attack_timer = aimed_shot_cooldown
		1:
			fire_aimed_shot()
			attack_timer = aimed_shot_cooldown
		2:
			fire_aimed_shot()
			attack_timer = aimed_shot_cooldown
		3:
			fire_triple_spread()
			attack_timer = spread_shot_cooldown
		4:
			fire_five_shot_spread()
			attack_timer = five_shot_cooldown
		5:
			fire_burst_fire()
			attack_timer = burst_fire_cooldown
		6:
			fire_burst_fire()
			attack_timer = burst_fire_cooldown
		_:
			fire_burst_fire()
			attack_timer = burst_fire_cooldown

	attack_index += 1

func execute_phase_two_attack() -> void:
	match attack_index % 12:
		0:
			fire_aimed_shot()
			attack_timer = aimed_shot_cooldown
		1:
			fire_aimed_shot()
			attack_timer = aimed_shot_cooldown
		2:
			fire_aimed_shot()
			attack_timer = aimed_shot_cooldown
		3:
			fire_triple_spread()
			attack_timer = spread_shot_cooldown
		4:
			fire_anchor_bullets()
			attack_timer = anchor_bullet_cooldown
		5:
			fire_five_shot_spread()
			attack_timer = five_shot_cooldown
		6:
			fire_burst_fire()
			attack_timer = burst_fire_cooldown
		7:
			fire_burst_fire()
			attack_timer = burst_fire_cooldown
		8:
			fire_burst_fire()
			attack_timer = burst_fire_cooldown
		9:
			fire_five_shot_spread()
			attack_timer = five_shot_cooldown
		10:
			fire_anchor_bullets()
			attack_timer = anchor_bullet_cooldown
		_:
			fire_triple_spread()
			attack_timer = spread_shot_cooldown

	attack_index += 1
	phase_two_attack_cycle_count += 1

func fire_aimed_shot() -> void:
	var direction = get_direction_to_player()
	spawn_attack_bullet(bullet_scene, direction, bullet_speed)

func fire_triple_spread() -> void:
	fire_spread_shot(3, spread_angle)

func fire_five_shot_spread() -> void:
	fire_spread_shot(5, five_shot_spread_angle)

func fire_burst_fire() -> void:
	call_deferred("_run_burst_fire")

func fire_bullet_hell_attack() -> void:
	if defeat_active or special_attack_active or not combat_enabled:
		return

	call_deferred("_run_bullet_hell_attack")

func begin_combat() -> void:
	if defeat_active or not intro_complete or combat_enabled:
		return

	combat_enabled = true
	attack_timer = 0.0
	boss_started.emit(max_hp, boss_name)
	boss_health_changed.emit(current_hp, max_hp)

func fire_anchor_bullets() -> void:
	if anchor_bullet_count <= 0:
		return

	var center_angle = randf_range(anchor_bullet_center_angle_min, anchor_bullet_center_angle_max)
	if anchor_bullet_count <= 1:
		spawn_anchor_bullet(Vector2.RIGHT.rotated(deg_to_rad(center_angle)))
		return

	var half_count = float(anchor_bullet_count - 1) * 0.5
	for i in range(anchor_bullet_count):
		var offset_index = float(i) - half_count
		var angle_offset = center_angle + offset_index * anchor_bullet_angle_step
		spawn_anchor_bullet(Vector2.RIGHT.rotated(deg_to_rad(angle_offset)))

func spawn_anchor_bullet(direction: Vector2) -> void:
	var projectile = spawn_attack_bullet(anchor_bullet_scene, direction, anchor_bullet_speed)
	if projectile != null and "damage" in projectile:
		projectile.damage = anchor_bullet_damage

func _run_burst_fire() -> void:
	for i in range(burst_fire_count):
		if not is_inside_tree() or hp <= 0.0:
			return

		var locked_direction = get_direction_to_player()
		spawn_attack_bullet(bullet_scene, locked_direction, bullet_speed)

		if i < burst_fire_count - 1:
			await get_tree().create_timer(burst_fire_delay, false).timeout

func _run_bullet_hell_attack() -> void:
	special_attack_active = true
	bullet_hell_invulnerable = true
	special_attack_target_position = bullet_hell_center_position
	is_holding_position = false
	hold_timer = 0.0

	while is_inside_tree() and hp > 0.0 and global_position.distance_to(special_attack_target_position) > 2.0:
		await get_tree().process_frame

	if not is_inside_tree() or hp <= 0.0:
		return

	global_position = special_attack_target_position

	if bullet_hell_windup > 0.0:
		await get_tree().create_timer(bullet_hell_windup, false).timeout

	await run_bullet_hell_patterns()

	special_attack_active = false
	bullet_hell_invulnerable = false
	reset_bullet_hell_invulnerability_visual()
	current_hold_target_position = get_next_hold_target_position()
	is_holding_position = false
	hold_timer = 0.0
	phase_two_attack_cycle_count = 0
	attack_timer = hold_attack_windup

func _run_defeat_sequence() -> void:
	await run_defeat_slowmo()
	await run_defeat_explosions()
	fade_out_boss()

	if defeat_dialog_line_duration > 0.0:
		await get_tree().create_timer(defeat_dialog_line_duration, false).timeout

	visible = false
	boss_defeat_finished.emit()
	boss_defeated.emit()
	queue_free()

func run_defeat_slowmo() -> void:
	if defeat_slowmo_duration <= 0.0:
		return

	var original_time_scale = Engine.time_scale
	Engine.time_scale = defeat_slowmo_scale
	await get_tree().create_timer(defeat_slowmo_duration, true, false, true).timeout
	Engine.time_scale = original_time_scale

func run_defeat_explosions() -> void:
	if defeat_explosion_scene == null or defeat_explosion_count <= 0:
		return

	for explosion_index in range(defeat_explosion_count):
		if not is_inside_tree():
			return

		spawn_defeat_explosion()

		if explosion_index < defeat_explosion_count - 1 and defeat_explosion_interval > 0.0:
			await get_tree().create_timer(defeat_explosion_interval, false).timeout

func spawn_defeat_explosion() -> void:
	if defeat_explosion_scene == null or get_parent() == null:
		return

	var explosion = defeat_explosion_scene.instantiate()
	get_parent().add_child(explosion)

	if explosion is Node2D:
		var explosion_node := explosion as Node2D
		explosion_node.global_position = global_position + Vector2(
			randf_range(-26.0, 26.0),
			randf_range(-22.0, 22.0)
		)

func fade_out_boss() -> void:
	if flash_sprites.is_empty():
		cache_flash_sprites(self)

	if flash_sprites.is_empty():
		return

	var fade_tween = create_tween()
	for sprite in flash_sprites:
		if not is_instance_valid(sprite):
			continue

		fade_tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.35)

func run_bullet_hell_patterns() -> void:
	await run_bullet_hell_radial_pattern()

	if bullet_hell_pattern_gap > 0.0 and is_inside_tree() and hp > 0.0:
		await get_tree().create_timer(bullet_hell_pattern_gap, false).timeout

	await run_bullet_hell_fan_pattern()

	if bullet_hell_pattern_gap > 0.0 and is_inside_tree() and hp > 0.0:
		await get_tree().create_timer(bullet_hell_pattern_gap, false).timeout

	await run_bullet_hell_tracking_spread_pattern()
	
func run_bullet_hell_radial_pattern() -> void:
	for pulse_index in range(bullet_hell_pulse_count):
		if not is_inside_tree() or hp <= 0.0:
			return

		spawn_bullet_hell_radial_pulse(pulse_index)

		if pulse_index < bullet_hell_pulse_count - 1 and bullet_hell_pulse_interval > 0.0:
			await get_tree().create_timer(bullet_hell_pulse_interval, false).timeout

func run_bullet_hell_fan_pattern() -> void:
	for pulse_index in range(bullet_hell_fan_pulse_count):
		if not is_inside_tree() or hp <= 0.0:
			return

		spawn_bullet_hell_fan_pulse(pulse_index)

		if pulse_index < bullet_hell_fan_pulse_count - 1 and bullet_hell_fan_pulse_interval > 0.0:
			await get_tree().create_timer(bullet_hell_fan_pulse_interval, false).timeout

func run_bullet_hell_tracking_spread_pattern() -> void:
	for burst_index in range(bullet_hell_tracking_burst_count):
		if not is_inside_tree() or hp <= 0.0:
			return

		spawn_bullet_hell_tracking_spread_burst()

		if burst_index < bullet_hell_tracking_burst_count - 1 and bullet_hell_tracking_burst_interval > 0.0:
			await get_tree().create_timer(bullet_hell_tracking_burst_interval, false).timeout

func spawn_bullet_hell_radial_pulse(pulse_index: int) -> void:
	if bullet_hell_bullet_count <= 0:
		return

	var angle_offset = deg_to_rad(float(pulse_index) * bullet_hell_angle_offset_step)
	for i in range(bullet_hell_bullet_count):
		var angle = angle_offset + TAU * float(i) / float(bullet_hell_bullet_count)
		spawn_bullet_hell_projectile(Vector2.RIGHT.rotated(angle), bullet_hell_bullet_speed)

func spawn_bullet_hell_fan_pulse(pulse_index: int) -> void:
	if bullet_hell_fan_bullet_count <= 0:
		return

	var base_direction := Vector2.LEFT
	var sweep_offset = sin(float(pulse_index) * 0.85) * bullet_hell_fan_sweep_angle
	base_direction = base_direction.rotated(deg_to_rad(sweep_offset))

	var half_count = float(bullet_hell_fan_bullet_count - 1) * 0.5
	for i in range(bullet_hell_fan_bullet_count):
		var offset_index = float(i) - half_count

		# Keep a wider center lane open so the player always has a readable escape gap.
		if absf(offset_index) <= bullet_hell_fan_safe_lane_half_width:
			continue

		var angle_offset = deg_to_rad(offset_index * bullet_hell_fan_angle_step)
		spawn_bullet_hell_projectile(base_direction.rotated(angle_offset), bullet_hell_fan_bullet_speed)

func spawn_bullet_hell_tracking_spread_burst() -> void:
	var base_direction = get_direction_to_player()
	var spread_angles = [
		-bullet_hell_tracking_spread_angle,
		0.0,
		bullet_hell_tracking_spread_angle,
	]

	for angle in spread_angles:
		spawn_bullet_hell_projectile(
			base_direction.rotated(deg_to_rad(angle)),
			bullet_hell_tracking_bullet_speed
		)

func spawn_bullet_hell_projectile(direction: Vector2, projectile_speed: float) -> void:
	var projectile = spawn_attack_bullet(anchor_bullet_scene, direction, projectile_speed)
	if projectile != null and "damage" in projectile:
		projectile.damage = anchor_bullet_damage

func update_bullet_hell_invulnerability_visual(delta: float) -> void:
	if not bullet_hell_invulnerable:
		return

	if flash_sprites.is_empty():
		cache_flash_sprites(self)

	var pulse_strength = 0.5 + 0.5 * sin(movement_elapsed * TAU * bullet_hell_invul_pulse_speed)
	var pulsed_color = Color.WHITE.lerp(bullet_hell_invul_color, pulse_strength)

	for sprite in flash_sprites:
		if not is_instance_valid(sprite):
			continue
		sprite.modulate = pulsed_color

func reset_bullet_hell_invulnerability_visual() -> void:
	if bullet_hell_invulnerable:
		return

	for sprite in flash_sprites:
		if not is_instance_valid(sprite):
			continue
		var original_modulate: Color = flash_original_modulates.get(sprite, Color.WHITE)
		sprite.modulate = original_modulate

func fire_spread_shot(projectile_count: int, angle_step: float) -> void:
	var base_direction = get_direction_to_player()
	if projectile_count <= 1:
		spawn_attack_bullet(bullet_scene, base_direction, bullet_speed)
		return

	var half_count = float(projectile_count - 1) * 0.5
	for i in range(projectile_count):
		var offset_index = float(i) - half_count
		var angle_offset = deg_to_rad(offset_index * angle_step)
		spawn_attack_bullet(
			bullet_scene,
			base_direction.rotated(angle_offset),
			bullet_speed
		)

func spawn_attack_bullet(scene: PackedScene, direction: Vector2, projectile_speed: float) -> Node:
	if scene == null or get_parent() == null:
		return null

	var projectile = scene.instantiate()
	get_parent().add_child(projectile)

	if projectile is Node2D:
		var projectile_node := projectile as Node2D
		projectile_node.global_position = global_position
		projectile_node.rotation = direction.angle()

	if "direction" in projectile:
		projectile.direction = direction
	if "speed" in projectile:
		projectile.speed = projectile_speed

	return projectile

func get_direction_to_player() -> Vector2:
	if is_instance_valid(target_player):
		var direction = (target_player.global_position - global_position).normalized()
		if direction != Vector2.ZERO:
			return direction

	return Vector2.LEFT
