extends SceneTree

const RunStats = preload("res://scripts/game/run_stats.gd")
const SpawnConfig = preload("res://scripts/resources/spawn_config.gd")
const SpawnManagerClass = preload("res://scripts/enemies/spawn_manager.gd")

func _init() -> void:
	print("--- Running Code Review Fixes Regression Test Suite ---")
	call_deferred("run_all_tests")

func run_all_tests() -> void:
	var main_scene = load("res://scenes/main/main.tscn")
	assert(main_scene != null, "Main scene must load")
	var main_node = main_scene.instantiate() as MainGame
	root.add_child(main_node)
	current_scene = main_node
	await process_frame

	await test_enemy_projectiles_damage_player(main_node)
	await test_consecutive_level_ups_queue(main_node)
	await test_run_stats_and_kill_tracking(main_node)
	await test_active_enemy_limit_enforcement(main_node)
	await test_synergy_cooldown_cleanup(main_node)
	await test_save_manager_safety()
	await test_enemy_knockback_physics(main_node)

	print("--- ALL CODE REVIEW REGRESSION TESTS PASSED SUCCESSFULLY! ---")
	quit(0)

func test_enemy_projectiles_damage_player(main_node: MainGame) -> void:
	print("[TEST] Testing enemy projectiles damage player...")
	var player = main_node.player
	player.current_health = 100.0
	player.invulnerable_timer = 0.0

	var proj_scene = load("res://scenes/combat/projectile.tscn")
	var enemy_proj = proj_scene.instantiate() as Projectile
	enemy_proj.faction = Projectile.Faction.ENEMY
	enemy_proj.damage = 18.0
	main_node.add_child(enemy_proj)
	await process_frame

	# 1. Enemy projectile damages player
	enemy_proj._on_body_entered(player)
	assert(player.current_health == 82.0, "Player must take 18 damage from enemy projectile (was %f)" % player.current_health)
	assert(enemy_proj.has_hit_player == true, "Enemy projectile must record hit on player")

	# 2. Friendly projectile does NOT damage player
	var friendly_proj = proj_scene.instantiate() as Projectile
	friendly_proj.faction = Projectile.Faction.PLAYER
	friendly_proj.damage = 25.0
	main_node.add_child(friendly_proj)
	await process_frame
	friendly_proj._on_body_entered(player)
	assert(player.current_health == 82.0, "Friendly projectile must not damage player")

	# Clean up
	enemy_proj.queue_free()
	friendly_proj.queue_free()
	print("[PASS] Enemy projectile damage, friendly immunity, and single-hit verified.")

func test_consecutive_level_ups_queue(main_node: MainGame) -> void:
	print("[TEST] Testing consecutive multiple level-ups queue...")
	var panel = main_node.hud.level_up_panel
	var player = main_node.player

	# 1. Multiple consecutive level up triggers
	panel.open_panel(player, 2)
	assert(panel.is_panel_open == true, "Panel must be marked open on first level up")
	assert(panel.visible == true, "Panel must be visible")
	assert(paused == true, "Game must be paused during level up")
	assert(panel.pending_levels.size() == 0, "No pending levels yet")

	# Second and third level ups arrive while panel is open
	panel.open_panel(player, 3)
	panel.open_panel(player, 4)
	assert(panel.pending_levels.size() == 2, "Pending queue must hold 2 queued levels")
	assert(panel.pending_levels[0] == 3 and panel.pending_levels[1] == 4, "Queue must preserve level order")

	# 2. Choose card for level 2 -> transitions to level 3
	var dummy_opt = RewardGenerator.UpgradeOption.new()
	dummy_opt.type = "stat"
	dummy_opt.title = "Test Stat"
	panel._on_card_selected(dummy_opt)

	assert(panel.pending_levels.size() == 1, "Queue must have 1 level remaining")
	assert(panel.is_panel_open == true, "Panel must remain open for next level choice")
	assert(paused == true, "Game must remain paused for next level choice")

	# 3. Choose card for level 3 -> transitions to level 4
	panel._on_card_selected(dummy_opt)
	assert(panel.pending_levels.size() == 0, "Queue must now be empty")
	assert(panel.is_panel_open == true, "Panel still open for final level 4 choice")

	# 4. Choose card for level 4 -> completes all choices, unpauses game
	panel._on_card_selected(dummy_opt)
	assert(panel.is_panel_open == false, "Panel must be closed after all levels processed")
	assert(panel.visible == false, "Panel must be hidden")
	assert(paused == false, "Game must be unpaused after all level ups completed")

	print("[PASS] Consecutive level-up queue, sequential display, and pause maintenance verified.")

