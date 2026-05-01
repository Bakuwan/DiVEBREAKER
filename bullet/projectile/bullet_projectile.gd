extends Area2D

@export var speed: float = 500.0 
@export var damage: float = 1.5
@export var viewport_margin: float = 32.0
var direction: Vector2 = Vector2.RIGHT # Default nembak lurus ke kanan

func _process(delta):
	position += direction * speed * delta
	
	if is_outside_visible_viewport():
		queue_free()

func _on_area_entered(area):
	if area.is_in_group("enemy"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		
		queue_free()

func is_outside_visible_viewport() -> bool:
	var screen_position = get_global_transform_with_canvas().origin
	var visible_rect = get_viewport_rect().grow(viewport_margin)
	return not visible_rect.has_point(screen_position)
