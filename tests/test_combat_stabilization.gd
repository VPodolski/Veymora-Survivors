class_name TestCombatStabilization
extends SceneTree

const MainGameScene = preload("res://scenes/main/main.tscn")
const DamageResolver = preload("res://scripts/combat/damage_resolver.gd")
const DamageContext = preload("res://scripts/combat/damage_context.gd")
const StatusEffects = preload("res://scripts/combat/status_effects.gd")
const SynergyRegistry = preload("res://scripts/synergies/synergy_registry.gd")
const SynergyEngine = preload("res://scripts/synergies/synergy_engine.gd")
const ReactionContext = preload("res://scripts/synergies/reaction_context.gd")
const RunStats = preload("res://scripts/game/run_stats.gd")
const BasicEnemyScene = preload("res://scenes/enemies/basic_enemy.tscn")
const MagicBoltAbility = preload("res://scripts/abilities/magic_bolt_ability.gd")
const FireballAbility = preload("res://scripts/abilities/fireball_ability.gd")
const IceStormAbility = preload("res://scripts/abilities/ice_storm_ability.gd")
const DeathMarkAbility = preload("res://scripts/abilities/death_mark_ability.gd")
const LightningAbility = preload("res://scripts/abilities/lightning_ability.gd")
const RunicBladeAbility = preload("res://scripts/abilities/runic_blade_ability.gd")
const MagicBarrierAbility = preload("res://scripts/abilities/magic_barrier_ability.gd")
const FontOfLifeAbility = preload("res://scripts/abilities/font_of_life_ability.gd")
const Projectile = preload("res://scripts/combat/projectile.gd")
const RewardGenerator = preload("res://scripts/progression/reward_generator.gd")

func _init() -> void:
	call_deferred("run_all_tests")

func run_all_tests() -> void:
	print("\n=======================================================")
	print("--- Running V0.5.1 Combat Stabilization Test Suite ---")
	print("=======================================================\n")

	var main_node = MainGameScene.instantiate()
	root.add_child(main_node)
	await process_frame

	var player = main_node.player as PlayerController
	var engine = main_node.synergy_engine as SynergyEngine
	var stats = main_node.run_stats as RunStats
	RunStats.active_stats = stats

	await test_1_1_single_death_reaction(engine, main_node)
	await test_1_2_charged_bolt_reaction(engine, player, main_node)
	await test_1_3_font_overheal_armor(player, main_node)
	await test_2_all_ten_synergies_behavior(engine, player, main_node)
	await test_3_telemetry_accuracy(stats, player, main_node)
	await test_4_ice_storm_balance(main_node)
	await test_5_thunder_shield_threshold(engine, player, main_node)
	await test_6_lethal_vs_nonlethal_hits(engine, main_node)
	await test_7_reward_generator_count_and_evolutions(player)

	print("\n=======================================================")
	print("--- ALL V0.5.1 COMBAT STABILIZATION TESTS PASSED! ---")
	print("=======================================================\n")

	main_node.queue_free()
	quit(0)

