class_name SpawnManager
extends Node2D

signal boss_spawned(boss: BossController)
signal enemy_killed(enemy: EnemyController)
signal enemy_spawned(enemy: EnemyController)

const SpawnConfigResource = preload("res://scripts/resources/spawn_config.gd")

@export var config: Resource
@export var enemy_scene: PackedScene = preload("res://scenes/enemies/basic_enemy.tscn")
@export var fast_enemy_scene: PackedScene = preload("res://scenes/enemies/fast_enemy.tscn")
@export var heavy_enemy_scene: PackedScene = preload("res://scenes/enemies/heavy_enemy.tscn")
@export var ranged_enemy_scene: PackedScene = preload("res://scenes/enemies/ranged_enemy.tscn")
@export var elite_scene: PackedScene = preload("res://scenes/enemies/elite_enemy.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/enemies/boss_enemy.tscn")

@export var base_spawn_interval: float = 1.5
@export var max_enemies: int = 95
@export var is_spawning_active: bool = true
@export var initial_pack_size: int = 4
@export var swarm_interval: float = 100.0
@export var elite_interval: float = 80.0
@export var boss_spawn_time: float = 480.0
@export var boss_respawn_interval: float = 100.0

var spawn_timer: float = 0.0
var swarm_timer: float = 0.0
var elite_timer: float = 0.0
var cleanup_timer: float = 0.0
var elapsed_time: float = 0.0
var has_spawned_boss: bool = false
var is_boss_alive: bool = false
var boss_respawn_timer: float = 0.0
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

func get_arena_extents() -> Vector2:
	var half_w = 1120.0
	var half_h = 720.0
	var arenas = get_tree().get_nodes_in_group("arena") if get_tree() else []
	if not arenas.is_empty() and "arena_size" in arenas[0]:
		half_w = (arenas[0].arena_size.x * 0.5) - 80.0
		half_h = (arenas[0].arena_size.y * 0.5) - 80.0
	return Vector2(half_w, half_h)

func find_safe_spawn_position(player: Node2D, enemy_radius: float = 20.0, min_distance: float = 400.0, max_distance: float = 650.0) -> Vector2:
	if not is_instance_valid(player):
		return Vector2.INF

	var p_pos = player.global_position
	var extents = get_arena_extents()
	var half_w = extents.x
	var half_h = extents.y

	var storm_zones = get_tree().get_nodes_in_group("ice_storm_zones") if get_tree() else []

	for attempt in range(24):
		var angle = randf() * TAU
		var dist = randf_range(min_distance, max_distance)
		var cand = p_pos + Vector2(cos(angle), sin(angle)) * dist

		# 1. Bounds check: must fit strictly within arena bounds with enemy_radius margin
		if cand.x - enemy_radius < -half_w or cand.x + enemy_radius > half_w:
			continue
		if cand.y - enemy_radius < -half_h or cand.y + enemy_radius > half_h:
			continue

		# 2. Minimum distance check to player
		var d = cand.distance_to(p_pos)
		if d < min_distance:
			continue

		# 3. Ice Storm avoidance check
		var inside_storm = false
		for zone in storm_zones:
			if is_instance_valid(zone) and not zone.is_queued_for_deletion():
				var z_r = zone.radius if "radius" in zone else 110.0
				if cand.distance_to(zone.global_position) < (z_r + enemy_radius):
					inside_storm = true
					break
		if inside_storm:
			continue

		return cand

	return Vector2.INF

func spawn_initial_pack() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty() or not enemy_scene:
		return

	var p = players[0] as Node2D
	for i in range(initial_pack_size):
		if active_enemies.size() >= max_enemies:
			break
		var spawn_pos = find_safe_spawn_position(p, 16.0, 320.0, 480.0)
		if spawn_pos.is_finite():
			spawn_enemy_at(spawn_pos)

func _process(delta: float) -> void:
	if not is_spawning_active:
		return

	elapsed_time += delta
	swarm_timer += delta
	elite_timer += delta
	cleanup_timer += delta

	# Periodic cleanup of destroyed enemies (1.5s interval to avoid per-frame allocations)
	if cleanup_timer >= 1.5:
		cleanup_timer = 0.0
		active_enemies = active_enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead)
		if is_boss_alive and get_tree():
			var bosses = get_tree().get_nodes_in_group("boss")
			is_boss_alive = not bosses.is_empty()

	# 1. Boss Spawn & Schedule Check
	if not has_spawned_boss and elapsed_time >= boss_spawn_time:
		has_spawned_boss = true
		spawn_boss()
	elif has_spawned_boss and not is_boss_alive:
		boss_respawn_timer += delta
		if boss_respawn_timer >= boss_respawn_interval:
			boss_respawn_timer = 0.0
			spawn_boss()

	# 2. Elite Enemy Spawning (strictly respecting max 2 active elites)
	if elite_timer >= elite_interval:
		var active_elites = get_tree().get_nodes_in_group("elite_enemies")
		if active_enemies.size() < max_enemies and active_elites.size() < 2:
			elite_timer = 0.0
			spawn_elite()
		else:
			elite_timer = elite_interval - 4.0

	# 3. Swarm Event (high pressure waves)
	if swarm_timer >= swarm_interval:
		swarm_timer = 0.0
		var swarm_count = 14 + int(elapsed_time / 45.0)
		trigger_swarm_event(swarm_count)

	# 4. Regular Wave Spawning with dynamic pacing
	var min_interval = config.min_spawn_interval if config else 0.50
	var max_wave = config.max_wave_size if config else 9
	var current_interval = max(min_interval, base_spawn_interval - (elapsed_time / 300.0) * 0.95)

	# Boss encounter clarity: if boss is alive, throttle regular enemy count
	var active_cap = 30 if is_boss_alive else max_enemies
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

	var active_elites = get_tree().get_nodes_in_group("elite_enemies") if get_tree() else []
	if active_elites.size() >= 2:
		return null

	var players = get_tree().get_nodes_in_group("player") if get_tree() else []
	if players.is_empty() or not elite_scene:
		return null

	var player = players[0] as Node2D
	var spawn_pos = find_safe_spawn_position(player, 34.0, 480.0, 700.0)
	if not spawn_pos.is_finite():
		return null # Safely defer spawn

	var elite = elite_scene.instantiate() as EnemyController
	elite.global_position = spawn_pos
	get_parent().add_child(elite)
	elite.died.connect(_on_enemy_died)
	active_enemies.append(elite)
	enemy_spawned.emit(elite)
	return elite

