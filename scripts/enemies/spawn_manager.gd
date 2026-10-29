class_name SpawnManager
extends Node2D

signal boss_spawned(boss: BossController)
signal enemy_killed(enemy: EnemyController)

const SpawnConfigResource = preload("res://scripts/resources/spawn_config.gd")

@export var config: Resource
@export var enemy_scene: PackedScene = preload("res://scenes/enemies/basic_enemy.tscn")
@export var fast_enemy_scene: PackedScene = preload("res://scenes/enemies/fast_enemy.tscn")
@export var heavy_enemy_scene: PackedScene = preload("res://scenes/enemies/heavy_enemy.tscn")
@export var ranged_enemy_scene: PackedScene = preload("res://scenes/enemies/ranged_enemy.tscn")
@export var elite_scene: PackedScene = preload("res://scenes/enemies/elite_enemy.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/enemies/boss_enemy.tscn")

@export var base_spawn_interval: float = 1.6
@export var max_enemies: int = 90
@export var is_spawning_active: bool = true
@export var initial_pack_size: int = 4
@export var swarm_interval: float = 120.0
@export var elite_interval: float = 150.0
@export var boss_spawn_time: float = 600.0

var spawn_timer: float = 0.0
var swarm_timer: float = 0.0
var elite_timer: float = 0.0
var elapsed_time: float = 0.0
var has_spawned_boss: bool = false
var active_enemies: Array[EnemyController] = []

func _ready() -> void:
	if config == null:
		var default_res = load("res://resources/game/default_spawn_config.tres")
		if default_res:
			config = default_res
		else:
			config = SpawnConfigResource.new()

	_sync_config_values()
	call_deferred("spawn_initial_pack")

func _sync_config_values() -> void:
	if config:
		base_spawn_interval = config.base_spawn_interval
		max_enemies = config.max_enemies
		initial_pack_size = config.initial_pack_size
		swarm_interval = config.swarm_interval
		elite_interval = config.elite_interval
		boss_spawn_time = config.boss_spawn_time

func spawn_initial_pack() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty() or not enemy_scene:
		return

	var p = players[0] as Node2D
	for i in range(initial_pack_size):
		if active_enemies.size() >= max_enemies:
			break
		var angle = (float(i) / float(initial_pack_size)) * TAU
		var dist = randf_range(280.0, 360.0)
		var spawn_pos = p.global_position + Vector2(cos(angle), sin(angle)) * dist
		spawn_enemy_at(clamp_to_arena(spawn_pos))

func _process(delta: float) -> void:
	if not is_spawning_active:
		return

	elapsed_time += delta
	swarm_timer += delta
	elite_timer += delta

	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead)

	# 1. Boss Spawn Check
	if not has_spawned_boss and elapsed_time >= boss_spawn_time:
		has_spawned_boss = true
		spawn_boss()

	# 2. Elite Enemy Spawning (strictly respecting max_enemies limit)
	if elite_timer >= elite_interval:
		if active_enemies.size() < max_enemies:
			elite_timer = 0.0
			spawn_elite()
		else:
			elite_timer = elite_interval - 3.0

	# 3. Swarm Event (high pressure waves)
	if swarm_timer >= swarm_interval:
		swarm_timer = 0.0
		var swarm_count = 14 + int(elapsed_time / 45.0)
		trigger_swarm_event(swarm_count)

	# 4. Regular Wave Spawning with dynamic pacing
	var min_interval = config.min_spawn_interval if config else 0.55
	var max_wave = config.max_wave_size if config else 9
	var current_interval = max(min_interval, base_spawn_interval - (elapsed_time / 300.0) * 0.95)

	# Boss encounter clarity: if boss is alive, throttle regular enemy count
	var active_cap = 25 if has_spawned_boss else max_enemies
	var wave_size = int(clamp(2 + int(elapsed_time / 60.0), 2, max_wave))

	spawn_timer += delta
	if spawn_timer >= current_interval:
		spawn_timer = 0.0
		if active_enemies.size() < active_cap:
			spawn_wave(wave_size)

