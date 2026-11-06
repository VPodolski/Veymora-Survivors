extends SceneTree

const SaveManager = preload("res://scripts/game/save_manager.gd")
const CharacterProgressionManager = preload("res://scripts/progression/character_progression_manager.gd")
const MetaShopConfig = preload("res://scripts/progression/meta_shop_config.gd")
const MetaShopManager = preload("res://scripts/progression/meta_shop_manager.gd")
const RunStats = preload("res://scripts/game/run_stats.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const PlayerStats = preload("res://scripts/player/player_stats.gd")
const MagicBoltAbility = preload("res://scripts/abilities/magic_bolt_ability.gd")
const GoldCoin = preload("res://scripts/pickups/gold_coin.gd")
const XPGem = preload("res://scripts/pickups/xp_gem.gd")
const Chest = preload("res://scripts/pickups/chest.gd")
const ResultsScreen = preload("res://scripts/ui/results_screen.gd")

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
	test_8_gold_coin_pickup_and_xp_gem_independence()
	test_9_chest_gold_and_runstats_tracking()
	test_10_results_screen_idempotency()

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

	# Simulate legacy v1 / v2 save data without meta progression fields
	var legacy_save: Dictionary = {
		"version": 2,
		"high_score": 1250,
		"best_survival_time": 240.0,
		"unlocked_arenas": ["forgotten_forest"]
	}

	var sanitized = SaveManager.sanitize_data(legacy_save)
	assert(sanitized.get("version") == 3, "Version bumped to 3")
	assert(sanitized.has("gold") and sanitized["gold"] == 0, "Default gold is 0")
	assert(sanitized.has("characters") and sanitized["characters"].has("wizard"), "Wizard character entry present")
	assert(sanitized["characters"]["wizard"]["level"] == 1, "Wizard initial level is 1")
	assert(sanitized["characters"]["wizard"]["xp"] == 0, "Wizard initial XP is 0")
	assert(sanitized.has("shop_upgrades") and sanitized["shop_upgrades"].is_empty(), "Shop upgrades initialized empty")

	# Test sanitization against negative or corrupted data
	var corrupted: Dictionary = {
		"gold": -50,
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
# 2. Cloud Sync Progression Merge
# -----------------------------------------------------------------------------
func test_2_cloud_sync_progression_merge() -> void:
	print("[TEST] 2. Cloud sync progression merge (Gold, Character XP, Upgrades)...")

	var local_state: Dictionary = {
		"gold": 250,
		"characters": {
			"wizard": {"level": 2, "xp": 120}
		},
		"shop_upgrades": {
			"vitality_health": 2,
			"defense_armor": 1
		}
	}

	var cloud_state: Dictionary = {
		"gold": 400,
		"characters": {
			"wizard": {"level": 3, "xp": 40}
		},
		"shop_upgrades": {
			"vitality_health": 1,
			"magic_power": 3
		}
	}

	var merged = SaveManager.merge_with_cloud(cloud_state, local_state)

	# Highest gold preserved
	assert(merged["gold"] == 400, "Highest gold preserved (got %d)" % merged["gold"])

	# Highest character level & XP preserved
	assert(merged["characters"]["wizard"]["level"] == 3, "Highest wizard level preserved (got %d)" % merged["characters"]["wizard"]["level"])
	assert(merged["characters"]["wizard"]["xp"] == 120, "Highest wizard XP preserved (got %d)" % merged["characters"]["wizard"]["xp"])

	# Max purchased level for each upgrade preserved
	assert(merged["shop_upgrades"]["vitality_health"] == 2, "Max vitality level (2) preserved")
	assert(merged["shop_upgrades"]["defense_armor"] == 1, "Local defense upgrade preserved")
	assert(merged["shop_upgrades"]["magic_power"] == 3, "Cloud magic power upgrade preserved")

	print("[PASS] 2. Cloud sync progression merge verified.")

# -----------------------------------------------------------------------------
# 3. Character XP & Level-up Formulas
# -----------------------------------------------------------------------------
func test_3_character_xp_and_level_up_formulas() -> void:
	print("[TEST] 3. Character XP curves and level-up calculations...")

	# XP curve verification: smooth exponential progression
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
	SaveManager.save_character_data("wizard", 1, 0)
	var res = CharacterProgressionManager.add_character_xp("wizard", 450)
	assert(res.leveled_up == true, "Level-up triggered")
	assert(res.new_level >= 2, "Wizard leveled up from 1 to at least 2 (new level %d)" % res.new_level)
	assert(res.current_xp >= 0, "Positive remaining XP")

	print("[PASS] 3. Character XP curves and level-up verified.")

# -----------------------------------------------------------------------------
# 4. Starter Spell Auto-scaling
# -----------------------------------------------------------------------------
func test_4_starter_spell_auto_scaling() -> void:
	print("[TEST] 4. Starter spell auto-scaling with character progression...")

	# At level 1: no bonus
	SaveManager.save_character_data("wizard", 1, 0)
	var bonus_l1 = CharacterProgressionManager.get_character_bonuses("wizard")
	assert(bonus_l1.damage_bonus == 0.0, "Lv 1 has +0.0 damage bonus")
	assert(bonus_l1.speed_bonus == 0.0, "Lv 1 has +0.0 speed bonus")

	# At level 4: 3 bonus levels -> +7.5 damage, +60.0 projectile speed
	SaveManager.save_character_data("wizard", 4, 0)
	var bonus_l4 = CharacterProgressionManager.get_character_bonuses("wizard")
	assert(is_equal_approx(bonus_l4.damage_bonus, 7.5), "Lv 4 has +7.5 damage bonus (got %f)" % bonus_l4.damage_bonus)
	assert(is_equal_approx(bonus_l4.speed_bonus, 60.0), "Lv 4 has +60.0 speed bonus (got %f)" % bonus_l4.speed_bonus)

	# Test player & MagicBoltAbility integration
	var player = PlayerController.new()
	player.stats = PlayerStats.new()
	CharacterProgressionManager.apply_character_progression_to_player(player, "wizard")
	assert(player.get_meta("character_level") == 4, "Player meta has character level 4")
	assert(is_equal_approx(player.get_meta("char_spell_damage_bonus"), 7.5), "Player meta has damage bonus")
	assert(is_equal_approx(player.get_meta("char_projectile_speed_bonus"), 60.0), "Player meta has speed bonus")

	var spell = MagicBoltAbility.new()
	spell.player_owner = player
	var eff_dmg = spell.get_effective_damage()
	# Base damage 22.0 + 7.5 bonus = 29.5
	assert(is_equal_approx(eff_dmg, 29.5), "Magic Bolt effective damage scaled to 29.5 (got %f)" % eff_dmg)

	player.queue_free()
	spell.queue_free()
	print("[PASS] 4. Starter spell auto-scaling verified.")

# -----------------------------------------------------------------------------
# 5. Gold Currency & Economy
# -----------------------------------------------------------------------------
func test_5_gold_currency_economy() -> void:
	print("[TEST] 5. Gold currency economy (Saving, Adding, Spending)...")

	var data = SaveManager.load_data()
	data["gold"] = 0
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

	print("[PASS] 5. Gold currency economy verified.")

# -----------------------------------------------------------------------------
# 6. Meta Shop Purchases & Level Caps
# -----------------------------------------------------------------------------
func test_6_meta_shop_purchases_and_caps() -> void:
	print("[TEST] 6. Meta Shop purchasing, affordability, and max level caps...")

	# Clear all shop upgrades and set gold to 150
	var data = SaveManager.load_data()
	data["shop_upgrades"] = {}
	data["gold"] = 150
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

	# Set up mock purchased upgrades across multiple categories
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
# 8. Gold Coin Pickup & XP Gem Independence
# -----------------------------------------------------------------------------
func test_8_gold_coin_pickup_and_xp_gem_independence() -> void:
	print("[TEST] 8. Gold Coin collection & independent XP Gem verification...")

	# Clear gold
	var data = SaveManager.load_data()
	data["gold"] = 0
	SaveManager.save_custom_data(data)

	var run = RunStats.new()
	RunStats.active_stats = run

	# 1. Gold Coin
	var coin = preload("res://scenes/pickups/gold_coin.tscn").instantiate() as GoldCoin
	coin.gold_value = 5
	coin.collect()

	assert(SaveManager.get_gold() == 5, "SaveManager credited 5 gold (got %d)" % SaveManager.get_gold())
	assert(run.gold_collected == 5, "RunStats tracked 5 gold (got %d)" % run.gold_collected)

	# 2. XP Gem
	var gem = preload("res://scenes/pickups/xp_gem.tscn").instantiate() as XPGem
	gem.xp_value = 10
	var col = gem.get_tier_color()
	assert(col.b > col.r and col.g > col.r, "XP Gem has sapphire azure color")

	coin.queue_free()
	gem.queue_free()
	print("[PASS] 8. Gold Coin collection and independent XP Gem verified.")

# -----------------------------------------------------------------------------
# 9. Chest Gold & RunStats Tracking
# -----------------------------------------------------------------------------
func test_9_chest_gold_and_runstats_tracking() -> void:
	print("[TEST] 9. Chest gold award and RunStats metrics...")

	var run = RunStats.new()
	RunStats.active_stats = run

	var data = SaveManager.load_data()
	data["gold"] = 0
	SaveManager.save_custom_data(data)

	var player = PlayerController.new()
	player.stats = PlayerStats.new()
	player.stats.gold_reward_mult = 1.40 # +40% bonus

	var chest = Chest.new()
	chest.open_chest(player)

	# Base 25 * 1.40 = 35 gold
	assert(run.chests_opened == 1, "RunStats recorded 1 chest opened")
	assert(run.gold_collected == 35, "RunStats recorded 35 gold collected (got %d)" % run.gold_collected)
	assert(SaveManager.get_gold() == 35, "SaveManager awarded 35 gold (got %d)" % SaveManager.get_gold())

	player.queue_free()
	chest.queue_free()
	print("[PASS] 9. Chest gold award and RunStats metrics verified.")

# -----------------------------------------------------------------------------
# 10. Results Screen Award Idempotency
# -----------------------------------------------------------------------------
func test_10_results_screen_idempotency() -> void:
	print("[TEST] 10. Results screen single-award idempotency (no double dip)...")

	var initial_gold = SaveManager.get_gold()
	var char_data = SaveManager.get_character_data("wizard")
	var initial_xp = int(char_data.get("xp", 0))

	var run = RunStats.new()
	run.total_kills = 20
	run.chests_opened = 1
	run.survival_time = 120.0

	var screen = ResultsScreen.new()
	screen.display_stats(run)

	var after_first_gold = SaveManager.get_gold()
	var char_after_first = SaveManager.get_character_data("wizard")
	var after_first_xp = int(char_after_first.get("xp", 0))

	assert(after_first_xp > initial_xp, "First display_stats awarded character XP")

	# Second call to display_stats on same results screen instance
	screen.display_stats(run)

	var after_second_gold = SaveManager.get_gold()
	var char_after_second = SaveManager.get_character_data("wizard")
	var after_second_xp = int(char_after_second.get("xp", 0))

	assert(after_second_gold == after_first_gold, "Gold was NOT awarded a second time")
	assert(after_second_xp == after_first_xp, "Character XP was NOT awarded a second time")

	screen.queue_free()
	print("[PASS] 10. Results screen award idempotency verified.")
