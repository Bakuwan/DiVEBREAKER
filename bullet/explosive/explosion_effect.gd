extends Node2D

@export var max_radius: float = 42.0
@export var color: Color = Color(1.0, 0.65, 0.2, 0.85)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if animated_sprite == null:
		queue_free()
		return

	animated_sprite.modulate = color
	apply_scale_from_radius()

	var animation_name := animated_sprite.animation
	if animation_name == StringName():
		animation_name = &"default"

	var sprite_frames := animated_sprite.sprite_frames
	if sprite_frames != null and sprite_frames.has_animation(animation_name):
		sprite_frames.set_animation_loop(animation_name, false)

	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

	animated_sprite.play(animation_name)

func apply_scale_from_radius() -> void:
	if animated_sprite == null:
		return

	var sprite_frames := animated_sprite.sprite_frames
	if sprite_frames == null:
		return

	var animation_name := animated_sprite.animation
	if animation_name == StringName():
		animation_name = &"default"

	if not sprite_frames.has_animation(animation_name):
		return

	if sprite_frames.get_frame_count(animation_name) <= 0:
		return

	var first_frame_texture = sprite_frames.get_frame_texture(animation_name, 0)
	if first_frame_texture == null:
		return

	var texture_size = first_frame_texture.get_size()
	var largest_dimension = max(texture_size.x, texture_size.y)
	if largest_dimension <= 0.0:
		return

	var desired_diameter = max_radius * 2.0
	var scale_factor = desired_diameter / largest_dimension
	animated_sprite.scale = Vector2.ONE * scale_factor

func _on_animation_finished() -> void:
	if is_inside_tree():
		queue_free()
