extends Area2D

@export var lifetime: float = 5.0
@export var move_speed: float = 120.0

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if lifetime > 0.0:
		var timer = get_tree().create_timer(lifetime)
		timer.timeout.connect(_on_lifetime_timeout)

func _process(delta: float) -> void:
	position.x -= move_speed * delta

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("pickup_lootbox"):
		body.pickup_lootbox()

	var current_scene = get_tree().current_scene
	if current_scene != null and current_scene.has_method("register_lootbox_picked"):
		current_scene.register_lootbox_picked()

	queue_free()

func _on_lifetime_timeout() -> void:
	if is_queued_for_deletion():
		return

	queue_free()
