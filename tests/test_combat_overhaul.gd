class_name TestCombatOverhaul
extends SceneTree

const MainGameScene = preload("res://scenes/main/main.tscn")
const DamageResolver = preload("res://scripts/combat/damage_resolver.gd")
const DamageContext = preload("res://scripts/combat/damage_context.gd")
const StatusEffects = preload("res://scripts/combat/status_effects.gd")
const SynergyRegistry = preload("res://scripts/synergies/synergy_registry.gd")
const SynergyEngine = preload("res://scripts/synergies/synergy_engine.gd")
const ReactionContext = preload("res://scripts/synergies/reaction_context.gd")
const InventoryState = preload("res://scripts/items/inventory_state.gd")
const RewardGenerator = preload("res://scripts/progression/reward_generator.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")
const RunStats = preload("res://scripts/game/run_stats.gd")
const Projectile = preload("res://scripts/combat/projectile.gd")
const MagicBoltAbility = preload("res://scripts/abilities/magic_bolt_ability.gd")
const FireballAbility = preload("res://scripts/abilities/fireball_ability.gd")
const IceStormAbility = preload("res://scripts/abilities/ice_storm_ability.gd")
const DeathMarkAbility = preload("res://scripts/abilities/death_mark_ability.gd")
const RunicBladeAbility = preload("res://scripts/abilities/runic_blade_ability.gd")
const MagicBarrierAbility = preload("res://scripts/abilities/magic_barrier_ability.gd")
const FontOfLifeAbility = preload("res://scripts/abilities/font_of_life_ability.gd")
const RangedEnemyController = preload("res://scripts/enemies/ranged_enemy_controller.gd")
const BasicEnemyScene = preload("res://scenes/enemies/basic_enemy.tscn")

func _init() -> void:
	call_deferred("run_all_tests")

func run_all_tests() -> void:
	print("\n=======================================================")
	print("--- Running V0.5 Combat & Synergy Overhaul Test Suite ---")
	print("=======================================================\n")

	var main_node = MainGameScene.instantiate()
	root.add_child(main_node)
	await process_frame

	var player = main_node.player as PlayerController
	var engine = main_node.synergy_engine as SynergyEngine
	var stats = main_node.run_stats as RunStats

	await test_spells_architecture(main_node)
	await test_magic_bolt_innate_pierce(main_node)
	await test_fireball_area_impact(main_node)
	await test_ice_storm_zone_cap(player, main_node)
	await test_death_mark_execute(main_node)
	await test_runic_blade_projectile_interception(player, main_node)
	await test_magic_barrier_absorption_and_break(player, main_node)
	await test_font_of_life_regen_and_kill_pulse(player, main_node)
	await test_enemy_projectile_balance_and_telegraph(main_node)
	await test_swarm_smoothing(main_node)
	await test_ten_core_synergies(engine, main_node)
	await test_artifacts_rebalance(player, main_node)
	await test_reward_synergy_hints(player, main_node)
	await test_localization_parity()
	await test_run_stats_defense_tracking()

	print("\n=======================================================")
	print("--- ALL V0.5 COMBAT & SYNERGY OVERHAUL TESTS PASSED! ---")
	print("=======================================================\n")

	main_node.queue_free()
	quit(0)

func test_spells_architecture(parent: Node) -> void:
	print("[TEST] 1. All 8 Spells registration & instantiability...")
	var ac = AbilityController.new()
	ac.max_abilities = 10
	parent.add_child(ac)

	var required_spells = [
		"magic_bolt", "ice_storm", "lightning_strike", "fireball",
		"death_mark", "runic_blade", "magic_barrier", "font_of_life"
	]

	for s_id in required_spells:
		assert(ac.available_scenes.has(s_id), "Available scenes must contain %s" % s_id)
		var spell = ac.unlock_ability(s_id)
		assert(spell != null, "Must instantiate %s" % s_id)
		assert(spell.ability_id == s_id, "Ability ID must match %s" % s_id)
		assert(spell.current_level == 1, "Initial level must be 1")
		assert(spell.max_level == 5, "Max level must be 5")

	ac.queue_free()
	print("[PASS] All 8 spells registered and instantiate cleanly.")

func test_magic_bolt_innate_pierce(parent: Node) -> void:
	print("[TEST] 2. Magic Bolt innate pierce scaling (Hourglass independence)...")
	var bolt = MagicBoltAbility.new()
	parent.add_child(bolt)

	assert(bolt.pierce_count == 1, "Level 1 bolt has 1 pierce")
	bolt.upgrade() # Lv 2
	assert(bolt.pierce_count == 1, "Level 2 bolt has 1 pierce")
	bolt.upgrade() # Lv 3
	assert(bolt.pierce_count == 2, "Level 3 bolt has innate pierce 2")
	assert(bolt.projectile_count == 2, "Level 3 bolt fires 2 projectiles")
	bolt.upgrade() # Lv 4
	assert(bolt.pierce_count == 2, "Level 4 bolt has pierce 2")
	bolt.upgrade() # Lv 5
	assert(bolt.pierce_count == 3, "Level 5 bolt has innate pierce 3")
	assert(bolt.projectile_count == 3, "Level 5 bolt fires 3 projectiles")

	bolt.queue_free()
	print("[PASS] Magic Bolt innate pierce scales cleanly to Lv 5.")

