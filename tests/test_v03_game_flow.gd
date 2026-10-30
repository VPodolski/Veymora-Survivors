class_name TestV03GameFlow
extends SceneTree

const GameFlowController = preload("res://scripts/game/game_flow_controller.gd")
const RunConfig = preload("res://scripts/game/run_config.gd")
const ArenaConfig = preload("res://scripts/arena/arena_config.gd")
const RunStats = preload("res://scripts/game/run_stats.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const FrostHazardZone = preload("res://scripts/arena/frost_hazard_zone.gd")
const Arena = preload("res://scripts/arena/arena.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const ResultsScreen = preload("res://scripts/ui/results_screen.gd")
const SettingsDialog = preload("res://scripts/ui/settings_dialog.gd")

func _init() -> void:
	call_deferred("run_all_v03_tests")

func run_all_v03_tests() -> void:
	print("\n--- Running Version 0.3 Game Flow & Features Verification Suite ---")

	test_arena_config_catalog()
	test_save_manager_v2_and_migration()
	test_run_stats_and_synergy_aggregation()
	test_game_flow_controller_transitions()
	test_arena_configuration_and_frost_hazard()
	test_player_frost_slow_reference_counting()
	test_ui_scenes_instantiation()
	test_results_screen_rendering()
	test_settings_dialog_persistence()

	print("--- ALL VERSION 0.3 TESTS PASSED SUCCESSFULLY! ---\n")
	quit(0)

func test_arena_config_catalog() -> void:
	print("[TEST] 1. ArenaConfig catalog and all 4 arenas verification...")
	var catalog = ArenaConfig.get_catalog()
	assert(catalog.size() == 4, "Catalog must contain 4 arenas")
	assert(catalog.has("forgotten_forest"), "Must contain forgotten_forest")
	assert(catalog.has("frost_necropolis"), "Must contain frost_necropolis")
	assert(catalog.has("ash_citadel"), "Must contain ash_citadel")
	assert(catalog.has("void_rift"), "Must contain void_rift")

	var forest = catalog["forgotten_forest"]
	assert(forest.is_unlocked == true, "Forgotten forest must be unlocked by default")
	assert(forest.special_mechanic == "rune_hotspots", "Forest must have rune_hotspots")

	var necro = catalog["frost_necropolis"]
	assert(necro.is_unlocked == true, "Frost necropolis is playable in v0.3")
	assert(necro.special_mechanic == "frost_zones", "Necropolis must have frost_zones")

	var citadel = catalog["ash_citadel"]
	assert(citadel.is_unlocked == false, "Ash citadel must be locked preview for v0.4")

	var void_rift = catalog["void_rift"]
	assert(void_rift.is_unlocked == false, "Void rift must be locked preview for v0.4")

	var fallback = ArenaConfig.get_arena_config("non_existent_arena")
	assert(fallback.id == "forgotten_forest", "Fallback arena must be forgotten_forest")
	print("[PASS] ArenaConfig catalog verified.")

func test_save_manager_v2_and_migration() -> void:
	print("[TEST] 2. SaveManager v2 schema, migration & arena stats...")
	var raw_v1_data = {
		"version": 1,
		"total_runs": 5,
		"best_survival_time": 240.0,
		"bosses_defeated": 1,
		"total_kills": 80,
		"discovered_spells": ["magic_bolt", "ice_storm"]
	}

	var migrated = SaveManager.sanitize_data(raw_v1_data)
	assert(migrated["version"] == 2, "Migrated version must be 2")
	assert(migrated["total_runs"] == 5, "Total runs preserved")
	assert(migrated["bosses_defeated"] == 1, "Bosses defeated preserved")
	assert(migrated.has("unlocked_arenas"), "Must contain unlocked_arenas")
	assert(migrated["unlocked_arenas"].has("forgotten_forest"), "Forest unlocked")
	assert(migrated["unlocked_arenas"].has("frost_necropolis"), "Necropolis unlocked")
	assert(migrated.has("arena_stats"), "Must have arena_stats")
	assert(migrated.has("run_history"), "Must have run_history")
	assert(migrated["screen_shake"] == true, "Default screen shake is true")
	assert(migrated["damage_numbers"] == true, "Default damage numbers is true")
	assert(migrated["vsync"] == true, "Default vsync is true")

	# Test record_run with summary
	var summary = {
		"arena_id": "frost_necropolis",
		"survival_time": 350.0,
		"kills": 45,
		"defeated_boss": true
	}
	var updated = SaveManager.record_run(350.0, 45, true, summary)
	assert(updated["total_runs"] >= 1, "Total runs incremented")
	assert(updated["arena_stats"]["frost_necropolis"]["runs"] >= 1, "Frost necropolis runs incremented")
	assert(updated["arena_stats"]["frost_necropolis"]["wins"] >= 1, "Frost necropolis wins incremented")
	assert(updated["run_history"].size() >= 1, "Run history recorded")
	print("[PASS] SaveManager v2 and migration verified.")

func test_run_stats_and_synergy_aggregation() -> void:
	print("[TEST] 3. RunStats aggregation and synergy metrics...")
	var stats = RunStats.new()
	stats.arena_id = "frost_necropolis"
	stats.arena_name = "Ледяной некрополь"
	stats.survival_time = 420.0
	stats.record_damage(1000.0)
	stats.record_xp(250.0)
	stats.artifacts_collected = 3

	# Record synergies
	stats.record_synergy_trigger("resonance", 150.0)
	stats.record_synergy_trigger("resonance", 150.0)
	stats.record_synergy_trigger("steam_rift", 100.0)

	assert(stats.synergy_counts["resonance"] == 2, "Resonance trigger count must be 2")
	assert(stats.synergy_damage["resonance"] == 300.0, "Resonance damage must be 300")
	assert(stats.synergy_counts["steam_rift"] == 1, "Steam rift count must be 1")
	assert(stats.synergy_damage["steam_rift"] == 100.0, "Steam rift damage must be 100")

	assert(stats.get_most_effective_synergy() == "resonance", "Most effective must be resonance")
	assert(is_equal_approx(stats.get_total_synergy_damage(), 400.0), "Total synergy damage must be 400")
	assert(is_equal_approx(stats.get_synergy_damage_ratio(), 0.4), "Synergy ratio must be 400/1000 = 0.4")

	var dict = stats.to_dictionary()
	assert(dict["arena_id"] == "frost_necropolis", "Dictionary arena_id matches")
	assert(dict["damage_dealt"] == 1000.0, "Dictionary damage matches")
	assert(dict["most_effective_synergy"] == "resonance", "Dictionary most effective matches")
	assert(is_equal_approx(dict["synergy_ratio"], 0.4), "Dictionary synergy ratio matches")
	print("[PASS] RunStats and synergy aggregation verified.")

func test_game_flow_controller_transitions() -> void:
	print("[TEST] 4. GameFlowController state flow and config passing...")
	var flow = GameFlowController.new()
	root.add_child(flow)

	assert(flow.current_state == GameFlowController.STATE_MAIN_MENU, "Initial state is main menu")

	var cfg = RunConfig.new("frost_necropolis", ["fast_enemies"])
	assert(cfg.arena_id == "frost_necropolis", "Config arena id set")
	assert(cfg.has_modifier("fast_enemies"), "Modifier present")

	var dup = cfg.duplicate_config() as RunConfig
	assert(dup.arena_id == "frost_necropolis", "Duplicated config arena matches")
	assert(dup.has_modifier("fast_enemies"), "Duplicated modifier matches")

	flow.current_run_config = cfg
	assert(flow.get_run_config().arena_id == "frost_necropolis", "Flow returns current config")

	flow.queue_free()
	print("[PASS] GameFlowController verified.")

func test_arena_configuration_and_frost_hazard() -> void:
	print("[TEST] 5. Arena configuration and FrostHazardZone mechanics...")
	var arena_scene = preload("res://scenes/arena/arena.tscn")
	var arena = arena_scene.instantiate() as Arena
	root.add_child(arena)

	var necro_cfg = ArenaConfig.get_arena_config("frost_necropolis")
	arena.apply_arena_config(necro_cfg)
	assert(arena.current_arena_id == "frost_necropolis", "Arena id must match config")
	assert(arena.arena_size == necro_cfg.arena_size, "Arena size matches config")
	assert(arena.border_color == necro_cfg.border_color, "Border color matches config")

	# Test FrostHazardZone lifecycle
	var fz = FrostHazardZone.new()
	fz.warning_duration = 0.05
	fz.active_duration = 0.1
	root.add_child(fz)

	assert(fz.is_active == false, "Initially in warning state")
	assert(fz.collision_shape.disabled == true, "Collision disabled in warning state")

	# Simulate process past warning
	fz._process(0.06)
	assert(fz.is_active == true, "Zone activated after warning duration")
	assert(fz.collision_shape.disabled == false, "Collision enabled after activation")

	fz.queue_free()
	arena.queue_free()
	print("[PASS] Arena configuration and FrostHazardZone verified.")

func test_player_frost_slow_reference_counting() -> void:
	print("[TEST] 6. PlayerController frost zone reference counting and speed mult...")
	var player_scene = preload("res://scenes/player/player.tscn")
	var player = player_scene.instantiate() as PlayerController
	root.add_child(player)

	assert(player.active_frost_zones == 0, "Initial frost zones 0")
	assert(is_equal_approx(player.get_effective_speed_mult(), 1.0), "Initial speed mult 1.0")

	player.enter_frost_zone()
	assert(player.active_frost_zones == 1, "Entered 1 zone")
	assert(is_equal_approx(player.get_effective_speed_mult(), 0.65), "Slowed speed mult 0.65")

	# Enter overlapping 2nd frost zone
	player.enter_frost_zone()
	assert(player.active_frost_zones == 2, "Entered 2nd overlapping zone")
	assert(is_equal_approx(player.get_effective_speed_mult(), 0.65), "Still slowed to 0.65")

	# Exit 1 zone
	player.exit_frost_zone()
	assert(player.active_frost_zones == 1, "Exited 1 zone, 1 remains")
	assert(is_equal_approx(player.get_effective_speed_mult(), 0.65), "Still slowed while inside 1")

	# Exit last zone
	player.exit_frost_zone()
	assert(player.active_frost_zones == 0, "All zones exited")
	assert(is_equal_approx(player.get_effective_speed_mult(), 1.0), "Speed restored to 1.0")

	# Test reset_frost_zones
	player.enter_frost_zone()
	player.enter_frost_zone()
	player.reset_frost_zones()
	assert(player.active_frost_zones == 0, "Reset clears all frost zones")
	assert(is_equal_approx(player.get_effective_speed_mult(), 1.0), "Speed restored after reset")

	player.queue_free()
	print("[PASS] PlayerController frost slow reference counting verified.")

func test_ui_scenes_instantiation() -> void:
	print("[TEST] 7. Main Menu, Arena Select, Loading Screen scenes instantiation...")
	var menu_scene = preload("res://scenes/ui/main_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	assert(menu != null, "Main menu instantiates")
	assert(menu.get_node_or_null("Center/VBox/StartButton") != null, "Start button present")
	assert(menu.get_node_or_null("Center/VBox/SettingsButton") != null, "Settings button present")
	assert(menu.get_node_or_null("Center/VBox/ArchiveButton") != null, "Archive button present")
	menu.queue_free()

	var sel_scene = preload("res://scenes/ui/arena_select.tscn")
	var sel = sel_scene.instantiate()
	root.add_child(sel)
	assert(sel != null, "Arena select instantiates")
	assert(sel.get_node_or_null("Center/VBox/BottomBar/StartRunButton") != null, "Start run button present")
	sel.queue_free()

	var load_scene = preload("res://scenes/ui/loading_screen.tscn")
	var loader = load_scene.instantiate()
	root.add_child(loader)
	assert(loader != null, "Loading screen instantiates")
	loader.queue_free()

	print("[PASS] UI scenes instantiation verified.")

func test_results_screen_rendering() -> void:
	print("[TEST] 8. ResultsScreen rendering with metrics and synergy breakdown...")
	var res_scene = preload("res://scenes/ui/results_screen.tscn")
	var res = res_scene.instantiate() as ResultsScreen
	root.add_child(res)

	var run_data = RunStats.new()
	run_data.arena_id = "frost_necropolis"
	run_data.arena_name = "Ледяной некрополь"
	run_data.survival_time = 480.0
	run_data.total_kills = 120
	run_data.elite_kills = 3
	run_data.boss_kills = 1
	run_data.level_reached = 12
	run_data.defeated_boss = true
	run_data.damage_dealt = 5000.0
	run_data.experience_gained = 1200.0
	run_data.artifacts_collected = 4
	run_data.record_synergy_trigger("resonance", 1200.0)
	run_data.record_synergy_trigger("steam_rift", 800.0)

	res.display_stats(run_data)
	assert(res.title_label.text.contains("ПОБЕДА"), "Victory text displayed")
	assert(res.stats_grid.get_child_count() > 0, "Stats metrics grid populated")
	assert(res.synergy_headline_label.text.contains("Вклад синергий"), "Synergy headline displayed")
	assert(res.synergy_cards_container.get_child_count() == 2, "2 synergy cards displayed")

	res.queue_free()
	print("[PASS] ResultsScreen rendering verified.")

func test_settings_dialog_persistence() -> void:
	print("[TEST] 9. SettingsDialog audio/visual options persistence...")
	var set_scene = preload("res://scenes/ui/settings_dialog.tscn")
	var dialog = set_scene.instantiate() as SettingsDialog
	root.add_child(dialog)

	dialog.open()
	assert(dialog.visible == true, "Dialog opened")

	# Test master volume slider
	dialog._on_master_slider_changed(0.65)
	assert(is_equal_approx(float(SaveManager.get_setting("master_volume", 1.0)), 0.65), "Master volume persisted")

	# Test sfx volume slider
	dialog._on_sfx_slider_changed(0.45)
	assert(is_equal_approx(float(SaveManager.get_setting("sfx_volume", 0.8)), 0.45), "SFX volume persisted")

	# Test screen shake
	dialog._on_shake_toggled(false)
	assert(SaveManager.get_setting("screen_shake", true) == false, "Screen shake disabled persisted")
	dialog._on_shake_toggled(true)
	assert(SaveManager.get_setting("screen_shake", false) == true, "Screen shake re-enabled persisted")

	# Test damage numbers
	dialog._on_dmg_num_toggled(false)
	assert(SaveManager.get_setting("damage_numbers", true) == false, "Damage numbers disabled persisted")
	dialog._on_dmg_num_toggled(true)
	assert(SaveManager.get_setting("damage_numbers", false) == true, "Damage numbers re-enabled persisted")

	dialog.close()
	assert(dialog.visible == false, "Dialog closed")
	dialog.queue_free()
	print("[PASS] SettingsDialog options persistence verified.")

