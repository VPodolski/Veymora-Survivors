class_name PlatformManager
extends Node

signal sdk_ready(is_local: bool)
signal pause_requested(reason: String)
signal resume_requested(reason: String)
signal interstitial_completed(was_shown: bool)
signal rewarded_completed(reward_granted: bool)
signal cloud_data_loaded(data: Dictionary)
signal cloud_data_saved(success: bool)
signal cloud_sync_completed(data: Dictionary)
signal auth_state_changed(is_authorized: bool, player_name: String)
signal leaderboard_score_submitted(success: bool)
signal leaderboard_entries_received(entries: Array)

const BasePlatformBridge = preload("res://scripts/platform/base_platform_bridge.gd")
const LocalPlatformBridge = preload("res://scripts/platform/local_platform_bridge.gd")
const YandexGamesBridge = preload("res://scripts/platform/yandex_games_bridge.gd")
const GamePushBridge = preload("res://scripts/platform/gamepush_bridge.gd")

static var instance: PlatformManager = null

var active_bridge: BasePlatformBridge = null
var platform_name: String = "local"

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_platform()

func detect_platform() -> String:
	# 1. Custom feature tags passed during Godot Web export
	if OS.has_feature("gamepush") or OS.has_feature("pikabu"):
		return "gamepush"
	if OS.has_feature("yandex"):
		return "yandex"

	# 2. Inspect browser URL and window properties when running on Web
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var js = Engine.get_singleton("JavaScriptBridge")
		var win = js.get_interface("window")
		if win:
			var loc = win.location
			var search = str(loc.search).to_lower()
			var host = str(loc.host).to_lower()
			if "pikabu" in search or "pikabu" in host or "gamepush" in search or "gp_" in search:
				return "gamepush"
			if "yandex" in search or "yandex" in host or "yandex.ru" in host:
				return "yandex"
			# Inspect window globals
			if "gp" in win or "onGPInit" in win or "setGpInitCallback" in win:
				return "gamepush"
			if "YaGames" in win or "ysdk" in win:
				return "yandex"

	# 3. Explicit project setting override
	var config_target = ProjectSettings.get_setting("platform/target_sdk", "auto")
	if config_target in ["yandex", "gamepush", "local"]:
		return config_target

	# 4. Fallback: local mode
	return "local"

func _initialize_platform() -> void:
	platform_name = detect_platform()
	print("[PlatformManager] Detected active platform: ", platform_name)

	match platform_name:
		"gamepush":
			active_bridge = GamePushBridge.new()
		"yandex":
			# If YandexBridge autoload already instantiated it, reuse it
			var existing_yandex = get_tree().root.get_node_or_null("YandexBridge") if get_tree() else null
			if existing_yandex is BasePlatformBridge:
				active_bridge = existing_yandex
			elif YandexGamesBridge.instance:
				active_bridge = YandexGamesBridge.instance
			else:
				active_bridge = YandexGamesBridge.new()
		_:
			active_bridge = LocalPlatformBridge.new()

	if active_bridge.get_parent() == null:
		add_child(active_bridge)

	_connect_bridge_signals()

func _connect_bridge_signals() -> void:
	if not active_bridge:
		return

	active_bridge.sdk_ready.connect(func(is_local): sdk_ready.emit(is_local))
	active_bridge.pause_requested.connect(func(reason): pause_requested.emit(reason))
	active_bridge.resume_requested.connect(func(reason): resume_requested.emit(reason))
	active_bridge.interstitial_completed.connect(func(was_shown): interstitial_completed.emit(was_shown))
	active_bridge.rewarded_completed.connect(func(granted): rewarded_completed.emit(granted))
	active_bridge.cloud_data_loaded.connect(func(data): cloud_data_loaded.emit(data))
	active_bridge.cloud_data_saved.connect(func(success): cloud_data_saved.emit(success))
	active_bridge.cloud_sync_completed.connect(func(data): cloud_sync_completed.emit(data))
	active_bridge.auth_state_changed.connect(func(is_auth, p_name): auth_state_changed.emit(is_auth, p_name))
	active_bridge.leaderboard_score_submitted.connect(func(success): leaderboard_score_submitted.emit(success))
	active_bridge.leaderboard_entries_received.connect(func(entries): leaderboard_entries_received.emit(entries))

func set_bridge_for_testing(bridge: BasePlatformBridge) -> void:
	if active_bridge and active_bridge != bridge and active_bridge.get_parent() == self:
		active_bridge.queue_free()
	active_bridge = bridge
	platform_name = bridge.get_platform_name()
	if active_bridge.get_parent() == null:
		add_child(active_bridge)
	_connect_bridge_signals()

# --- Unified Platform API ---

func get_platform_name() -> String:
	return active_bridge.get_platform_name() if active_bridge else platform_name

func is_web_build() -> bool:
	return active_bridge.is_web_build() if active_bridge else OS.has_feature("web")

func is_mobile() -> bool:
	return active_bridge.is_mobile() if active_bridge else OS.has_feature("mobile")

func get_player_name() -> String:
	return active_bridge.player_name if active_bridge else "Исследователь"

func get_player_unique_id() -> String:
	return active_bridge.player_unique_id if active_bridge else ""

func is_authorized() -> bool:
	return active_bridge.is_authorized if active_bridge else false

func get_player_language() -> String:
	return active_bridge.player_language if active_bridge else "ru"

func notify_game_ready() -> void:
	if active_bridge:
		active_bridge.notify_game_ready()

func reconcile_gameplay_state() -> void:
	if active_bridge:
		active_bridge.reconcile_gameplay_state()

func can_show_interstitial() -> bool:
	return active_bridge.can_show_interstitial() if active_bridge else false

func show_interstitial(on_complete: Callable = Callable()) -> void:
	if active_bridge:
		active_bridge.show_interstitial(on_complete)
	elif on_complete.is_valid():
		on_complete.call(false)

func show_rewarded(reward_callback: Callable, close_callback: Callable = Callable()) -> void:
	if active_bridge:
		active_bridge.show_rewarded(reward_callback, close_callback)
	elif close_callback.is_valid():
		close_callback.call(false)

func schedule_cloud_save() -> void:
	if active_bridge:
		active_bridge.schedule_cloud_save()

func flush_cloud_save() -> void:
	if active_bridge:
		active_bridge.flush_cloud_save()

func load_cloud_save(on_loaded: Callable = Callable()) -> void:
	if active_bridge:
		active_bridge.load_cloud_save(on_loaded)
	elif on_loaded.is_valid():
		on_loaded.call({})

func submit_score(score: int, extra_data: String = "") -> void:
	if active_bridge:
		active_bridge.submit_score(score, extra_data)

func fetch_leaderboard(max_entries: int = 10, include_user: bool = true) -> void:
	if active_bridge:
		active_bridge.fetch_leaderboard(max_entries, include_user)

func authorize_player() -> void:
	if active_bridge:
		active_bridge.authorize_player()
