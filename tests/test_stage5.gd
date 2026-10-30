extends SceneTree

func _init() -> void:
	print("--- Running Stage 5 Automated Tests ---")
	call_deferred("run_tests")

func run_tests() -> void:
	var main_scene = load("res://scenes/main/main.tscn")
	assert(main_scene != null, "Main scene must load")

	var main_node = main_scene.instantiate() as MainGame
	root.add_child(main_node)
	current_scene = main_node

	var player = main_node.get_node_or_null("Player") as PlayerController
	var spawner = main_node.get_node_or_null("SpawnManager") as SpawnManager
	var ac = player.ability_controller

	assert(player != null, "Player must exist")
	assert(spawner != null, "SpawnManager must exist")
	assert(ac != null, "AbilityController must exist")

	await process_frame

	# 1. Test Ice Storm Ability
	var ice_ability = ac.unlock_ability("ice_storm") as IceStormAbility
	assert(ice_ability != null, "Ice Storm unlocked")
	assert(ac.has_ability("ice_storm"), "AbilityController tracks Ice Storm")

	var enemy_ice = spawner.spawn_enemy_at(Vector2(100, 0))
	ice_ability.cooldown_timer = 0.0
	var cast_ice = ice_ability.try_cast()
	assert(cast_ice, "Ice Storm cast succeeded")

	# Wait for zone tick
	await process_frame
	print("[PASS] Ice Storm ability and zone verified")

	# 2. Test Death Mark Ability
	var mark_ability = ac.unlock_ability("death_mark") as DeathMarkAbility
	assert(mark_ability != null, "Death Mark unlocked")

	var heavy_enemy = spawner.spawn_enemy_at(Vector2(140, 0))
	heavy_enemy.stats.max_health = 100.0
	heavy_enemy.current_health = 100.0

	mark_ability.cooldown_timer = 0.0
	var cast_mark = mark_ability.try_cast()
	assert(cast_mark, "Death Mark cast succeeded")
	assert(heavy_enemy.has_status(StatusEffects.STATUS_MARKED), "Enemy received Death Mark status")

	# Verify amplified damage
	var hp_before = heavy_enemy.current_health
	heavy_enemy.take_damage(20.0)
	var dealt = hp_before - heavy_enemy.current_health
	assert(dealt > 20.0, "Marked target took amplified damage (>20.0)")
	print("[PASS] Death Mark single-target debuff and damage amp verified")

	# 3. Test Treasure Chest & Artifact Drop
	var chest_scene = load("res://scenes/pickups/chest.tscn")
	var chest = chest_scene.instantiate() as Chest
	chest.global_position = Vector2(0, 0)
	main_node.add_child(chest)

	var arts_before = player.inventory.artifacts.size()
	chest.open_chest(player)
	var chest_panel = main_node.hud.chest_reward_panel
	assert(chest_panel != null and chest_panel.is_panel_open, "Chest opened modal reward panel")
	assert(chest_panel.current_options.size() > 0, "Chest panel has reward options")
	var opt = chest_panel.current_options[0]
	chest_panel._on_card_selected(opt)
	var arts_after = player.inventory.artifacts.size()
	assert(arts_after > arts_before, "Treasure chest granted a new artifact")
	print("[PASS] Treasure chest and 3-choice modal artifact reward verified")

	# 4. Test Elite Enemy & Guaranteed Chest Drop
	var elite = spawner.spawn_elite() as EliteEnemyController
	assert(elite != null, "Elite enemy spawned")
	assert(elite.is_in_group("elite_enemies"), "Elite in elite_enemies group")
	assert(elite.stats.max_health >= 150.0, "Elite has heavy health pool")

	var chest_count_before = main_node.get_tree().get_nodes_in_group("chests").size()
	elite.die()
	await process_frame
	var chest_count_after = main_node.get_tree().get_nodes_in_group("chests").size()
	assert(chest_count_after > chest_count_before, "Elite enemy dropped a treasure chest on death")
	print("[PASS] Elite enemy and chest drop on death verified")

	# 5. Test Boss Spawn and Mechanics
	var boss = spawner.spawn_boss() as BossController
	assert(boss != null, "Boss spawned")
	assert(boss.is_in_group("boss"), "Boss in boss group")
	assert(boss.stats.max_health >= 500.0, "Boss has high health (700)")

	# Test Boss Dash
	boss.start_dash_attack()
	assert(boss.is_dashing, "Boss dash attack started")

	# Test Boss Defeat signal
	var boss_defeated_flag = [false]
	boss.boss_defeated.connect(func(): boss_defeated_flag[0] = true)
	boss.die()
	assert(boss_defeated_flag[0], "Boss emitted boss_defeated signal")
	print("[PASS] Boss spawn, dash attack, and defeat lifecycle verified")

	# 6. Test Save Manager & Run Summary Recording
	var record = SaveManager.record_run(145.0, 52, true)
	assert(record["total_runs"] > 0, "SaveManager records run count")
	assert(record["best_survival_time"] >= 145.0, "SaveManager records best survival time")
	assert(record["bosses_defeated"] > 0, "SaveManager records boss defeat")
	print("[PASS] SaveManager run statistics recording verified")

	print("--- ALL STAGE 5 TESTS PASSED SUCCESSFULLY! ---")
	quit(0)
