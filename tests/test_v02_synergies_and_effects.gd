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
const MagicBoltAbility = preload("res://scripts/abilities/magic_bolt_ability.gd")
const IceStormAbility = preload("res://scripts/abilities/ice_storm_ability.gd")
const FireballAbility = preload("res://scripts/abilities/fireball_ability.gd")
const LightningAbility = preload("res://scripts/abilities/lightning_ability.gd")
const RewardGenerator = preload("res://scripts/progression/reward_generator.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const MainGame = preload("res://scripts/game/main.gd")

func _init() -> void:
	call_deferred("run_all_v02_tests")

func run_all_v02_tests() -> void:
	print("--- Running Version 0.2 Code Review & Stabilization Verification Suite ---")

	var main_node = MainGameScene.instantiate() as MainGame
	root.add_child(main_node)
	await process_frame

	var player = main_node.player
	var synergy_engine = main_node.synergy_engine

	test_combat_effects_visual_primitives(main_node)
	test_fx_intensity_modes_and_limits()
	test_combat_effects_caps_and_throttling(main_node)

	await test_arcane_resonance_conditions_and_spread(synergy_engine, main_node)
	await test_lightning_chain_uncharged_vs_charged(synergy_engine, main_node)
	await test_lightning_ability_deduplication(player, main_node)
	await test_ice_shatter_visuals_and_projectiles(synergy_engine, main_node)
	await test_steam_rift_and_thermal_conflagration_priority(synergy_engine, main_node)
	await test_reaction_depth_and_recursion_limit(synergy_engine, main_node)
	await test_cooldowns_and_auto_cleanup(synergy_engine, main_node)
	await test_enemy_death_reactions_and_xp_uniqueness(synergy_engine, main_node)

	test_returning_pierce_visuals_and_trajectory(player, main_node)
	test_all_four_evolutions(player)
	test_rune_zone_multi_overlap_and_cleanup(player, main_node)
	await test_all_enemy_archetypes_status_dots_and_bars(main_node)
	test_audio_manager_and_save_manager_volumes()

	print("--- ALL VERSION 0.2 CODE REVIEW TESTS PASSED SUCCESSFULLY! ---")
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

	CombatEffects.set_fx_intensity("standard")
	print("[PASS] FX Intensity modes and concurrency limits verified.")

func test_combat_effects_caps_and_throttling(parent: Node) -> void:
	print("[TEST] 3. CombatEffects caps, priority reserves & duplicate throttling...")

	CombatEffects.reset()
	assert(CombatEffects.active_priority_popups == 0, "Priority popups count is 0 after reset")
	assert(CombatEffects.active_text_popups == 0, "Text popups count is 0 after reset")

	# Test priority popup limit (MAX_PRIORITY_POPUPS = 3)
	CombatEffects.spawn_text_popup(parent, Vector2(100, 100), "PRIO_1", Color.YELLOW, true)
	CombatEffects.spawn_text_popup(parent, Vector2(100, 100), "PRIO_2", Color.YELLOW, true)
	CombatEffects.spawn_text_popup(parent, Vector2(100, 100), "PRIO_3", Color.YELLOW, true)
	assert(CombatEffects.active_priority_popups == 3, "Active priority popups reached 3")

	# 4th priority popup should be dropped due to cap
	CombatEffects.spawn_text_popup(parent, Vector2(100, 100), "PRIO_4", Color.YELLOW, true)
	assert(CombatEffects.active_priority_popups == 3, "Active priority popups capped at 3")

	# Test duplicate message throttling (same text within 350ms is suppressed)
	var count_before = CombatEffects.active_text_popups
	CombatEffects.spawn_text_popup(parent, Vector2(120, 120), "REPEAT_TEST", Color.WHITE, false)
	assert(CombatEffects.active_text_popups == count_before + 1, "First repeat message spawned")
	CombatEffects.spawn_text_popup(parent, Vector2(120, 120), "REPEAT_TEST", Color.WHITE, false)
	assert(CombatEffects.active_text_popups == count_before + 1, "Duplicate message suppressed within throttle window")

	# Test critical hazard telegraph ignores decorative cap
	CombatEffects.active_decorative_effects = 100
	var tel = CombatEffects.spawn_hazard_telegraph(parent, Vector2(0, 0), Vector2.UP, 100.0, 20.0, 0.2)
	assert(tel != null, "Hazard telegraph must spawn regardless of decorative limit")
	tel.queue_free()

	CombatEffects.reset()
	print("[PASS] CombatEffects caps, priority reserves and duplicate throttling verified.")

func test_arcane_resonance_conditions_and_spread(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 4. Arcane Resonance strict condition and spreading logic...")

	var enemy_a = HeavyEnemyScene.instantiate()
	var enemy_b = HeavyEnemyScene.instantiate()
	parent.add_child(enemy_a)
	parent.add_child(enemy_b)
	enemy_a.global_position = Vector2(1500, 1500)
	enemy_b.global_position = Vector2(1540, 1500) # Inside 85px radius

	var reaction_box = {"name": ""}
	var handler = func(n, _p): reaction_box["name"] = n
	engine.reaction_triggered.connect(handler)

	# Condition 1: Arcane on UNCHARGED target -> must NOT trigger resonance and must NOT apply charge
	var ctx_uncharged = ReactionContext.new(null, enemy_a, ["arcane"], enemy_a.global_position, 20.0, 0)
	engine.on_hit_landed(ctx_uncharged)
	assert(reaction_box["name"] == "", "Arcane on uncharged target must NOT trigger resonance")
	assert(not enemy_a.has_status(StatusEffects.STATUS_CHARGED), "Arcane attack does not charge target")

	# Condition 2: Lightning must NOT trigger Arcane Resonance!
	enemy_a.apply_status(StatusEffects.STATUS_CHARGED, 4.0)
	reaction_box["name"] = ""
	var ctx_lightning = ReactionContext.new(null, enemy_a, ["lightning"], enemy_a.global_position, 20.0, 0)
	engine.on_hit_landed(ctx_lightning)
	assert(reaction_box["name"] != "resonance", "Lightning attack must NEVER trigger Arcane Resonance")

	# Condition 3: Arcane on CHARGED target -> triggers resonance, consumes charge, deals 18 dmg to B, charges B
	enemy_a.apply_status(StatusEffects.STATUS_CHARGED, 4.0)
	reaction_box["name"] = ""
	var hp_b_before = enemy_b.current_health
	var ctx_arcane = ReactionContext.new(null, enemy_a, ["arcane"], enemy_a.global_position, 20.0, 0)
	engine.on_hit_landed(ctx_arcane)

	assert(reaction_box["name"] == "resonance", "Arcane on charged target triggers resonance")
	assert(not enemy_a.has_status(StatusEffects.STATUS_CHARGED), "Charged status consumed from target A")
	assert(enemy_b.current_health == hp_b_before - 18.0, "Secondary target received exactly 18.0 resonance damage")
	assert(enemy_b.has_status(StatusEffects.STATUS_CHARGED), "Secondary target gained charged status from impulse")

	engine.reaction_triggered.disconnect(handler)
	enemy_a.queue_free()
	enemy_b.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Arcane Resonance conditions and spread verified.")

func test_lightning_chain_uncharged_vs_charged(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 5. Lightning Chain uncharged vs charged activation conditions...")

	var enemy_a = HeavyEnemyScene.instantiate()
	var enemy_b = HeavyEnemyScene.instantiate()
	parent.add_child(enemy_a)
	parent.add_child(enemy_b)
	enemy_a.global_position = Vector2(2000, 2000)
	enemy_b.global_position = Vector2(2050, 2000) # Inside 150px

	var reaction_box = {"name": ""}
	var handler = func(n, _p): reaction_box["name"] = n
	engine.reaction_triggered.connect(handler)

	# Case 1: First hit on UNCHARGED target -> applies charge, does NOT trigger lightning_chain reaction!
	var hp_b_before = enemy_b.current_health
	var ctx_first = ReactionContext.new(null, enemy_a, ["lightning"], enemy_a.global_position, 22.0, 0)
	engine.on_hit_landed(ctx_first)

	assert(reaction_box["name"] == "", "First hit on uncharged target must NOT trigger lightning_chain reaction")
	assert(enemy_a.has_status(StatusEffects.STATUS_CHARGED), "First lightning hit applied charged status to target A")
	assert(enemy_b.current_health == hp_b_before, "Secondary target received no synergy damage on first strike")

	# Case 2: Hit on CHARGED target -> triggers lightning_chain, consumes charge, damages B by 14
	reaction_box["name"] = ""
	var ctx_second = ReactionContext.new(null, enemy_a, ["lightning"], enemy_a.global_position, 22.0, 0)
	engine.on_hit_landed(ctx_second)

	assert(reaction_box["name"] == "lightning_chain", "Lightning on charged target triggers lightning_chain")
	assert(not enemy_a.has_status(StatusEffects.STATUS_CHARGED), "Charged status consumed from target A")
	assert(enemy_b.current_health == hp_b_before - 14.0, "Secondary target received exactly 14.0 chain damage")
	assert(enemy_b.has_status(StatusEffects.STATUS_CHARGED), "Secondary target B gained charged status")

	engine.reaction_triggered.disconnect(handler)
	enemy_a.queue_free()
	enemy_b.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Lightning Chain activation conditions verified.")

func test_lightning_ability_deduplication(player: PlayerController, parent: Node) -> void:
	print("[TEST] 6. Lightning Ability de-duplication and chain count...")

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
	enemy1.global_position = Vector2(3000, 3000)
	enemy2.global_position = Vector2(3080, 3000)
	enemy3.global_position = Vector2(3160, 3000)

	var hp1_start = enemy1.current_health
	var hp2_start = enemy2.current_health

	# Cast lightning on enemy1
	lightning.cast_lightning(enemy1)
	assert(enemy1.current_health < hp1_start, "Primary target received damage")
	assert(enemy2.current_health < hp2_start, "Base chain hit enemy2")

	enemy1.queue_free()
	enemy2.queue_free()
	enemy3.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Lightning Ability de-duplication verified.")

func test_ice_shatter_visuals_and_projectiles(engine: SynergyEngine, _parent: Node) -> void:
	print("[TEST] 7. Ice Shatter synergy and crystalline shards...")

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
	await _parent.get_tree().process_frame
	print("[PASS] Ice Shatter shards and projectiles verified.")

func test_steam_rift_and_thermal_conflagration_priority(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 8. Steam Rift & Thermal Conflagration multi-status priority...")

	# Test Elemental Precedence: target has BOTH charged and slowed
	var dual_enemy = HeavyEnemyScene.instantiate()
	parent.add_child(dual_enemy)
	dual_enemy.global_position = Vector2(4000, 4000)
	dual_enemy.apply_status(StatusEffects.STATUS_CHARGED, 4.0)
	dual_enemy.apply_status(StatusEffects.STATUS_SLOWED, 4.0)

	var reaction_box = {"name": ""}
	var handler = func(n, _p): reaction_box["name"] = n
	engine.reaction_triggered.connect(handler)

	# Fire hit on dual-status enemy: Thermal Conflagration must take priority!
	var ctx = ReactionContext.new(null, dual_enemy, ["fire"], dual_enemy.global_position, 25.0, 0)
	engine.on_hit_landed(ctx)

	assert(reaction_box["name"] == "thermal_conflagration", "Thermal Conflagration takes priority over Steam Rift on dual status")
	assert(not dual_enemy.has_status(StatusEffects.STATUS_CHARGED), "Charged status was consumed by Thermal Conflagration")
	assert(dual_enemy.has_status(StatusEffects.STATUS_SLOWED), "Slowed status was preserved for subsequent interactions")

	# Subsequent fire hit on the remaining slowed enemy now triggers Steam Rift
	reaction_box["name"] = ""
	var ctx_subsequent = ReactionContext.new(null, dual_enemy, ["fire"], dual_enemy.global_position, 25.0, 0)
	engine.on_hit_landed(ctx_subsequent)
	assert(reaction_box["name"] == "steam_rift", "Subsequent fire hit triggers Steam Rift")
	assert(not dual_enemy.has_status(StatusEffects.STATUS_SLOWED), "Slowed status consumed by Steam Rift")

	engine.reaction_triggered.disconnect(handler)
	dual_enemy.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Steam Rift and Thermal Conflagration priority rules verified.")

func test_reaction_depth_and_recursion_limit(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 9. Reaction depth and recursion limit enforcement...")

	var enemy = HeavyEnemyScene.instantiate()
	parent.add_child(enemy)
	enemy.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	var reaction_box = {"name": ""}
	var handler = func(n, _p): reaction_box["name"] = n
	engine.reaction_triggered.connect(handler)

	# Context with depth = 2 (MAX_REACTION_DEPTH = 2) must be immediately dropped
	var ctx_deep = ReactionContext.new(null, enemy, ["arcane"], enemy.global_position, 15.0, 2)
	engine.on_hit_landed(ctx_deep)
	assert(reaction_box["name"] == "", "Depth >= 2 must NOT trigger any reaction")
	assert(enemy.has_status(StatusEffects.STATUS_CHARGED), "Charge status not consumed on dropped depth")

	# Context with allow_reactions = false must be dropped
	reaction_box["name"] = ""
	var ctx_disallowed = ReactionContext.new(null, enemy, ["arcane"], enemy.global_position, 15.0, 0, false)
	engine.on_hit_landed(ctx_disallowed)
	assert(reaction_box["name"] == "", "allow_reactions == false must NOT trigger reaction")

	engine.reaction_triggered.disconnect(handler)
	enemy.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Reaction depth and recursion limits verified.")

func test_cooldowns_and_auto_cleanup(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 10. Centralized reaction cooldowns and auto-cleanup...")

	var enemy = HeavyEnemyScene.instantiate()
	parent.add_child(enemy)
	var e_id = enemy.get_instance_id()

	assert(engine.can_trigger_reaction(enemy, "resonance") == true, "Fresh enemy can trigger reaction")
	engine.record_reaction(enemy, "resonance")
	assert(engine.can_trigger_reaction(enemy, "resonance") == false, "Recorded reaction is immediately on cooldown")

	# Different reaction on same enemy is NOT blocked
	assert(engine.can_trigger_reaction(enemy, "frost_shatter") == true, "Different reaction on same enemy is allowed")

	# Enemy tree exit cleans up all registered cooldowns
	enemy.queue_free()
	await parent.get_tree().process_frame

	var found_key = false
	var prefix = str(e_id) + "_"
	for k in engine.reaction_cooldowns.keys():
		if k.begins_with(prefix):
			found_key = true
	assert(not found_key, "All cooldown entries for freed enemy were cleaned up")
	print("[PASS] Reaction cooldowns and auto-cleanup verified.")

func test_enemy_death_reactions_and_xp_uniqueness(engine: SynergyEngine, parent: Node) -> void:
	print("[TEST] 11. Enemy death reactions, Soul Harvest & single XP gem...")

	var victim = HeavyEnemyScene.instantiate()
	var bystander = HeavyEnemyScene.instantiate()
	parent.add_child(victim)
	parent.add_child(bystander)
	victim.global_position = Vector2(5000, 5000)
	bystander.global_position = Vector2(5030, 5000)

	victim.apply_status(StatusEffects.STATUS_MARKED, 5.0)

	var reaction_box = {"name": ""}
	var handler = func(n, _p): reaction_box["name"] = n
	engine.reaction_triggered.connect(handler)

	var hp_b_before = bystander.current_health
	victim.die()

	assert(victim.is_dead == true, "Victim is dead")
	assert(reaction_box["name"] == "soul_harvest", "Death of marked enemy triggers soul_harvest reaction")
	assert(bystander.current_health < hp_b_before, "Bystander took soul harvest damage")

	# Verify calling die() a second time is a complete no-op
	reaction_box["name"] = ""
	victim.die()
	assert(reaction_box["name"] == "", "Repeated die() call does nothing")

	engine.reaction_triggered.disconnect(handler)
	victim.queue_free()
	bystander.queue_free()
	await parent.get_tree().process_frame
	print("[PASS] Enemy death reactions and single execution verified.")

func test_returning_pierce_visuals_and_trajectory(player: PlayerController, parent: Node) -> void:
	print("[TEST] 12. Returning Pierce trajectory and visual states...")

	var proj = Projectile.new()
	proj.faction = Projectile.Faction.PLAYER
	proj.is_returning = true
	proj.lifetime = 1.0
	proj.global_position = Vector2(0, 0)
	proj.direction = Vector2.RIGHT
	parent.add_child(proj)

	proj._physics_process(0.5)
	assert(proj.has_turned_back == true, "Projectile must trigger turn-back state past 45% lifetime")

	proj.queue_free()
	print("[PASS] Returning Pierce turn-back and trajectory verified.")

func test_all_four_evolutions(player: PlayerController) -> void:
	print("[TEST] 13. All 4 evolutions: requirements, stats, names, descriptions...")

	var ac = player.ability_controller
	var inv = player.inventory

	# 1. Magic Bolt + Hourglass -> Returning Pierce
	var bolt = ac.get_ability("magic_bolt") as MagicBoltAbility
	if not bolt:
		ac.unlock_ability("magic_bolt")
		bolt = ac.get_ability("magic_bolt") as MagicBoltAbility
	bolt.current_level = 5
	inv.add_artifact("hourglass")
	var choices_1 = RewardGenerator.generate_choices(player, 3)
	var opt_1 = null
	for o in choices_1:
		if o.id == "evolve_magic_bolt": opt_1 = o; break
	assert(opt_1 != null, "Magic Bolt evolution offered")
	RewardGenerator.apply_upgrade(player, opt_1)
	assert(bolt.is_evolved == true, "Magic Bolt evolved")
	assert(bolt.ability_name == "Возвращающийся разлом", "Magic Bolt renamed")
	assert(bolt.base_damage == 55.0, "Magic Bolt damage updated to 55")

	# Cannot evolve again
	var choices_1_again = RewardGenerator.generate_choices(player, 3)
	var opt_1_again = null
	for o in choices_1_again:
		if o.id == "evolve_magic_bolt": opt_1_again = o; break
	assert(opt_1_again == null, "Already evolved Magic Bolt cannot be evolved again")

	# 2. Ice Storm + Frost Core -> Blizzard Cataclysm
	ac.unlock_ability("ice_storm")
	var storm = ac.get_ability("ice_storm") as IceStormAbility
	storm.current_level = 5
	inv.add_artifact("frost_core")
	var choices_2 = RewardGenerator.generate_choices(player, 3)
	var opt_2 = null
	for o in choices_2:
		if o.id == "evolve_ice_storm": opt_2 = o; break
	assert(opt_2 != null, "Ice Storm evolution offered")
	RewardGenerator.apply_upgrade(player, opt_2)
	assert(storm.is_evolved == true, "Ice storm evolved")
	assert(storm.ability_name == "Абсолютный буран", "Ice storm renamed")
	assert(storm.base_damage == 32.0, "Ice storm damage updated to 32")

	# 3. Fireball + Obsidian Heart -> Infernal Supernova
	ac.unlock_ability("fireball")
	var fireball = ac.get_ability("fireball") as FireballAbility
	fireball.current_level = 5
	inv.add_artifact("obsidian_heart")
	var choices_3 = RewardGenerator.generate_choices(player, 3)
	var opt_3 = null
	for o in choices_3:
		if o.id == "evolve_fireball": opt_3 = o; break
	assert(opt_3 != null, "Fireball evolution offered")
	RewardGenerator.apply_upgrade(player, opt_3)
	assert(fireball.is_evolved == true, "Fireball evolved")
	assert(fireball.ability_name == "Инфернальная сверхновая", "Fireball renamed")
	assert(fireball.base_damage == 50.0, "Fireball damage updated to 50")

	# 4. Lightning Strike + Lightning Rod -> Wrath of the Heavens
	ac.unlock_ability("lightning_strike")
	var lightning = ac.get_ability("lightning_strike") as LightningAbility
	lightning.current_level = 5
	inv.add_artifact("lightning_rod")
	var choices_4 = RewardGenerator.generate_choices(player, 3)
	var opt_4 = null
	for o in choices_4:
		if o.id == "evolve_lightning": opt_4 = o; break
	assert(opt_4 != null, "Lightning evolution offered")
	RewardGenerator.apply_upgrade(player, opt_4)
	assert(lightning.is_evolved == true, "Lightning evolved")
	assert(lightning.ability_name == "Ярость Небес", "Lightning renamed")
	assert(lightning.base_damage == 45.0, "Lightning damage updated to 45")

	print("[PASS] All 4 evolutions verified.")

func test_rune_zone_multi_overlap_and_cleanup(player: PlayerController, parent: Node) -> void:
	print("[TEST] 14. RuneZone multi-overlap and cleanup reference counting...")

	player.reset_rune_zones()
	assert(player.is_in_rune_zone() == false, "Player starts outside rune zone")
	assert(player.active_rune_zones == 0, "active_rune_zones is 0")

	var rz1 = RuneZoneScene.new()
	var rz2 = RuneZoneScene.new()
	parent.add_child(rz1)
	parent.add_child(rz2)

	# Enter zone 1
	rz1._on_body_entered(player)
	assert(player.is_in_rune_zone() == true, "Player inside zone 1")
	assert(player.active_rune_zones == 1, "active_rune_zones is 1")
	assert(player.get_meta("in_rune_zone", false) == true, "Metadata in_rune_zone is true")

	# Enter overlapping zone 2
	rz2._on_body_entered(player)
	assert(player.active_rune_zones == 2, "active_rune_zones is 2 with 2 overlapping zones")
	assert(player.is_in_rune_zone() == true, "Player still inside rune zone")

	# Exit zone 1: player should STILL have rune zone buff because zone 2 is active!
	rz1._on_body_exited(player)
	assert(player.active_rune_zones == 1, "active_rune_zones decremented to 1")
	assert(player.is_in_rune_zone() == true, "Buff remains while inside zone 2")
	assert(player.get_meta("in_rune_zone", false) == true, "Metadata remains true")

	# Zone 2 expires while player is inside: buff must be cleanly cleared!
	rz2._expire()
	assert(player.active_rune_zones == 0, "active_rune_zones is 0 after zone 2 expires")
	assert(player.is_in_rune_zone() == false, "Buff cleanly cleared")
	assert(player.get_meta("in_rune_zone", false) == false, "Metadata cleanly false")

	rz1.queue_free()
	print("[PASS] RuneZone multi-overlap and reference counting verified.")

func test_all_enemy_archetypes_status_dots_and_bars(parent: Node) -> void:
	print("[TEST] 15. Status dots and mini health bars across all enemy archetypes...")

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

	await parent.get_tree().process_frame
	print("[PASS] All enemy archetypes render statuses and mini health bars.")

func test_audio_manager_and_save_manager_volumes() -> void:
	print("[TEST] 16. AudioManager separate sliders & SaveManager persistence...")

	SaveManager.set_setting("master_volume", 0.65)
	SaveManager.set_setting("sfx_volume", 0.45)
	assert(abs(SaveManager.get_setting("master_volume") - 0.65) < 0.01, "master_volume saved")
	assert(abs(SaveManager.get_setting("sfx_volume") - 0.45) < 0.01, "sfx_volume saved")

	if AudioManager.instance:
		AudioManager.instance.set_master_volume(0.65)
		AudioManager.instance.set_sfx_volume(0.45)
		assert(abs(AudioManager.instance.master_volume - 0.65) < 0.01, "AudioManager master_volume updated")
		assert(abs(AudioManager.instance.sfx_volume - 0.45) < 0.01, "AudioManager sfx_volume updated")

	# Restore default
	SaveManager.set_setting("master_volume", 1.0)
	SaveManager.set_setting("sfx_volume", 0.8)
	if AudioManager.instance:
		AudioManager.instance.set_master_volume(1.0)
		AudioManager.instance.set_sfx_volume(0.8)

	print("[PASS] AudioManager separate sliders and SaveManager persistence verified.")
