class_name SpawnManager
extends Node2D

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/basic_enemy.tscn")
@export var spawn_interval: float = 3.5
@export var max_enemies: int = 15
@export var is_spawning_active: bool = true

var spawn_timer: float = 0.0
var active_enemies: Array[EnemyController] = []

func _ready() -> void:
	# Spawn initial test enemy near player
	call_deferred("spawn_initial_enemy")

func spawn_initial_enemy() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and enemy_scene:
		var p = players[0] as Node2D
		var spawn_pos = p.global_position + Vector2(250, 0)
		spawn_enemy_at(spawn_pos)

func _process(delta: float) -> void:
	if not is_spawning_active:
		return

	# Clean up invalid references
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead)

	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		if active_enemies.size() < max_enemies:
			spawn_wave()

func spawn_wave() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player = players[0] as Node2D
	var angle = randf() * TAU
	var distance = randf_range(480.0, 620.0)
	var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance
	spawn_enemy_at(spawn_pos)

func spawn_enemy_at(pos: Vector2) -> EnemyController:
	if not enemy_scene:
		return null

	var enemy = enemy_scene.instantiate() as EnemyController
	enemy.global_position = pos
	get_parent().add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	active_enemies.append(enemy)
	return enemy

func _on_enemy_died(enemy: EnemyController) -> void:
	active_enemies.erase(enemy)

func stop_spawning() -> void:
	is_spawning_active = false

