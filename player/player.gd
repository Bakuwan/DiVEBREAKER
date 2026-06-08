extends CharacterBody2D
class_name PlayerShip

@export var speed = 400.0

@export var max_health: float = 100.0
@export var hit_flash_duration: float = 0.08
@export var hit_flash_hold_duration: float = 0.05
@export var hit_flash_color: Color = Color.WHITE
@export var death_effect_scene: PackedScene
@export var death_effect_fallback_duration: float = 0.8
@export var hide_player_visuals_on_death: bool = true
@export_category("Audio")
@export var hurt_sound: AudioStream = preload("res://assets/audio/hurt_sound.wav")
@export var hurt_sound_volume_db: float = -4.0
@export var death_sound: AudioStream = preload("res://assets/audio/death_sound.wav")
@export var death_sound_volume_db: float = -2.0
var current_health: float

signal health_changed(new_health: float, max_health: float)
signal player_died
signal player_damaged(amount: float)
signal weapon_changed(new_weapon: WeaponData)
signal intro_finished

const HIT_FLASH_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(tex.rgb, flash_color.rgb, flash_amount), tex.a);
}
"""

@export var starting_weapon: WeaponData = preload("res://weapons/gun_single_hitscan.tres")
@export var weapon_pool: Array[WeaponData]
@export var intro_entry_speed: float = 280.0
var current_weapon: WeaponData

var fire_timer = 0.0
var screen_size: Vector2
var flash_tween: Tween
var flash_sprites: Array[Sprite2D] = []
var flash_original_materials := {}
var flash_materials := {}
var hit_flash_shader: Shader
var is_dead := false
var movement_locked := false
var shooting_locked := false
var intro_active := false
var intro_target_position: Vector2 = Vector2.ZERO

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	current_health = max_health
	is_dead = false
	screen_size = get_viewport_rect().size
	cache_flash_sprites(self)
	set_current_weapon(starting_weapon)
	
	call_deferred("emit_signal", "health_changed", current_health, max_health)

func _physics_process(delta):
	if intro_active:
		update_intro_entry(delta)
		return

	handle_movement(delta)
	
	if current_weapon != null and not shooting_locked:
		fire_timer -= delta
		if fire_timer <= 0.0:
			shoot()
			fire_timer = current_weapon.fire_rate

func shoot():
	if current_weapon == null:
		return

	var p = current_weapon.pattern_scene.instantiate()
	get_parent().add_child(p)
	p.fire(current_weapon, global_position)

func pickup_lootbox() -> void:
	var next_weapon = roll_new_weapon()
	if next_weapon == null:
		return

	set_current_weapon(next_weapon, true)

func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func roll_new_weapon() -> WeaponData:
	var available_weapons: Array[WeaponData] = []

	for weapon in weapon_pool:
		if weapon != null and weapon != current_weapon:
			available_weapons.append(weapon)

	if available_weapons.is_empty():
		return null

	return available_weapons.pick_random()

func set_current_weapon(new_weapon: WeaponData, reset_cooldown: bool = false) -> void:
	current_weapon = new_weapon

	if reset_cooldown:
		fire_timer = 0.0

	weapon_changed.emit(current_weapon)

func handle_movement(_delta):
	if movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
	global_position.x = clamp(global_position.x, 0, screen_size.x)
	global_position.y = clamp(global_position.y, 0, screen_size.y)

func set_movement_locked(is_locked: bool) -> void:
	movement_locked = is_locked
	if is_locked:
		velocity = Vector2.ZERO

func set_shooting_locked(is_locked: bool) -> void:
	shooting_locked = is_locked

func start_scene_entry(start_position: Vector2, target_position: Vector2) -> void:
	global_position = start_position
	intro_target_position = target_position
	intro_active = true
	set_movement_locked(true)
	set_shooting_locked(true)
	velocity = Vector2.ZERO

func update_intro_entry(delta: float) -> void:
	global_position = global_position.move_toward(intro_target_position, intro_entry_speed * delta)
	if global_position.distance_to(intro_target_position) <= 2.0:
		global_position = intro_target_position
		intro_active = false
		set_movement_locked(false)
		set_shooting_locked(false)
		intro_finished.emit()

func take_damage(amount: float):
	if is_dead:
		return

	var previous_health := current_health
	current_health -= amount
	current_health = max(0, current_health)
	var damage_taken := previous_health - current_health
	if damage_taken > 0.0:
		play_hit_flash()
		play_one_shot_sound(hurt_sound, hurt_sound_volume_db)
		player_damaged.emit(damage_taken)

	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		die()

func die():
	if is_dead:
		return

	is_dead = true
	play_one_shot_sound(death_sound, death_sound_volume_db)
	intro_active = false
	set_movement_locked(true)
	set_shooting_locked(true)
	set_physics_process(false)
	velocity = Vector2.ZERO
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	if hide_player_visuals_on_death:
		set_player_visuals_visible(false)

	call_deferred("_run_death_sequence")

func _run_death_sequence() -> void:
	var death_effect = spawn_death_effect()
	var wait_duration = get_death_sequence_duration(death_effect)
	if wait_duration > 0.0:
		await get_tree().create_timer(wait_duration).timeout

	player_died.emit()

func spawn_death_effect() -> Node:
	if death_effect_scene == null or get_parent() == null:
		return null

	var death_effect = death_effect_scene.instantiate()
	get_parent().add_child(death_effect)

	if death_effect is Node2D:
		var death_effect_node := death_effect as Node2D
		death_effect_node.global_position = global_position
		death_effect_node.rotation = rotation

	configure_death_effect_animation(death_effect)

	return death_effect

func get_death_sequence_duration(death_effect: Node) -> float:
	if death_effect != null:
		if death_effect.has_method("get_duration"):
			var custom_duration = float(death_effect.get_duration())
			if custom_duration > 0.0:
				return custom_duration

		if "duration" in death_effect:
			var exported_duration = float(death_effect.duration)
			if exported_duration > 0.0:
				return exported_duration

		var animated_sprite = find_first_animated_sprite(death_effect)
		if animated_sprite != null:
			var animation_duration = get_animated_sprite_duration(animated_sprite)
			if animation_duration > 0.0:
				return animation_duration

	return death_effect_fallback_duration

func configure_death_effect_animation(death_effect: Node) -> void:
	var animated_sprite = find_first_animated_sprite(death_effect)
	if animated_sprite == null:
		return

	var animation_name: StringName = animated_sprite.animation
	if animation_name == StringName():
		animation_name = &"default"

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.sprite_frames.set_animation_loop(animation_name, false)

	animated_sprite.play(animation_name)

func find_first_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node as AnimatedSprite2D

	for child in node.get_children():
		var animated_sprite = find_first_animated_sprite(child)
		if animated_sprite != null:
			return animated_sprite

	return null

func get_animated_sprite_duration(animated_sprite: AnimatedSprite2D) -> float:
	if animated_sprite.sprite_frames == null:
		return 0.0

	var animation_name: StringName = animated_sprite.animation
	if animation_name == StringName():
		animation_name = &"default"

	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return 0.0

	var frame_count = animated_sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return 0.0

	var animation_speed = animated_sprite.sprite_frames.get_animation_speed(animation_name)
	if animation_speed <= 0.0:
		return 0.0

	var total_duration := 0.0
	for frame_index in range(frame_count):
		total_duration += animated_sprite.sprite_frames.get_frame_duration(animation_name, frame_index)

	return total_duration / animation_speed

func set_player_visuals_visible(is_visible: bool) -> void:
	for sprite in flash_sprites:
		if is_instance_valid(sprite):
			sprite.visible = is_visible

func cache_flash_sprites(node: Node) -> void:
	for child in node.get_children():
		if child is Sprite2D:
			var sprite := child as Sprite2D
			flash_sprites.append(sprite)

		cache_flash_sprites(child)

func play_hit_flash() -> void:
	if flash_sprites.is_empty():
		return

	if flash_tween != null and flash_tween.is_running():
		flash_tween.kill()
		restore_hit_flash_materials()

	flash_tween = create_tween()

	for sprite in flash_sprites:
		if not is_instance_valid(sprite):
			continue

		if not flash_original_materials.has(sprite):
			flash_original_materials[sprite] = sprite.material

		var flash_material = get_hit_flash_material(sprite)
		flash_material.set_shader_parameter("flash_color", hit_flash_color)
		flash_material.set_shader_parameter("flash_amount", 1.0)
		sprite.material = flash_material

		flash_tween.parallel() \
			.tween_property(flash_material, "shader_parameter/flash_amount", 0.0, hit_flash_duration) \
			.set_delay(hit_flash_hold_duration)

	flash_tween.chain().tween_callback(Callable(self, "restore_hit_flash_materials"))

func get_hit_flash_material(sprite: Sprite2D) -> ShaderMaterial:
	if flash_materials.has(sprite):
		return flash_materials[sprite] as ShaderMaterial

	var material := ShaderMaterial.new()
	material.shader = get_hit_flash_shader()
	material.set_shader_parameter("flash_color", hit_flash_color)
	material.set_shader_parameter("flash_amount", 0.0)
	flash_materials[sprite] = material
	return material

func get_hit_flash_shader() -> Shader:
	if hit_flash_shader == null:
		hit_flash_shader = Shader.new()
		hit_flash_shader.code = HIT_FLASH_SHADER_CODE

	return hit_flash_shader

func restore_hit_flash_materials() -> void:
	for sprite in flash_sprites:
		if not is_instance_valid(sprite):
			continue

		if flash_materials.has(sprite):
			var flash_material = flash_materials[sprite] as ShaderMaterial
			flash_material.set_shader_parameter("flash_amount", 0.0)

		if flash_original_materials.has(sprite):
			sprite.material = flash_original_materials[sprite]

func play_one_shot_sound(sound: AudioStream, volume_db: float) -> void:
	if sound == null:
		return

	var playback_parent: Node = get_parent()
	if playback_parent == null:
		playback_parent = get_tree().current_scene

	if playback_parent == null:
		return

	var audio_player := AudioStreamPlayer.new()
	audio_player.stream = sound
	audio_player.volume_db = volume_db
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_player.finished.connect(audio_player.queue_free)

	playback_parent.add_child(audio_player)
	audio_player.play()