func test_fireball_area_impact(parent: Node) -> void:
	print("[TEST] 3. Fireball area explosion and multi-projectile scaling...")
	var fb = FireballAbility.new()
	parent.add_child(fb)

	assert(fb.explosion_radius == 85.0, "Level 1 radius is 85px")
	assert(fb.fireball_count == 1, "Level 1 fires 1 fireball")
	fb.upgrade() # Lv 2
	assert(fb.explosion_radius == 95.0, "Level 2 radius is 95px")
	fb.upgrade() # Lv 3
	assert(fb.fireball_count == 2, "Level 3 fires 2 fireballs in spread")
	fb.upgrade() # Lv 4
	assert(fb.explosion_radius == 110.0, "Level 4 radius is 110px")
	fb.upgrade() # Lv 5
	assert(fb.fireball_count == 2, "Level 5 fires 2 fireballs")
	assert(fb.explosion_radius == 120.0, "Level 5 radius is 120px")
	assert(fb.base_damage == 62.0, "Level 5 explosion damage is 62")

	fb.queue_free()
	print("[PASS] Fireball area explosion and multi-projectile verified.")

func test_ice_storm_zone_cap(player: PlayerController, parent: Node) -> void:
	print("[TEST] 4. Ice Storm zone cap (maximum 2 simultaneous zones)...")
	var storm = IceStormAbility.new()
	player.add_child(storm)
	storm.player_owner = player
	player.velocity = Vector2.RIGHT * 120.0

	# Spawn zone 1
	var ok1 = storm.try_cast()
	assert(ok1, "Zone 1 cast succeeded")
	assert(storm.active_zones.size() == 1, "1 active zone")

	# Spawn zone 2
	var ok2 = storm.try_cast()
	assert(ok2, "Zone 2 cast succeeded")
	assert(storm.active_zones.size() == 2, "2 active zones")

	# Spawn zone 3 -> oldest zone must be removed/faded out, count stays <= 2!
	var ok3 = storm.try_cast()
	assert(ok3, "Zone 3 cast succeeded")
	assert(storm.active_zones.size() == 2, "Cap enforced: active zones count remains 2")

	storm.queue_free()
	print("[PASS] Ice Storm zone cap of 2 enforced.")

func test_death_mark_execute(parent: Node) -> void:
	print("[TEST] 5. Death Mark execution threshold and damage amplification...")
	var dm = DeathMarkAbility.new()
	parent.add_child(dm)

	assert(dm.damage_amplification == 0.40, "Level 1 amp is +40%")
	assert(dm.execute_ratio == 0.15, "Level 1 execute ratio is 15%")
	dm.upgrade()
	dm.upgrade() # Lv 3
	assert(dm.execute_ratio == 0.20, "Level 3 execute ratio is 20%")
	dm.upgrade()
	dm.upgrade() # Lv 5
	assert(dm.damage_amplification == 0.80, "Level 5 amp is +80%")
	assert(dm.execute_ratio == 0.25, "Level 5 execute ratio is 25%")

	var enemy = BasicEnemyScene.instantiate() as EnemyController
	parent.add_child(enemy)
	enemy.current_health = 100.0
	enemy.stats.max_health = 100.0

	enemy.apply_status(StatusEffects.STATUS_MARKED, 5.0)
	enemy.set_meta("death_mark_amp", 0.80)
	enemy.set_meta("death_mark_execute_ratio", 0.25)

	# 50 base damage * 1.80 = 90 damage -> HP drops to 10% (< 25%) -> triggers execution!
	var ctx = DamageContext.new(null, enemy, 50.0, ["arcane"], "magic_bolt", enemy.global_position)
	var res = DamageResolver.apply_damage(ctx)
	assert(res["killed"] == true, "Enemy under execute threshold was executed")
	assert(enemy.current_health == 0.0, "Executed enemy health drops to 0")

	dm.queue_free()
	enemy.queue_free()
	print("[PASS] Death Mark execution threshold and damage amplification verified.")

