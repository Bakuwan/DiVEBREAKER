extends Node2D

enum StageState {
	NORMAL,
	PRE_BOSS,
	BOSS_INTRO,
	BOSS_FIGHT,
	BOSS_CLEAR
}

const NORMAL_PARALLAX_SCROLL := Vector2(-400.0, 0.0)
const BOSS_PARALLAX_SCROLL := Vector2(-300.0, 0.0)
const MAIN_MENU_SCENE_PATH := "res://ui/main_menu/main_menu.tscn"
const DAMAGE_EDGE_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float flash_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.5) = 0.18;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.16;

void fragment() {
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge_mask = 1.0 - smoothstep(edge_width, edge_width + edge_softness, edge_distance);
	COLOR = vec4(flash_color.rgb, flash_color.a * flash_alpha * edge_mask);
}
"""

@export var boss_scene: PackedScene = preload("res://enemy/boss/boss.tscn")
@export var dialog_bubble_scene: PackedScene = preload("res://ui/world_dialog/world_dialog_bubble.tscn")
@export var boss_lootbox_scene: PackedScene = preload("res://lootbox/lootbox_pickup.tscn")
@export var boss_healing_scene: PackedScene = preload("res://healing/healing_pickup.tscn")
@export_category("Audio")
@export var stage_bgm: AudioStream
@export var boss_bgm: AudioStream
@export var bgm_fade_duration: float = 0.6
@export var bgm_volume_db: float = -6.0
@export var warning_sound: AudioStream = preload("res://assets/audio/warning.wav")
@export var warning_sound_volume_db: float = -3.0
@export var pre_boss_delay: float = 0.5
@export var warning_duration: float = 0.5
@export var boss_clear_duration: float = 1.0
@export var player_intro_start_offset: Vector2 = Vector2(-180.0, 0.0)
@export var boss_dialog_line_duration: float = 1.5
@export var boss_dialog_line_gap: float = 0.15
@export var player_dialog_offset: Vector2 = Vector2(0.0, -42.0)
@export var boss_dialog_offset: Vector2 = Vector2(0.0, -68.0)
@export var boss_lootbox_spawn_interval: float = 9.0
@export var boss_healing_spawn_interval: float = 13.0
@export var boss_pickup_spawn_margin: float = 48.0
@export var boss_pickup_spawn_y_padding: float = 24.0
@export_category("Damage Feedback")
@export var damage_shake_strength: float = 3.0
@export var damage_shake_duration: float = 0.12
@export var damage_overlay_color: Color = Color(1.0, 0.0, 0.0, 1.0)
@export var damage_overlay_alpha: float = 0.42
@export var damage_overlay_fade_duration: float = 0.22
@export var damage_overlay_edge_width: float = 0.16
@export var damage_overlay_edge_softness: float = 0.18
@export var boss_intro_dialog_lines: Array[String] = [
	"So you made it this far.",
	"Let's see if your dive still holds."
]
@export var player_intro_dialog_lines: Array[String] = [
	"Still talking, huh?",
	"Then let's end this in the air."
]

var stage_state: StageState = StageState.NORMAL
var active_boss: BossMain
var parallax_tween: Tween
var game_over := false
var enemy_killed_count := 0
var lootbox_picked_count := 0
var healing_picked_count := 0
var damage_feedback_camera: Camera2D
var damage_shake_tween: Tween
var damage_overlay_tween: Tween
var damage_overlay_material: ShaderMaterial

@onready var parallax_background: Parallax2D = $Parallax2D
@onready var player: PlayerShip = $Player
@onready var ui_layer: CanvasLayer = $CanvasLayer
@onready var enemy_spawner: Node2D = $EnemySpawner
@onready var boss_spawn_point: Marker2D = $BossSpawnPoint
@onready var boss_anchor_point: Marker2D = $BossAnchorPoint
@onready var boss_warning_label: Label = $CanvasLayer/HBoxContainer/VBoxContainer/BossWarning
@onready var boss_warning_animation_player: AnimationPlayer = $CanvasLayer/HBoxContainer/VBoxContainer/BossWarning/AnimationPlayer
@onready var boss_health_bar: ProgressBar = $CanvasLayer/BossHealthBar
@onready var lose_overlay: CanvasLayer = $LoseOverlay
@onready var victory_overlay: CanvasLayer = $VictoryOverlay
@onready var stage_bgm_player: AudioStreamPlayer = $StageBgmPlayer
@onready var boss_bgm_player: AudioStreamPlayer = $BossBgmPlayer

func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	game_over = false
	enemy_killed_count = 0
	lootbox_picked_count = 0
	healing_picked_count = 0
	boss_warning_label.visible = false
	boss_health_bar.visible = false
	boss_health_bar.min_value = 0.0
	boss_health_bar.value = 0.0
	parallax_background.autoscroll = NORMAL_PARALLAX_SCROLL
	setup_damage_feedback()
	player.player_died.connect(_on_player_died)
	player.player_damaged.connect(_on_player_damaged)
	lose_overlay.retry_requested.connect(_on_retry_requested)
	lose_overlay.main_menu_requested.connect(_on_main_menu_requested)
	victory_overlay.retry_requested.connect(_on_retry_requested)
	victory_overlay.main_menu_requested.connect(_on_main_menu_requested)
	lose_overlay.hide_overlay()
	victory_overlay.hide_overlay()
	setup_bgm_players()
	play_stage_bgm(true)
	player.set_movement_locked(true)
	player.set_shooting_locked(true)

	call_deferred("start_stage_flow")

func start_stage_flow() -> void:
	await run_player_intro_sequence()
	if enemy_spawner != null:
		enemy_spawner.run_stage()
	call_deferred("start_boss_stage_flow")

func start_boss_stage_flow() -> void:
	if enemy_spawner != null and enemy_spawner.has_signal("stage_completed"):
		await enemy_spawner.stage_completed
	else:
		await wait_for_spawner_completion()

	if game_over or not is_inside_tree():
		return

	while not game_over and is_inside_tree() and has_remaining_enemies():
		await get_tree().process_frame

	if game_over or not is_inside_tree():
		return

	await start_pre_boss_transition()

func wait_for_spawner_completion() -> void:
	while not game_over and is_inside_tree() and enemy_spawner != null and bool(enemy_spawner.get("stage_running")):
		await get_tree().process_frame

func has_remaining_enemies() -> bool:
	if game_over or not is_inside_tree():
		return false

	var tree = get_tree()
	if tree == null:
		return false

	for enemy in tree.get_nodes_in_group("enemy"):
		if enemy is BossMain:
			continue
		return true

	return false

func stop_enemy_spawner() -> void:
	if enemy_spawner != null and enemy_spawner.has_method("stop_stage"):
		enemy_spawner.stop_stage()

func start_pre_boss_transition() -> void:
	stage_state = StageState.PRE_BOSS

	if pre_boss_delay > 0.0:
		await get_tree().create_timer(pre_boss_delay, false).timeout

	player.set_shooting_locked(true)
	tween_parallax_scroll(BOSS_PARALLAX_SCROLL, 0.5)
	show_boss_warning("WARNING")
	play_warning_sound()
	await get_tree().create_timer(warning_duration, false).timeout
	spawn_boss()

func spawn_boss() -> void:
	if boss_scene == null:
		return

	stage_state = StageState.BOSS_INTRO
	active_boss = boss_scene.instantiate() as BossMain
	if active_boss == null:
		return

	add_child(active_boss)
	active_boss.global_position = boss_spawn_point.global_position
	active_boss.set_spawn_transform(boss_spawn_point.global_position)
	active_boss.start_intro(boss_anchor_point.global_position)
	active_boss.boss_intro_finished.connect(_on_boss_intro_finished)
	active_boss.boss_started.connect(_on_boss_started)
	active_boss.boss_health_changed.connect(_on_boss_health_changed)
	active_boss.boss_defeat_started.connect(_on_boss_defeat_started)
	active_boss.boss_defeat_finished.connect(_on_boss_defeat_finished)

func show_boss_warning(text: String) -> void:
	boss_warning_label.text = text
	boss_warning_label.visible = true
	if boss_warning_animation_player != null and boss_warning_animation_player.has_animation("warning_blink"):
		boss_warning_animation_player.play("warning_blink")

func hide_boss_warning() -> void:
	if boss_warning_animation_player != null:
		boss_warning_animation_player.stop()
	boss_warning_label.visible = false

func tween_parallax_scroll(target_scroll: Vector2, duration: float) -> void:
	if parallax_tween != null and parallax_tween.is_running():
		parallax_tween.kill()

	parallax_tween = create_tween()
	parallax_tween.tween_property(parallax_background, "autoscroll", target_scroll, duration)

func setup_damage_feedback() -> void:
	damage_feedback_camera = Camera2D.new()
	damage_feedback_camera.name = "DamageFeedbackCamera"
	damage_feedback_camera.position = get_viewport_rect().size * 0.5
	add_child(damage_feedback_camera)
	damage_feedback_camera.make_current()

	var damage_overlay := ColorRect.new()
	damage_overlay.name = "DamageEdgeOverlay"
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_overlay.color = Color.WHITE
	damage_overlay.z_index = 100
	damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_overlay.offset_left = 0.0
	damage_overlay.offset_top = 0.0
	damage_overlay.offset_right = 0.0
	damage_overlay.offset_bottom = 0.0

	var shader := Shader.new()
	shader.code = DAMAGE_EDGE_SHADER_CODE
	damage_overlay_material = ShaderMaterial.new()
	damage_overlay_material.shader = shader
	damage_overlay_material.set_shader_parameter("flash_color", damage_overlay_color)
	damage_overlay_material.set_shader_parameter("flash_alpha", 0.0)
	damage_overlay_material.set_shader_parameter("edge_width", damage_overlay_edge_width)
	damage_overlay_material.set_shader_parameter("edge_softness", damage_overlay_edge_softness)
	damage_overlay.material = damage_overlay_material

	ui_layer.add_child(damage_overlay)

func play_damage_camera_shake() -> void:
	if damage_feedback_camera == null or damage_shake_strength <= 0.0 or damage_shake_duration <= 0.0:
		return

	if damage_shake_tween != null and damage_shake_tween.is_running():
		damage_shake_tween.kill()

	damage_shake_tween = create_tween()
	damage_shake_tween.tween_method(
		Callable(self, "set_damage_camera_shake"),
		damage_shake_strength,
		0.0,
		damage_shake_duration
	)
	damage_shake_tween.tween_callback(Callable(self, "reset_damage_camera_shake"))

func set_damage_camera_shake(strength: float) -> void:
	if damage_feedback_camera == null:
		return

	damage_feedback_camera.offset = Vector2(
		randf_range(-strength, strength),
		randf_range(-strength, strength)
	)

func reset_damage_camera_shake() -> void:
	if damage_feedback_camera != null:
		damage_feedback_camera.offset = Vector2.ZERO

func play_damage_overlay_flash() -> void:
	if damage_overlay_material == null or damage_overlay_alpha <= 0.0:
		return

	if damage_overlay_tween != null and damage_overlay_tween.is_running():
		damage_overlay_tween.kill()

	damage_overlay_material.set_shader_parameter("flash_color", damage_overlay_color)
	damage_overlay_material.set_shader_parameter("edge_width", damage_overlay_edge_width)
	damage_overlay_material.set_shader_parameter("edge_softness", damage_overlay_edge_softness)
	damage_overlay_material.set_shader_parameter("flash_alpha", damage_overlay_alpha)

	damage_overlay_tween = create_tween()
	damage_overlay_tween.tween_property(
		damage_overlay_material,
		"shader_parameter/flash_alpha",
		0.0,
		damage_overlay_fade_duration
	)

func _on_boss_started(max_hp: float, boss_name: String) -> void:
	stage_state = StageState.BOSS_FIGHT
	hide_boss_warning()
	tween_parallax_scroll(BOSS_PARALLAX_SCROLL, 1)
	play_boss_bgm()
	boss_health_bar.max_value = max_hp
	boss_health_bar.value = max_hp
	boss_health_bar.visible = true
	boss_warning_label.text = boss_name
	player.set_movement_locked(false)
	player.set_shooting_locked(false)
	call_deferred("run_boss_pickup_spawn_loop", boss_lootbox_scene, boss_lootbox_spawn_interval)
	call_deferred("run_boss_pickup_spawn_loop", boss_healing_scene, boss_healing_spawn_interval)

func _on_boss_health_changed(current_hp: float, max_hp: float) -> void:
	boss_health_bar.max_value = max_hp
	boss_health_bar.value = current_hp

func _on_boss_defeat_started() -> void:
	if game_over:
		return

	stage_state = StageState.BOSS_CLEAR
	stop_all_bgm()
	boss_health_bar.visible = false
	show_boss_warning("MISSION CLEAR")
	player.set_movement_locked(true)
	player.set_shooting_locked(true)
	tween_parallax_scroll(NORMAL_PARALLAX_SCROLL, 1.0)
	call_deferred("play_boss_defeat_dialog_sequence")

func _on_boss_defeat_finished() -> void:
	if game_over:
		return

	active_boss = null
	call_deferred("show_victory_overlay")

func _on_player_died() -> void:
	if game_over:
		return

	game_over = true
	stage_state = StageState.BOSS_CLEAR
	stop_enemy_spawner()
	stop_all_bgm()
	boss_health_bar.visible = false
	hide_boss_warning()
	lose_overlay.show_overlay()
	get_tree().paused = true

func _on_player_damaged(_amount: float) -> void:
	if game_over:
		return

	play_damage_camera_shake()
	play_damage_overlay_flash()

func _on_retry_requested() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	stop_enemy_spawner()
	stop_all_bgm()
	get_tree().reload_current_scene()

func _on_main_menu_requested() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	stop_enemy_spawner()
	stop_all_bgm()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_boss_intro_finished() -> void:
	if game_over:
		return

	call_deferred("start_boss_dialog_sequence")

func run_player_intro_sequence() -> void:
	var target_position = player.global_position
	player.start_scene_entry(target_position + player_intro_start_offset, target_position)
	await player.intro_finished

func start_boss_dialog_sequence() -> void:
	player.set_movement_locked(true)
	player.set_shooting_locked(true)
	hide_boss_warning()
	await play_boss_intro_dialog_sequence()
	if is_instance_valid(active_boss):
		active_boss.begin_combat()

func play_boss_intro_dialog_sequence() -> void:
	var line_count = maxi(boss_intro_dialog_lines.size(), player_intro_dialog_lines.size())
	for line_index in range(line_count):
		if line_index < boss_intro_dialog_lines.size():
			await show_world_dialog(active_boss, boss_intro_dialog_lines[line_index], boss_dialog_offset)

		if line_index < player_intro_dialog_lines.size():
			await show_world_dialog(player, player_intro_dialog_lines[line_index], player_dialog_offset)

func play_boss_defeat_dialog_sequence() -> void:
	if not is_instance_valid(active_boss):
		return

	var dialog_delay = active_boss.defeat_slowmo_duration + minf(active_boss.defeat_explosion_interval * 2.0, 0.35)
	if dialog_delay > 0.0:
		await get_tree().create_timer(dialog_delay, false).timeout

	if not is_instance_valid(active_boss):
		return

	for dialog_text in active_boss.defeat_dialog_lines:
		await show_world_dialog(
			active_boss,
			dialog_text,
			boss_dialog_offset,
			active_boss.defeat_dialog_line_duration,
			0.0
		)

func show_world_dialog(
	target_node: Node2D,
	dialog_text: String,
	dialog_offset: Vector2,
	line_duration: float = boss_dialog_line_duration,
	line_gap: float = boss_dialog_line_gap
) -> void:
	if dialog_bubble_scene == null or dialog_text.is_empty() or not is_instance_valid(target_node):
		return

	var dialog_bubble = dialog_bubble_scene.instantiate()
	add_child(dialog_bubble)
	dialog_bubble.setup(dialog_text, target_node, dialog_offset)

	if line_duration > 0.0:
		await get_tree().create_timer(line_duration, false).timeout

	if is_instance_valid(dialog_bubble):
		dialog_bubble.queue_free()

	if line_gap > 0.0:
		await get_tree().create_timer(line_gap, false).timeout

func run_boss_pickup_spawn_loop(pickup_scene: PackedScene, spawn_interval: float) -> void:
	if pickup_scene == null or spawn_interval <= 0.0:
		return

	while stage_state == StageState.BOSS_FIGHT and not game_over and is_instance_valid(active_boss):
		await get_tree().create_timer(spawn_interval, false).timeout

		if stage_state != StageState.BOSS_FIGHT or game_over or not is_instance_valid(active_boss):
			return

		spawn_boss_pickup(pickup_scene)

func spawn_boss_pickup(pickup_scene: PackedScene) -> void:
	if pickup_scene == null:
		return

	var pickup = pickup_scene.instantiate()
	add_child(pickup)

	if pickup is Node2D:
		var pickup_node := pickup as Node2D
		var visible_rect = get_viewport_rect()
		var spawn_x = visible_rect.end.x + boss_pickup_spawn_margin
		var min_y = visible_rect.position.y + boss_pickup_spawn_y_padding
		var max_y = visible_rect.end.y - boss_pickup_spawn_y_padding
		if max_y < min_y:
			max_y = min_y

		pickup_node.global_position = Vector2(
			spawn_x,
			randf_range(min_y, max_y)
		)

func register_enemy_killed() -> void:
	enemy_killed_count += 1

func register_lootbox_picked() -> void:
	lootbox_picked_count += 1

func register_healing_picked() -> void:
	healing_picked_count += 1

func show_victory_overlay() -> void:
	hide_boss_warning()
	stop_all_bgm()
	var run_stats = {
		"enemy_killed": enemy_killed_count,
		"lootbox_picked": lootbox_picked_count,
		"healing_picked": healing_picked_count,
	}
	victory_overlay.show_overlay(run_stats, "GAME CLEARED", "congratulations")
	get_tree().paused = true

func setup_bgm_players() -> void:
	if stage_bgm_player != null:
		stage_bgm_player.stream = stage_bgm
		stage_bgm_player.volume_db = bgm_volume_db

	if boss_bgm_player != null:
		boss_bgm_player.stream = boss_bgm
		boss_bgm_player.volume_db = bgm_volume_db

func play_stage_bgm(immediate: bool = false) -> void:
	if stage_bgm_player == null or stage_bgm_player.stream == null:
		return

	crossfade_bgm(stage_bgm_player, boss_bgm_player, immediate)

func play_boss_bgm(immediate: bool = false) -> void:
	if boss_bgm_player == null or boss_bgm_player.stream == null:
		return

	crossfade_bgm(boss_bgm_player, stage_bgm_player, immediate)

func play_warning_sound() -> void:
	if warning_sound == null:
		return

	var audio_player := AudioStreamPlayer.new()
	audio_player.stream = warning_sound
	audio_player.volume_db = warning_sound_volume_db
	audio_player.finished.connect(audio_player.queue_free)
	add_child(audio_player)
	audio_player.play()

func crossfade_bgm(next_player: AudioStreamPlayer, previous_player: AudioStreamPlayer, immediate: bool = false) -> void:
	if next_player == null:
		return

	var fade_duration = 0.0 if immediate else bgm_fade_duration
	if previous_player != null and previous_player == next_player:
		return

	if previous_player != null and previous_player.playing and fade_duration <= 0.0:
		previous_player.stop()

	if not next_player.playing:
		next_player.volume_db = bgm_volume_db if fade_duration <= 0.0 else -60.0
		next_player.play()

	if fade_duration <= 0.0:
		next_player.volume_db = bgm_volume_db
		return

	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(next_player, "volume_db", bgm_volume_db, fade_duration)

	if previous_player != null and previous_player.playing:
		fade_tween.tween_property(previous_player, "volume_db", -60.0, fade_duration)
		fade_tween.chain().tween_callback(previous_player.stop)
		fade_tween.chain().tween_callback(func() -> void:
			previous_player.volume_db = bgm_volume_db
		)

func stop_all_bgm() -> void:
	if stage_bgm_player != null:
		stage_bgm_player.stop()
		stage_bgm_player.volume_db = bgm_volume_db

	if boss_bgm_player != null:
		boss_bgm_player.stop()
		boss_bgm_player.volume_db = bgm_volume_db
