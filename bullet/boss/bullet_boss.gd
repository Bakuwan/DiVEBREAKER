extends Area2D

@export var speed: float = 240.0
@export var damage: float = 14.0
@export var viewport_margin: float = 32.0

var direction: Vector2 = Vector2.LEFT

@onready var sprite: Sprite2D = $Sprite2D


func _process(delta: float) -> void:
	position += direction * speed * delta
	rotation = direction.angle()

	if sprite != null:
		sprite.rotation += TAU * delta

	if is_outside_visible_viewport():
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()

func is_outside_visible_viewport() -> bool:
	var screen_position = get_global_transform_with_canvas().origin
	var visible_rect = get_viewport_rect().grow(viewport_margin)
	return not visible_rect.has_point(screen_position)