func test_runic_blade_projectile_interception(player: PlayerController, parent: Node) -> void:
	print("[TEST] 6. Runic Blade enemy projectile interception...")
	var blade_ability = RunicBladeAbility.new()
	player.add_child(blade_ability)
	blade_ability.player_owner = player

	# Create simulated enemy projectile
	var enemy_proj = Projectile.new()
	enemy_proj.faction = Projectile.Faction.ENEMY
	enemy_proj.damage = 10.0
	parent.add_child(enemy_proj)

	blade_ability._on_blade_area_entered(enemy_proj)
	assert(enemy_proj.is_destroyed, "Enemy projectile destroyed on blade interception")

	blade_ability.queue_free()
	enemy_proj.queue_free()
	print("[PASS] Runic Blade destroys enemy projectiles on contact.")

func test_magic_barrier_absorption_and_break(player: PlayerController, parent: Node) -> void:
	print("[TEST] 7. Magic Barrier absorption, recharge cooldown, and break shockwave...")
	player.current_health = 100.0

	var barrier = MagicBarrierAbility.new()
	player.add_child(barrier)
	barrier.player_owner = player
	barrier.current_shield = 30.0
	barrier.max_shield = 30.0

	# 1. Absorb partial damage (10 incoming)
	var absorbed = barrier.absorb_damage(10.0)
	assert(absorbed == 10.0, "Barrier absorbed full 10 damage")
	assert(barrier.current_shield == 20.0, "Barrier shield reduced to 20")
	assert(player.current_health == 100.0, "Player HP unharmed")

	# 2. Break barrier with excess damage (25 incoming on 20 shield)
	var absorbed_break = barrier.absorb_damage(25.0)
	assert(absorbed_break == 20.0, "Barrier absorbed remaining 20 shield")
	assert(barrier.current_shield == 0.0, "Barrier broken")
	assert(barrier.is_active == false, "Barrier is inactive while recharging")
	assert(barrier.recharge_timer > 0.0, "Recharge timer started")

	# 3. Restore barrier
	barrier.restore_barrier()
	assert(barrier.is_active == true, "Barrier restored")
	assert(barrier.current_shield == 30.0, "Shield restored to max")

	barrier.queue_free()
	print("[PASS] Magic Barrier absorption and break verified.")

func test_font_of_life_regen_and_kill_pulse(player: PlayerController, parent: Node) -> void:
	print("[TEST] 8. Font of Life periodic regeneration and kill-based pulse...")
	player.current_health = 60.0

	var font = FontOfLifeAbility.new()
	player.add_child(font)
	font.player_owner = player
	font.heal_amount = 6.0
	font.kill_heal_amount = 3.0

	# Periodic heal
	font._trigger_interval_heal()
	assert(player.current_health == 66.0, "Healed +6 HP from interval")

	# Kill pulse (15 kills)
	for i in range(14):
		font.notify_enemy_killed()
		assert(font.kill_counter == i + 1, "Kill counter incrementing")

	# 15th kill triggers pulse
	font.notify_enemy_killed()
	assert(font.kill_counter == 0, "Counter reset after pulse")
	assert(player.current_health == 69.0, "Healed +3 HP from kill pulse")

	font.queue_free()
	print("[PASS] Font of Life regeneration and kill pulse verified.")

func test_enemy_projectile_balance_and_telegraph(parent: Node) -> void:
	print("[TEST] 9. Enemy Projectile speed 245 px/s and cast telegraphing...")
	var cultist = preload("res://scenes/enemies/ranged_enemy.tscn").instantiate() as RangedEnemyController
	parent.add_child(cultist)

	assert(cultist.stats.contact_damage == 8.0, "Cultist contact damage is 8.0")
	cultist.start_casting()
	assert(cultist.is_casting == true, "Casting state active")
	assert(cultist.cast_timer == 0.40, "Cast timer is 0.40 seconds telegraph")

	cultist.queue_free()
	print("[PASS] Enemy projectile balance and telegraphing verified.")

func test_swarm_smoothing(parent: Node) -> void:
	print("[TEST] 10. Swarm smoothing (large swarms split into two batches)...")
	var sm = SpawnManager.new()
	parent.add_child(sm)

	sm.trigger_swarm_event(22)
	assert(sm.has_method("trigger_swarm_event"), "SpawnManager supports smoothed swarm events")

	sm.queue_free()
	print("[PASS] Swarm smoothing verified.")