func test_run_stats_and_kill_tracking(main_node: MainGame) -> void:
	print("[TEST] Testing RunStats and idempotent kill tracking...")
	var stats = RunStats.new()
	assert(stats.total_kills == 0, "Initial kills must be 0")

	var enemy_scene = load("res://scenes/enemies/basic_enemy.tscn")
	var enemy = enemy_scene.instantiate() as EnemyController
	main_node.add_child(enemy)
	await process_frame

	# 1. Record basic enemy kill
	stats.record_kill(enemy)
	assert(stats.total_kills == 1, "Total kills must be 1")
	assert(stats.elite_kills == 0, "Elite kills must be 0")

	# 2. Idempotency: recording the exact same enemy twice must NOT increment kills
	stats.record_kill(enemy)
	assert(stats.total_kills == 1, "Duplicate kill event must not increment kill count")

	# 3. Record elite enemy kill
	var elite_scene = load("res://scenes/enemies/elite_enemy.tscn")
	var elite = elite_scene.instantiate() as EnemyController
	main_node.add_child(elite)
	await process_frame
	stats.record_kill(elite)
	assert(stats.total_kills == 2, "Total kills must be 2")
	assert(stats.elite_kills == 1, "Elite kills must be 1")

	# 4. Record boss kill
	var boss_scene = load("res://scenes/enemies/boss_enemy.tscn")
	var boss = boss_scene.instantiate() as BossController
	main_node.add_child(boss)
	await process_frame
	stats.record_kill(boss)
	assert(stats.total_kills == 3, "Total kills must be 3")
	assert(stats.boss_kills == 1, "Boss kills must be 1")
	assert(stats.defeated_boss == true, "defeated_boss flag must be true")

	# Clean up
	enemy.queue_free()
	elite.queue_free()
	boss.queue_free()
	print("[PASS] RunStats kill tracking, category classification, and idempotency verified.")

func test_active_enemy_limit_enforcement(main_node: MainGame) -> void:
	print("[TEST] Testing active enemy limit enforcement...")
	var spawn_mgr = main_node.spawn_manager
	var original_max = spawn_mgr.max_enemies
	spawn_mgr.max_enemies = 5

	var enemy_scene = load("res://scenes/enemies/basic_enemy.tscn")

	# Clear any currently active enemies first
	for e in spawn_mgr.active_enemies:
		if is_instance_valid(e):
			e.queue_free()
	spawn_mgr.active_enemies.clear()

	# Fill up to limit (5 enemies)
	for i in range(5):
		var e = enemy_scene.instantiate() as EnemyController
		main_node.add_child(e)
		spawn_mgr.active_enemies.append(e)
	await process_frame

	assert(spawn_mgr.active_enemies.size() == 5, "Active enemies must be 5")

	# 1. Try spawn wave when at max: should not exceed
	spawn_mgr.spawn_wave(3)
	assert(spawn_mgr.active_enemies.size() <= 5, "Wave spawn must not exceed max_enemies limit")

	# 2. Try spawn elite when at max: should be rejected
	var elite = spawn_mgr.spawn_elite()
	assert(elite == null, "Elite spawn must return null when capacity is full")
	assert(spawn_mgr.active_enemies.size() <= 5, "Active enemies must remain <= 5")

	# 3. Spawn boss when at max: culls 1 regular enemy to reserve slot, keeping size at max
	var boss = spawn_mgr.spawn_boss()
	assert(boss != null, "Boss must spawn via priority slot")
	assert(spawn_mgr.active_enemies.size() <= 5, "Boss spawn must not exceed max_enemies")

	# Clean up and restore
	for e in spawn_mgr.active_enemies:
		if is_instance_valid(e):
			e.queue_free()
	spawn_mgr.active_enemies.clear()
	spawn_mgr.max_enemies = original_max
	print("[PASS] Active enemy limit enforcement across waves, elites, and boss verified.")