# -----------------------------------------------------------------------------
# 1.1 Single Death Reaction Trigger
# -----------------------------------------------------------------------------
func test_1_1_single_death_reaction(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 1.1 Single Death Reaction (No Duplicate Death Triggers)...")
	engine.reset()

	var enemy = BasicEnemyScene.instantiate() as EnemyController
	parent.add_child(enemy)
	enemy.global_position = Vector2(8000, 8000)
	enemy.current_health = 20.0
	enemy.stats.max_health = 20.0
	enemy.apply_status(StatusEffects.STATUS_MARKED, 5.0)
	enemy.apply_status(StatusEffects.STATUS_UNSTABLE, 5.0)

	var counts = {"soul_harvest": 0, "unstable_explosion": 0}
	var death_cb = func(n, _p):
		if counts.has(n):
			counts[n] += 1

	engine.reaction_triggered.connect(death_cb)

	# Apply lethal damage through DamageResolver
	var ctx = DamageContext.new(null, enemy, 30.0, ["generic"], "test", enemy.global_position)
	var res = DamageResolver.apply_damage(ctx)

	assert(res["killed"] == true, "Enemy must be reported killed")
	assert(enemy.is_dead == true, "Enemy is_dead must be true")
	assert(counts["soul_harvest"] == 1, "Soul Harvest must trigger exactly ONCE (got %d)" % counts["soul_harvest"])
	assert(counts["unstable_explosion"] == 1, "Unstable explosion must trigger exactly ONCE (got %d)" % counts["unstable_explosion"])

	# Verify re-entrant die() call is ignored
	enemy.die()
	assert(counts["soul_harvest"] == 1, "Re-entrant die() must NOT re-trigger Soul Harvest")
	assert(counts["unstable_explosion"] == 1, "Re-entrant die() must NOT re-trigger Unstable Explosion")

	engine.reaction_triggered.disconnect(death_cb)
	enemy.queue_free()
	print("[PASS] 1.1 Exactly one death reaction triggered on enemy demise.")

# -----------------------------------------------------------------------------
# 1.2 Charged Bolt
# -----------------------------------------------------------------------------
func test_1_2_charged_bolt_reaction(engine: SynergyEngine, player: PlayerController, parent: Node) -> void:
	print("[TEST] 1.2 Charged Bolt Reaction & Discard of Old Resonance...")
	engine.reset()

	# Equip player with Magic Bolt and Lightning Strike
	player.ability_controller.unlock_ability("magic_bolt")
	player.ability_controller.unlock_ability("lightning_strike")

	var target = BasicEnemyScene.instantiate() as EnemyController
	parent.add_child(target)
	target.global_position = Vector2(8100, 8100)
	target.current_health = 80.0
	target.stats.max_health = 80.0
	target.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	var sec_enemy = BasicEnemyScene.instantiate() as EnemyController
	parent.add_child(sec_enemy)
	sec_enemy.global_position = Vector2(8150, 8100) # within 120px radius
	sec_enemy.current_health = 60.0
	sec_enemy.stats.max_health = 60.0

	var triggered_reactions: Array[String] = []
	var cb = func(n, _p): triggered_reactions.append(n)
	engine.reaction_triggered.connect(cb)

	# Hit with Arcane tag on Charged target
	var hit_ctx = ReactionContext.new(null, target, ["arcane"], target.global_position, 20.0, 0)
	engine.on_hit_landed(hit_ctx)

	assert(triggered_reactions.has("charged_bolt"), "Charged Bolt MUST be triggered")
	assert(not triggered_reactions.has("resonance"), "Old Resonance reaction MUST NOT be triggered")
	assert(not target.has_status(StatusEffects.STATUS_CHARGED), "Charged status on primary target must be consumed")
	assert(sec_enemy.has_status(StatusEffects.STATUS_CHARGED), "Secondary target must receive Charged status")
	assert(sec_enemy.current_health < 60.0, "Secondary target must take reaction damage")

	# Check cooldown: immediate second hit must not trigger charged bolt again
	triggered_reactions.clear()
	target.apply_status(StatusEffects.STATUS_CHARGED, 4.0)
	engine.on_hit_landed(hit_ctx)
	assert(not triggered_reactions.has("charged_bolt"), "Charged Bolt cooldown must prevent duplicate trigger")

	engine.reaction_triggered.disconnect(cb)
	target.queue_free()
	sec_enemy.queue_free()
	print("[PASS] 1.2 Charged Bolt triggers cleanly without triggering old resonance.")

# -----------------------------------------------------------------------------
# 1.3 Font of Life Overheal Armor
# -----------------------------------------------------------------------------
func test_1_3_font_overheal_armor(player: PlayerController, parent: Node) -> void:
	print("[TEST] 1.3 Font of Life Temporary Overheal Armor & Expiry...")
	player.current_health = 100.0
	player.stats.max_health = 100.0
	if player.has_meta("font_overheal_armor"):
		player.remove_meta("font_overheal_armor")

	var font = FontOfLifeAbility.new()
	player.add_child(font)
	font.player_owner = player
	font.current_level = 5 # Level 5 gives overheal armor
	font.overheal_armor_duration = 2.0

	# 1. Overheal trigger
	font._trigger_interval_heal()
	assert(player.has_meta("font_overheal_armor"), "Player must have font_overheal_armor meta")
	assert(font.has_overheal_armor() == true, "Font must indicate active overheal armor")
	assert(abs(player.get_meta("font_overheal_armor") - 0.15) < 0.001, "Armor bonus must be 15%")

	# 2. Damage mitigation: 20 incoming damage mitigated by 15% -> 17 damage taken
	var dmg_ctx = DamageContext.new(null, player, 20.0, ["enemy_damage"], "enemy", player.global_position)
	player.invulnerable_timer = 0.0
	var res = DamageResolver.apply_damage(dmg_ctx)
	assert(abs(res["damage_dealt"] - 17.0) < 0.01, "Damage should be 17.0 (mitigated by 15%%), got %f" % res["damage_dealt"])
	assert(abs(player.current_health - 83.0) < 0.01, "Player health must be 83.0")

	# 3. Re-healing while full refreshes duration without stacking defense
	player.current_health = 100.0
	font._trigger_interval_heal()
	assert(abs(player.get_meta("font_overheal_armor") - 0.15) < 0.001, "Armor bonus remains 15%, no infinite stack")
	assert(font.overheal_armor_timer >= 1.9, "Duration refreshed to 2.0s")

	# 4. Timer expiry
	font._physics_process(2.5)
	assert(font.has_overheal_armor() == false, "Armor should expire after duration")
	assert(not player.has_meta("font_overheal_armor"), "font_overheal_armor meta must be removed")

	# 5. Damage after expiry has 0 mitigation
	player.current_health = 100.0
	player.invulnerable_timer = 0.0
	var res2 = DamageResolver.apply_damage(dmg_ctx)
	assert(abs(res2["damage_dealt"] - 20.0) < 0.01, "Full 20.0 damage taken after armor expiry")

	font.queue_free()
	print("[PASS] 1.3 Temporary overheal armor applies, refreshes, and cleanly expires.")

# -----------------------------------------------------------------------------
# 2. All 10 Core Synergies Behavior Testing
# -----------------------------------------------------------------------------
func test_2_all_ten_synergies_behavior(engine: SynergyEngine, player: PlayerController, parent: Node) -> void:
	print("[TEST] 2. Behavior testing for all 10 Core Synergies...")
	var core_synergies = SynergyRegistry.get_core_synergies()
	assert(core_synergies.size() == 10, "Must have exactly 10 core synergies registered")
	player.ability_controller.max_abilities = 10

	for syn in core_synergies:
		engine.reset()
		var s_id = syn.id
		var triggered_names: Array[String] = []
		var cb = func(n, _p): triggered_names.append(n)
		engine.reaction_triggered.connect(cb)

		var target = BasicEnemyScene.instantiate() as EnemyController
		parent.add_child(target)
		target.global_position = Vector2(8500, 8500)
		target.current_health = 150.0
		target.stats.max_health = 150.0

		var neighbor = BasicEnemyScene.instantiate() as EnemyController
		parent.add_child(neighbor)
		neighbor.global_position = Vector2(8560, 8500)
		neighbor.current_health = 150.0
		neighbor.stats.max_health = 150.0

		match s_id:
			"steam_rift":
				player.ability_controller.unlock_ability("ice_storm")
				player.ability_controller.unlock_ability("fireball")
				target.apply_status(StatusEffects.STATUS_SLOWED, 3.0)
				var ctx = ReactionContext.new(null, target, ["fire"], target.global_position, 25.0, 0)
				engine.on_hit_landed(ctx)
				assert(triggered_names.has("steam_rift"), "Steam Rift triggered")

			"cryogenic_shock":
				player.ability_controller.unlock_ability("ice_storm")
				player.ability_controller.unlock_ability("lightning_strike")
				target.apply_status(StatusEffects.STATUS_SLOWED, 3.0)
				var ctx = ReactionContext.new(null, target, ["lightning"], target.global_position, 25.0, 0)
				engine.on_hit_landed(ctx)
				assert(triggered_names.has("cryogenic_shock"), "Cryogenic Shock triggered")

			"frost_shatter":
				player.ability_controller.unlock_ability("ice_storm")
				player.ability_controller.unlock_ability("runic_blade")
				target.apply_status(StatusEffects.STATUS_SLOWED, 3.0)
				var ctx = ReactionContext.new(null, target, ["melee", "orbit"], target.global_position, 25.0, 0)
				engine.on_hit_landed(ctx)
				assert(triggered_names.has("frost_shatter"), "Frost Shatter triggered")

			"conflagration_execution":
				player.ability_controller.unlock_ability("fireball")
				player.ability_controller.unlock_ability("death_mark")
				target.apply_status(StatusEffects.STATUS_MARKED, 5.0)
				var ctx = ReactionContext.new(null, target, ["fire"], target.global_position, 30.0, 0)
				engine.on_hit_landed(ctx)
				assert(triggered_names.has("conflagration_execution"), "Conflagration Execution triggered")

			"charged_bolt":
				player.ability_controller.unlock_ability("magic_bolt")
				player.ability_controller.unlock_ability("lightning_strike")
				target.apply_status(StatusEffects.STATUS_CHARGED, 4.0)
				var ctx = ReactionContext.new(null, target, ["arcane"], target.global_position, 20.0, 0)
				engine.on_hit_landed(ctx)
				assert(triggered_names.has("charged_bolt"), "Charged Bolt triggered")

			"thunder_shield":
				player.ability_controller.unlock_ability("magic_barrier")
				player.ability_controller.unlock_ability("lightning_strike")
				target.global_position = player.global_position + Vector2(60, 0)
				engine.on_barrier_absorbed(player, 30.0) # passes 25.0 threshold
				assert(triggered_names.has("thunder_shield"), "Thunder Shield triggered")

			"glacial_ward":
				player.ability_controller.unlock_ability("magic_barrier")
				player.ability_controller.unlock_ability("ice_storm")
				target.global_position = player.global_position + Vector2(60, 0)
				engine.on_barrier_broken(player, 120.0)
				assert(triggered_names.has("glacial_ward"), "Glacial Ward triggered")

			"life_harvest":
				player.ability_controller.unlock_ability("font_of_life")
				player.ability_controller.unlock_ability("death_mark")
				player.current_health = 70.0
				target.apply_status(StatusEffects.STATUS_MARKED, 5.0)
				engine.on_enemy_death(target)
				assert(triggered_names.has("life_harvest"), "Life Harvest triggered")
				assert(player.current_health >= 79.0, "Player healed +9 from Life Harvest")

			"blazing_blades":
				player.ability_controller.unlock_ability("runic_blade")
				player.ability_controller.unlock_ability("fireball")
				var ctx = ReactionContext.new(null, target, ["melee", "orbit", "runic_blade"], target.global_position, 20.0, 0)
				engine.on_hit_landed(ctx)
				assert(triggered_names.has("blazing_blades"), "Blazing Blades triggered")
				assert(target.has_status(StatusEffects.STATUS_BURNING), "Target ignited with burning")

			"piercing_frost":
				player.ability_controller.unlock_ability("ice_storm")
				player.ability_controller.unlock_ability("magic_bolt")
				target.apply_status(StatusEffects.STATUS_SLOWED, 3.0)
				var ctx = ReactionContext.new(null, target, ["arcane"], target.global_position, 20.0, 0)
				engine.on_hit_landed(ctx)
				assert(triggered_names.has("piercing_frost"), "Piercing Frost triggered")

		engine.reaction_triggered.disconnect(cb)
		target.queue_free()
		neighbor.queue_free()

	print("[PASS] 2. All 10 Core Synergies verified in actual game combat flow.")

# -----------------------------------------------------------------------------
# 3. Telemetry Accuracy & Healing Tracking
# -----------------------------------------------------------------------------
func test_3_telemetry_accuracy(stats: RunStats, player: PlayerController, parent: Node) -> void:
	print("[TEST] 3. Telemetry Accuracy (Actual Damage, Healing, Projectiles Intercepted)...")
	stats.reset()

	# 1. Healing test: Player has 90/100 HP, heal 20 -> actual healed is 10.0
	player.current_health = 90.0
	player.stats.max_health = 100.0
	player.heal(20.0)
	assert(player.current_health == 100.0, "Player health capped at 100")
	assert(abs(stats.total_healing_done - 10.0) < 0.01, "Stats must record exactly 10.0 actual healed, got %f" % stats.total_healing_done)

	# 2. Overkill test: Enemy has 15 HP, hit for 50 -> actual damage dealt is 15.0
	var enemy = BasicEnemyScene.instantiate() as EnemyController
	parent.add_child(enemy)
	enemy.current_health = 15.0
	enemy.stats.max_health = 15.0

	var ctx = DamageContext.new(null, enemy, 50.0, ["arcane"], "magic_bolt", enemy.global_position)
	var res = DamageResolver.apply_damage(ctx)
	assert(abs(res["damage_dealt"] - 15.0) < 0.01, "DamageResolver reports 15.0 actual damage dealt")
	assert(abs(stats.damage_dealt - 15.0) < 0.01, "RunStats reports 15.0 actual damage dealt, got %f" % stats.damage_dealt)
	assert(abs(stats.spell_damage.get("magic_bolt", 0.0) - 15.0) < 0.01, "Spell damage recorded correctly")

	# 3. Projectile intercepted
	stats.record_projectile_intercepted(12.0)
	assert(stats.projectiles_intercepted == 1, "Projectiles intercepted counted")
	assert(abs(stats.damage_prevented - 12.0) < 0.01, "Damage prevented tracked")

	# 4. Barrier absorption
	stats.record_damage_absorbed(30.0)
	assert(abs(stats.barrier_absorbed_damage - 30.0) < 0.01, "Barrier absorbed tracked")

	enemy.queue_free()
	print("[PASS] 3. Telemetry accurately tracks capped damage, actual healing, and defense.")

# -----------------------------------------------------------------------------
# 4. Ice Storm Balance & Evolution
# -----------------------------------------------------------------------------
func test_4_ice_storm_balance(parent: Node) -> void:
	print("[TEST] 4. Ice Storm Balance & Evolution Parameters...")
	var storm = IceStormAbility.new()
	parent.add_child(storm)

	# Base level 5 parameters
	storm.current_level = 5
	storm.apply_level_modifiers()
	assert(storm.zone_radius == 160.0, "Lv 5 radius is 160.0")
	assert(storm.base_damage == 12.0, "Lv 5 tick damage is 12.0")
	assert(storm.max_active_zones == 2, "Lv 5 max active zones is 2")

	# Evolution parameters
	storm.evolve()
	assert(storm.is_evolved == true, "Storm evolved")
	assert(storm.zone_radius == 195.0, "Evolved radius balanced at 195.0 (not 230)")
	assert(storm.base_damage == 18.0, "Evolved tick damage balanced at 18.0 (not 32)")
	assert(storm.max_active_zones == 2, "Max active zones capped at 2 (not 3)")
	assert(storm.base_cooldown == 2.2, "Cooldown balanced at 2.2s (not 1.8)")

	# Calculate DPS
	# 18.0 per tick every 0.5s = 36 DPS per zone
	# Max stacked 2 zones = 72 DPS max (healthy, comparable to other evolutions)
	var single_zone_dps = (storm.base_damage / 0.5)
	var max_stacked_dps = single_zone_dps * storm.max_active_zones
	assert(abs(single_zone_dps - 36.0) < 0.01, "Single zone DPS is 36")
	assert(abs(max_stacked_dps - 72.0) < 0.01, "Max stacked DPS is 72")

	storm.queue_free()
	print("[PASS] 4. Ice Storm balance verified: 36 DPS single zone, 72 max stacked DPS.")

# -----------------------------------------------------------------------------
# 5. Thunder Shield Rate Limiting & Energy Threshold
# -----------------------------------------------------------------------------
func test_5_thunder_shield_threshold(engine: SynergyEngine, player: PlayerController, parent: Node) -> void:
	print("[TEST] 5. Thunder Shield Accumulation & Internal Cooldown...")
	engine.reset()
	player.ability_controller.unlock_ability("magic_barrier")
	player.ability_controller.unlock_ability("lightning_strike")

	var target = BasicEnemyScene.instantiate() as EnemyController
	parent.add_child(target)
	target.global_position = player.global_position + Vector2(80, 0)
	target.current_health = 100.0
	target.stats.max_health = 100.0

	var triggers = [0]
	var cb = func(n, _p):
		if n == "thunder_shield":
			triggers[0] += 1
	engine.reaction_triggered.connect(cb)

	# Small hit (10 absorbed) -> below 25.0 threshold, no retaliation yet
	engine.on_barrier_absorbed(player, 10.0)
	assert(triggers[0] == 0, "No discharge below 25.0 energy threshold")
	assert(abs(engine.thunder_energy - 10.0) < 0.01, "10.0 energy accumulated")

	# Second hit (15 absorbed) -> total 25.0 reaches threshold, discharges!
	engine.on_barrier_absorbed(player, 15.0)
	assert(triggers[0] == 1, "Discharged upon reaching 25.0 threshold")
	assert(abs(engine.thunder_energy) < 0.01, "Energy reset after discharge")
	assert(engine.thunder_cooldown > 0.0, "Internal cooldown active")

	# Immediate third hit (30 absorbed) -> internal cooldown blocks rapid spam
	engine.on_barrier_absorbed(player, 30.0)
	assert(triggers[0] == 1, "Internal cooldown blocked rapid second discharge")

	engine.reaction_triggered.disconnect(cb)
	target.queue_free()
	print("[PASS] 5. Thunder Shield energy threshold and internal cooldown prevent spam.")

# -----------------------------------------------------------------------------
# 6. Lethal vs Non-Lethal Hits
# -----------------------------------------------------------------------------
func test_6_lethal_vs_nonlethal_hits(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 6. Lethal vs Non-Lethal Hit Processing Order...")
	engine.reset()

	var events_order: Array[String] = []

	var target = BasicEnemyScene.instantiate() as EnemyController
	parent.add_child(target)
	target.global_position = Vector2(9200, 9200)
	target.current_health = 15.0
	target.stats.max_health = 50.0
	target.apply_status(StatusEffects.STATUS_SLOWED, 5.0)
	target.apply_status(StatusEffects.STATUS_MARKED, 5.0)

	var neighbor = BasicEnemyScene.instantiate() as EnemyController
	parent.add_child(neighbor)
	neighbor.global_position = Vector2(9250, 9200)
	neighbor.current_health = 50.0

	var cb = func(n, _p):
		events_order.append(n)
	engine.reaction_triggered.connect(cb)

	# Melee blade attack deals 30 damage to 15 HP Slowed + Marked target -> Lethal Hit!
	# Proper order:
	# 1. Damage applied
	# 2. On-hit reaction (frost_shatter) triggers
	# 3. Death reaction (soul_harvest) triggers
	var ctx = DamageContext.new(null, target, 30.0, ["melee", "orbit"], "runic_blade", target.global_position)
	var res = DamageResolver.apply_damage(ctx)

	assert(res["killed"] == true, "Target was killed")
	assert(events_order.size() >= 2, "Both on-hit and death reactions triggered")
	assert(events_order[0] == "frost_shatter", "On-hit reaction must trigger first (got %s)" % events_order[0])
	assert(events_order[1] == "soul_harvest", "On-death reaction must trigger second (got %s)" % events_order[1])

	engine.reaction_triggered.disconnect(cb)
	target.queue_free()
	neighbor.queue_free()
	print("[PASS] 6. Lethal hits correctly trigger on-hit reactions before death reactions.")

# -----------------------------------------------------------------------------
# 7. Reward Generator Options Count & Evolutions Priority
# -----------------------------------------------------------------------------
func test_7_reward_generator_count_and_evolutions(player: PlayerController) -> void:
	print("[TEST] 7. RewardGenerator strict count and multiple evolutions...")
	var ac = player.ability_controller
	var inv = player.inventory

	# Setup 2 evolutions ready: Magic Bolt Lv 5 + Hourglass, Ice Storm Lv 5 + Frost Core
	var bolt = ac.get_ability("magic_bolt") as MagicBoltAbility
	if not bolt:
		bolt = ac.unlock_ability("magic_bolt") as MagicBoltAbility
	bolt.current_level = 5
	bolt.is_evolved = false
	inv.add_artifact("hourglass")

	var storm = ac.get_ability("ice_storm") as IceStormAbility
	if not storm:
		storm = ac.unlock_ability("ice_storm") as IceStormAbility
	storm.current_level = 5
	storm.is_evolved = false
	inv.add_artifact("frost_core")

	# Test count = 3 when 2 evolutions available
	var choices_3 = RewardGenerator.generate_choices(player, 3)
	assert(choices_3.size() == 3, "generate_choices must return exactly 3 choices, got %d" % choices_3.size())

	var evo_count = 0
	for c in choices_3:
		if c.type == "evolution":
			evo_count += 1
	assert(evo_count == 2, "Both available evolutions should be prioritized")

	# Add 2 more evolutions: Fireball Lv 5 + Obsidian Heart, Lightning Lv 5 + Lightning Rod
	var fb = ac.get_ability("fireball") as FireballAbility
	if not fb:
		fb = ac.unlock_ability("fireball") as FireballAbility
	fb.current_level = 5
	fb.is_evolved = false
	inv.add_artifact("obsidian_heart")

	var lt = ac.get_ability("lightning_strike") as LightningAbility
	if not lt:
		lt = ac.unlock_ability("lightning_strike") as LightningAbility
	lt.current_level = 5
	lt.is_evolved = false
	inv.add_artifact("lightning_rod")

	# 4 evolutions are now available, but count = 3
	var choices_overflow = RewardGenerator.generate_choices(player, 3)
	assert(choices_overflow.size() == 3, "generate_choices must NEVER exceed requested count 3 (got %d)" % choices_overflow.size())

	# Ensure candidate IDs are unique
	var seen_ids: Dictionary = {}
	for c in choices_overflow:
		assert(not seen_ids.has(c.id), "Choices must not contain duplicate ID %s" % c.id)
		seen_ids[c.id] = true

	# Subsequent call should still have remaining evolutions available
	var choices_next = RewardGenerator.generate_choices(player, 3)
	assert(choices_next.size() == 3, "Subsequent call returns 3 choices")

	print("[PASS] 7. RewardGenerator strictly respects count=3 and prioritizes available evolutions.")
