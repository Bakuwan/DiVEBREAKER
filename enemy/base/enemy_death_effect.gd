extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if animated_sprite == null:
		queue_free()
		return

	var animation_name := animated_sprite.animation
	if animation_name == StringName():
		animation_name = &"default"

	var sprite_frames := animated_sprite.sprite_frames
	if sprite_frames != null and sprite_frames.has_animation(animation_name):
		sprite_frames.set_animation_loop(animation_name, false)

	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

	animated_sprite.play(animation_name)

func _on_animation_finished() -> void:
	queue_free()
