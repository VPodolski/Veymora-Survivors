extends SceneTree

const PauseManager = preload("res://scripts/game/pause_manager.gd")
const YandexGamesBridge = preload("res://scripts/platform/yandex_games_bridge.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")
const VirtualJoystick = preload("res://scripts/ui/virtual_joystick.gd")
const SecondChanceDialog = preload("res://scripts/ui/second_chance_dialog.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")

func _init() -> void:
	print("\n--- Running Yandex Games Platform Integration Test Suite ---")
	call_deferred("run_all_tests")

func run_all_tests() -> void:
	test_pause_manager_multi_reasons_and_mute()
	test_yandex_bridge_lifecycle_and_fallback()
	test_save_manager_cloud_merge()
	test_localization_manager()
	test_virtual_joystick_mechanics()
	test_second_chance_lifecycle()
	test_gameplay_api_integration()

	print("\n--- ALL YANDEX GAMES INTEGRATION TESTS PASSED SUCCESSFULLY! ---")
	quit(0)

func test_pause_manager_multi_reasons_and_mute() -> void:
	print("[TEST] 1. PauseManager multi-reason tracking, precedence & audio mute...")
	var pm = PauseManager.new()
	root.add_child(pm)

	assert(!pm.is_paused(), "Initially not paused")
	assert(pm.get_active_reasons().is_empty(), "No active reasons initially")

	# Add user pause
	pm.add_pause_reason(PauseManager.REASON_USER)
	assert(pm.is_paused(), "Paused after user reason")
	assert(pm.has_pause_reason(PauseManager.REASON_USER), "Has user reason")
	assert(AudioServer.is_bus_mute(0), "User pause mutes audio bus")

	# Add browser focus pause (external)
	pm.add_pause_reason(PauseManager.REASON_BROWSER_FOCUS)
	assert(pm.has_pause_reason(PauseManager.REASON_BROWSER_FOCUS), "Has browser focus reason")
	assert(AudioServer.is_bus_mute(0), "Browser blur keeps audio bus muted")

	# External focus returns: remove BROWSER_FOCUS
	pm.remove_pause_reason(PauseManager.REASON_BROWSER_FOCUS)
	assert(!pm.has_pause_reason(PauseManager.REASON_BROWSER_FOCUS), "Browser focus reason removed")
	assert(pm.has_pause_reason(PauseManager.REASON_USER), "User pause MUST remain active!")
	assert(pm.is_paused(), "Game must still be paused because user paused it")
	assert(AudioServer.is_bus_mute(0), "Audio remains muted while user pause is still active")

	# Remove user pause
	pm.remove_pause_reason(PauseManager.REASON_USER)
	assert(!pm.is_paused(), "Game unpaused after user pause removed")
	assert(!AudioServer.is_bus_mute(0), "Audio unmuted when all mute reasons cleared")

	# Add Ad pause
	pm.add_pause_reason(PauseManager.REASON_ADVERTISEMENT)
	assert(AudioServer.is_bus_mute(0), "Ad pause mutes audio")
	pm.remove_pause_reason(PauseManager.REASON_ADVERTISEMENT)
	assert(!AudioServer.is_bus_mute(0), "Audio unmuted after ad")

	# Test REASON_MODAL alone does not mute (in-game level-up audio allowed)
	pm.add_pause_reason(PauseManager.REASON_MODAL)
	assert(pm.is_paused(), "Game paused for modal")
	assert(!AudioServer.is_bus_mute(0), "Modal pause alone does not mute audio bus")
	pm.remove_pause_reason(PauseManager.REASON_MODAL)

	# Clear all reasons except user pause
	pm.add_pause_reason(PauseManager.REASON_USER)
	pm.add_pause_reason(PauseManager.REASON_MODAL)
	pm.clear_reasons(true) # keep user pause
	assert(pm.has_pause_reason(PauseManager.REASON_USER), "User pause retained")
	assert(!pm.has_pause_reason(PauseManager.REASON_MODAL), "Modal reason cleared")
	assert(AudioServer.is_bus_mute(0), "Audio remains muted because user pause is kept")

	# Full clear
	pm.clear_reasons(false)
	assert(!pm.is_paused(), "Completely unpaused")
	assert(!AudioServer.is_bus_mute(0), "Audio unmuted")

	pm.queue_free()
	print("[PASS] PauseManager multi-reason mutex and audio mute verified.")

