extends CanvasLayer

signal retry_requested
signal main_menu_requested

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Center/Panel/Margin/VBox/TitleLabel
@onready var subtitle_label: Label = $Root/Center/Panel/Margin/VBox/SubtitleLabel
@onready var retry_button: Button = $Root/Center/Panel/Margin/VBox/ButtonRow/RetryButton
@onready var menu_button: Button = $Root/Center/Panel/Margin/VBox/ButtonRow/MenuButton

var default_title_text: String
var default_subtitle_text: String

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	default_title_text = title_label.text
	default_subtitle_text = subtitle_label.text
	hide_overlay()
	retry_button.pressed.connect(_on_retry_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

func show_overlay(title_text: String = "", subtitle_text: String = "") -> void:
	visible = true
	title_label.text = title_text if not title_text.is_empty() else default_title_text
	subtitle_label.text = subtitle_text if not subtitle_text.is_empty() else default_subtitle_text
	root.visible = true
	retry_button.grab_focus()

func hide_overlay() -> void:
	root.visible = false
	visible = false

func _on_retry_button_pressed() -> void:
	retry_requested.emit()

func _on_menu_button_pressed() -> void:
	main_menu_requested.emit()