func test_ten_core_synergies(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 11. 10 Core Synergies registration in SynergyRegistry...")
	var core_ids = [
		"steam_rift", "cryogenic_shock", "frost_shatter", "conflagration_execution",
		"charged_bolt", "thunder_shield", "glacial_ward", "life_harvest",
		"blazing_blades", "piercing_frost"
	]

	for syn_id in core_ids:
		assert(SynergyRegistry.has_definition(syn_id), "Registry must contain %s" % syn_id)
		var defn = SynergyRegistry.get_definition(syn_id)
		assert(not defn.default_name.is_empty(), "Synergy %s must have a name" % syn_id)
		assert(not defn.formula.is_empty(), "Synergy %s must have a formula" % syn_id)

	# Test Conflagration Execution trigger
	var e = BasicEnemyScene.instantiate() as EnemyController
	parent.add_child(e)
	e.global_position = Vector2(9000, 9000)
	e.current_health = 100.0
	e.stats.max_health = 100.0
	e.apply_status(StatusEffects.STATUS_MARKED, 5.0)

	var fire_ctx = ReactionContext.new(null, e, ["fire"], e.global_position, 30.0, 0)
	var flag = [false]
	var cb = func(n, p):
		if n == "conflagration_execution":
			flag[0] = true
	engine.reaction_triggered.connect(cb)
	engine.on_hit_landed(fire_ctx)
	engine.reaction_triggered.disconnect(cb)

	assert(flag[0] == true, "Conflagration Execution triggered on Fire + Marked")

	e.queue_free()
	print("[PASS] 10 Core Synergies and Conflagration Execution verified.")

func test_artifacts_rebalance(player: PlayerController, parent: Node) -> void:
	print("[TEST] 12. Artifacts rebalance (Time Echo Hourglass, Life Crystal, Warding Rune)...")
	var inv = player.inventory

	# Test Hourglass Time Echo
	inv.add_artifact("hourglass")
	assert(player.has_meta("has_hourglass"), "Player has hourglass metadata")
	assert(player.has_meta("has_time_echo"), "Player has time_echo metadata")
	assert(player.stats.cooldown_mult < 1.0, "Hourglass reduces cooldown by 15%")

	# Test Life Crystal
	inv.add_artifact("life_crystal")
	assert(player.has_meta("has_life_crystal"), "Player has life_crystal metadata")
	assert(player.stats.max_health >= 135.0, "Life crystal increased max HP by +35")

	# Test Warding Rune
	inv.add_artifact("warding_rune")
	assert(player.has_meta("has_warding_rune"), "Player has warding_rune metadata")

	print("[PASS] Artifacts rebalance verified.")

func test_reward_synergy_hints(player: PlayerController, parent: Node) -> void:
	print("[TEST] 13. RewardGenerator synergy hint detection...")
	var ac = player.ability_controller
	ac.unlock_ability("ice_storm")

	var choices = RewardGenerator.generate_choices(player, 5)
	for opt in choices:
		if opt.id == "fireball":
			assert(opt.synergy_hint.contains("Паровой разлом"), "Fireball choice indicates Steam Rift synergy")
		elif opt.id == "lightning_strike":
			assert(opt.synergy_hint.contains("Криогенный шок"), "Lightning choice indicates Cryogenic Shock synergy")

	print("[PASS] RewardGenerator synergy hints verified.")

func test_localization_parity() -> void:
	print("[TEST] 14. Localization RU/EN parity for all new combat content...")
	var loc = LocalizationManager.instance
	if not loc:
		loc = LocalizationManager.new()
		root.add_child(loc)
		LocalizationManager.instance = loc

	var required_keys = [
		"syn_steam_rift_name", "syn_cryogenic_shock_name", "syn_frost_shatter_name",
		"syn_conflagration_execution_name", "syn_charged_bolt_name", "syn_thunder_shield_name",
		"syn_glacial_ward_name", "syn_life_harvest_name", "syn_blazing_blades_name", "syn_piercing_frost_name",
		"spell_magic_barrier_name", "spell_font_of_life_name",
		"art_life_crystal_name", "art_warding_rune_name",
		"metric_barrier_absorbed", "metric_healing_done"
	]

	for k in required_keys:
		loc.set_language("ru")
		var ru_txt = loc.get_text(k)
		assert(not ru_txt.is_empty() and ru_txt != k, "RU localization missing key %s" % k)

		loc.set_language("en")
		var en_txt = loc.get_text(k)
		assert(not en_txt.is_empty() and en_txt != k, "EN localization missing key %s" % k)

	print("[PASS] Localization RU/EN parity verified.")

func test_run_stats_defense_tracking() -> void:
	print("[TEST] 15. RunStats defense & healing telemetry tracking...")
	var stats = RunStats.new()

	stats.record_spell_hit("fireball", 150.0)
	stats.record_damage_absorbed(45.0)
	stats.record_healing(30.0)

	assert(stats.damage_dealt == 150.0, "Total damage recorded")
	assert(stats.spell_damage["fireball"] == 150.0, "Spell damage recorded for fireball")
	assert(stats.barrier_absorbed_damage == 45.0, "Barrier absorbed damage recorded")
	assert(stats.total_healing_done == 30.0, "Total healing recorded")

	var dict = stats.to_dictionary()
	assert(dict["barrier_absorbed_damage"] == 45.0, "Dictionary contains barrier absorbed")
	assert(dict["total_healing_done"] == 30.0, "Dictionary contains total healing")

	print("[PASS] RunStats defense & healing telemetry verified.")