func test_yandex_bridge_lifecycle_and_fallback() -> void:
	print("[TEST] 2. YandexGamesBridge lifecycle, local fallback & callbacks...")
	var bridge = YandexGamesBridge.new()
	root.add_child(bridge)

	assert(bridge.is_local_mode, "Non-web execution defaults to local mode")
	assert(!bridge.is_web_build(), "Native engine runner is not web build")
	assert(!bridge.is_mobile(), "Default device is not mobile")

	# Loading API ready notification
	assert(!bridge.has_notified_ready, "Initial ready flag is false")
	bridge.notify_game_ready()
	assert(bridge.has_notified_ready, "Ready flag becomes true")
	# Second call is idempotent
	bridge.notify_game_ready()
	assert(bridge.has_notified_ready, "Idempotent ready verified")

	# Gameplay API
	assert(!bridge.is_gameplay_active, "Initially gameplay is inactive")
	bridge.gameplay_start()
	assert(bridge.is_gameplay_active, "Gameplay started")
	bridge.gameplay_stop()
	assert(!bridge.is_gameplay_active, "Gameplay stopped")

	# Interstitial fallback
	var ad_shown_result = false
	bridge.show_interstitial(func(was_shown): ad_shown_result = was_shown)
	assert(!ad_shown_result, "Local mode interstitial returns false safely without hanging")

	# Rewarded fallback
	var callback_state = {"reward": false, "closed": false}
	bridge.show_rewarded(
		func(): callback_state["reward"] = true,
		func(granted): callback_state["closed"] = true
	)
	assert(!callback_state["reward"], "Reward strictly NOT granted in unmocked fallback")
	assert(callback_state["closed"], "Close callback invoked cleanly")

	# Ad Session Protection & Late Callback Rejection
	var session_reward_called = {"val": false}
	var session_close_called = {"val": false, "granted": false}
	bridge._current_rewarded_session_id = 42
	bridge._current_rewarded_state = bridge.AdSessionState.PENDING
	bridge._pending_reward_callable = func(): session_reward_called["val"] = true
	bridge._pending_reward_close_callable = func(g): session_close_called["val"] = true; session_close_called["granted"] = g

	# Late callback from previous session (id 41) must be rejected
	bridge._on_js_rewarded_reward([41])
	assert(!session_reward_called["val"], "Late reward from previous session 41 must be rejected")

	# Legitimate session 42 open
	bridge._on_js_rewarded_open([42])
	assert(bridge._current_rewarded_state == bridge.AdSessionState.OPENED, "State transitions to OPENED")

	# Legitimate session 42 reward
	bridge._on_js_rewarded_reward([42])
	assert(session_reward_called["val"], "Reward callback invoked on legitimate onRewarded")
	assert(bridge._current_rewarded_state == bridge.AdSessionState.REWARDED, "State transitions to REWARDED")

	# Legitimate session 42 close with grant confirmed
	bridge._on_js_rewarded_close([42, true])
	assert(session_close_called["val"], "Close callback invoked")
	assert(session_close_called["granted"], "Reward successfully granted on verified session")
	assert(bridge._current_rewarded_state == bridge.AdSessionState.CLOSED, "State transitions to CLOSED")

	# Rogue late reward after session closed must be rejected
	session_reward_called["val"] = false
	bridge._on_js_rewarded_reward([42])
	assert(!session_reward_called["val"], "Rogue late reward after session close rejected")

	bridge.queue_free()
	print("[PASS] YandexGamesBridge lifecycle and fallback verified.")

