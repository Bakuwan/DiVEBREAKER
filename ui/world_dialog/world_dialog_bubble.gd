extends Node2D

@export var follow_offset: Vector2 = Vector2(0.0, -48.0)

var target_node: Node2D

@onready var bubble_panel: PanelContainer = $BubblePanel
@onready var text_label: Label = $BubblePanel/Margin/Label

func _process(_delta: float) -> void:
	if is_instance_valid(target_node):
		global_position = target_node.global_position + follow_offset

	if bubble_panel != null:
		bubble_panel.position = Vector2(-bubble_panel.size.x * 0.5, -bubble_panel.size.y)

func setup(dialog_text: String, follow_target: Node2D, offset: Vector2 = Vector2(0.0, -48.0)) -> void:
	target_node = follow_target
	follow_offset = offset
	text_label.text = dialog_text
	if is_instance_valid(target_node):
		global_position = target_node.global_position + follow_offset
