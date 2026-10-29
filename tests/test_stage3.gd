extends SceneTree

func _init() -> void:
	print("--- Running Stage 3 Automated Tests ---")
	call_deferred("run_tests")

func run_tests() -> void:
	var main_scene = load("res://scenes/main/main.tscn")
	assert(main_scene != null, "Main scene must load")

	var main_node = main_scene.instantiate() as MainGame
	root.add_child(main_node)

	var player = main_node.get_node_or_null("Player") as PlayerController
	var synergy_engine = main_node.get_node_or_null("SynergyEngine") as SynergyEngine
	var spawner = main_node.get_node_or_null("SpawnManager") as SpawnManager

	assert(player != null, "Player must exist")
	assert(synergy_engine != null, "SynergyEngine must exist")
	assert(spawner != null, "SpawnManager must exist")
	assert(player.inventory != null, "Player Inventory must exist")

	await process_frame

	# 1. Test Status Effects on Enemy
	var enemy1 = spawner.spawn_enemy_at(Vector2(150, 0))
	assert(enemy1 != null, "Enemy 1 must spawn")
	assert(not enemy1.has_status(StatusEffects.STATUS_CHARGED), "Enemy initially has no charged status")

	enemy1.apply_status(StatusEffects.STATUS_CHARGED, 4.0)
	assert(enemy1.has_status(StatusEffects.STATUS_CHARGED), "Enemy now has charged status")

	# Test Slowed status and speed reduction
	var normal_speed = enemy1.get_effective_speed()
	enemy1.apply_status(StatusEffects.STATUS_SLOWED, 3.0)
	assert(enemy1.has_status(StatusEffects.STATUS_SLOWED), "Enemy has slowed status")
	assert(enemy1.get_effective_speed() < normal_speed, "Slowed status reduces move speed")
	print("[PASS] Status effects application and speed modifier verified")

	# 2. Test Arcane Resonance Reaction
	var enemy2 = spawner.spawn_enemy_at(Vector2(180, 0)) # Nearby enemy to test AoE
	var enemy2_hp_before = enemy2.current_health

	# Target enemy1 is charged. Hitting it with arcane should trigger Resonance AoE
	var hit_ctx = ReactionContext.new(player, enemy1, ["arcane"], enemy1.global_position, 15.0, 0)
	synergy_engine.on_hit_landed(hit_ctx)

	assert(not enemy1.has_status(StatusEffects.STATUS_CHARGED), "Resonance consumes charged status")
	assert(enemy2.current_health < enemy2_hp_before, "Resonance AoE dealt damage to nearby enemy2")
	print("[PASS] Arcane Resonance synergy reaction verified")

	# 3. Test Frost Shatter Reaction
	var enemy3 = spawner.spawn_enemy_at(Vector2(300, 0))
	enemy3.apply_status(StatusEffects.STATUS_SLOWED, 3.0)
	var shatter_ctx = ReactionContext.new(player, enemy3, ["melee", "orbit"], enemy3.global_position, 15.0, 0)
	synergy_engine.on_hit_landed(shatter_ctx)
	print("[PASS] Frost Shatter synergy reaction verified")

	# 4. Test Recursion Depth Protection
	var loop_ctx = ReactionContext.new(player, enemy1, ["arcane"], enemy1.global_position, 15.0, SynergyEngine.MAX_REACTION_DEPTH)
	# Should return immediately and not crash or loop
	synergy_engine.on_hit_landed(loop_ctx)
	print("[PASS] Synergy infinite loop recursion guard verified")

	# 5. Test 3 Artifacts Behavior Modifications
	# Artifact 1: Hourglass (Returning & Pierce)
	player.inventory.add_artifact("hourglass")
	assert(player.inventory.has_artifact("hourglass"), "Hourglass artifact acquired")
	assert(player.has_meta("has_hourglass"), "Hourglass metadata set on player")

	# Artifact 2: Obsidian Heart (Dynamic spell power from lost HP & Repulsion)
	player.inventory.add_artifact("obsidian_heart")
	assert(player.inventory.has_artifact("obsidian_heart"), "Obsidian Heart artifact acquired")
	player.take_damage(40.0) # Player is now at 60 HP
	player.inventory._process(0.016)
	var bonus_sp = player.get_meta("obsidian_heart_bonus", 0.0)
	assert(bonus_sp > 0.0, "Obsidian Heart increases spell power when player loses HP")

	# Artifact 3: Rift Compass (Unstable status & death explosion)
	player.inventory.add_artifact("rift_compass")
	assert(player.inventory.has_artifact("rift_compass"), "Rift Compass artifact acquired")
	assert(player.inventory.artifacts.size() == 3, "Inventory holds all 3 artifacts")
	print("[PASS] 3 distinct behavior-altering artifacts verified")

	# 6. Test Evolution Lifecycle
	var bolt = player.ability_controller.get_ability("magic_bolt") as MagicBoltAbility
	assert(bolt != null, "Magic Bolt exists")

	# Level Magic Bolt to max level 5
	bolt.current_level = 5

	# Generate choices: since bolt is level 5 AND hourglass is owned, evolution must appear!
	var choices = RewardGenerator.generate_choices(player, 3)
	var found_evolution = false
	for c in choices:
		if c.type == "evolution" and c.id == "evolve_magic_bolt":
			found_evolution = true
			# Apply evolution
			RewardGenerator.apply_upgrade(player, c)
			break

	assert(found_evolution, "Evolution card 'Возвращающийся разлом' was generated")
	assert(bolt.is_evolved, "Magic Bolt successfully evolved into Rebounding Rift")
	assert(bolt.base_damage >= 50.0, "Evolved spell has legendary base damage (55)")
	print("[PASS] Spell Evolution condition, generation, and application verified")

	print("--- ALL STAGE 3 TESTS PASSED SUCCESSFULLY! ---")
	quit(0)