func test_save_manager_cloud_merge() -> void:
	print("[TEST] 3. SaveManager cloud sync union & safe merge...")
	# Local dataset
	var local_data = {
		"version": 2,
		"unlocked_arenas": ["forgotten_forest", "frost_necropolis"],
		"best_survival_time": 420.0,
		"total_runs": 15,
		"bosses_defeated": 3,
		"completed_atlas_goals": ["first_blood", "survive_5_min"],
		"arena_stats": {
			"forgotten_forest": {"runs": 10, "wins": 2, "best_time": 420.0, "kills": 400},
			"frost_necropolis": {"runs": 5, "wins": 1, "best_time": 300.0, "kills": 200}
		}
	}

	# Incoming cloud dataset (e.g. played on another device)
	var cloud_data = {
		"version": 2,
		"unlocked_arenas": ["forgotten_forest", "ash_citadel"],
		"best_survival_time": 600.0,
		"total_runs": 20,
		"bosses_defeated": 5,
		"completed_atlas_goals": ["first_blood", "defeat_colossus"],
		"arena_stats": {
			"forgotten_forest": {"runs": 12, "wins": 3, "best_time": 500.0, "kills": 550},
			"ash_citadel": {"runs": 8, "wins": 2, "best_time": 600.0, "kills": 350}
		}
	}

	var merged = SaveManager.merge_with_cloud(cloud_data, local_data)

	# 1. Unlocked arenas must be UNION of both
	var arenas = merged.get("unlocked_arenas", [])
	assert(arenas.has("forgotten_forest"), "Has forgotten_forest")
	assert(arenas.has("frost_necropolis"), "Has frost_necropolis (from local)")
	assert(arenas.has("ash_citadel"), "Has ash_citadel (from cloud)")
	assert(arenas.size() == 3, "Union of arenas has 3 items without duplicates")

	# 2. Metrics must take MAX
	assert(merged.get("best_survival_time") == 600.0, "Best survival time takes max (600)")
	assert(merged.get("total_runs") == 20, "Total runs takes max (20)")
	assert(merged.get("bosses_defeated") == 5, "Bosses defeated takes max (5)")

	# 3. Completed goals must be UNION
	var goals = merged.get("completed_atlas_goals", [])
	assert(goals.has("survive_5_min"), "Has local goal survive_5_min")
	assert(goals.has("defeat_colossus"), "Has cloud goal defeat_colossus")
	assert(goals.size() == 3, "Union of goals has 3 items")

	# 4. Arena stats must merge per arena
	var m_arena = merged.get("arena_stats", {})
	assert(m_arena.has("forgotten_forest") and m_arena.has("frost_necropolis") and m_arena.has("ash_citadel"), "All 3 arenas in stats")
	assert(m_arena["forgotten_forest"]["best_time"] == 500.0, "Forgotten forest best time is max 500")
	assert(m_arena["frost_necropolis"]["best_time"] == 300.0, "Frost necropolis best time is 300")

	# 5. Empty cloud data must NEVER wipe local data
	var empty_cloud = {}
	var fallback_merge = SaveManager.merge_with_cloud(empty_cloud, local_data)
	assert(fallback_merge.get("unlocked_arenas").size() == 2, "Empty cloud never overwrites local unlocks")
	assert(fallback_merge.get("best_survival_time") == 420.0, "Empty cloud retains local records")

	# 6. Test debounced cloud sync
	var test_bridge = YandexGamesBridge.new()
	root.add_child(test_bridge)
	assert(!test_bridge._is_cloud_save_scheduled, "No cloud save scheduled initially")
	test_bridge.schedule_cloud_save()
	assert(test_bridge._is_cloud_save_scheduled, "Cloud save scheduled")
	assert(test_bridge._save_debounce_timer > 0.0, "Debounce timer running")
	test_bridge.flush_cloud_save()
	assert(!test_bridge._is_cloud_save_scheduled, "Cloud save dispatched and cleared")

	# 7. Test user authorization triggering cloud merge
	var auth_called = {"val": false, "name": ""}
	test_bridge.auth_state_changed.connect(func(is_auth, p_name):
		auth_called["val"] = is_auth
		auth_called["name"] = p_name
	)
	test_bridge.authorize_player()
	assert(auth_called["val"], "Authorization succeeded and signal emitted")
	assert(!auth_called["name"].is_empty(), "Player name populated")

	test_bridge.queue_free()

	print("[PASS] SaveManager cloud merge union and conflict resolution verified.")

