class_name LocalPlatformBridge
extends "res://scripts/platform/base_platform_bridge.gd"

const SaveManager = preload("res://scripts/game/save_manager.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_web = OS.has_feature("web")
	is_local_mode = true
	is_sdk_available = false
	is_sdk_initialized = true

	var sys_lang = OS.get_locale_language().to_lower()
	player_language = "ru" if sys_lang in ["ru", "be", "uk", "kk", "ky", "uz"] else "en"
	device_type = "mobile" if OS.has_feature("mobile") else "desktop"

	call_deferred("_emit_ready")

func _emit_ready() -> void:
	sdk_ready.emit(true)

func get_platform_name() -> String:
	return "local"

func notify_game_ready() -> void:
	super.notify_game_ready()
	print("[LocalPlatformBridge] Game ready notified in local mode.")

func reconcile_gameplay_state() -> void:
	var in_game = false
	if Engine.has_singleton("GameFlow"):
		var gf = Engine.get_main_loop().root.get_node_or_null("GameFlow") if Engine.get_main_loop() else null
		if gf and "current_state" in gf:
			in_game = (gf.current_state == "playing")
	is_gameplay_active = in_game
	if is_gameplay_active:
		print("[LocalPlatformBridge] Gameplay started [Local]")
	else:
		print("[LocalPlatformBridge] Gameplay stopped [Local]")

func can_show_interstitial() -> bool:
	return false

func show_interstitial(on_complete: Callable = Callable()) -> void:
	interstitial_completed.emit(false)
	if on_complete.is_valid():
		on_complete.call(false)

func show_rewarded(reward_callback: Callable, close_callback: Callable = Callable()) -> void:
	# Local mock reward mode for testing: reward is granted gracefully
	print("[LocalPlatformBridge] Rewarded ad called in local mode (mock grant).")
	rewarded_completed.emit(true)
	if reward_callback.is_valid():
		reward_callback.call()
	if close_callback.is_valid():
		close_callback.call(true)

func schedule_cloud_save() -> void:
	# In local mode, data is already saved to user:// save_data.json
	cloud_data_saved.emit(true)

func flush_cloud_save() -> void:
	cloud_data_saved.emit(true)

func load_cloud_save(on_loaded: Callable = Callable()) -> void:
	var local_data = SaveManager.load_data()
	cloud_data_loaded.emit(local_data)
	cloud_sync_completed.emit(local_data)
	if on_loaded.is_valid():
		on_loaded.call(local_data)

func submit_score(score: int, _extra_data: String = "") -> void:
	print("[LocalPlatformBridge] Score %d recorded locally." % score)
	leaderboard_score_submitted.emit(true)

func authorize_player() -> void:
	is_authorized = true
	player_name = "Исследователь"
	auth_state_changed.emit(true, player_name)
