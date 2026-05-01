extends BaseEnemy
class_name EnemyKamikaze

@export_category("Kamikaze")
@export var damage: float = 20.0

@onready var target_player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	
func move(delta: float) -> void:
	if is_instance_valid(target_player):
		look_at(target_player.global_position)
		var direction = (target_player.global_position - global_position).normalized()
		position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
