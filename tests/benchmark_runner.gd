class_name BenchmarkRunner
extends SceneTree

const DamageResolver = preload("res://scripts/combat/damage_resolver.gd")
const StatusEffects = preload("res://scripts/combat/status_effects.gd")

var main_node: MainGame = null
var results: Dictionary = {}

func _init() -> void:
	print("\n=======================================================")
	print("--- Veymora Survivors Performance Benchmark Harness ---")
	print("=======================================================\n")
	call_deferred("run_all_benchmarks")

func run_all_benchmarks() -> void:
	var main_scene = load("res://scenes/main/main.tscn")
	main_node = main_scene.instantiate() as MainGame
	root.add_child(main_node)
	current_scene = main_node
	await process_frame

	# Ensure spawner doesn't interfere automatically with our manual scenario setups
	main_node.spawn_manager.is_spawning_active = false

	# 1. Run Scenario 1: Start of run (0:00)
	print("[BENCHMARK] Running Scenario 1: Start of Run (0:00)...")
	results["scenario_1_start"] = await run_scenario(1)

	# 2. Run Scenario 2: Mid-game (~5:00)
	print("[BENCHMARK] Running Scenario 2: Mid-Game (~5:00)...")
	results["scenario_2_mid"] = await run_scenario(2)

	# 3. Run Scenario 3: Late-game (~10-12:00)
	print("[BENCHMARK] Running Scenario 3: Late-Game (~10-12:00)...")
	results["scenario_3_late"] = await run_scenario(3)

	_print_summary(results)
	_save_json_results(results)

	quit(0)

func _clear_entities() -> void:
	# Clear existing enemies
	for e in main_node.spawn_manager.active_enemies:
		if is_instance_valid(e):
			e.queue_free()
	main_node.spawn_manager.active_enemies.clear()

	# Clear existing pickups
	var pickups = get_nodes_in_group("pickups")
	for p in pickups:
		if is_instance_valid(p):
			p.queue_free()

	# Clear existing projectiles
	for child in main_node.get_children():
		if child is Projectile:
			child.queue_free()

	# Let queue_free resolve
	for f in range(3):
		await process_frame

func run_scenario(scenario_id: int) -> Dictionary:
	await _clear_entities()

	var player = main_node.player
	var abilities = player.ability_controller
	var basic_scene = load("res://scenes/enemies/basic_enemy.tscn")
	var fast_scene = load("res://scenes/enemies/fast_enemy.tscn")
	var heavy_scene = load("res://scenes/enemies/heavy_enemy.tscn")
	var ranged_scene = load("res://scenes/enemies/ranged_enemy.tscn")
	var elite_scene = load("res://scenes/enemies/elite_enemy.tscn")
	var boss_scene = load("res://scenes/enemies/boss_enemy.tscn")
	var gem_scene = load("res://scenes/pickups/xp_gem.tscn")

	# Setup abilities and levels
	if scenario_id == 1:
		# Scenario 1: Lv 1, Magic Bolt
		player.current_health = 100.0
		# Spawn 12 basic enemies
		_spawn_enemy_ring(basic_scene, 12, 350.0, 500.0)
		# Spawn 5 gems
		_spawn_gems(gem_scene, 5, 200.0)

	elif scenario_id == 2:
		# Scenario 2: Lv 8, Magic Bolt Lv 3, Fireball Lv 2, Magic Barrier Lv 2, Runic Blade Lv 2
		player.current_health = 100.0
		_ensure_ability("magic_bolt", 3)
		_ensure_ability("fireball", 2)
		_ensure_ability("magic_barrier", 2)
		_ensure_ability("runic_blade", 2)
		# Spawn 50 enemies (30 basic, 10 fast, 5 heavy, 5 ranged)
		_spawn_enemy_ring(basic_scene, 30, 300.0, 550.0)
		_spawn_enemy_ring(fast_scene, 10, 320.0, 580.0)
		_spawn_enemy_ring(heavy_scene, 5, 280.0, 480.0)
		_spawn_enemy_ring(ranged_scene, 5, 380.0, 600.0)
		# Spawn 1 Elite
		var elite = elite_scene.instantiate() as EnemyController
		elite.global_position = Vector2(400, 0)
		main_node.add_child(elite)
		main_node.spawn_manager.active_enemies.append(elite)
		# Spawn 40 gems
		_spawn_gems(gem_scene, 40, 350.0)

	elif scenario_id == 3:
		# Scenario 3: Lv 18, Magic Bolt Lv 5 (evolved), Fireball Lv 4, Ice Storm Lv 3, Chain Lightning Lv 4, Font of Life Lv 3, Magic Barrier Lv 4
		player.current_health = 100.0
		_ensure_ability("magic_bolt", 5)
		_ensure_ability("fireball", 4)
		_ensure_ability("ice_storm", 3)
		_ensure_ability("chain_lightning", 4)
		_ensure_ability("font_of_life", 3)
		_ensure_ability("magic_barrier", 4)
		_ensure_ability("runic_blade", 4)

		# Spawn max cap horde: 95 enemies (55 basic, 20 fast, 10 heavy, 10 ranged)
		_spawn_enemy_ring(basic_scene, 55, 280.0, 620.0)
		_spawn_enemy_ring(fast_scene, 20, 300.0, 650.0)
		_spawn_enemy_ring(heavy_scene, 10, 260.0, 520.0)
		_spawn_enemy_ring(ranged_scene, 10, 360.0, 640.0)

		# Spawn 2 Elites
		for pos in [Vector2(450, 200), Vector2(-450, -200)]:
			var elite = elite_scene.instantiate() as EnemyController
			elite.global_position = pos
			main_node.add_child(elite)
			main_node.spawn_manager.active_enemies.append(elite)

		# Spawn Boss
		var boss = boss_scene.instantiate() as BossController
		boss.global_position = Vector2(0, -420)
		main_node.add_child(boss)
		main_node.spawn_manager.active_enemies.append(boss)
		main_node.spawn_manager.is_boss_alive = true

		# Spawn 100 gems
		_spawn_gems(gem_scene, 100, 480.0)

	# Warmup for 60 frames to stabilize allocations and let initial physics settle
	for f in range(60):
		await process_frame

	# Measurement window: 180 frames (approx. 3 seconds at 60 FPS)
	var frame_times: Array[float] = []
	var process_times: Array[float] = []
	var physics_times: Array[float] = []
	var draw_calls: Array[float] = []
	var total_frames = 180

	for f in range(total_frames):
		var t_start = Time.get_ticks_usec()
		await process_frame
		var frame_dur_ms = (Time.get_ticks_usec() - t_start) / 1000.0
		frame_times.append(frame_dur_ms)

		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	# Compute statistics
	frame_times.sort()
	var sum_ft = 0.0
	for ft in frame_times:
		sum_ft += ft
	var avg_ft = sum_ft / float(frame_times.size())
	var peak_ft = frame_times[frame_times.size() - 1]
	# 99th percentile (approx 1% lowest frame times)
	var p99_idx = int(floor(float(frame_times.size()) * 0.99))
	var p99_ft = frame_times[clamp(p99_idx, 0, frame_times.size() - 1)]

	var avg_fps = 1000.0 / max(0.001, avg_ft)
	var p99_fps = 1000.0 / max(0.001, p99_ft)

	var avg_process = _average(process_times)
	var avg_physics = _average(physics_times)
	var avg_draw_calls = _average(draw_calls)

	var active_enemies = main_node.spawn_manager.active_enemies.size()
	var active_gems = get_nodes_in_group("pickups").size()
	var active_projectiles = 0
	for child in main_node.get_children():
		if child is Projectile:
			active_projectiles += 1

	var active_fx = CombatEffects.active_decorative_effects
	var total_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var memory_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)

	var metrics = {
		"scenario_id": scenario_id,
		"avg_fps": avg_fps,
		"low_1pct_fps": p99_fps,
		"avg_frame_time_ms": avg_ft,
		"p99_frame_time_ms": p99_ft,
		"peak_frame_time_ms": peak_ft,
		"script_process_ms": avg_process,
		"physics_process_ms": avg_physics,
		"avg_draw_calls": avg_draw_calls,
		"active_enemies": active_enemies,
		"active_projectiles": active_projectiles,
		"active_gems": active_gems,
		"active_fx": active_fx,
		"total_nodes": total_nodes,
		"memory_mb": memory_mb
	}

	return metrics