func test_synergy_cooldown_cleanup(main_node: MainGame) -> void:
	print("[TEST] Testing synergy cooldown cleanup on enemy removal...")
	var engine = main_node.synergy_engine

	var enemy_scene = load("res://scenes/enemies/basic_enemy.tscn")
	var enemy_a = enemy_scene.instantiate() as EnemyController
	var enemy_b = enemy_scene.instantiate() as EnemyController
	main_node.add_child(enemy_a)
	main_node.add_child(enemy_b)
	await process_frame

	engine.record_reaction(enemy_a, "resonance")
	engine.record_reaction(enemy_b, "resonance")

	var key_a = str(enemy_a.get_instance_id()) + "_resonance"
	var key_b = str(enemy_b.get_instance_id()) + "_resonance"
	assert(engine.reaction_cooldowns.has(key_a), "Key A must be registered in cooldowns")
	assert(engine.reaction_cooldowns.has(key_b), "Key B must be registered in cooldowns")

	# Clean target A
	engine.clear_target_cooldowns(enemy_a)
	assert(not engine.reaction_cooldowns.has(key_a), "Key A must be erased from cooldowns")
	assert(engine.reaction_cooldowns.has(key_b), "Key B must remain intact")

	enemy_a.queue_free()
	enemy_b.queue_free()
	print("[PASS] Synergy cooldown cleanup on target removal verified.")

func test_save_manager_safety() -> void:
	print("[TEST] Testing SaveManager error handling and sanitization...")

	# 1. Corrupted dictionary with negative numbers, invalid strings, nulls
	var corrupted_raw = {
		"version": "invalid_version_str",
		"total_runs": -99,
		"best_survival_time": -12.5,
		"bosses_defeated": "NaN",
		"total_kills": null
	}
	var clean = SaveManager.sanitize_data(corrupted_raw)
	assert(clean["version"] == SaveManager.CURRENT_VERSION, "Version must fallback to default")
	assert(clean["total_runs"] == 0, "Negative total_runs must fallback to 0")
	assert(clean["best_survival_time"] == 0.0, "Negative survival time must fallback to 0.0")
	assert(clean["bosses_defeated"] == 0, "Invalid bosses_defeated must fallback to 0")
	assert(clean["total_kills"] == 0, "Null total_kills must fallback to 0")

	# 2. Valid partial dictionary
	var partial = {
		"version": 1,
		"total_runs": 5,
		"best_survival_time": 145.2
	}
	var clean_partial = SaveManager.sanitize_data(partial)
	assert(clean_partial["total_runs"] == 5, "Valid total_runs must be preserved")
	assert(clean_partial["best_survival_time"] == 145.2, "Valid best_survival_time must be preserved")
	assert(clean_partial["bosses_defeated"] == 0, "Missing bosses_defeated must receive default 0")
	assert(clean_partial["total_kills"] == 0, "Missing total_kills must receive default 0")

	print("[PASS] SaveManager sanitization and corruption resistance verified.")

func test_enemy_knockback_physics(main_node: MainGame) -> void:
	print("[TEST] Testing enemy physics-based knockback...")
	var enemy_scene = load("res://scenes/enemies/basic_enemy.tscn")
	var enemy = enemy_scene.instantiate() as EnemyController
	main_node.add_child(enemy)
	await process_frame

	enemy.apply_knockback(Vector2(350.0, 0.0))
	assert(enemy.knockback_velocity == Vector2(350.0, 0.0), "Knockback velocity must be applied")

	# Simulate 1 physics tick (0.016s)
	enemy._physics_process(0.016)
	assert(enemy.velocity.x > 300.0, "Enemy velocity during knockback must follow knockback impulse")
	assert(enemy.knockback_velocity.x < 350.0, "Knockback velocity must decay smoothly")

	enemy.queue_free()
	print("[PASS] Physics-based knockback and decay verified.")
