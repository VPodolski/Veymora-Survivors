extends SceneTree

const MainGameScene = preload("res://scenes/main/main.tscn")
const HeavyEnemyScene = preload("res://scenes/enemies/heavy_enemy.tscn")
const EliteEnemyScene = preload("res://scenes/enemies/elite_enemy.tscn")
const BossEnemyScene = preload("res://scenes/enemies/boss_enemy.tscn")
const RuneZoneScene = preload("res://scripts/arena/rune_zone.gd")

const CombatEffects = preload("res://scripts/combat/combat_effects.gd")
const SynergyEngine = preload("res://scripts/synergies/synergy_engine.gd")
const SynergyRegistry = preload("res://scripts/synergies/synergy_registry.gd")
const ReactionContext = preload("res://scripts/synergies/reaction_context.gd")
const StatusEffects = preload("res://scripts/combat/status_effects.gd")
const Projectile = preload("res://scripts/combat/projectile.gd")
const SteamCloudArea = preload("res://scripts/combat/steam_cloud_area.gd")
const LightningAbility = preload("res://scripts/abilities/lightning_ability.gd")
const IceStormAbility = preload("res://scripts/abilities/ice_storm_ability.gd")
const IceStormZone = preload("res://scripts/abilities/ice_storm_zone.gd")
const FireballAbility = preload("res://scripts/abilities/fireball_ability.gd")
const MagicBoltAbility = preload("res://scripts/abilities/magic_bolt_ability.gd")
const RunicBladeAbility = preload("res://scripts/abilities/runic_blade_ability.gd")
const DeathMarkAbility = preload("res://scripts/abilities/death_mark_ability.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const MainGame = preload("res://scripts/game/main.gd")
const RunStats = preload("res://scripts/game/run_stats.gd")

func _init() -> void:
	call_deferred("run_all_v04_tests")

func run_all_v04_tests() -> void:
	print("--- Running Version 0.4 Synergy Overhaul Comprehensive Test Suite ---")

	var main_node = MainGameScene.instantiate() as MainGame
	root.add_child(main_node)
	await process_frame

	var player = main_node.player
	var engine = main_node.synergy_engine
	var stats = main_node.run_stats

	# 1. Activation conditions & wrong elements
	await test_activation_conditions_and_wrong_elements(engine, main_node)

	# 2. Status consumption & elemental precedence
	await test_status_consumption_and_precedence(engine, main_node)

	# 3. Ice Storm self-trigger immunity
	await test_ice_storm_self_trigger_immunity(main_node)

	# 4. Lightning Chain de-duplication vs base chain
	await test_lightning_chain_deduplication(player, main_node)

	# 5. Secondary damage cascade & recursion guards
	await test_cascade_and_recursion_protection(engine, main_node)

	# 6. Death reactions idempotency & multiple marks
	await test_death_reactions_and_idempotency(engine, main_node)

	# 7. Steam Rift lingering zone mechanics
	await test_steam_rift_lingering_cloud(engine, main_node)

	# 8. Frost Shatter shard alignment & Frost Core artifact
	await test_frost_shatter_and_frost_core(engine, player, main_node)

	# 9. Artifact modifications on synergies (Lightning Rod, Obsidian Heart, Rift Compass)
	await test_artifact_synergy_modifications(engine, player, main_node)

	# 10. RunStats accurate accounting (no double-counting)
	await test_run_stats_accurate_accounting(engine, stats, main_node)

	# 11. Visual primitives & Reduced FX compliance
	test_visual_and_reduced_fx_compliance(main_node)

	# 12. Procedural sound triggers
	test_procedural_sound_triggers()

	# 13. Synergy interaction with Elite & Boss enemies
	await test_synergies_with_elites_and_bosses(engine, main_node)

	# 14. New P2 synergies (Spatial Collapse, Cryogenic Shock, Chain of Doom, Runic Conductor)
	await test_new_v04_synergies(engine, player, main_node)

	print("--- ALL VERSION 0.4 SYNERGY OVERHAUL TESTS PASSED CLEANLY! ---")
	quit(0)

func test_activation_conditions_and_wrong_elements(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 1. Synergy activation conditions and wrong element rejection...")

	var enemy = HeavyEnemyScene.instantiate()
	parent.add_child(enemy)
	enemy.global_position = Vector2(1000, 1000)

	var reaction_box = {"name": ""}
	var handler = func(n, _p): reaction_box["name"] = n
	engine.reaction_triggered.connect(handler)

	# Uncharged target: arcane hit does NOT trigger resonance
	var ctx_wrong = ReactionContext.new(null, enemy, ["arcane"], enemy.global_position, 15.0, 0)
	engine.on_hit_landed(ctx_wrong)
	assert(reaction_box["name"] == "", "Arcane on uncharged enemy must not trigger resonance")

	# Wrong element: charged target hit by fire does NOT trigger resonance
	enemy.apply_status(StatusEffects.STATUS_CHARGED, 4.0)
	reaction_box["name"] = ""
	var ctx_fire = ReactionContext.new(null, enemy, ["fire"], enemy.global_position, 15.0, 0)
	engine.on_hit_landed(ctx_fire)
	assert(reaction_box["name"] == "thermal_conflagration", "Fire on charged enemy triggers thermal_conflagration, NOT resonance")

	engine.reaction_triggered.disconnect(handler)
	enemy.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Activation conditions and wrong element rejection verified.")

func test_status_consumption_and_precedence(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 2. Status consumption rules and elemental precedence...")

	var enemy = HeavyEnemyScene.instantiate()
	parent.add_child(enemy)
	enemy.global_position = Vector2(1100, 1000)

	# Apply both CHARGED and SLOWED
	enemy.apply_status(StatusEffects.STATUS_CHARGED, 4.0)
	enemy.apply_status(StatusEffects.STATUS_SLOWED, 4.0)

	var reaction_box = {"name": ""}
	var handler = func(n, _p): reaction_box["name"] = n
	engine.reaction_triggered.connect(handler)

	# Fire hit: Precedence dictates Thermal Conflagration takes priority over Steam Rift
	var ctx = ReactionContext.new(null, enemy, ["fire"], enemy.global_position, 20.0, 0)
	engine.on_hit_landed(ctx)

	assert(reaction_box["name"] == "thermal_conflagration", "Thermal Conflagration takes priority on dual-status target")
	assert(not enemy.has_status(StatusEffects.STATUS_CHARGED), "Charged status was consumed by Thermal Conflagration")
	assert(enemy.has_status(StatusEffects.STATUS_SLOWED), "Slowed status was preserved")

	engine.reaction_triggered.disconnect(handler)
	enemy.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Status consumption and elemental precedence verified.")

func test_ice_storm_self_trigger_immunity(parent: Node) -> void:
	print("[TEST] 3. Ice Storm self-trigger immunity (zone prepares targets without shattering)...")

	var zone = IceStormZone.new()
	zone.radius = 100.0
	zone.damage_per_tick = 8.0
	parent.add_child(zone)
	zone.global_position = Vector2(1200, 1000)

	var enemy = HeavyEnemyScene.instantiate()
	parent.add_child(enemy)
	enemy.global_position = Vector2(1200, 1000) # Inside zone

	# Wait for 2 physics frames for Area2D collision overlap detection
	await parent.get_tree().physics_frame
	await parent.get_tree().physics_frame

	var engine = parent.get_node_or_null("SynergyEngine") as SynergyEngine
	var reaction_box = {"name": ""}
	var handler = func(n, _p): reaction_box["name"] = n
	if engine:
		engine.reaction_triggered.connect(handler)

	# Tick the zone
	zone.apply_storm_tick()
	await parent.get_tree().process_frame

	assert(enemy.has_status(StatusEffects.STATUS_SLOWED), "Enemy is slowed by Ice Storm zone")
	assert(reaction_box["name"] == "", "Ice Storm zone tick must NOT trigger Frost Shatter on itself!")

	if engine:
		engine.reaction_triggered.disconnect(handler)
	zone.queue_free()
	enemy.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Ice Storm zone self-trigger immunity verified.")

func test_lightning_chain_deduplication(player: PlayerController, parent: Node) -> void:
	print("[TEST] 4. Lightning Chain de-duplication vs base chain targets...")

	var ac = player.ability_controller
	var lightning = ac.get_ability("lightning_strike") as LightningAbility
	if not lightning:
		ac.unlock_ability("lightning_strike")
		lightning = ac.get_ability("lightning_strike") as LightningAbility

	var enemy1 = HeavyEnemyScene.instantiate()
	var enemy2 = HeavyEnemyScene.instantiate()
	var enemy3 = HeavyEnemyScene.instantiate()
	parent.add_child(enemy1)
	parent.add_child(enemy2)
	parent.add_child(enemy3)
	enemy1.global_position = Vector2(2000, 2000)
	enemy2.global_position = Vector2(2060, 2000)
	enemy3.global_position = Vector2(2200, 2000)

	enemy1.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	var hp1_before = enemy1.current_health
	var hp2_before = enemy2.current_health

	lightning.cast_lightning(enemy1)

	assert(enemy1.current_health < hp1_before, "Primary target received base damage")
	assert(enemy2.current_health < hp2_before, "Secondary enemy2 was hit by base chain jumps")
	# enemy2 should NOT have been hit twice (by base chain AND by synergy)
	var dmg_taken_e2 = hp2_before - enemy2.current_health
	assert(dmg_taken_e2 <= lightning.get_effective_damage() * 0.85, "Enemy2 only took base chain jump damage, no double-hit")

	enemy1.queue_free()
	enemy2.queue_free()
	enemy3.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Lightning Chain de-duplication verified.")

func test_cascade_and_recursion_protection(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 5. Secondary damage cascade & recursion protection...")

	var enemy = HeavyEnemyScene.instantiate()
	parent.add_child(enemy)
	enemy.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	var reaction_box = {"name": ""}
	var handler = func(n, _p): reaction_box["name"] = n
	engine.reaction_triggered.connect(handler)

	# Context with depth = 2 (max is 2) must be dropped
	var ctx_max = ReactionContext.new(null, enemy, ["arcane"], enemy.global_position, 15.0, 2)
	engine.on_hit_landed(ctx_max)
	assert(reaction_box["name"] == "", "Context at max depth must not trigger reactions")

	# Context with allow_reactions = false must be dropped
	var ctx_no_sub = ReactionContext.new(null, enemy, ["arcane"], enemy.global_position, 15.0, 0, false)
	engine.on_hit_landed(ctx_no_sub)
	assert(reaction_box["name"] == "", "Context with allow_reactions=false must not trigger reactions")

	engine.reaction_triggered.disconnect(handler)
	enemy.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Cascade and recursion protection verified.")

func test_death_reactions_and_idempotency(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 6. Death reactions idempotency & multiple marks resolution...")

	var victim = HeavyEnemyScene.instantiate()
	var bystander = HeavyEnemyScene.instantiate()
	parent.add_child(victim)
	parent.add_child(bystander)
	victim.global_position = Vector2(3000, 3000)
	bystander.global_position = Vector2(3040, 3000)

	# Victim has BOTH marked and unstable
	victim.apply_status(StatusEffects.STATUS_MARKED, 5.0)
	victim.apply_status(StatusEffects.STATUS_UNSTABLE, 5.0)

	var triggered: Array[String] = []
	var handler = func(n, _p): triggered.append(n)
	engine.reaction_triggered.connect(handler)

	victim.die()
	assert(triggered.has("soul_harvest"), "Death triggered soul_harvest")
	assert(triggered.has("unstable_explosion"), "Death also triggered unstable_explosion")

	# Calling die() again is completely idempotent (no re-triggering)
	triggered.clear()
	victim.die()
	assert(triggered.is_empty(), "Repeated die() call does nothing")

	engine.reaction_triggered.disconnect(handler)
	victim.queue_free()
	bystander.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Death reactions idempotency verified.")

func test_steam_rift_lingering_cloud(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 7. Steam Rift lingering vapor cloud mechanics...")

	var enemy = HeavyEnemyScene.instantiate()
	parent.add_child(enemy)
	enemy.global_position = Vector2(4000, 4000)
	enemy.apply_status(StatusEffects.STATUS_SLOWED, 4.0)

	var ctx = ReactionContext.new(null, enemy, ["fire"], enemy.global_position, 20.0, 0)
	engine.on_hit_landed(ctx)

	# Check that a SteamCloudArea was spawned into the container
	var container = engine.get_effects_container()
	var cloud_found = false
	for child in container.get_children():
		if child is SteamCloudArea:
			cloud_found = true
			assert(child.radius == 90.0, "Steam cloud radius matches 90.0 px")
			assert(child.duration >= 2.0, "Steam cloud duration is at least 2 seconds")
			child.queue_free()
			break

	assert(cloud_found, "Steam Rift must spawn a lingering SteamCloudArea")
	enemy.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Steam Rift lingering vapor cloud verified.")

func test_frost_shatter_and_frost_core(engine: SynergyEngine, player: PlayerController, parent: Node) -> void:
	print("[TEST] 8. Frost Shatter shard alignment and Frost Core artifact boost...")

	var enemy = HeavyEnemyScene.instantiate()
	parent.add_child(enemy)
	enemy.global_position = Vector2(5000, 5000)
	enemy.apply_status(StatusEffects.STATUS_SLOWED, 4.0)

	var container = engine.get_effects_container()
	var proj_before = 0
	for c in container.get_children():
		if c is Projectile:
			proj_before += 1

	var ctx = ReactionContext.new(null, enemy, ["melee", "orbit"], enemy.global_position, 20.0, 0)
	engine.on_hit_landed(ctx)

	var proj_after = 0
	for c in container.get_children():
		if c is Projectile:
			proj_after += 1

	assert(proj_after == proj_before + 3, "Base Frost Shatter spawns exactly 3 projectile shards")
	assert(not enemy.has_status(StatusEffects.STATUS_SLOWED), "Slowed ice crust was shattered and consumed")

	# Test with Frost Core (+2 shards = 5 total)
	player.set_meta("has_frost_core", true)
	enemy.apply_status(StatusEffects.STATUS_SLOWED, 4.0)
	engine.clear_target_cooldowns(enemy)

	proj_before = proj_after
	engine.on_hit_landed(ctx)

	proj_after = 0
	for c in container.get_children():
		if c is Projectile:
			proj_after += 1

	assert(proj_after == proj_before + 5, "Empowered Frost Shatter with Frost Core spawns exactly 5 shards")

	player.remove_meta("has_frost_core")
	enemy.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Frost Shatter shard alignment and Frost Core boost verified.")

func test_artifact_synergy_modifications(engine: SynergyEngine, player: PlayerController, parent: Node) -> void:
	print("[TEST] 9. Artifact modifications on synergies (Lightning Rod, Obsidian Heart, Rift Compass)...")

	# 1. Lightning Rod: increases chain hops and search radius
	player.set_meta("has_lightning_rod", true)
	var e1 = HeavyEnemyScene.instantiate()
	var e2 = HeavyEnemyScene.instantiate()
	var e3 = HeavyEnemyScene.instantiate()
	var e4 = HeavyEnemyScene.instantiate()
	parent.add_child(e1)
	parent.add_child(e2)
	parent.add_child(e3)
	parent.add_child(e4)
	e1.global_position = Vector2(6000, 6000)
	e2.global_position = Vector2(6050, 6000)
	e3.global_position = Vector2(6100, 6000)
	e4.global_position = Vector2(6150, 6000)
	e1.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	var hp4_before = e4.current_health
	var ctx = ReactionContext.new(null, e1, ["lightning"], e1.global_position, 20.0, 0)
	engine.on_hit_landed(ctx)

	assert(e4.current_health < hp4_before, "Lightning Rod allowed third chain hop to reach enemy 4")

	# 2. Obsidian Heart: increases Thermal Conflagration damage by 35%
	player.set_meta("has_obsidian_heart", true)
	var target_obs = HeavyEnemyScene.instantiate()
	parent.add_child(target_obs)
	target_obs.global_position = Vector2(6500, 6000)
	target_obs.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	var hp_obs_before = target_obs.current_health
	var ctx_fire = ReactionContext.new(null, target_obs, ["fire"], target_obs.global_position, 20.0, 0)
	engine.on_hit_landed(ctx_fire)
	var dmg_taken = hp_obs_before - target_obs.current_health
	assert(dmg_taken > 45.0, "Obsidian Heart amplified Thermal Conflagration damage (base 38 * 1.35 = 51.3)")

	player.remove_meta("has_lightning_rod")
	player.remove_meta("has_obsidian_heart")
	e1.queue_free()
	e2.queue_free()
	e3.queue_free()
	e4.queue_free()
	target_obs.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Artifact modifications on synergies verified.")

func test_run_stats_accurate_accounting(engine: SynergyEngine, stats: RunStats, parent: Node) -> void:
	print("[TEST] 10. RunStats accurate accounting (no double-counting triggers)...")

	stats.reset()

	var e1 = HeavyEnemyScene.instantiate()
	var e2 = HeavyEnemyScene.instantiate()
	parent.add_child(e1)
	parent.add_child(e2)
	e1.global_position = Vector2(7000, 7000)
	e2.global_position = Vector2(7040, 7000)
	e1.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	# Trigger resonance: 1 activation, hitting 1 secondary enemy
	var ctx = ReactionContext.new(null, e1, ["arcane"], e1.global_position, 20.0, 0)
	engine.on_hit_landed(ctx)

	# Check that activation count is exactly 1 (not 1 + targets count!)
	assert(stats.synergy_counts["resonance"] == 1, "Resonance activation count must be exactly 1")
	assert(stats.synergy_damage["resonance"] == 18.0, "Resonance damage must be exactly 18.0")
	assert(stats.synergy_targets["resonance"] >= 1, "Resonance targets must record secondary targets")

	e1.queue_free()
	e2.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] RunStats accurate accounting verified.")

func test_visual_and_reduced_fx_compliance(parent: Node) -> void:
	print("[TEST] 11. Visual primitives and Reduced FX mode compliance...")

	CombatEffects.set_fx_intensity("reduced")
	assert(CombatEffects.get_particle_multiplier() == 0.5, "Reduced multiplier is 0.5")

	# Test all composite presets without crashing
	CombatEffects.spawn_resonance_visuals(parent, Vector2(100, 100), 85.0)
	CombatEffects.spawn_frost_shatter_visuals(parent, Vector2(100, 100), 3)
	CombatEffects.spawn_lightning_chain_visuals(parent, Vector2(100, 100), [Vector2(150, 100)])
	CombatEffects.spawn_steam_rift_visuals(parent, Vector2(100, 100), 90.0)
	CombatEffects.spawn_thermal_conflagration_visuals(parent, Vector2(100, 100), 95.0, true)
	CombatEffects.spawn_soul_harvest_visuals(parent, Vector2(100, 100), 90.0)
	CombatEffects.spawn_unstable_explosion_visuals(parent, Vector2(100, 100), 90.0)
	CombatEffects.spawn_spatial_collapse_visuals(parent, Vector2(100, 100), 110.0)

	CombatEffects.set_fx_intensity("standard")
	print("[PASS] Visual presets and Reduced FX mode verified.")

func test_procedural_sound_triggers() -> void:
	print("[TEST] 12. Procedural sound triggers for all synergies...")

	var am = AudioManager.instance
	assert(am != null, "AudioManager instance must exist")

	am.play_synergy("resonance")
	am.play_synergy("frost_shatter")
	am.play_synergy("lightning_chain")
	am.play_synergy("steam_rift")
	am.play_synergy("thermal_conflagration")
	am.play_synergy("soul_harvest")
	am.play_synergy("unstable_explosion")
	am.play_synergy("spatial_collapse")

	print("[PASS] Procedural sounds for all synergies triggered cleanly.")

func test_synergies_with_elites_and_bosses(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 13. Synergy interactions with Elite and Boss enemies...")

	var boss = BossEnemyScene.instantiate()
	parent.add_child(boss)
	boss.global_position = Vector2(8000, 8000)
	boss.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	var hp_boss_before = boss.current_health
	var ctx = ReactionContext.new(null, boss, ["arcane"], boss.global_position, 20.0, 0)
	engine.on_hit_landed(ctx)

	# Boss can be charged, can trigger resonance without breaking boss phases
	assert(not boss.has_status(StatusEffects.STATUS_CHARGED), "Boss charged status consumed by Resonance")

	boss.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Synergy interactions with Boss verified.")

func test_new_v04_synergies(engine: SynergyEngine, player: PlayerController, parent: Node) -> void:
	print("[TEST] 14. New V0.4 synergies (Spatial Collapse, Cryogenic Shock, Chain of Doom, Runic Conductor)...")

	# 1. Spatial Collapse (Arcane on Unstable)
	var e_collapse = HeavyEnemyScene.instantiate()
	var e_nearby = HeavyEnemyScene.instantiate()
	parent.add_child(e_collapse)
	parent.add_child(e_nearby)
	e_collapse.global_position = Vector2(9000, 9000)
	e_nearby.global_position = Vector2(9060, 9000)
	e_collapse.apply_status(StatusEffects.STATUS_UNSTABLE, 4.0)

	var reaction_box = {"name": ""}
	var handler = func(n, _p): reaction_box["name"] = n
	engine.reaction_triggered.connect(handler)

	var ctx_arc = ReactionContext.new(null, e_collapse, ["arcane"], e_collapse.global_position, 20.0, 0)
	engine.on_hit_landed(ctx_arc)
	assert(reaction_box["name"] == "spatial_collapse", "Arcane on Unstable triggers Spatial Collapse")
	assert(e_nearby.knockback_velocity.length() > 0.0, "Nearby enemy was pulled toward collapse epicenter")

	# 2. Cryogenic Shock (Lightning on Slowed)
	reaction_box["name"] = ""
	var e_cryo = HeavyEnemyScene.instantiate()
	parent.add_child(e_cryo)
	e_cryo.global_position = Vector2(9200, 9000)
	e_cryo.apply_status(StatusEffects.STATUS_SLOWED, 4.0)

	var ctx_light = ReactionContext.new(null, e_cryo, ["lightning"], e_cryo.global_position, 20.0, 0)
	engine.on_hit_landed(ctx_light)
	assert(reaction_box["name"] == "cryogenic_shock", "Lightning on Slowed triggers Cryogenic Shock")
	assert(not e_cryo.has_status(StatusEffects.STATUS_SLOWED), "Slowed was consumed by Cryogenic Shock")

	# 3. Runic Conductor (Lightning while in Rune Zone)
	player.set_meta("in_rune_zone", true)
	reaction_box["name"] = ""
	var e_rune = HeavyEnemyScene.instantiate()
	parent.add_child(e_rune)
	e_rune.global_position = Vector2(9400, 9000)
	var ctx_rune = ReactionContext.new(null, e_rune, ["lightning"], e_rune.global_position, 20.0, 0)
	engine.on_hit_landed(ctx_rune)
	assert(reaction_box["name"] == "runic_conductor", "Lightning while standing in Rune Zone triggers Runic Conductor")
	player.remove_meta("in_rune_zone")

	# 4. Chain of Doom (Death of marked enemy with chain enabled)
	reaction_box["name"] = ""
	var e_doom = HeavyEnemyScene.instantiate()
	var e_doom_next = HeavyEnemyScene.instantiate()
	parent.add_child(e_doom)
	parent.add_child(e_doom_next)
	e_doom.global_position = Vector2(9600, 9000)
	e_doom_next.global_position = Vector2(9650, 9000)
	e_doom.apply_status(StatusEffects.STATUS_MARKED, 5.0)
	e_doom.set_meta("chain_of_doom_enabled", true)
	e_doom.die()

	assert(reaction_box["name"] == "chain_of_doom", "Death of chain-enabled marked enemy triggers Chain of Doom")
	assert(e_doom_next.has_status(StatusEffects.STATUS_MARKED), "Chain of Doom transferred mark to next enemy")

	engine.reaction_triggered.disconnect(handler)
	e_collapse.queue_free()
	e_nearby.queue_free()
	e_cryo.queue_free()
	e_rune.queue_free()
	e_doom.queue_free()
	e_doom_next.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] New V0.4 synergies verified.")
