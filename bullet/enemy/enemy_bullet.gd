extends Area2D

var speed: float = 300.0 
var direction: Vector2 = Vector2.LEFT # Default meluncur ke kiri
@export var damage: float = 8.0
@export var viewport_margin: float = 32.0

func _process(delta):
	position += direction * speed * delta
	
	if is_outside_visible_viewport():
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free() 

func is_outside_visible_viewport() -> bool:
	var screen_position = get_global_transform_with_canvas().origin
	var visible_rect = get_viewport_rect().grow(viewport_margin)
	return not visible_rect.has_point(screen_position)