func spawn_boss() -> BossController:
	var active_boss_count = 0
	if get_tree():
		for b in get_tree().get_nodes_in_group("boss"):
			if is_instance_valid(b) and not b.is_queued_for_deletion() and not (b is EnemyController and b.is_dead):
				active_boss_count += 1
	if active_boss_count > 0 or is_boss_alive:
		return null

	var players = get_tree().get_nodes_in_group("player") if get_tree() else []
	if players.is_empty() or not boss_scene:
		return null

	if active_enemies.size() >= max_enemies:
		_cull_furthest_regular_enemy(players[0] as Node2D)

	var player = players[0] as Node2D
	var spawn_pos = find_safe_spawn_position(player, 62.0, 500.0, 750.0)
	if not spawn_pos.is_finite():
		# Calculate an opposite-quadrant safe fallback point that strictly respects arena limits and min distance
		var extents = get_arena_extents()
		var alt_x = clamp(player.global_position.x + (500.0 if player.global_position.x < 0 else -500.0), -extents.x + 65.0, extents.x - 65.0)
		var alt_y = clamp(player.global_position.y + (300.0 if player.global_position.y < 0 else -300.0), -extents.y + 65.0, extents.y - 65.0)
		spawn_pos = Vector2(alt_x, alt_y)

	var boss = boss_scene.instantiate() as BossController
	boss.global_position = spawn_pos
	get_parent().add_child(boss)
	boss.died.connect(_on_enemy_died)
	active_enemies.append(boss)
	is_boss_alive = true
	enemy_spawned.emit(boss)

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
	var players = get_tree().get_nodes_in_group("player") if get_tree() else []
	if players.is_empty():
		return

	var player = players[0] as Node2D
	for i in range(count):
		if active_enemies.size() >= max_enemies:
			break
		var spawn_pos = find_safe_spawn_position(player, 16.0, 420.0, 650.0)
		if spawn_pos.is_finite():
			spawn_enemy_at(spawn_pos)

func trigger_swarm_event(swarm_size: int) -> void:
	var players = get_tree().get_nodes_in_group("player") if get_tree() else []
	if players.is_empty():
		return

	# Smooth out swarm waves: split large swarms (>= 18) into two staggered waves spaced 3 seconds apart
	if swarm_size >= 18:
		var half_1 = int(swarm_size * 0.5)
		var half_2 = swarm_size - half_1
		_spawn_swarm_batch(half_1)
		var t = get_tree().create_timer(3.0)
		t.timeout.connect(func(): _spawn_swarm_batch(half_2))
	else:
		_spawn_swarm_batch(swarm_size)

func _spawn_swarm_batch(count: int) -> void:
	var players = get_tree().get_nodes_in_group("player") if get_tree() else []
	if players.is_empty():
		return

	var player = players[0] as Node2D
	for i in range(count):
		if active_enemies.size() >= max_enemies:
			break
		var spawn_pos = find_safe_spawn_position(player, 16.0, 460.0, 700.0)
		if spawn_pos.is_finite():
			spawn_enemy_at(spawn_pos)

func clamp_to_arena(pos: Vector2) -> Vector2:
	var half_w = 1120.0
	var half_h = 720.0
	var arenas = get_tree().get_nodes_in_group("arena") if get_tree() else []
	if not arenas.is_empty() and "arena_size" in arenas[0]:
		half_w = (arenas[0].arena_size.x * 0.5) - 80.0
		half_h = (arenas[0].arena_size.y * 0.5) - 80.0
	return Vector2(clamp(pos.x, -half_w, half_w), clamp(pos.y, -half_h, half_h))

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
	enemy_spawned.emit(enemy)
	return enemy

func _on_enemy_died(enemy: EnemyController) -> void:
	active_enemies.erase(enemy)
	if enemy is BossController:
		is_boss_alive = false
		boss_respawn_timer = 0.0
	enemy_killed.emit(enemy)

func stop_spawning() -> void:
	is_spawning_active = false
