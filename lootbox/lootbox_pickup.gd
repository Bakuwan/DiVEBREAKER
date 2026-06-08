extends Area2D

@export var lifetime: float = 5.0
@export var move_speed: float = 120.0
@export var pickup_sound: AudioStream = preload("res://assets/audio/gacha_sound.wav")
@export var pickup_sound_volume_db: float = -4.0

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

	play_pickup_sound()
	queue_free()

func _on_lifetime_timeout() -> void:
	if is_queued_for_deletion():
		return

	queue_free()

func play_pickup_sound() -> void:
	if pickup_sound == null:
		return

	var playback_parent: Node = get_parent()
	if playback_parent == null:
		playback_parent = get_tree().current_scene

	if playback_parent == null:
		return

	var audio_player := AudioStreamPlayer2D.new()
	audio_player.stream = pickup_sound
	audio_player.volume_db = pickup_sound_volume_db
	audio_player.finished.connect(audio_player.queue_free)

	playback_parent.add_child(audio_player)
	audio_player.global_position = global_position
	audio_player.play()