func _ensure_ability(ability_id: String, level: int) -> void:
	var ctrl = main_node.player.ability_controller
	var ab = ctrl.get_ability(ability_id)
	if not ab:
		ctrl.unlock_ability(ability_id)
		ab = ctrl.get_ability(ability_id)
	if ab:
		ab.current_level = level
		if ab.has_method("apply_level_modifiers"):
			ab.apply_level_modifiers()
		if level >= 5 and ab.has_method("apply_evolution"):
			ab.apply_evolution()

func _spawn_enemy_ring(scene: PackedScene, count: int, r_min: float, r_max: float) -> void:
	for i in range(count):
		var angle = (float(i) / float(count)) * TAU
		var dist = randf_range(r_min, r_max)
		var e = scene.instantiate() as EnemyController
		e.global_position = Vector2(cos(angle), sin(angle)) * dist
		main_node.add_child(e)
		main_node.spawn_manager.active_enemies.append(e)

func _spawn_gems(scene: PackedScene, count: int, radius: float) -> void:
	for i in range(count):
		var angle = randf() * TAU
		var dist = randf_range(60.0, radius)
		var g = scene.instantiate() as XPGem
		g.global_position = Vector2(cos(angle), sin(angle)) * dist
		g.xp_value = 10
		main_node.add_child(g)

func _average(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var sum = 0.0
	for v in arr:
		sum += v
	return sum / float(arr.size())

func _print_summary(data: Dictionary) -> void:
	print("\n=======================================================")
	print("--- BENCHMARK RESULTS SUMMARY ---")
	print("=======================================================\n")
	for sc_name in data.keys():
		var m = data[sc_name]
		print("Scenario: %s" % sc_name)
		print("  Avg FPS:          %6.1f" % m["avg_fps"])
		print("  1%% Low FPS:       %6.1f" % m["low_1pct_fps"])
		print("  Avg Frame Time:   %6.2f ms" % m["avg_frame_time_ms"])
		print("  Peak Frame Time:  %6.2f ms" % m["peak_frame_time_ms"])
		print("  Process Time:     %6.2f ms" % m["script_process_ms"])
		print("  Physics Time:     %6.2f ms" % m["physics_process_ms"])
		print("  Draw Calls:       %6.1f" % m["avg_draw_calls"])
		print("  Active Enemies:   %d" % m["active_enemies"])
		print("  Active Proj:      %d" % m["active_projectiles"])
		print("  Active Gems:      %d" % m["active_gems"])
		print("  Active FX:        %d" % m["active_fx"])
		print("  Total Nodes:      %d" % m["total_nodes"])
		print("  Memory Static:    %.2f MB" % m["memory_mb"])
		print("-------------------------------------------------------")

func _save_json_results(data: Dictionary) -> void:
	var f = FileAccess.open("res://build/benchmark_baseline.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
		print("[BENCHMARK] Baseline results saved to build/benchmark_baseline.json")

