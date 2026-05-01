extends Area2D

@export var speed: float = 1000.0
@export var damage: float = 2.0
@export var max_hits: int = 3
@export var viewport_margin: float = 32.0

var direction: Vector2 = Vector2.RIGHT
var remaining_hits: int
var hit_target_ids: Array[int] = []

func _ready() -> void:
	remaining_hits = max_hits

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position += direction * speed * delta

	if is_outside_visible_viewport():
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy"):
		return

	var target_id = area.get_instance_id()
	if hit_target_ids.has(target_id):
		return

	hit_target_ids.append(target_id)

	if area.has_method("take_damage"):
		area.take_damage(damage)

	remaining_hits -= 1
	if remaining_hits <= 0:
		queue_free()

func is_outside_visible_viewport() -> bool:
	var screen_position = get_global_transform_with_canvas().origin
	var visible_rect = get_viewport_rect().grow(viewport_margin)
	return not visible_rect.has_point(screen_position)
