extends Resource
class_name EnemySpawnWaveData

@export var enemy_scene: PackedScene
@export var slots: Array[EnemySpawnSlotData]
@export var start_delay: float = 0.0
@export var clear_timeout: float = 0.0