func test_localization_manager() -> void:
	print("[TEST] 4. LocalizationManager RU / EN dictionaries and dynamic switching...")
	var loc = LocalizationManager.new()
	root.add_child(loc)

	# Initial RU check
	loc.set_language("ru")
	assert(loc.current_language == "ru", "Current language is RU")
	assert(loc.get_text("pause_resume") == "Продолжить", "RU text for pause_resume matches")
	assert(loc.get_text("second_chance_title") == "ВТОРОЙ ШАНС", "RU text for second chance matches")

	# Switch to EN
	var loc_state = {"changed": ""}
	loc.language_changed.connect(func(l): loc_state["changed"] = l)
	loc.set_language("en")
	assert(loc.current_language == "en", "Switched to EN")
	assert(loc_state["changed"] == "en", "language_changed signal fired")
	assert(loc.get_text("pause_resume") == "Resume", "EN text for pause_resume matches")
	assert(loc.get_text("second_chance_title") == "SECOND CHANCE", "EN text for second chance matches")

	# Fallback for unknown key
	assert(loc.get_text("non_existent_key_xyz", "DefaultVal") == "DefaultVal", "Fallback returned for unknown key")

	# Restore RU
	loc.set_language("ru")
	loc.queue_free()
	print("[PASS] LocalizationManager dictionaries and switching verified.")

func test_virtual_joystick_mechanics() -> void:
	print("[TEST] 5. VirtualJoystick vector clamping, deadzone & release...")
	var vjoy_scene = preload("res://scenes/ui/virtual_joystick.tscn")
	var vjoy = vjoy_scene.instantiate() as VirtualJoystick
	root.add_child(vjoy)

	assert(vjoy.get_direction() == Vector2.ZERO, "Initial joystick direction is ZERO")

	# Simulate touch drag within bounds
	vjoy.touch_index = 0
	vjoy.is_active = true
	vjoy._update_stick_position(Vector2(30, 0)) # Drag 30px right
	var dir = vjoy.get_direction()
	assert(dir.x > 0.0 and abs(dir.y) < 0.01, "Joystick outputs rightward vector")
	assert(dir.length() <= 1.0, "Joystick vector length is <= 1.0")

	# Simulate touch drag far beyond radius (e.g. 300px away)
	vjoy._update_stick_position(Vector2(300, 0))
	var clamped_dir = vjoy.get_direction()
	assert(abs(clamped_dir.length() - 1.0) < 0.01, "Joystick clamps output magnitude to 1.0")
	assert(clamped_dir.x > 0.99, "Vector points strictly right")

	# Reset joystick
	vjoy._reset_joystick()
	assert(vjoy.get_direction() == Vector2.ZERO, "Joystick direction resets to ZERO on release")

	vjoy.queue_free()
	print("[PASS] VirtualJoystick clamping and deadzone verified.")

