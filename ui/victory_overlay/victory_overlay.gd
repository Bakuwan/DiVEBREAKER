extends CanvasLayer

signal retry_requested
signal main_menu_requested

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Center/Panel/Margin/VBox/TitleLabel
@onready var subtitle_label: Label = $Root/Center/Panel/Margin/VBox/SubtitleLabel
@onready var enemy_killed_value: Label = $Root/Center/Panel/Margin/VBox/StatsColumn/EnemyKilledRow/ValueLabel
@onready var lootbox_value: Label = $Root/Center/Panel/Margin/VBox/StatsColumn/LootboxRow/ValueLabel
@onready var healing_value: Label = $Root/Center/Panel/Margin/VBox/StatsColumn/HealingRow/ValueLabel
@onready var retry_button: Button = $Root/Center/Panel/Margin/VBox/ButtonRow/RetryButton
@onready var menu_button: Button = $Root/Center/Panel/Margin/VBox/ButtonRow/MenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide_overlay()
	retry_button.pressed.connect(_on_retry_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

func show_overlay(run_stats: Dictionary, title_text: String = "GAME CLEARED", subtitle_text: String = "congratulations") -> void:
	visible = true
	title_label.text = title_text
	subtitle_label.text = subtitle_text
	enemy_killed_value.text = str(run_stats.get("enemy_killed", 0))
	lootbox_value.text = str(run_stats.get("lootbox_picked", 0))
	healing_value.text = str(run_stats.get("healing_picked", 0))
	root.visible = true
	retry_button.grab_focus()

func hide_overlay() -> void:
	root.visible = false
	visible = false

func _on_retry_button_pressed() -> void:
	retry_requested.emit()

func _on_menu_button_pressed() -> void:
	main_menu_requested.emit()
