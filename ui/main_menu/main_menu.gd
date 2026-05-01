extends Control

const GAME_SCENE_PATH := "res://level/main/main.tscn"

@export var background_scroll_speed: Vector2 = Vector2(-120.0, 0.0)

@onready var background: Parallax2D = $Parallax2D
@onready var title_label: Label = $MenuRoot/Content/TitleBlock/TitleLabel
@onready var start_button: Button = $MenuRoot/Content/ButtonPanel/ButtonMargin/ButtonColumn/StartButton
@onready var quit_button: Button = $MenuRoot/Content/ButtonPanel/ButtonMargin/ButtonColumn/QuitButton

func _ready() -> void:
	get_tree().paused = false
	background.autoscroll = background_scroll_speed
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	start_button.grab_focus()

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
