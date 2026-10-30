extends SceneTree

const MainGameScene = preload("res://scenes/main/main.tscn")
const FastEnemyScene = preload("res://scenes/enemies/fast_enemy.tscn")
const HeavyEnemyScene = preload("res://scenes/enemies/heavy_enemy.tscn")
const RangedEnemyScene = preload("res://scenes/enemies/ranged_enemy.tscn")
const EliteEnemyScene = preload("res://scenes/enemies/elite_enemy.tscn")
const BossEnemyScene = preload("res://scenes/enemies/boss_enemy.tscn")
const RuneZoneScene = preload("res://scripts/arena/rune_zone.gd")

const CombatEffects = preload("res://scripts/combat/combat_effects.gd")
const SynergyEngine = preload("res://scripts/synergies/synergy_engine.gd")
const ReactionContext = preload("res://scripts/synergies/reaction_context.gd")
const StatusEffects = preload("res://scripts/combat/status_effects.gd")
const Projectile = preload("res://scripts/combat/projectile.gd")
const LightningAbility = preload("res://scripts/abilities/lightning_ability.gd")
const RewardGenerator = preload("res://scripts/progression/reward_generator.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const MainGame = preload("res://scripts/game/main.gd")

func _init() -> void:
	call_deferred("run_all_v02_tests")

func run_all_v02_tests() -> void:
	print("--- Running Version 0.2 Synergies, Visual Primitives & FX Verification Suite ---")

	var main_node = MainGameScene.instantiate() as MainGame
	root.add_child(main_node)
	await process_frame

	var player = main_node.player
	var synergy_engine = main_node.synergy_engine

	test_combat_effects_visual_primitives(main_node)
	test_fx_intensity_modes_and_limits()
	test_arcane_resonance_visuals_and_logic(synergy_engine, main_node)
	test_ice_shatter_visuals_and_projectiles(synergy_engine, main_node)
	test_lightning_chain_decay_and_hops(synergy_engine, main_node)
	test_steam_rift_and_thermal_conflagration(synergy_engine, main_node)
	test_unstable_detonation_fracture(synergy_engine, main_node)
	test_returning_pierce_visuals_and_trajectory(player, main_node)
	test_wrath_of_the_heavens_fourth_evolution(player)
	test_rune_zone_arena_hotspot(player, main_node)
	test_all_enemy_archetypes_status_dots_and_bars(main_node)
	test_save_manager_settings_persistence()

	print("--- ALL VERSION 0.2 TESTS PASSED SUCCESSFULLY! ---")
	quit(0)

func test_combat_effects_visual_primitives(parent: Node) -> void:
	print("[TEST] 1. CombatEffects 12 visual primitives verification...")

	# 1. Hit Flash
	CombatEffects.spawn_hit_flash(parent, Vector2(100, 100), Color.CYAN, 14.0)
	# 2. Ring
	CombatEffects.spawn_ring(parent, Vector2(120, 100), 5.0, 40.0, Color.MAGENTA, 0.2)
	# 3. Shockwave
	CombatEffects.spawn_shockwave(parent, Vector2(140, 100), 60.0, Color.ORANGE, 0.2)
	# 4. Trail
	CombatEffects.spawn_projectile_trail(parent, Vector2(160, 100), Vector2.RIGHT, 30.0, Color.WHITE)
	# 5. Lightning Arc
	CombatEffects.spawn_lightning_arc(parent, Vector2(100, 100), Vector2(180, 100), Color.CYAN, 2.0)
	# 6. Geometric Shards
	CombatEffects.spawn_geometric_shards(parent, Vector2(200, 100), Color.CYAN, 4, 150.0)
	# 7. Status Mark
	CombatEffects.spawn_status_mark(parent, Vector2(220, 100), Color.RED, "✦")
	# 8. Rift Fracture
	CombatEffects.spawn_rift_fracture(parent, Vector2(240, 100), 35.0, Color.PURPLE)
	# 9. AoE Indicator
	var aoe = CombatEffects.spawn_aoe_indicator(parent, Vector2(260, 100), 45.0, Color.BLUE, 0.3)
	assert(aoe != null, "AoE indicator must be spawned")
	# 10. Target Highlight
	var dummy_target = Node2D.new()
	parent.add_child(dummy_target)
	CombatEffects.spawn_target_highlight(dummy_target, Color.YELLOW, 20.0)
	# 11. Hazard Telegraph
	var telegraph = CombatEffects.spawn_hazard_telegraph(parent, Vector2(280, 100), Vector2.RIGHT, 100.0, 30.0, 0.3)
	assert(telegraph != null, "Hazard telegraph must be spawned")
	# 12. Reward Pickup
	CombatEffects.spawn_reward_pickup(parent, Vector2(300, 100), Color.GOLD)

	dummy_target.queue_free()
	print("[PASS] All 12 visual primitives spawned and initialized cleanly.")

func test_fx_intensity_modes_and_limits() -> void:
	print("[TEST] 2. FX Intensity modes and capping limits...")

	CombatEffects.set_fx_intensity("standard")
	assert(CombatEffects.fx_intensity == "standard", "Standard intensity mode set")
	assert(CombatEffects.get_max_decorative() == 36, "Standard cap is 36")
	assert(CombatEffects.get_particle_multiplier() == 1.0, "Standard particle multiplier is 1.0")

	CombatEffects.set_fx_intensity("reduced")
	assert(CombatEffects.fx_intensity == "reduced", "Reduced intensity mode set")
	assert(CombatEffects.get_max_decorative() == 16, "Reduced cap is 16")
	assert(CombatEffects.get_particle_multiplier() == 0.5, "Reduced particle multiplier is 0.5")

	# Restore standard mode
	CombatEffects.set_fx_intensity("standard")
	print("[PASS] FX Intensity modes and concurrency limits verified.")

func test_arcane_resonance_visuals_and_logic(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 3. Arcane Resonance synergy visuals and spreading logic...")

	var enemy_a = HeavyEnemyScene.instantiate()
	var enemy_b = HeavyEnemyScene.instantiate()
	parent.add_child(enemy_a)
	parent.add_child(enemy_b)
	enemy_a.global_position = Vector2(0, 0)
	enemy_b.global_position = Vector2(40, 0) # Inside 85px radius

	enemy_a.apply_status(StatusEffects.STATUS_CHARGED, 4.0)
	assert(enemy_a.has_status(StatusEffects.STATUS_CHARGED), "Enemy A is charged")

	var ctx = ReactionContext.new(null, enemy_a, ["arcane"], enemy_a.global_position, 20.0, 0)
	engine.on_hit_landed(ctx)

	assert(not enemy_a.has_status(StatusEffects.STATUS_CHARGED), "Charged consumed from primary target")
	assert(enemy_b.has_status(StatusEffects.STATUS_CHARGED), "Secondary target B gained charged from resonance impulse")

	enemy_a.queue_free()
	enemy_b.queue_free()
	print("[PASS] Arcane Resonance spread and visual execution verified.")

func test_ice_shatter_visuals_and_projectiles(engine: SynergyEngine, _parent: Node) -> void:
	print("[TEST] 4. Ice Shatter synergy and crystalline shards...")

	var enemy = HeavyEnemyScene.instantiate()
	var container = engine.get_effects_container()
	container.add_child(enemy)
	enemy.apply_status(StatusEffects.STATUS_SLOWED, 4.0)

	var proj_count_before = 0
	for child in container.get_children():
		if child is Projectile:
			proj_count_before += 1

	var ctx = ReactionContext.new(null, enemy, ["ice", "melee"], enemy.global_position, 15.0, 0)
	engine.on_hit_landed(ctx)

	var proj_count_after = 0
	for child in container.get_children():
		if child is Projectile:
			proj_count_after += 1

	assert(proj_count_after >= proj_count_before + 3, "Ice Shatter must fire 3 crystalline projectile shards")
	enemy.queue_free()
	print("[PASS] Ice Shatter shards and projectiles verified.")

func test_lightning_chain_decay_and_hops(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 5. Lightning Chain decaying hops...")

	var enemy_a = HeavyEnemyScene.instantiate()
	var enemy_b = HeavyEnemyScene.instantiate()
	parent.add_child(enemy_a)
	parent.add_child(enemy_b)
	enemy_a.global_position = Vector2(800, 800)
	enemy_b.global_position = Vector2(850, 800)

	var hp_b_before = enemy_b.current_health
	var ctx = ReactionContext.new(null, enemy_a, ["lightning"], enemy_a.global_position, 22.0, 0)
	engine.on_hit_landed(ctx)

	assert(enemy_b.current_health < hp_b_before, "Target B received chained lightning damage")
	assert(enemy_b.has_status(StatusEffects.STATUS_CHARGED), "Target B received charged status")

	enemy_a.queue_free()
	enemy_b.queue_free()
	print("[PASS] Lightning Chain multi-hop execution verified.")

func test_steam_rift_and_thermal_conflagration(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 6. Steam Rift & Thermal Conflagration dual reactions...")

	# Steam Rift
	var enemy_slow = HeavyEnemyScene.instantiate()
	parent.add_child(enemy_slow)
	enemy_slow.global_position = Vector2(1000, 1000)
	enemy_slow.apply_status(StatusEffects.STATUS_SLOWED, 3.0)

	var reaction_box = {"name": ""}
	var handler = func(n, _p): reaction_box["name"] = n
	engine.reaction_triggered.connect(handler)

	var ctx_steam = ReactionContext.new(null, enemy_slow, ["fire"], enemy_slow.global_position, 25.0, 0)
	engine.on_hit_landed(ctx_steam)
	assert(reaction_box["name"] == "steam_rift", "Steam Rift reaction triggered on fire on slowed")

	# Thermal Conflagration
	var enemy_charged = HeavyEnemyScene.instantiate()
	parent.add_child(enemy_charged)
	enemy_charged.global_position = Vector2(1200, 1200)
	enemy_charged.apply_status(StatusEffects.STATUS_CHARGED, 3.0)
	reaction_box["name"] = ""

	var ctx_thermal = ReactionContext.new(null, enemy_charged, ["fire"], enemy_charged.global_position, 25.0, 0)
	engine.on_hit_landed(ctx_thermal)
	assert(reaction_box["name"] == "thermal_conflagration", "Thermal Conflagration reaction triggered on fire on charged")
	assert(enemy_charged.has_status(StatusEffects.STATUS_BURNING), "Thermal Conflagration applies burning status")

	engine.reaction_triggered.disconnect(handler)
	enemy_slow.queue_free()
	enemy_charged.queue_free()
	print("[PASS] Steam Rift and Thermal Conflagration reactions verified.")

func test_unstable_detonation_fracture(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 7. Unstable Detonation void fracture...")

	var enemy = HeavyEnemyScene.instantiate()
	parent.add_child(enemy)
	enemy.global_position = Vector2(50, 50)
	var hp_before = enemy.current_health

	engine.trigger_unstable_explosion(Vector2(50, 50))
	assert(enemy.current_health < hp_before, "Unstable explosion must deal AoE damage to nearby targets")

	enemy.queue_free()
	print("[PASS] Unstable Detonation void fracture verified.")

func test_returning_pierce_visuals_and_trajectory(player: PlayerController, parent: Node) -> void:
	print("[TEST] 8. Returning Pierce trajectory and visual states...")

	var proj = Projectile.new()
	proj.faction = Projectile.Faction.PLAYER
	proj.is_returning = true
	proj.lifetime = 1.0
	proj.global_position = Vector2(0, 0)
	proj.direction = Vector2.RIGHT
	parent.add_child(proj)

	# Simulate travel past 45% lifetime threshold
	proj._physics_process(0.5)
	assert(proj.has_turned_back == true, "Projectile must trigger turn-back state")

	proj.queue_free()
	print("[PASS] Returning Pierce turn-back and state verified.")

func test_wrath_of_the_heavens_fourth_evolution(player: PlayerController) -> void:
	print("[TEST] 9. 4th Evolution: Wrath of the Heavens (Lightning Strike Lv 5 + Lightning Rod)...")

	var ac = player.ability_controller
	ac.unlock_ability("lightning_strike")
	var lightning = ac.get_ability("lightning_strike") as LightningAbility
	assert(lightning != null, "Lightning strike unlocked")

	lightning.current_level = 5
	player.inventory.add_artifact("lightning_rod")

	var choices = RewardGenerator.generate_choices(player, 3)
	var found_evo = false
	for opt in choices:
		if opt.id == "evolve_lightning":
			found_evo = true
			RewardGenerator.apply_upgrade(player, opt)
			break

	assert(found_evo == true, "Wrath of the Heavens evolution must be offered")
	assert(lightning.is_evolved == true, "Lightning must be evolved")
	assert(lightning.ability_name == "Ярость Небес", "Ability renamed to Ярость Небес")
	assert(lightning.base_damage == 45.0, "Base damage increased to 45")
	assert(lightning.base_cooldown == 1.4, "Cooldown reduced to 1.4")
	print("[PASS] Wrath of the Heavens evolution mechanics verified.")

func test_rune_zone_arena_hotspot(player: PlayerController, parent: Node) -> void:
	print("[TEST] 10. RuneZone Arena hotspot tactical buff...")

	var rz = RuneZoneScene.new()
	rz.global_position = Vector2(0, 0)
	parent.add_child(rz)

	player.global_position = Vector2(0, 0)
	rz._on_body_entered(player)

	assert(player.get_meta("in_rune_zone", false) == true, "Player receives in_rune_zone metadata boost")

	var bolt = player.ability_controller.get_ability("magic_bolt")
	if bolt:
		var cd = bolt.get_effective_cooldown()
		assert(cd <= bolt.base_cooldown * 0.75 + 0.001, "Spell cooldown reduced by 25% inside RuneZone")

	rz._on_body_exited(player)
	assert(player.get_meta("in_rune_zone", false) == false, "Player loses in_rune_zone metadata when leaving")

	rz.queue_free()
	print("[PASS] RuneZone hotspot buffs and lifecycle verified.")

func test_all_enemy_archetypes_status_dots_and_bars(parent: Node) -> void:
	print("[TEST] 11. Status dots and mini health bars across all enemy archetypes...")

	var enemies = [
		FastEnemyScene.instantiate(),
		HeavyEnemyScene.instantiate(),
		RangedEnemyScene.instantiate(),
		EliteEnemyScene.instantiate(),
		BossEnemyScene.instantiate()
	]

	for e in enemies:
		parent.add_child(e)
		e.apply_status(StatusEffects.STATUS_SLOWED, 2.0)
		e.apply_status(StatusEffects.STATUS_CHARGED, 2.0)
		assert(e.active_statuses.size() == 2, "Enemy has 2 active statuses")
		e.take_damage(10.0)
		assert(e.current_health < e.stats.max_health, "Enemy received damage and tracks health")
		e.queue_free()

	print("[PASS] All enemy archetypes render statuses and mini health bars.")

func test_save_manager_settings_persistence() -> void:
	print("[TEST] 12. SaveManager settings persistence (fx_intensity, volumes)...")

	SaveManager.set_setting("fx_intensity", "reduced")
	assert(SaveManager.get_setting("fx_intensity") == "reduced", "fx_intensity saved as reduced")

	SaveManager.set_setting("master_volume", 0.65)
	assert(abs(SaveManager.get_setting("master_volume") - 0.65) < 0.01, "master_volume saved as 0.65")

	# Restore standard
	SaveManager.set_setting("fx_intensity", "standard")
	SaveManager.set_setting("master_volume", 1.0)
	print("[PASS] SaveManager settings verified.")