func get_enemy_scene_for_time(time_seconds: float) -> PackedScene:
	var roll = randf()
	if time_seconds < 120.0:
		return enemy_scene
	elif time_seconds < 300.0:
		if roll < 0.40 and fast_enemy_scene:
			return fast_enemy_scene
		return enemy_scene
	elif time_seconds < 480.0:
		if roll < 0.35 and fast_enemy_scene:
			return fast_enemy_scene
		elif roll < 0.55 and heavy_enemy_scene:
			return heavy_enemy_scene
		elif roll < 0.70 and ranged_enemy_scene:
			return ranged_enemy_scene
		return enemy_scene
	else:
		if roll < 0.30 and fast_enemy_scene:
			return fast_enemy_scene
		elif roll < 0.55 and heavy_enemy_scene:
			return heavy_enemy_scene
		elif roll < 0.75 and ranged_enemy_scene:
			return ranged_enemy_scene
		return enemy_scene

func spawn_elite() -> EnemyController:
	if active_enemies.size() >= max_enemies:
		return null

	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty() or not elite_scene:
		return null

	var player = players[0] as Node2D
	var angle = randf() * TAU
	var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * 520.0

	var elite = elite_scene.instantiate() as EnemyController
	elite.global_position = clamp_to_arena(spawn_pos)
	get_parent().add_child(elite)
	elite.died.connect(_on_enemy_died)
	active_enemies.append(elite)

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_text_popup(container, elite.global_position, "ЭЛИТНЫЙ ВРАГ!", Color(1.0, 0.8, 0.2, 1.0))
	return elite

func spawn_boss() -> BossController:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty() or not boss_scene:
		return null

	if active_enemies.size() >= max_enemies:
		_cull_furthest_regular_enemy(players[0] as Node2D)

	var player = players[0] as Node2D
	var spawn_pos = player.global_position + Vector2(400.0, 0.0)

	var boss = boss_scene.instantiate() as BossController
	boss.global_position = clamp_to_arena(spawn_pos)
	get_parent().add_child(boss)
	boss.died.connect(_on_enemy_died)
	active_enemies.append(boss)

	boss_spawned.emit(boss)

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, boss.global_position, 200.0, Color(0.9, 0.2, 1.0, 1.0))
	CombatEffects.spawn_text_popup(container, boss.global_position, "ПОВЕЛИТЕЛЬ РАЗЛОМА!", Color(1.0, 0.2, 0.8, 1.0))
	return boss

func _cull_furthest_regular_enemy(player: Node2D) -> void:
	var furthest: EnemyController = null
	var max_dist_sq = -1.0
	for e in active_enemies:
		if is_instance_valid(e) and not e.is_dead and not (e is BossController) and not (e is EliteEnemyController):
			var d = e.global_position.distance_squared_to(player.global_position)
			if d > max_dist_sq:
				max_dist_sq = d
				furthest = e

	if furthest:
		active_enemies.erase(furthest)
		furthest.queue_free()

func spawn_wave(count: int) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player = players[0] as Node2D
	var base_angle = randf() * TAU
	var base_dist = randf_range(520.0, 650.0)

	for i in range(count):
		if active_enemies.size() >= max_enemies:
			break
		var angle_offset = randf_range(-0.35, 0.35)
		var dist_offset = randf_range(-40.0, 40.0)
		var angle = base_angle + angle_offset
		var dist = base_dist + dist_offset
		var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * dist
		spawn_enemy_at(clamp_to_arena(spawn_pos))

func trigger_swarm_event(swarm_size: int) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player = players[0] as Node2D
	for i in range(swarm_size):
		if active_enemies.size() >= max_enemies:
			break
		var angle = (float(i) / float(swarm_size)) * TAU + randf_range(-0.1, 0.1)
		var dist = randf_range(580.0, 680.0)
		var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * dist
		spawn_enemy_at(clamp_to_arena(spawn_pos))

func clamp_to_arena(pos: Vector2) -> Vector2:
	return Vector2(clamp(pos.x, -1120.0, 1120.0), clamp(pos.y, -720.0, 720.0))

func spawn_enemy_at(pos: Vector2) -> EnemyController:
	if active_enemies.size() >= max_enemies:
		return null

	var selected_scene = get_enemy_scene_for_time(elapsed_time)
	if not selected_scene:
		selected_scene = enemy_scene
	if not selected_scene:
		return null

	var enemy = selected_scene.instantiate() as EnemyController
	enemy.global_position = pos
	get_parent().add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	active_enemies.append(enemy)
	return enemy

func _on_enemy_died(enemy: EnemyController) -> void:
	active_enemies.erase(enemy)
	enemy_killed.emit(enemy)

func stop_spawning() -> void:
	is_spawning_active = false
