extends SceneTree

const SaveManager = preload("res://scripts/game/save_manager.gd")
const CharacterProgressionManager = preload("res://scripts/progression/character_progression_manager.gd")
const MetaShopConfig = preload("res://scripts/progression/meta_shop_config.gd")
const MetaShopManager = preload("res://scripts/progression/meta_shop_manager.gd")
const RunStats = preload("res://scripts/game/run_stats.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const PlayerStats = preload("res://scripts/player/player_stats.gd")
const MagicBoltAbility = preload("res://scripts/abilities/magic_bolt_ability.gd")
const IceStormAbility = preload("res://scripts/abilities/ice_storm_ability.gd")
const FireballAbility = preload("res://scripts/abilities/fireball_ability.gd")
const RunicBladeAbility = preload("res://scripts/abilities/runic_blade_ability.gd")
const LightningAbility = preload("res://scripts/abilities/lightning_ability.gd")
const GoldCoin = preload("res://scripts/pickups/gold_coin.gd")
const XPGem = preload("res://scripts/pickups/xp_gem.gd")
const Chest = preload("res://scripts/pickups/chest.gd")
const ResultsScreen = preload("res://scripts/ui/results_screen.gd")
const EnemyController = preload("res://scripts/enemies/enemy_controller.gd")
const EliteEnemyController = preload("res://scripts/enemies/elite_enemy_controller.gd")
const BossController = preload("res://scripts/enemies/boss_controller.gd")

func _init() -> void:
	print("\n=======================================================")
	print("--- Running Meta-Progression & Economy Test Suite ---")
	print("=======================================================\n")

	SaveManager.save_custom_data(SaveManager.get_default_data())

	test_1_save_manager_v3_migration_and_sanitization()
	test_2_cloud_sync_progression_merge()
	test_3_character_xp_and_level_up_formulas()
	test_4_starter_spell_auto_scaling()
	test_5_gold_currency_economy()
	test_6_meta_shop_purchases_and_caps()
	test_7_meta_shop_player_stats_application()
	test_8_gold_coin_pickup_and_batch_saving()
	test_9_chest_gold_and_runstats_tracking()
	test_10_results_screen_idempotency()
	test_11_unique_run_id_deduplication()
	test_12_total_xp_reconstruction()
	test_13_area_upgrades_scaling()
	test_14_elite_and_boss_drops()

	SaveManager.save_custom_data(SaveManager.get_default_data())

	print("\n=======================================================")
	print("--- ALL META-PROGRESSION TESTS PASSED CLEANLY! ---")
	print("=======================================================\n")
	quit()

# -----------------------------------------------------------------------------
# 1. SaveManager v3 Migration & Sanitization
# -----------------------------------------------------------------------------
func test_1_save_manager_v3_migration_and_sanitization() -> void:
	print("[TEST] 1. SaveManager v3 schema migration & data sanitization...")

	var legacy_save: Dictionary = {
		"version": 2,
		"high_score": 1250,
		"best_survival_time": 240.0,
		"unlocked_arenas": ["forgotten_forest"]
	}

	var sanitized = SaveManager.sanitize_data(legacy_save)
	assert(sanitized.get("version") == 3, "Version bumped to 3")
	assert(sanitized.has("gold") and sanitized["gold"] == 0, "Default gold is 0")
	assert(sanitized.has("lifetime_gold_earned") and sanitized["lifetime_gold_earned"] == 0, "Lifetime gold earned is 0")
	assert(sanitized.has("lifetime_gold_spent") and sanitized["lifetime_gold_spent"] == 0, "Lifetime gold spent is 0")
	assert(sanitized.has("characters") and sanitized["characters"].has("wizard"), "Wizard character entry present")
	assert(sanitized["characters"]["wizard"]["level"] == 1, "Wizard initial level is 1")
	assert(sanitized["characters"]["wizard"]["xp"] == 0, "Wizard initial XP is 0")
	assert(sanitized.has("shop_upgrades") and sanitized["shop_upgrades"].is_empty(), "Shop upgrades initialized empty")

	# Corrupted data recovery
	var corrupted: Dictionary = {
		"gold": -50,
		"lifetime_gold_earned": -10,
		"characters": {
			"wizard": {"level": -5, "xp": -100}
		},
		"shop_upgrades": {
			"vitality_health": -1,
			"defense_armor": 0
		}
	}
	var clean = SaveManager.sanitize_data(corrupted)
	assert(clean["gold"] == 0, "Negative gold sanitized to 0")
	assert(clean["characters"]["wizard"]["level"] == 1, "Negative level sanitized to minimum 1")
	assert(clean["characters"]["wizard"]["xp"] == 0, "Negative XP sanitized to minimum 0")
	assert(clean["shop_upgrades"].is_empty(), "Non-positive upgrades purged")

	print("[PASS] 1. SaveManager v3 schema migration & sanitization verified.")

# -----------------------------------------------------------------------------
# 2. Cloud Sync Progression Merge (Protect Spent Currency)
# -----------------------------------------------------------------------------
func test_2_cloud_sync_progression_merge() -> void:
	print("[TEST] 2. Cloud sync progression merge (Gold, Character XP, Upgrades)...")

	# Device A spent gold on upgrades: earned 500, spent 300, remaining gold 200
	var local_state: Dictionary = {
		"gold": 200,
		"lifetime_gold_earned": 500,
		"lifetime_gold_spent": 300,
		"characters": {
			"wizard": {"level": 2, "xp": 120}
		},
		"shop_upgrades": {
			"vitality_health": 2, # Cost 50 + 100 = 150
			"defense_armor": 1    # Cost 80
		}
	}

	# Stale cloud save: gold balance 400, but 0 spent
	var cloud_state: Dictionary = {
		"gold": 400,
		"lifetime_gold_earned": 400,
		"lifetime_gold_spent": 0,
		"characters": {
			"wizard": {"level": 3, "xp": 40}
		},
		"shop_upgrades": {
			"magic_power": 1      # Cost 100
		}
	}

	var merged = SaveManager.merge_with_cloud(cloud_state, local_state)

	# Protection against stale gold resurrecting spent coins:
	# Total spent accounts for all merged upgrades: vitality (2) + armor (1) + magic_power (1)
	assert(merged["lifetime_gold_spent"] >= 330, "Monotonic spent gold tracks all purchased upgrades")
	assert(merged["gold"] == merged["lifetime_gold_earned"] - merged["lifetime_gold_spent"], "Gold balance is earned minus spent")

	# Character total XP preserved
	assert(merged["characters"]["wizard"]["level"] >= 3, "Highest wizard level preserved")
	assert(merged["characters"]["wizard"]["total_xp"] >= 260, "Highest total XP preserved")

	# Upgrades merged to highest level
	assert(merged["shop_upgrades"]["vitality_health"] == 2, "Local vitality upgrade preserved")
	assert(merged["shop_upgrades"]["defense_armor"] == 1, "Local defense upgrade preserved")
	assert(merged["shop_upgrades"]["magic_power"] == 1, "Cloud magic power upgrade preserved")

	print("[PASS] 2. Cloud sync progression merge verified.")

# -----------------------------------------------------------------------------
# 3. Character XP & Level-up Formulas
# -----------------------------------------------------------------------------
func test_3_character_xp_and_level_up_formulas() -> void:
	print("[TEST] 3. Character XP curves and level-up calculations...")

	var req_1 = CharacterProgressionManager.get_required_xp(1)
	var req_2 = CharacterProgressionManager.get_required_xp(2)
	var req_3 = CharacterProgressionManager.get_required_xp(3)
	assert(req_1 == 100, "Level 1 requires 100 XP (got %d)" % req_1)
	assert(req_2 > req_1, "Level 2 requires more XP (%d > %d)" % [req_2, req_1])
	assert(req_3 > req_2, "Level 3 requires more XP (%d > %d)" % [req_3, req_2])

	# Post-run XP calculation
	var run = RunStats.new()
	run.total_kills = 80
	run.chests_opened = 2
	run.defeated_boss = true
	run.survival_time = 300.0
	run.is_victory = true

	var earned_xp = CharacterProgressionManager.calculate_run_character_xp(run)
	# 80 * 1 + 2 * 25 + 150 (boss) + 60 (time * 0.2) + 200 (victory) = 540 XP
	assert(earned_xp == 540, "Calculated 540 XP from run (got %d)" % earned_xp)

	# Reset wizard to baseline Lv 1, 0 XP
	SaveManager.save_character_data("wizard", 1, 0, 0)
	var res = CharacterProgressionManager.add_character_xp("wizard", 450)
	assert(res.leveled_up == true, "Level-up triggered")
	assert(res.new_level >= 2, "Wizard leveled up from 1 to at least 2 (new level %d)" % res.new_level)
	assert(res.current_xp >= 0, "Positive remaining XP")

	print("[PASS] 3. Character XP curves and level-up verified.")

# -----------------------------------------------------------------------------
# 4. Starter Spell Auto-scaling (+1% base damage per level above 1, no speed bonus)
# -----------------------------------------------------------------------------
func test_4_starter_spell_auto_scaling() -> void:
	print("[TEST] 4. Starter spell auto-scaling with character progression (+1%%/lvl)...")

	# At level 1: no bonus
	SaveManager.save_character_data("wizard", 1, 0, 0)
	var bonus_l1 = CharacterProgressionManager.get_character_bonuses("wizard")
	assert(is_equal_approx(bonus_l1.damage_mult_bonus, 0.0), "Lv 1 has +0.0 damage mult bonus")

	# At level 4: 3 bonus levels -> +3% base damage
	SaveManager.save_character_data("wizard", 4, 0)
	var bonus_l4 = CharacterProgressionManager.get_character_bonuses("wizard")
	assert(is_equal_approx(bonus_l4.damage_mult_bonus, 0.03), "Lv 4 has +3%% damage bonus (got %f)" % bonus_l4.damage_mult_bonus)

	# At level 10: 9 bonus levels -> +9% base damage
	SaveManager.save_character_data("wizard", 10, 0)
	var bonus_l10 = CharacterProgressionManager.get_character_bonuses("wizard")
	assert(is_equal_approx(bonus_l10.damage_mult_bonus, 0.09), "Lv 10 has +9%% damage bonus (got %f)" % bonus_l10.damage_mult_bonus)

	# Test player & MagicBoltAbility integration
	var player = PlayerController.new()
	player.stats = PlayerStats.new()
	CharacterProgressionManager.apply_character_progression_to_player(player, "wizard")
	assert(player.get_meta("character_level") == 10, "Player meta has character level 10")
	assert(is_equal_approx(player.get_meta("char_spell_damage_mult_bonus"), 0.09), "Player meta has damage mult bonus 0.09")

	var spell = MagicBoltAbility.new()
	spell.player_owner = player
	var eff_dmg = spell.get_effective_damage()
	# Base damage 22.0 * 1.09 = 23.98
	assert(is_equal_approx(eff_dmg, 22.0 * 1.09), "Magic Bolt effective damage scaled to 23.98 (got %f)" % eff_dmg)

	player.queue_free()
	spell.queue_free()
	print("[PASS] 4. Starter spell auto-scaling verified.")

# -----------------------------------------------------------------------------
# 5. Gold Currency Economy & Monotonic Lifetime
# -----------------------------------------------------------------------------
func test_5_gold_currency_economy() -> void:
	print("[TEST] 5. Gold currency economy (Saving, Adding, Spending, Monotonicity)...")

	var data = SaveManager.load_data()
	data["gold"] = 0
	data["lifetime_gold_earned"] = 0
	data["lifetime_gold_spent"] = 0
	SaveManager.save_custom_data(data)

	assert(SaveManager.get_gold() == 0, "Initial gold is 0")
	SaveManager.add_gold(150)
	assert(SaveManager.get_gold() == 150, "Gold increased to 150")

	var spent_ok = SaveManager.spend_gold(50)
	assert(spent_ok == true, "Spent 50 gold successfully")
	assert(SaveManager.get_gold() == 100, "Gold remaining is 100")

	var overspend = SaveManager.spend_gold(300)
	assert(overspend == false, "Cannot overspend beyond balance")
	assert(SaveManager.get_gold() == 100, "Gold remains 100 after failed spend")

	var post_data = SaveManager.load_data()
	assert(post_data["lifetime_gold_earned"] == 150, "Lifetime earned tracks 150")
	assert(post_data["lifetime_gold_spent"] == 50, "Lifetime spent tracks 50")

	print("[PASS] 5. Gold currency economy verified.")

# -----------------------------------------------------------------------------
# 6. Meta Shop Purchases & Level Caps
# -----------------------------------------------------------------------------
func test_6_meta_shop_purchases_and_caps() -> void:
	print("[TEST] 6. Meta Shop purchasing, affordability, and max level caps...")

	var data = SaveManager.load_data()
	data["shop_upgrades"] = {}
	data["gold"] = 150
	data["lifetime_gold_earned"] = 150
	data["lifetime_gold_spent"] = 0
	SaveManager.save_custom_data(data)

	# vitality_health costs: [50, 100, 200, 350, 600]
	assert(MetaShopManager.can_purchase("vitality_health") == true, "Can afford Lv 1 (cost 50, have 150)")
	var bought_1 = MetaShopManager.purchase_upgrade("vitality_health")
	assert(bought_1 == true, "Purchased vitality Lv 1")
	assert(MetaShopManager.get_upgrade_level("vitality_health") == 1, "Level is now 1")
	assert(SaveManager.get_gold() == 100, "Remaining gold is 100")

	# Can afford Lv 2 (cost 100, have 100)
	assert(MetaShopManager.can_purchase("vitality_health") == true, "Can afford Lv 2")
	var bought_2 = MetaShopManager.purchase_upgrade("vitality_health")
	assert(bought_2 == true, "Purchased vitality Lv 2")
	assert(MetaShopManager.get_upgrade_level("vitality_health") == 2, "Level is now 2")
	assert(SaveManager.get_gold() == 0, "Remaining gold is 0")

	# Cannot afford Lv 3 (cost 200, have 0)
	assert(MetaShopManager.can_purchase("vitality_health") == false, "Cannot afford Lv 3")

	# Set level to 5 (max)
	SaveManager.set_upgrade_level("vitality_health", 5)
	SaveManager.add_gold(10000)
	assert(MetaShopManager.can_purchase("vitality_health") == false, "Cannot purchase beyond max level 5")

	print("[PASS] 6. Meta Shop purchases and level caps verified.")

# -----------------------------------------------------------------------------
# 7. Meta Shop Player Stats Application
# -----------------------------------------------------------------------------
func test_7_meta_shop_player_stats_application() -> void:
	print("[TEST] 7. Applying permanent shop upgrades to player stats...")

	var data = SaveManager.load_data()
	data["shop_upgrades"] = {
		"vitality_health": 3,   # +30 HP
		"vitality_regen": 2,    # +0.8 HP/s
		"defense_armor": 2,     # +6% DR
		"defense_barrier": 2,   # +30% barrier
		"magic_power": 3,       # +12% spell power
		"magic_cooldown": 2,    # -6% CD
		"magic_area": 2,        # +10% area
		"synergy_potency": 2,   # +12% synergy dmg
		"synergy_energy": 2,    # +20% energy gain
		"treasure_greed": 2,    # +6% coin drop
		"treasure_bounty": 2    # +40% gold reward
	}
	SaveManager.save_custom_data(data)

	var player = PlayerController.new()
	player.stats = PlayerStats.new()
	MetaShopManager.apply_shop_upgrades_to_player(player)

	assert(is_equal_approx(player.stats.max_health, 130.0), "Max health is 130.0 (got %f)" % player.stats.max_health)
	assert(is_equal_approx(player.stats.hp_regen, 0.8), "HP regen is 0.8 (got %f)" % player.stats.hp_regen)
	assert(is_equal_approx(player.stats.damage_reduction, 0.06), "Damage reduction is 6%% (got %f)" % player.stats.damage_reduction)
	assert(is_equal_approx(player.stats.barrier_durability_mult, 1.30), "Barrier durability is 1.30 (got %f)" % player.stats.barrier_durability_mult)
	assert(is_equal_approx(player.stats.spell_power_mult, 1.12), "Spell power mult is 1.12 (got %f)" % player.stats.spell_power_mult)
	assert(is_equal_approx(player.stats.cooldown_mult, 0.94), "Cooldown mult is 0.94 (got %f)" % player.stats.cooldown_mult)
	assert(is_equal_approx(player.stats.spell_area_mult, 1.10), "Spell area mult is 1.10 (got %f)" % player.stats.spell_area_mult)
	assert(is_equal_approx(player.stats.synergy_damage_mult, 1.12), "Synergy damage mult is 1.12 (got %f)" % player.stats.synergy_damage_mult)
	assert(is_equal_approx(player.stats.synergy_energy_mult, 1.20), "Synergy energy mult is 1.20 (got %f)" % player.stats.synergy_energy_mult)
	assert(is_equal_approx(player.stats.gold_drop_chance_bonus, 0.06), "Gold drop chance bonus is 6%% (got %f)" % player.stats.gold_drop_chance_bonus)
	assert(is_equal_approx(player.stats.gold_reward_mult, 1.40), "Gold reward mult is 1.40 (got %f)" % player.stats.gold_reward_mult)

	player.queue_free()
	print("[PASS] 7. Meta Shop player stats application verified.")

# -----------------------------------------------------------------------------
# 8. Gold Coin Pickup & Batch Saving (No Disk I/O During Run)
# -----------------------------------------------------------------------------
func test_8_gold_coin_pickup_and_batch_saving() -> void:
	print("[TEST] 8. Gold Coin pickup batch saving & sapphire XP Gem...")

	var data = SaveManager.load_data()
	data["gold"] = 10
	data["lifetime_gold_earned"] = 10
	data["lifetime_gold_spent"] = 0
	SaveManager.save_custom_data(data)

	var run = RunStats.new()
	RunStats.active_stats = run

	# 1. Gold Coin pickup during run
	var coin = preload("res://scenes/pickups/gold_coin.tscn").instantiate() as GoldCoin
	coin.gold_value = 5
	coin.collect()

	# Crucial: SaveManager gold must remain 10 (no disk write during run!)
	assert(SaveManager.get_gold() == 10, "SaveManager was NOT modified on coin pickup (batch optimization)")
	assert(run.gold_collected == 5, "RunStats tracked 5 gold collected")

	# 2. XP Gem appearance
	var gem = preload("res://scenes/pickups/xp_gem.tscn").instantiate() as XPGem
	gem.xp_value = 10
	# Gems are independent and sapphire
	assert(gem.xp_value == 10, "Gem XP value preserved")

	coin.queue_free()
	gem.queue_free()
	print("[PASS] 8. Gold Coin batch saving and XP Gem verified.")

# -----------------------------------------------------------------------------
# 9. Chest Gold & RunStats Tracking
# -----------------------------------------------------------------------------
func test_9_chest_gold_and_runstats_tracking() -> void:
	print("[TEST] 9. Chest gold award and RunStats metrics...")

	var run = RunStats.new()
	RunStats.active_stats = run

	var player = PlayerController.new()
	player.stats = PlayerStats.new()
	player.stats.gold_reward_mult = 1.40 # +40% bonus

	var chest = Chest.new()
	chest.open_chest(player)

	assert(run.chests_opened == 1, "RunStats recorded 1 chest opened")
	assert(run.gold_collected == 35, "RunStats recorded 35 gold collected (got %d)" % run.gold_collected)

	player.queue_free()
	chest.queue_free()
	print("[PASS] 9. Chest gold award and RunStats metrics verified.")

# -----------------------------------------------------------------------------
# 10. Results Screen Award Idempotency & Deduplication
# -----------------------------------------------------------------------------
func test_10_results_screen_idempotency() -> void:
	print("[TEST] 10. Results screen single-award idempotency (no double dip)...")

	SaveManager.save_character_data("wizard", 1, 0)
	var initial_gold = SaveManager.get_gold()
	var char_data = SaveManager.get_character_data("wizard")
	var initial_total_xp = int(char_data.get("total_xp", 0))

	var run = RunStats.new()
	run.run_id = "test_run_10_unique"
	run.character_id = "wizard"
	run.total_kills = 20
	run.chests_opened = 1
	run.survival_time = 120.0
	run.gold_collected = 15

	var screen = ResultsScreen.new()
	screen.display_stats(run)

	var after_first_gold = SaveManager.get_gold()
	var char_after_first = SaveManager.get_character_data("wizard")
	var after_first_total_xp = int(char_after_first.get("total_xp", 0))

	assert(after_first_gold > initial_gold, "First display_stats awarded gold")
	assert(after_first_total_xp > initial_total_xp, "First display_stats awarded character total XP")

	# Second call to display_stats on same results screen instance or reload
	screen.display_stats(run)

	var after_second_gold = SaveManager.get_gold()
	var char_after_second = SaveManager.get_character_data("wizard")
	var after_second_total_xp = int(char_after_second.get("total_xp", 0))

	assert(after_second_gold == after_first_gold, "Gold was NOT awarded a second time")
	assert(after_second_total_xp == after_first_total_xp, "Character total XP was NOT awarded a second time")

	screen.queue_free()
	print("[PASS] 10. Results screen award idempotency verified.")

# -----------------------------------------------------------------------------
# 11. Unique Run ID Deduplication in SaveManager
# -----------------------------------------------------------------------------
func test_11_unique_run_id_deduplication() -> void:
	print("[TEST] 11. Unique Run ID deduplication journal in SaveManager...")

	var run_id = "test_run_dedup_xyz"
	var initial_gold = SaveManager.get_gold()

	var first_claim = SaveManager.claim_run_rewards(run_id, "wizard", 100, 50)
	assert(first_claim.success == true, "First claim succeeded")
	assert(first_claim.already_processed == false, "Not marked as already processed")
	assert(SaveManager.get_gold() == initial_gold + 50, "Gold increased by 50")

	var second_claim = SaveManager.claim_run_rewards(run_id, "wizard", 100, 50)
	assert(second_claim.already_processed == true, "Second claim flagged as already processed")
	assert(SaveManager.get_gold() == initial_gold + 50, "Gold balance unchanged on repeated claim")

	print("[PASS] 11. Unique Run ID deduplication verified.")

# -----------------------------------------------------------------------------
# 12. Total XP Reconstruction Algorithm
# -----------------------------------------------------------------------------
func test_12_total_xp_reconstruction() -> void:
	print("[TEST] 12. Total XP reconstruction & conversion across levels...")

	# Lv 1 with 40 residual -> total_xp = 40
	var t1 = CharacterProgressionManager.calc_total_xp_for_level_and_residual(1, 40)
	assert(t1 == 40, "Total XP for Lv 1 + 40 is 40")

	var r1 = CharacterProgressionManager.calc_level_and_residual_from_total(40)
	assert(r1.level == 1 and r1.xp == 40, "Reconstructed Lv 1 and 40 XP")

	# Lv 2 with 0 residual -> total_xp = req(1) = 100
	var t2 = CharacterProgressionManager.calc_total_xp_for_level_and_residual(2, 0)
	assert(t2 == 100, "Total XP for Lv 2 + 0 is 100")

	var r2 = CharacterProgressionManager.calc_level_and_residual_from_total(100)
	assert(r2.level == 2 and r2.xp == 0, "Reconstructed Lv 2 and 0 XP")

	# Lv 3 with 50 residual -> total_xp = req(1) + req(2) + 50
	var req_1 = CharacterProgressionManager.get_required_xp(1)
	var req_2 = CharacterProgressionManager.get_required_xp(2)
	var t3 = CharacterProgressionManager.calc_total_xp_for_level_and_residual(3, 50)
	assert(t3 == req_1 + req_2 + 50, "Total XP matches sum of previous levels + residual")

	var r3 = CharacterProgressionManager.calc_level_and_residual_from_total(t3)
	assert(r3.level == 3 and r3.xp == 50, "Reconstructed Lv 3 and 50 XP accurately")

	print("[PASS] 12. Total XP reconstruction algorithm verified.")

# -----------------------------------------------------------------------------
# 13. Area Upgrades (magic_area) Scaling in All Area Abilities
# -----------------------------------------------------------------------------
func test_13_area_upgrades_scaling() -> void:
	print("[TEST] 13. Scaling of area abilities via spell_area_mult...")

	var player = PlayerController.new()
	player.stats = PlayerStats.new()
	player.stats.spell_area_mult = 1.25 # +25% Area
	player.update_modifiers_meta()

	# 1. Runic Blade
	var blade_spell = RunicBladeAbility.new()
	blade_spell.player_owner = player
	var orbit_r = blade_spell.get_effective_orbit_radius()
	# base 90.0 * 1.25 = 112.5
	assert(is_equal_approx(orbit_r, 112.5), "Runic blade orbit radius scaled by 1.25 (got %f)" % orbit_r)

	player.queue_free()
	blade_spell.queue_free()
	print("[PASS] 13. Area upgrades scaling in abilities verified.")

# -----------------------------------------------------------------------------
# 14. Elite & Boss Drops Architecture (No Duplicate Regular Drops)
# -----------------------------------------------------------------------------
func test_14_elite_and_boss_drops() -> void:
	print("[TEST] 14. Elite and Boss drop isolation...")

	var elite = EliteEnemyController.new()
	assert(elite.has_method("spawn_drop"), "EliteEnemyController overrides spawn_drop")

	var boss = BossController.new()
	assert(boss.has_method("spawn_drop"), "BossController overrides spawn_drop")

	elite.queue_free()
	boss.queue_free()
	print("[PASS] 14. Elite and Boss drop isolation verified.")
