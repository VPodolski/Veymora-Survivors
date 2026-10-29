extends SceneTree

func _init() -> void:
	print("--- Running Stage 2 Automated Tests ---")
	call_deferred("run_tests")

func run_tests() -> void:
	var main_scene = load("res://scenes/main/main.tscn")
	assert(main_scene != null, "Main scene must load")

	var main_node = main_scene.instantiate() as MainGame
	root.add_child(main_node)

	# 1. Verify Player and Ability Controller
	var player = main_node.get_node_or_null("Player") as PlayerController
	assert(player != null, "Player must exist")
	var ac = player.get_node_or_null("Abilities") as AbilityController
	assert(ac != null, "AbilityController must exist on Player")

	# Wait for deferred call to unlock starting ability
	await process_frame

	assert(ac.has_ability("magic_bolt"), "Player should start with Magic Bolt ability")
	var bolt = ac.get_ability("magic_bolt") as MagicBoltAbility
	assert(bolt != null, "Magic Bolt should be instantiated")
	assert(bolt.current_level == 1, "Magic Bolt starts at level 1")
	print("[PASS] Starting ability (Magic Bolt) verified")

	# 2. Verify Target Selector and Magic Bolt Auto-Cast
	var spawner = main_node.get_node_or_null("SpawnManager") as SpawnManager
	var test_enemy = spawner.spawn_enemy_at(Vector2(200, 0))
	assert(test_enemy != null, "Test enemy should be spawned")

	var nearest = TargetSelector.find_nearest_enemy(self, player.global_position, 900.0)
	assert(nearest == test_enemy, "TargetSelector should find the spawned enemy")
	print("[PASS] TargetSelector nearest enemy logic verified")

	# Trigger cast
	bolt.cooldown_timer = 0.0
	var cast_success = bolt.try_cast()
	assert(cast_success, "Magic bolt should successfully cast towards target")
	print("[PASS] Magic Bolt auto-casting verified")

	# 3. Verify Runic Blade Ability & Hit Cooldown
	var blade_ability = ac.unlock_ability("runic_blade") as RunicBladeAbility
	assert(blade_ability != null, "Runic Blade ability should unlock")
	assert(ac.has_ability("runic_blade"), "AbilityController tracks Runic Blade")
	assert(blade_ability.blade_nodes.size() == 1, "Runic Blade starts with 1 blade")

	var enemy_hp_before = test_enemy.current_health
	blade_ability._on_blade_hit(test_enemy)
	assert(test_enemy.current_health < enemy_hp_before, "Runic blade dealt damage on hit")
	var hp_after_first_hit = test_enemy.current_health

	# Second immediate hit should be ignored due to per-enemy hit interval
	blade_ability._on_blade_hit(test_enemy)
	assert(test_enemy.current_health == hp_after_first_hit, "Hit cooldown prevented consecutive tick damage")
	print("[PASS] Runic Blade hit cooldown per enemy verified")

	# 4. Verify Experience & Drop on Death
	var exp_manager = main_node.get_node_or_null("ExperienceManager") as ExperienceManager
	assert(exp_manager != null, "ExperienceManager must exist")
	assert(exp_manager.current_level == 1, "Starts at level 1")

	# Simulate death of enemy
	test_enemy.die()

	# Test XPGem manual collection
	var gem = load("res://scenes/pickups/xp_gem.tscn").instantiate() as XPGem
	gem.xp_value = 30
	main_node.add_child(gem)
	gem.collect()

	assert(exp_manager.current_level == 2, "Collecting 30 XP should level up to level 2")
	print("[PASS] Experience and Level Up lifecycle verified")

	# 5. Verify Reward Generator choices
	var choices = RewardGenerator.generate_choices(player, 3)
	assert(choices.size() == 3, "RewardGenerator should generate exactly 3 choices")
	for c in choices:
		assert(c.title != "", "Choice should have a non-empty title")
		assert(c.description != "", "Choice should have a description")
	print("[PASS] RewardGenerator 3-choice generation verified")

	# 6. Verify Upgrade Application
	var bolt_dmg_before = bolt.base_damage
	var upgrade_success = ac.upgrade_ability("magic_bolt")
	assert(upgrade_success, "Ability upgrade succeeded")
	assert(bolt.current_level == 2, "Magic bolt reached level 2")
	assert(bolt.base_damage > bolt_dmg_before, "Magic bolt damage increased with level")
	print("[PASS] Ability leveling verified")

	print("--- ALL STAGE 2 TESTS PASSED SUCCESSFULLY! ---")
	quit(0)
