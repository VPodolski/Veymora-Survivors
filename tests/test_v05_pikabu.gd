extends SceneTree

const PlatformManager = preload("res://scripts/platform/platform_manager.gd")
const BasePlatformBridge = preload("res://scripts/platform/base_platform_bridge.gd")
const LocalPlatformBridge = preload("res://scripts/platform/local_platform_bridge.gd")
const GamePushBridge = preload("res://scripts/platform/gamepush_bridge.gd")
const YandexGamesBridge = preload("res://scripts/platform/yandex_games_bridge.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const PauseManager = preload("res://scripts/game/pause_manager.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")
const VirtualJoystick = preload("res://scripts/ui/virtual_joystick.gd")
const ResultsScreenScene = preload("res://scenes/ui/results_screen.tscn")
const ResultsScreen = preload("res://scripts/ui/results_screen.gd")
const RunStats = preload("res://scripts/game/run_stats.gd")

# Mock GamePush SDK for headless test verification
class MockGPNode extends Node:
	var is_inited: bool = false
	var gp: Dictionary = {}
	var ads: MockGPAds = MockGPAds.new()
	var player: MockGPPlayer = MockGPPlayer.new()
	var game: MockGPGame = MockGPGame.new()
	var device: MockGPDevice = MockGPDevice.new()
	var language: MockGPLanguage = MockGPLanguage.new()

	signal inited(success: bool)

	func _init() -> void:
		add_child(ads)
		add_child(player)
		add_child(game)
		add_child(device)
		add_child(language)

class MockGPAds extends Node:
	var is_fullscreen_available_flag: bool = true
	var is_rewarded_available_flag: bool = true
	var should_grant_reward: bool = true
	var should_succeed_fullscreen: bool = true

	signal fullscreen_start()
	signal fullscreen_close(success: bool)
	signal rewarded_start()
	signal rewarded_reward()
	signal rewarded_close(success: bool)

	func is_fullscreen_available() -> bool:
		return is_fullscreen_available_flag

	func is_rewarded_available() -> bool:
		return is_rewarded_available_flag

	func show_fullscreen() -> void:
		fullscreen_start.emit()
		call_deferred("_emit_fullscreen_close")

	func _emit_fullscreen_close() -> void:
		fullscreen_close.emit(should_succeed_fullscreen)

	func show_rewarded_video() -> void:
		rewarded_start.emit()
		call_deferred("_emit_rewarded_finish")

	func _emit_rewarded_finish() -> void:
		if should_grant_reward:
			rewarded_reward.emit()
			rewarded_close.emit(true)
		else:
			rewarded_close.emit(false)

class MockGPPlayer extends Node:
	var _storage: Dictionary = {}
	var _is_logged: bool = false
	var _player_name: String = "Исследователь Пикабу"
	var _player_id: int = 123456

	signal logged_in(success: bool)
	signal synced(success: bool)
	signal loaded(success: bool)

	func get_id() -> int:
		return _player_id

	func get_player_name() -> String:
		return _player_name

	func is_logged_in() -> bool:
		return _is_logged

	func login() -> void:
		_is_logged = true
		logged_in.emit(true)

	func get_value(key: String) -> Variant:
		return _storage.get(key, null)

	func set_value(key: String, value: Variant) -> void:
		_storage[key] = value

	func sync() -> void:
		synced.emit(true)

	func load() -> void:
		loaded.emit(true)

class MockGPGame extends Node:
	var is_game_started: bool = false
	var is_gameplay_active: bool = false

	signal paused
	signal resumed

	func game_start() -> void:
		is_game_started = true

	func gameplay_start() -> void:
		is_gameplay_active = true

	func gameplay_stop() -> void:
		is_gameplay_active = false

class MockGPDevice extends Node:
	var mobile_flag: bool = false
	func is_mobile() -> bool:
		return mobile_flag

class MockGPLanguage extends Node:
	var lang: String = "ru"
	func current() -> String:
		return lang

func _init() -> void:
	print("\n--- Running Veymora Survivors 0.5 (Pikabu Edition) Test Suite ---")
	call_deferred("run_all_tests")

func run_all_tests() -> void:
	await test_1_local_launch_without_sdk()
	await test_2_gamepush_successful_init()
	await test_3_gamepush_init_error_fallback()
	await test_4_cloud_save_load()
	await test_5_cloud_save_push()
	await test_6_local_and_cloud_progress_merge()
	await test_7_offline_handling()
	await test_8_ad_load_failure_handling()
	await test_9_rewarded_video_success()
	await test_10_rewarded_video_closed_without_reward()
	await test_11_tab_hide_pause()
	await test_12_clean_unpause_lifecycle()
	await test_13_mobile_virtual_joystick()
	await test_14_input_conflict_immunity()
	await test_15_web_export_and_zip_verification()

	print("\n--- ALL VEYMORA SURVIVORS 0.5 (PIKABU) TESTS PASSED CLEANLY! ---")
	quit(0)

func test_1_local_launch_without_sdk() -> void:
	print("[TEST] 1. Local launch without SDK...")
	var local_bridge = LocalPlatformBridge.new()
	root.add_child(local_bridge)
	await process_frame

	assert(local_bridge.get_platform_name() == "local", "Platform name must be local")
	assert(local_bridge.is_local_mode == true, "Must be in local mode")
	assert(local_bridge.is_sdk_available == false, "SDK must not be available")
	assert(local_bridge.can_show_interstitial() == false, "Cannot show interstitial in local")

	local_bridge.notify_game_ready()
	assert(local_bridge.has_notified_ready == true, "Game ready notified")

	local_bridge.queue_free()
	print("[PASS] Local launch without SDK verified.")

func test_2_gamepush_successful_init() -> void:
	print("[TEST] 2. GamePush successful initialization...")
	var mock_gp = MockGPNode.new()
	var bridge = GamePushBridge.new()
	bridge.gp_node_override = mock_gp
	root.add_child(bridge)

	# Simulate successful init from GamePush
	mock_gp.is_inited = true
	mock_gp.gp = {"active": true}
	bridge._on_gp_inited(true)
	await process_frame

	assert(bridge.get_platform_name() == "gamepush", "Bridge platform name must be gamepush")
	assert(bridge.is_sdk_available == true, "SDK must be marked available")
	assert(bridge.is_local_mode == false, "Must not be local mode")
	assert(bridge.player_name == "Исследователь Пикабу", "Player name must match mock")
	assert(bridge.player_unique_id == "123456", "Player ID must match mock")

	# Test game ready call
	bridge.notify_game_ready()
	assert(mock_gp.game.is_game_started == true, "GP.game.game_start must be invoked")

	# Test gameplay start/stop
	bridge.is_gameplay_active = true
	bridge.reconcile_gameplay_state()
	bridge.is_gameplay_active = false
	bridge.reconcile_gameplay_state()

	bridge.queue_free()
	mock_gp.queue_free()
	print("[PASS] GamePush successful initialization verified.")

func test_3_gamepush_init_error_fallback() -> void:
	print("[TEST] 3. GamePush initialization error / timeout fallback...")
	var mock_gp = MockGPNode.new()
	var bridge = GamePushBridge.new()
	bridge.gp_node_override = mock_gp
	root.add_child(bridge)

	# Simulate failed init from GamePush
	mock_gp.is_inited = true
	bridge._on_gp_inited(false)
	await process_frame

	assert(bridge.is_sdk_available == false, "SDK must not be available after failure")
	assert(bridge.is_local_mode == true, "Must fall back to local mode")
	assert(bridge.is_sdk_initialized == true, "Initialization flag must be set")

	bridge.queue_free()
	mock_gp.queue_free()
	print("[PASS] GamePush initialization error fallback verified.")

func test_4_cloud_save_load() -> void:
	print("[TEST] 4. Cloud save load and JSON deserialization...")
	var mock_gp = MockGPNode.new()
	mock_gp.gp = {"active": true}

	var cloud_payload = {
		"version": 2,
		"total_runs": 15,
		"total_kills": 950,
		"bosses_defeated": 2,
		"unlocked_arenas": ["forgotten_forest", "frost_necropolis"],
		"discovered_spells": ["magic_bolt", "fireball"]
	}
	mock_gp.player._storage["veymora_save"] = JSON.stringify(cloud_payload)

	var bridge = GamePushBridge.new()
	bridge.gp_node_override = mock_gp
	root.add_child(bridge)
	mock_gp.is_inited = true
	bridge._on_gp_inited(true)
	await process_frame

	var loaded_data = {}
	bridge.load_cloud_save(func(data): loaded_data.merge(data, true))
	await process_frame

	assert(!loaded_data.is_empty(), "Loaded cloud data must not be empty")
	assert(loaded_data.get("total_runs", 0) >= 15, "Merged total runs must be >= 15")
	assert(loaded_data.get("unlocked_arenas", []).has("frost_necropolis"), "Must have unlocked arena")

	bridge.queue_free()
	mock_gp.queue_free()
	print("[PASS] Cloud save load verified.")

func test_5_cloud_save_push() -> void:
	print("[TEST] 5. Cloud save push and debouncing...")
	var mock_gp = MockGPNode.new()
	mock_gp.gp = {"active": true}

	var bridge = GamePushBridge.new()
	bridge.gp_node_override = mock_gp
	root.add_child(bridge)
	mock_gp.is_inited = true
	bridge._on_gp_inited(true)
	await process_frame

	bridge.schedule_cloud_save()
	assert(bridge._is_cloud_save_scheduled == true, "Cloud save must be scheduled")
	assert(bridge._save_debounce_timer > 0.0, "Debounce timer must be positive")

	# Immediate flush
	bridge.flush_cloud_save()
	assert(bridge._is_cloud_save_scheduled == false, "Scheduled flag cleared after flush")
	assert(mock_gp.player._storage.has("veymora_save"), "Cloud storage must have veymora_save")

	bridge.queue_free()
	mock_gp.queue_free()
	print("[PASS] Cloud save push verified.")

func test_6_local_and_cloud_progress_merge() -> void:
	print("[TEST] 6. Local and cloud progress union merge...")
	var local_data = SaveManager.get_default_data()
	local_data["total_runs"] = 10
	local_data["total_kills"] = 500
	local_data["discovered_spells"] = ["magic_bolt", "ice_storm"]
	local_data["unlocked_arenas"] = ["forgotten_forest"]

	var cloud_data = {
		"total_runs": 8,
		"total_kills": 800,
		"discovered_spells": ["magic_bolt", "fireball"],
		"unlocked_arenas": ["forgotten_forest", "frost_necropolis"]
	}

	var merged = SaveManager.merge_with_cloud(cloud_data, local_data)

	assert(merged["total_runs"] == 10, "Total runs must be max of local (10) and cloud (8)")
	assert(merged["total_kills"] == 800, "Total kills must be max of local (500) and cloud (800)")
	assert(merged["discovered_spells"].has("ice_storm"), "Must keep local ice_storm")
	assert(merged["discovered_spells"].has("fireball"), "Must union cloud fireball")
	assert(merged["unlocked_arenas"].has("frost_necropolis"), "Must union cloud arena")

	print("[PASS] Local and cloud progress union merge verified.")

func test_7_offline_handling() -> void:
	print("[TEST] 7. Offline and network disruption handling...")
	SaveManager.save_custom_data(SaveManager.get_default_data(), false)

	var bridge = LocalPlatformBridge.new()
	root.add_child(bridge)
	await process_frame

	var save_box = [false]
	bridge.cloud_data_saved.connect(func(res): save_box[0] = res)
	bridge.schedule_cloud_save()
	bridge.flush_cloud_save()
	await process_frame

	assert(save_box[0] == true, "Offline save must report success locally")
	assert(FileAccess.file_exists(SaveManager.SAVE_PATH), "Local save file must exist")

	bridge.queue_free()
	print("[PASS] Offline handling verified.")

func test_8_ad_load_failure_handling() -> void:
	print("[TEST] 8. Ad load failure / adblock handling...")
	var mock_gp = MockGPNode.new()
	mock_gp.gp = {"active": true}
	mock_gp.ads.is_fullscreen_available_flag = false
	mock_gp.ads.should_succeed_fullscreen = false

	var bridge = GamePushBridge.new()
	bridge.gp_node_override = mock_gp
	root.add_child(bridge)
	mock_gp.is_inited = true
	bridge._on_gp_inited(true)
	await process_frame

	assert(bridge.can_show_interstitial() == false, "Cannot show interstitial if unavailable")

	var ad_res = {"finished": false, "shown": true}
	bridge.show_interstitial(func(shown):
		ad_res["finished"] = true
		ad_res["shown"] = shown
	)
	await process_frame

	assert(ad_res["finished"] == true, "Must complete immediately without hang")
	assert(ad_res["shown"] == false, "Must report ad was not shown")

	bridge.queue_free()
	mock_gp.queue_free()
	print("[PASS] Ad load failure handling verified.")

func test_9_rewarded_video_success() -> void:
	print("[TEST] 9. Rewarded video successful view and +25% bonus reward...")
	var mock_gp = MockGPNode.new()
	mock_gp.gp = {"active": true}
	mock_gp.ads.should_grant_reward = true

	var bridge = GamePushBridge.new()
	bridge.gp_node_override = mock_gp
	root.add_child(bridge)
	mock_gp.is_inited = true
	bridge._on_gp_inited(true)
	await process_frame

	var cb_state = {
		"reward_called": false,
		"close_called": false,
		"close_granted": false
	}

	bridge.show_rewarded(
		func(): cb_state["reward_called"] = true,
		func(granted):
			cb_state["close_called"] = true
			cb_state["close_granted"] = granted
	)
	await process_frame
	await process_frame

	assert(cb_state["reward_called"] == true, "Reward callback must be called on verified view")
	assert(cb_state["close_called"] == true, "Close callback must be called")
	assert(cb_state["close_granted"] == true, "Close granted flag must be true")

	# Test ResultsScreen Bonus Button with Rewarded Ad
	var orig_bridge = PlatformManager.instance.active_bridge if PlatformManager.instance else null
	if PlatformManager.instance:
		PlatformManager.instance.active_bridge = bridge

	var results = ResultsScreenScene.instantiate() as ResultsScreen
	root.add_child(results)
	var r_stats = RunStats.new()
	r_stats.survival_time = 120.0 # 1200 pts
	r_stats.total_kills = 20      # 100 pts -> final_score = 1300
	results.display_stats(r_stats)

	assert(results.final_score == 1300, "Base final score must be 1300")
	assert(results.is_reward_claimed == false, "Reward must not be claimed initially")
	assert(results.reward_bonus_btn != null, "Bonus button must exist on ResultsScreen")

	# Press reward button
	results._on_reward_bonus_pressed()
	await process_frame
	await process_frame

	assert(results.is_reward_claimed == true, "Reward claimed flag must become true")
	assert(results.final_score == int(1300 * 1.25), "Final score must be boosted by 25%")
	assert(results.reward_bonus_btn.disabled == true, "Bonus button must remain disabled")

	# Pressing a second time does nothing
	var score_before = results.final_score
	results._on_reward_bonus_pressed()
	assert(results.final_score == score_before, "Cannot claim bonus twice")

	if PlatformManager.instance:
		PlatformManager.instance.active_bridge = orig_bridge

	results.queue_free()
	bridge.queue_free()
	mock_gp.queue_free()
	print("[PASS] Rewarded video success and bonus claim verified.")

func test_10_rewarded_video_closed_without_reward() -> void:
	print("[TEST] 10. Rewarded video closed without reward...")
	var mock_gp = MockGPNode.new()
	mock_gp.gp = {"active": true}
	mock_gp.ads.should_grant_reward = false # user skipped ad

	var bridge = GamePushBridge.new()
	bridge.gp_node_override = mock_gp
	root.add_child(bridge)
	mock_gp.is_inited = true
	bridge._on_gp_inited(true)
	await process_frame

	var cb_state = {
		"reward_called": false,
		"close_granted": true
	}

	bridge.show_rewarded(
		func(): cb_state["reward_called"] = true,
		func(granted): cb_state["close_granted"] = granted
	)
	await process_frame
	await process_frame

	assert(cb_state["reward_called"] == false, "Reward must NOT be granted if ad skipped")
	assert(cb_state["close_granted"] == false, "Close granted flag must be false")

	bridge.queue_free()
	mock_gp.queue_free()
	print("[PASS] Rewarded video closed without reward verified.")

func test_11_tab_hide_pause() -> void:
	print("[TEST] 11. Game pause on tab hide / browser focus loss...")
	var pm = PauseManager.new()
	root.add_child(pm)

	assert(!pm.is_paused(), "Initially unpaused")

	# External browser focus lost (tab hidden)
	pm.add_pause_reason(PauseManager.REASON_BROWSER_FOCUS)
	assert(pm.is_paused(), "Game must be paused when tab hidden")
	assert(pm.has_pause_reason(PauseManager.REASON_BROWSER_FOCUS), "Has browser focus reason")
	assert(AudioServer.is_bus_mute(0), "Audio must be muted when tab hidden")

	pm.queue_free()
	print("[PASS] Game pause on tab hide verified.")

func test_12_clean_unpause_lifecycle() -> void:
	print("[TEST] 12. Clean unpause lifecycle without breaking user pause...")
	var pm = PauseManager.new()
	root.add_child(pm)

	# User paused game
	pm.add_pause_reason(PauseManager.REASON_USER)
	assert(pm.is_paused(), "User paused game")

	# Tab hidden
	pm.add_pause_reason(PauseManager.REASON_BROWSER_FOCUS)
	assert(pm.is_paused(), "Game still paused")

	# Tab restored
	pm.remove_pause_reason(PauseManager.REASON_BROWSER_FOCUS)
	assert(pm.has_pause_reason(PauseManager.REASON_USER), "User pause reason must remain")
	assert(pm.is_paused(), "Game must still be paused")
	assert(AudioServer.is_bus_mute(0), "Audio remains muted because user pause is active")

	# User unpauses
	pm.remove_pause_reason(PauseManager.REASON_USER)
	assert(!pm.is_paused(), "Game unpaused after user resumes")
	assert(!AudioServer.is_bus_mute(0), "Audio unmuted")

	pm.queue_free()
	print("[PASS] Clean unpause lifecycle verified.")

func test_13_mobile_virtual_joystick() -> void:
	print("[TEST] 13. Mobile virtual joystick controls...")
	var vj = VirtualJoystick.new()
	root.add_child(vj)
	vj.global_position = Vector2(100, 500)

	assert(vj.get_direction() == Vector2.ZERO, "Initial direction is zero")

	# Simulate touch drag to the right
	var touch_down = InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.pressed = true
	touch_down.position = Vector2(100 + vj.base_radius * 0.8, 500)
	vj._input(touch_down)

	assert(vj.is_active == true, "Joystick active after touch")
	assert(vj.get_direction().x > 0.0, "Direction x must be positive rightward")

	# Simulate touch release
	var touch_up = InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.pressed = false
	vj._input(touch_up)

	assert(vj.is_active == false, "Joystick inactive after release")
	assert(vj.get_direction() == Vector2.ZERO, "Direction reset to zero")

	vj.queue_free()
	print("[PASS] Mobile virtual joystick controls verified.")

func test_14_input_conflict_immunity() -> void:
	print("[TEST] 14. Touch & UI input conflict immunity...")
	var vj = VirtualJoystick.new()
	root.add_child(vj)

	# Simulate pause notification while dragging
	vj.is_active = true
	vj.stick_position = Vector2(30, 30)
	vj.output_direction = Vector2(1, 0)

	vj._notification(Node.NOTIFICATION_PAUSED)
	assert(vj.is_active == false, "Joystick resets on pause notification")
	assert(vj.get_direction() == Vector2.ZERO, "Direction clears on pause")

	vj.queue_free()
	print("[PASS] Input conflict immunity verified.")

func test_15_web_export_and_zip_verification() -> void:
	print("[TEST] 15. Web export presets configuration verification...")
	assert(FileAccess.file_exists("res://export_presets.cfg"), "export_presets.cfg must exist")

	var f = FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	var text = f.get_as_text()
	f.close()

	assert(text.contains("name=\"Web\""), "Preset for Web must exist")
	assert(text.contains("Web (Pikabu GamePush)"), "Preset for Pikabu GamePush must exist")
	assert(text.contains("variant/thread_support=false"), "Must be single-threaded for universal browser compatibility")
	assert(text.contains("setGpInitCallback"), "Pikabu preset must include GamePush callback script")

	# Verify store promotional materials exist
	assert(FileAccess.file_exists("res://media/store/icon_1024x1024.png"), "Icon 1024x1024 must exist")
	assert(FileAccess.file_exists("res://media/store/cover_1920x1080.png"), "Cover 1920x1080 must exist")
	assert(FileAccess.file_exists("res://media/store/screenshot_1_gameplay.png"), "Screenshot 1 must exist")
	assert(FileAccess.file_exists("res://media/store/screenshot_2_synergies.png"), "Screenshot 2 must exist")
	assert(FileAccess.file_exists("res://media/store/screenshot_3_boss.png"), "Screenshot 3 must exist")
	assert(FileAccess.file_exists("res://media/store/screenshot_4_artifacts.png"), "Screenshot 4 must exist")

	assert(FileAccess.file_exists("res://build/veymora_survivors_pikabu.zip"), "ZIP archive for Pikabu must exist")

	print("[PASS] Web export and store assets verified.")
