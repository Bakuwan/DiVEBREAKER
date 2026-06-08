extends Node2D

signal stage_completed

@export var stage_data: EnemySpawnStageData
@export var auto_start: bool = true

var stage_running := false
var stage_cancelled := false
var current_wave_id: int = 0
var active_enemy_ids_by_wave: Dictionary = {}

func _ready():
	if auto_start:
		call_deferred("run_stage")

func run_stage() -> void:
	if stage_running:
		return

	stage_running = true
	stage_cancelled = false

	if stage_data == null:
		stage_running = false
		return

	for wave in stage_data.waves:
		if should_stop_stage():
			break
		await execute_wave(wave)

	stage_running = false
	if not stage_cancelled and is_inside_tree():
		stage_completed.emit()

func stop_stage() -> void:
	stage_cancelled = true
	stage_running = false
	active_enemy_ids_by_wave.clear()

func execute_wave(wave: EnemySpawnWaveData) -> void:
	if wave == null or should_stop_stage():
		return

	if wave.start_delay > 0.0:
		await wait_seconds(wave.start_delay)
		if should_stop_stage():
			return

	if wave.enemy_scene == null:
		return

	var active_slots = get_sorted_enabled_slots(wave)
	if active_slots.is_empty():
		return

	current_wave_id += 1
	var wave_id = current_wave_id
	active_enemy_ids_by_wave[wave_id] = {}

	var last_spawn_delay := 0.0
	for slot in active_slots:
		if should_stop_stage():
			return

		var wait_time = slot.spawn_delay_from_wave_start - last_spawn_delay
		if wait_time > 0.0:
			await wait_seconds(wait_time)
			if should_stop_stage():
				return

		spawn_enemy_for_slot(wave_id, wave.enemy_scene, slot)
		last_spawn_delay = slot.spawn_delay_from_wave_start

	await wait_for_wave_clear(wave_id, wave.clear_timeout)
	active_enemy_ids_by_wave.erase(wave_id)

func get_sorted_enabled_slots(wave: EnemySpawnWaveData) -> Array[EnemySpawnSlotData]:
	var enabled_slots: Array[EnemySpawnSlotData] = []

	for slot in wave.slots:
		if slot != null and slot.enabled:
			enabled_slots.append(slot)

	enabled_slots.sort_custom(_sort_slots_by_delay)
	return enabled_slots

func spawn_enemy_for_slot(wave_id: int, enemy_scene: PackedScene, slot: EnemySpawnSlotData) -> void:
	if should_stop_stage():
		return

	var enemy = enemy_scene.instantiate()
	add_child(enemy)

	if enemy is Node2D:
		var enemy_node := enemy as Node2D
		enemy_node.global_position = slot.spawn_position
		enemy_node.rotation = deg_to_rad(slot.spawn_rotation_degrees)

		if enemy_node is BaseEnemy:
			var base_enemy := enemy_node as BaseEnemy
			base_enemy.set_spawn_transform(slot.spawn_position)

	var enemy_id = enemy.get_instance_id()
	active_enemy_ids_by_wave[wave_id][enemy_id] = true
	enemy.tree_exited.connect(_on_wave_enemy_exited.bind(wave_id, enemy_id))

func wait_for_wave_clear(wave_id: int, clear_timeout: float) -> void:
	var elapsed := 0.0

	while true:
		if should_stop_stage():
			return

		var active_enemy_ids: Dictionary = active_enemy_ids_by_wave.get(wave_id, {})
		if active_enemy_ids.is_empty():
			return

		if clear_timeout > 0.0 and elapsed >= clear_timeout:
			return

		await get_tree().process_frame
		elapsed += get_process_delta_time()

func wait_seconds(duration: float) -> void:
	var tree = get_tree()
	if tree == null:
		return

	await tree.create_timer(duration, false).timeout

func should_stop_stage() -> bool:
	return stage_cancelled or not stage_running or not is_inside_tree() or get_tree() == null

func _on_wave_enemy_exited(wave_id: int, enemy_id: int) -> void:
	if not active_enemy_ids_by_wave.has(wave_id):
		return

	active_enemy_ids_by_wave[wave_id].erase(enemy_id)

func _sort_slots_by_delay(a: EnemySpawnSlotData, b: EnemySpawnSlotData) -> bool:
	return a.spawn_delay_from_wave_start < b.spawn_delay_from_wave_start