func test_second_chance_lifecycle() -> void:
	print("[TEST] 6. Second Chance dialog, modal pause & player revival...")
	var sc_scene = preload("res://scenes/ui/second_chance_dialog.tscn")
	var dialog = sc_scene.instantiate() as SecondChanceDialog
	root.add_child(dialog)

	# Test modal pause on open
	assert(!dialog.is_open, "Dialog starts closed")
	dialog.open_dialog()
	assert(dialog.is_open, "Dialog opened")
	assert(dialog.visible, "Dialog is visible")
	if PauseManager.instance:
		assert(PauseManager.instance.has_pause_reason(PauseManager.REASON_MODAL), "Modal pause reason added on open")

	dialog.close_dialog()
	assert(!dialog.is_open, "Dialog closed")
	assert(!dialog.visible, "Dialog is hidden")
	if PauseManager.instance:
		assert(!PauseManager.instance.has_pause_reason(PauseManager.REASON_MODAL), "Modal pause reason cleared on close")

	# Test PlayerController revival mechanics
	var player_scene = preload("res://scenes/player/player.tscn")
	var player = player_scene.instantiate() as PlayerController
	root.add_child(player)
	player.current_health = 0.0
	player.is_alive = false

	player.revive_second_chance(0.5)
	assert(player.is_alive, "Player is marked alive after second chance")
	assert(player.current_health == player.stats.max_health * 0.5, "Player revived with exactly 50% max health")
	assert(player.invulnerable_timer >= 2.0, "Player has i-frames buffer upon reviving")

	player.queue_free()
	dialog.queue_free()
	print("[PASS] Second Chance lifecycle and revival mechanics verified.")

func test_gameplay_api_integration() -> void:
	print("[TEST] 7. GameFlowController & Yandex GameplayAPI calls...")
	var flow = GameFlowController.instance
	var bridge = YandexGamesBridge.instance
	var pm = PauseManager.instance
	assert(flow != null, "GameFlowController instance exists")
	assert(bridge != null, "YandexGamesBridge instance exists")
	assert(pm != null, "PauseManager instance exists")

	# Ensure lifecycle sync is active
	bridge.setup_lifecycle_sync()

	# 1. Launch game -> PLAYING, unpaused -> gameplay active
	flow.launch_game_scene()
	assert(flow.current_state == GameFlowController.STATE_PLAYING, "State is PLAYING")
	assert(!pm.is_paused(), "PauseManager is unpaused")
	assert(bridge.is_gameplay_active, "Gameplay must be active in game when unpaused")

	# 2. In game: user pauses -> gameplay must stop
	pm.add_pause_reason(PauseManager.REASON_USER)
	assert(pm.is_paused(), "PauseManager is paused")
	assert(!bridge.is_gameplay_active, "Gameplay must be stopped on user pause")

	# 3. In game: user unpauses -> gameplay must restart
	pm.remove_pause_reason(PauseManager.REASON_USER)
	assert(!pm.is_paused(), "PauseManager is unpaused")
	assert(bridge.is_gameplay_active, "Gameplay must restart when unpaused in game")

	# 4. In game: multi-reason external pause (blur + platform)
	pm.add_pause_reason(PauseManager.REASON_BROWSER_FOCUS)
	assert(!bridge.is_gameplay_active, "Gameplay stopped on browser blur")
	pm.add_pause_reason(PauseManager.REASON_PLATFORM)
	assert(!bridge.is_gameplay_active, "Gameplay remains stopped with platform pause")

	# Remove only blur -> platform pause still active
	pm.remove_pause_reason(PauseManager.REASON_BROWSER_FOCUS)
	assert(!bridge.is_gameplay_active, "Gameplay remains stopped while platform pause active")

	# Remove platform -> unpaused -> resumes
	pm.remove_pause_reason(PauseManager.REASON_PLATFORM)
	assert(bridge.is_gameplay_active, "Gameplay resumes when all pause reasons removed")

	# 5. Transition to Results screen -> gameplay must stop
	flow.open_results_screen(RunStats.new())
	assert(flow.current_state == GameFlowController.STATE_RESULTS, "State is RESULTS")
	assert(!bridge.is_gameplay_active, "Gameplay stopped on results screen")

	# 6. Unpausing outside gameplay must NEVER activate gameplay
	pm.clear_reasons(false)
	assert(!bridge.is_gameplay_active, "Gameplay remains stopped in results screen even when unpaused")

	# 7. Menu transition -> still inactive
	flow.go_to_main_menu()
	assert(flow.current_state == GameFlowController.STATE_MAIN_MENU, "State is MAIN_MENU")
	assert(!bridge.is_gameplay_active, "Gameplay remains stopped in main menu")

	print("[PASS] GameFlowController GameplayAPI integration verified.")
