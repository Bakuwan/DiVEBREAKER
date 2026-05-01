extends Node2D

@export var speed = 1500.0 # Sekarang lo bisa set gila-gilaan kencengnya!
@export var damage: float = 1.0
@export var viewport_margin: float = 32.0
@onready var raycast = $RayCast2D

func _process(delta):
	var step_distance = speed * delta
	
	raycast.target_position = Vector2(step_distance, 0)
	
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var target = raycast.get_collider() # Ambil node yang ketabrak
		
		# Kalau yang ketabrak beneran musuh
		if target.is_in_group("enemy"):
			if target.has_method("take_damage"):
				target.take_damage(damage)
			
		queue_free() 
	
	position += Vector2.RIGHT.rotated(rotation) * step_distance
	
	if is_outside_visible_viewport():
		queue_free()

func is_outside_visible_viewport() -> bool:
	var screen_position = get_global_transform_with_canvas().origin
	var visible_rect = get_viewport_rect().grow(viewport_margin)
	return not visible_rect.has_point(screen_position)
