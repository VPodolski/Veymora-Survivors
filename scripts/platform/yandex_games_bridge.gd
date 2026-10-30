class_name YandexGamesBridge
extends Node

signal sdk_ready(is_local: bool)
signal pause_requested(reason: String)
signal resume_requested(reason: String)
signal interstitial_completed(was_shown: bool)
signal rewarded_completed(reward_granted: bool)
signal cloud_data_loaded(data: Dictionary)
signal cloud_data_saved(success: bool)
signal auth_state_changed(is_authorized: bool, player_name: String)
signal leaderboard_score_submitted(success: bool)
signal leaderboard_entries_received(entries: Array)

const PauseManager = preload("res://scripts/game/pause_manager.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")

static var instance: YandexGamesBridge = null

var is_web: bool = false
var is_sdk_available: bool = false
var is_local_mode: bool = true

var player_language: String = "ru"
var device_type: String = "desktop"
var is_authorized: bool = false
var player_name: String = "Исследователь"
var player_unique_id: String = ""

var has_notified_ready: bool = false
var is_game_ready: bool = false
var is_sdk_initialized: bool = false
var has_sent_loading_ready: bool = false
var is_gameplay_active: bool = false

# Internal callbacks kept alive to prevent garbage collection in JavaScriptBridge
var _cb_sdk_init: JavaScriptObject
var _cb_pause: JavaScriptObject
var _cb_resume: JavaScriptObject
var _cb_blur: JavaScriptObject
var _cb_focus: JavaScriptObject
var _cb_interstitial_close: JavaScriptObject
var _cb_interstitial_error: JavaScriptObject
var _cb_rewarded_reward: JavaScriptObject
var _cb_rewarded_close: JavaScriptObject
var _cb_rewarded_error: JavaScriptObject
var _cb_load_data: JavaScriptObject
var _cb_save_data: JavaScriptObject
var _cb_auth_success: JavaScriptObject
var _cb_auth_error: JavaScriptObject
var _cb_lb_set: JavaScriptObject
var _cb_lb_get: JavaScriptObject

var _pending_reward_callable: Callable = Callable()
var _pending_reward_close_callable: Callable = Callable()
var _pending_interstitial_callable: Callable = Callable()

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_web = OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge")

	# Initial fallback language
	var sys_lang = OS.get_locale_language().to_lower()
	player_language = "ru" if sys_lang in ["ru", "be", "uk", "kk", "ky", "uz"] else "en"

	call_deferred("setup_lifecycle_sync")

	if is_web:
		_setup_web_callbacks()
		call_deferred("_init_yandex_sdk")
	else:
		is_local_mode = true
		is_sdk_available = false
		is_sdk_initialized = true
		call_deferred("_emit_sdk_ready", true)
		call_deferred("_check_and_send_loading_ready")

func _setup_web_callbacks() -> void:
	if not is_web:
		return
	var js = Engine.get_singleton("JavaScriptBridge")
	if not js:
		return

	_cb_sdk_init = js.create_callback(_on_js_sdk_init)
	_cb_pause = js.create_callback(_on_js_platform_pause)
	_cb_resume = js.create_callback(_on_js_platform_resume)
	_cb_blur = js.create_callback(_on_js_browser_blur)
	_cb_focus = js.create_callback(_on_js_browser_focus)
	_cb_interstitial_close = js.create_callback(_on_js_interstitial_close)
	_cb_interstitial_error = js.create_callback(_on_js_interstitial_error)
	_cb_rewarded_reward = js.create_callback(_on_js_rewarded_reward)
	_cb_rewarded_close = js.create_callback(_on_js_rewarded_close)
	_cb_rewarded_error = js.create_callback(_on_js_rewarded_error)
	_cb_load_data = js.create_callback(_on_js_cloud_data_loaded)
	_cb_save_data = js.create_callback(_on_js_cloud_data_saved)
	_cb_auth_success = js.create_callback(_on_js_auth_success)
	_cb_auth_error = js.create_callback(_on_js_auth_error)
	_cb_lb_set = js.create_callback(_on_js_leaderboard_set)
	_cb_lb_get = js.create_callback(_on_js_leaderboard_get)

	var win = js.get_interface("window")
	if win:
		win.__godotYandexBridge = {
			"onSdkInit": _cb_sdk_init,
			"onPause": _cb_pause,
			"onResume": _cb_resume,
			"onBlur": _cb_blur,
			"onFocus": _cb_focus,
			"onInterstitialClose": _cb_interstitial_close,
			"onInterstitialError": _cb_interstitial_error,
			"onRewardedReward": _cb_rewarded_reward,
			"onRewardedClose": _cb_rewarded_close,
			"onRewardedError": _cb_rewarded_error,
			"onLoadData": _cb_load_data,
			"onSaveData": _cb_save_data,
			"onAuthSuccess": _cb_auth_success,
			"onAuthError": _cb_auth_error,
			"onLeaderboardSet": _cb_lb_set,
			"onLeaderboardGet": _cb_lb_get
		}

func _init_yandex_sdk() -> void:
	if not is_web:
		is_sdk_initialized = true
		_emit_sdk_ready(true)
		_check_and_send_loading_ready()
		return

	var js = Engine.get_singleton("JavaScriptBridge")
	if not js:
		is_sdk_initialized = true
		_emit_sdk_ready(true)
		_check_and_send_loading_ready()
		return

	# JavaScript initialization snippet with overall 4.0s timeout & getPlayer 2.0s protection
	var init_code = """
	(function() {
		var bridge = window.__godotYandexBridge;
		var isFinished = false;

		function finishInit(success, lang, devType, isAuth, name, uid) {
			if (isFinished) return;
			isFinished = true;
			clearTimeout(overallTimeout);
			if (bridge && bridge.onSdkInit) {
				bridge.onSdkInit(success, lang, devType, isAuth, name, uid);
			}
		}

		var overallTimeout = setTimeout(function() {
			console.warn('[YandexGamesBridge] YaGames SDK overall initialization timed out (4000ms), fallback to local.');
			finishInit(false, 'ru', 'desktop', false, 'Исследователь', '');
		}, 4000);

		if (typeof YaGames === 'undefined') {
			console.log('[YandexGamesBridge] YaGames SDK script not found on window, switching to local mode.');
			finishInit(false, 'ru', 'desktop', false, 'Исследователь', '');
			return;
		}

		YaGames.init().then(function(ysdk) {
			if (isFinished) return;
			window.ysdk = ysdk;
			console.log('[YandexGamesBridge] YaGames SDK initialized successfully.');

			var lang = (ysdk.environment && ysdk.environment.i18n && ysdk.environment.i18n.lang) ? ysdk.environment.i18n.lang : 'ru';
			var devType = (ysdk.deviceInfo && ysdk.deviceInfo.type) ? ysdk.deviceInfo.type : 'desktop';

			window.addEventListener('blur', function() { if (bridge && bridge.onBlur) bridge.onBlur(); });
			window.addEventListener('focus', function() { if (bridge && bridge.onFocus) bridge.onFocus(); });
			document.addEventListener('visibilitychange', function() {
				if (document.hidden) {
					if (bridge && bridge.onBlur) bridge.onBlur();
				} else {
					if (bridge && bridge.onFocus) bridge.onFocus();
				}
			});

			if (ysdk.onEvent) {
				ysdk.onEvent('game_api_pause', function() { if (bridge && bridge.onPause) bridge.onPause(); });
				ysdk.onEvent('game_api_resume', function() { if (bridge && bridge.onResume) bridge.onResume(); });
			}

			var playerPromise = (ysdk.getPlayer && typeof ysdk.getPlayer === 'function') ? ysdk.getPlayer() : Promise.reject(new Error('no getPlayer'));
			var playerTimeout = new Promise(function(_, reject) {
				setTimeout(function() { reject(new Error('getPlayer timeout')); }, 2000);
			});

			Promise.race([playerPromise, playerTimeout]).then(function(player) {
				if (isFinished) return;
				window.__yandexPlayer = player;
				var isAuth = player.getMode() !== 'lite';
				var name = player.getName() || 'Исследователь';
				var uid = player.getUniqueID() || '';
				finishInit(true, lang, devType, isAuth, name, uid);
			}).catch(function(err) {
				if (isFinished) return;
				console.warn('[YandexGamesBridge] Failed to get player, continuing as guest:', err);
				finishInit(true, lang, devType, false, 'Исследователь', '');
			});
		}).catch(function(err) {
			if (isFinished) return;
			console.error('[YandexGamesBridge] YaGames.init() failed:', err);
			finishInit(false, 'ru', 'desktop', false, 'Исследователь', '');
		});
	})();
	"""
	js.eval(init_code)

func _on_js_sdk_init(args: Array) -> void:
	var success = bool(args[0]) if args.size() > 0 else false
	is_sdk_initialized = true
	if success:
		is_sdk_available = true
		is_local_mode = false
		if args.size() > 1 and args[1] != null:
			var l = str(args[1]).to_lower()
			player_language = "ru" if l in ["ru", "be", "uk", "kk", "ky", "uz"] else "en"
			var has_user_choice = not str(SaveManager.get_setting("user_selected_language", "")).is_empty()
			if LocalizationManager.instance and not has_user_choice:
				LocalizationManager.instance.set_language(player_language, false)
		if args.size() > 2 and args[2] != null:
			device_type = str(args[2])
		if args.size() > 3:
			is_authorized = bool(args[3])
		if args.size() > 4 and args[4] != null:
			player_name = str(args[4])
		if args.size() > 5 and args[5] != null:
			player_unique_id = str(args[5])
	else:
		is_sdk_available = false
		is_local_mode = true

	_emit_sdk_ready(is_local_mode)
	_check_and_send_loading_ready()

func _emit_sdk_ready(local_mode: bool) -> void:
	sdk_ready.emit(local_mode)

# --- Loading API ---
func notify_game_ready() -> void:
	if is_game_ready:
		return
	is_game_ready = true
	has_notified_ready = true
	_check_and_send_loading_ready()

func _check_and_send_loading_ready() -> void:
	if has_sent_loading_ready:
		return
	if not is_game_ready:
		return
	if not is_sdk_initialized:
		return

	has_sent_loading_ready = true
	if is_web and is_sdk_available:
		var js = Engine.get_singleton("JavaScriptBridge")
		if js:
			js.eval("""
			if (window.ysdk && window.ysdk.features && window.ysdk.features.LoadingAPI) {
				window.ysdk.features.LoadingAPI.ready();
				console.log('[YandexGamesBridge] LoadingAPI.ready() notified successfully.');
			}
			""")
	else:
		print("[YandexGamesBridge] LoadingAPI.ready() called in local mode.")

# --- Gameplay API ---
func setup_lifecycle_sync() -> void:
	if PauseManager.instance and not PauseManager.instance.pause_state_changed.is_connected(_on_pause_state_changed):
		PauseManager.instance.pause_state_changed.connect(_on_pause_state_changed)
	if GameFlowController.instance and not GameFlowController.instance.state_changed.is_connected(_on_game_state_changed):
		GameFlowController.instance.state_changed.connect(_on_game_state_changed)
	reconcile_gameplay_state()

func _on_pause_state_changed(_is_paused: bool, _reasons: Array) -> void:
	reconcile_gameplay_state()

func _on_game_state_changed(_new_state: String) -> void:
	reconcile_gameplay_state()

func reconcile_gameplay_state() -> void:
	var in_game = false
	if GameFlowController.instance:
		in_game = (GameFlowController.instance.current_state == GameFlowController.STATE_PLAYING)

	var is_paused = false
	if PauseManager.instance:
		is_paused = PauseManager.instance.is_paused()

	if in_game and not is_paused:
		gameplay_start()
	else:
		gameplay_stop()

func gameplay_start() -> void:
	if is_gameplay_active:
		return
	is_gameplay_active = true

	if is_web and is_sdk_available:
		var js = Engine.get_singleton("JavaScriptBridge")
		if js:
			js.eval("""
			if (window.ysdk && window.ysdk.features && window.ysdk.features.GameplayAPI) {
				window.ysdk.features.GameplayAPI.start();
				console.log('[YandexGamesBridge] GameplayAPI.start()');
			}
			""")
	else:
		print("[YandexGamesBridge] GameplayAPI.start() [Local]")

func gameplay_stop() -> void:
	if not is_gameplay_active:
		return
	is_gameplay_active = false

	if is_web and is_sdk_available:
		var js = Engine.get_singleton("JavaScriptBridge")
		if js:
			js.eval("""
			if (window.ysdk && window.ysdk.features && window.ysdk.features.GameplayAPI) {
				window.ysdk.features.GameplayAPI.stop();
				console.log('[YandexGamesBridge] GameplayAPI.stop()');
			}
			""")
	else:
		print("[YandexGamesBridge] GameplayAPI.stop() [Local]")

# --- Platform & Browser Event Handlers ---
func _on_js_platform_pause(_args: Array = []) -> void:
	print("[YandexGamesBridge] Event: Platform Pause (game_api_pause)")
	if PauseManager.instance:
		PauseManager.instance.add_pause_reason(PauseManager.REASON_PLATFORM)
	else:
		reconcile_gameplay_state()
	pause_requested.emit(PauseManager.REASON_PLATFORM)

func _on_js_platform_resume(_args: Array = []) -> void:
	print("[YandexGamesBridge] Event: Platform Resume (game_api_resume)")
	if PauseManager.instance:
		PauseManager.instance.remove_pause_reason(PauseManager.REASON_PLATFORM)
	else:
		reconcile_gameplay_state()
	resume_requested.emit(PauseManager.REASON_PLATFORM)

func _on_js_browser_blur(_args: Array = []) -> void:
	if PauseManager.instance:
		PauseManager.instance.add_pause_reason(PauseManager.REASON_BROWSER_FOCUS)
	else:
		reconcile_gameplay_state()
	pause_requested.emit(PauseManager.REASON_BROWSER_FOCUS)

func _on_js_browser_focus(_args: Array = []) -> void:
	if PauseManager.instance:
		PauseManager.instance.remove_pause_reason(PauseManager.REASON_BROWSER_FOCUS)
	else:
		reconcile_gameplay_state()
	resume_requested.emit(PauseManager.REASON_BROWSER_FOCUS)

# --- Interstitial Advertisement ---
func show_interstitial(callback: Callable = Callable()) -> void:
	_pending_interstitial_callable = callback

	if not is_web or not is_sdk_available:
		# Local fallback: immediate return
		_finish_interstitial(false)
		return

	if PauseManager.instance:
		PauseManager.instance.add_pause_reason(PauseManager.REASON_ADVERTISEMENT)
	else:
		reconcile_gameplay_state()

	var js = Engine.get_singleton("JavaScriptBridge")
	if not js:
		_finish_interstitial(false)
		return

	var code = """
	(function() {
		var bridge = window.__godotYandexBridge;
		if (!window.ysdk || !window.ysdk.adv) {
			if (bridge && bridge.onInterstitialClose) bridge.onInterstitialClose(false);
			return;
		}
		window.ysdk.adv.showFullscreenAdv({
			callbacks: {
				onOpen: function() { console.log('[YandexGamesBridge] Interstitial opened'); },
				onClose: function(wasShown) {
					console.log('[YandexGamesBridge] Interstitial closed, wasShown:', wasShown);
					if (bridge && bridge.onInterstitialClose) bridge.onInterstitialClose(wasShown !== false);
				},
				onError: function(err) {
					console.warn('[YandexGamesBridge] Interstitial error:', err);
					if (bridge && bridge.onInterstitialError) bridge.onInterstitialError();
				}
			}
		});
	})();
	"""
	js.eval(code)

func _on_js_interstitial_close(args: Array = []) -> void:
	var was_shown = bool(args[0]) if args.size() > 0 else true
	_finish_interstitial(was_shown)

func _on_js_interstitial_error(_args: Array = []) -> void:
	_finish_interstitial(false)

func _finish_interstitial(was_shown: bool) -> void:
	if PauseManager.instance:
		PauseManager.instance.remove_pause_reason(PauseManager.REASON_ADVERTISEMENT)
	if _pending_interstitial_callable.is_valid():
		_pending_interstitial_callable.call(was_shown)
		_pending_interstitial_callable = Callable()
	interstitial_completed.emit(was_shown)

# --- Rewarded Advertisement ---
func show_rewarded(reward_callback: Callable, close_callback: Callable = Callable()) -> void:
	_pending_reward_callable = reward_callback
	_pending_reward_close_callable = close_callback

	if not is_web or not is_sdk_available:
		# In local mode, cannot show ad; do not grant free reward
		_finish_rewarded(false)
		return

	if PauseManager.instance:
		PauseManager.instance.add_pause_reason(PauseManager.REASON_ADVERTISEMENT)
	else:
		reconcile_gameplay_state()

	var js = Engine.get_singleton("JavaScriptBridge")
	if not js:
		_finish_rewarded(false)
		return

	var code = """
	(function() {
		var bridge = window.__godotYandexBridge;
		var rewardGranted = false;
		if (!window.ysdk || !window.ysdk.adv) {
			if (bridge && bridge.onRewardedClose) bridge.onRewardedClose(false);
			return;
		}
		window.ysdk.adv.showRewardedVideo({
			callbacks: {
				onOpen: function() { console.log('[YandexGamesBridge] Rewarded video opened'); },
				onRewarded: function() {
					console.log('[YandexGamesBridge] onRewarded callback confirmed by SDK!');
					rewardGranted = true;
					if (bridge && bridge.onRewardedReward) bridge.onRewardedReward();
				},
				onClose: function() {
					console.log('[YandexGamesBridge] Rewarded video closed. Granted:', rewardGranted);
					if (bridge && bridge.onRewardedClose) bridge.onRewardedClose(rewardGranted);
				},
				onError: function(err) {
					console.warn('[YandexGamesBridge] Rewarded video error:', err);
					if (bridge && bridge.onRewardedError) bridge.onRewardedError();
				}
			}
		});
	})();
	"""
	js.eval(code)

func _on_js_rewarded_reward(_args: Array = []) -> void:
	if _pending_reward_callable.is_valid():
		var cb = _pending_reward_callable
		_pending_reward_callable = Callable()
		cb.call()

func _on_js_rewarded_close(args: Array = []) -> void:
	var granted = bool(args[0]) if args.size() > 0 else false
	_finish_rewarded(granted)

func _on_js_rewarded_error(_args: Array = []) -> void:
	_finish_rewarded(false)

func _finish_rewarded(granted: bool) -> void:
	if PauseManager.instance:
		PauseManager.instance.remove_pause_reason(PauseManager.REASON_ADVERTISEMENT)
	if _pending_reward_close_callable.is_valid():
		var cb = _pending_reward_close_callable
		_pending_reward_close_callable = Callable()
		cb.call(granted)
	rewarded_completed.emit(granted)

# --- Cloud Saves & Player Data ---
func load_cloud_data() -> void:
	if not is_web or not is_sdk_available:
		var local = SaveManager.load_data()
		cloud_data_loaded.emit(local)
		return

	var js = Engine.get_singleton("JavaScriptBridge")
	if not js:
		cloud_data_loaded.emit(SaveManager.load_data())
		return

	var code = """
	(function() {
		var bridge = window.__godotYandexBridge;
		var p = window.__yandexPlayer;
		if (!p) {
			if (bridge && bridge.onLoadData) bridge.onLoadData(null);
			return;
		}
		p.getData().then(function(data) {
			var jsonStr = JSON.stringify(data || {});
			if (bridge && bridge.onLoadData) bridge.onLoadData(jsonStr);
		}).catch(function(err) {
			console.warn('[YandexGamesBridge] Failed to load cloud data:', err);
			if (bridge && bridge.onLoadData) bridge.onLoadData(null);
		});
	})();
	"""
	js.eval(code)

func _on_js_cloud_data_loaded(args: Array = []) -> void:
	var json_str = str(args[0]) if args.size() > 0 and args[0] != null else ""
	var cloud_dict: Dictionary = {}
	if not json_str.is_empty():
		var json = JSON.new()
		if json.parse(json_str) == OK and json.data is Dictionary:
			cloud_dict = json.data

	# Safe merge with local storage
	var merged = SaveManager.merge_with_cloud(cloud_dict)
	cloud_data_loaded.emit(merged)

func save_cloud_data(data: Dictionary) -> void:
	if not is_web or not is_sdk_available:
		var ok = SaveManager.save_custom_data(data)
		cloud_data_saved.emit(ok)
		return

	var js = Engine.get_singleton("JavaScriptBridge")
	if not js:
		cloud_data_saved.emit(false)
		return

	var json_str = JSON.stringify(data)
	var escaped = json_str.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
	var code = """
	(function() {
		var bridge = window.__godotYandexBridge;
		var p = window.__yandexPlayer;
		if (!p) {
			if (bridge && bridge.onSaveData) bridge.onSaveData(false);
			return;
		}
		try {
			var parsed = JSON.parse('%s');
			p.setData(parsed, true).then(function() {
				if (bridge && bridge.onSaveData) bridge.onSaveData(true);
			}).catch(function(err) {
				console.warn('[YandexGamesBridge] Failed to save cloud data:', err);
				if (bridge && bridge.onSaveData) bridge.onSaveData(false);
			});
		} catch(e) {
			if (bridge && bridge.onSaveData) bridge.onSaveData(false);
		}
	})();
	""" % escaped
	js.eval(code)

func _on_js_cloud_data_saved(args: Array = []) -> void:
	var success = bool(args[0]) if args.size() > 0 else false
	cloud_data_saved.emit(success)

# --- Authorization ---
func authorize_player() -> void:
	if not is_web or not is_sdk_available:
		return
	var js = Engine.get_singleton("JavaScriptBridge")
	if not js:
		return

	var code = """
	(function() {
		var bridge = window.__godotYandexBridge;
		if (!window.ysdk || !window.ysdk.auth) return;
		window.ysdk.auth.openAuthDialog().then(function() {
			return window.ysdk.getPlayer();
		}).then(function(player) {
			window.__yandexPlayer = player;
			var isAuth = player.getMode() !== 'lite';
			var name = player.getName() || 'Исследователь';
			var uid = player.getUniqueID() || '';
			if (bridge && bridge.onAuthSuccess) bridge.onAuthSuccess(isAuth, name, uid);
		}).catch(function(err) {
			console.warn('[YandexGamesBridge] Auth dialog dismissed or failed:', err);
			if (bridge && bridge.onAuthError) bridge.onAuthError();
		});
	})();
	"""
	js.eval(code)

func _on_js_auth_success(args: Array = []) -> void:
	is_authorized = bool(args[0]) if args.size() > 0 else false
	if args.size() > 1 and args[1] != null:
		player_name = str(args[1])
	if args.size() > 2 and args[2] != null:
		player_unique_id = str(args[2])
	auth_state_changed.emit(is_authorized, player_name)
	# Load cloud data on successful authorization
	load_cloud_data()

func _on_js_auth_error(_args: Array = []) -> void:
	auth_state_changed.emit(false, player_name)

# --- Leaderboard ---
func submit_score(score: int, extra_data: String = "") -> void:
	if not is_web or not is_sdk_available:
		leaderboard_score_submitted.emit(true)
		return

	var js = Engine.get_singleton("JavaScriptBridge")
	if not js:
		leaderboard_score_submitted.emit(false)
		return

	var code = """
	(function() {
		var bridge = window.__godotYandexBridge;
		if (!window.ysdk || !window.ysdk.getLeaderboards) {
			if (bridge && bridge.onLeaderboardSet) bridge.onLeaderboardSet(false);
			return;
		}
		window.ysdk.getLeaderboards().then(function(lb) {
			return lb.setLeaderboardScore('rift_explorers', %d, '%s');
		}).then(function() {
			console.log('[YandexGamesBridge] Score %d submitted to leaderboard');
			if (bridge && bridge.onLeaderboardSet) bridge.onLeaderboardSet(true);
		}).catch(function(err) {
			console.warn('[YandexGamesBridge] Failed to submit score:', err);
			if (bridge && bridge.onLeaderboardSet) bridge.onLeaderboardSet(false);
		});
	})();
	""" % [score, extra_data, score]
	js.eval(code)

func _on_js_leaderboard_set(args: Array = []) -> void:
	var success = bool(args[0]) if args.size() > 0 else false
	leaderboard_score_submitted.emit(success)

func request_leaderboard_entries(max_count: int = 10) -> void:
	if not is_web or not is_sdk_available:
		leaderboard_entries_received.emit([])
		return

	var js = Engine.get_singleton("JavaScriptBridge")
	if not js:
		leaderboard_entries_received.emit([])
		return

	var code = """
	(function() {
		var bridge = window.__godotYandexBridge;
		if (!window.ysdk || !window.ysdk.getLeaderboards) {
			if (bridge && bridge.onLeaderboardGet) bridge.onLeaderboardGet('[]');
			return;
		}
		window.ysdk.getLeaderboards().then(function(lb) {
			return lb.getLeaderboardEntries('rift_explorers', { quantityTop: %d, includeUser: true });
		}).then(function(res) {
			var cleanEntries = [];
			if (res && res.entries) {
				for (var i = 0; i < res.entries.length; i++) {
					var e = res.entries[i];
					cleanEntries.push({
						rank: e.rank,
						score: e.score,
						name: (e.player && e.player.publicName) ? e.player.publicName : 'Исследователь'
					});
				}
			}
			if (bridge && bridge.onLeaderboardGet) bridge.onLeaderboardGet(JSON.stringify(cleanEntries));
		}).catch(function(err) {
			console.warn('[YandexGamesBridge] Failed to fetch leaderboard:', err);
			if (bridge && bridge.onLeaderboardGet) bridge.onLeaderboardGet('[]');
		});
	})();
	""" % max_count
	js.eval(code)

func _on_js_leaderboard_get(args: Array = []) -> void:
	var json_str = str(args[0]) if args.size() > 0 and args[0] != null else "[]"
	var entries: Array = []
	var json = JSON.new()
	if json.parse(json_str) == OK and json.data is Array:
		entries = json.data
	leaderboard_entries_received.emit(entries)

func is_web_build() -> bool:
	return is_web

func is_mobile() -> bool:
	return device_type == "mobile" or device_type == "tablet"

func is_desktop() -> bool:
	return device_type == "desktop"

func get_device_type() -> String:
	return device_type

func get_language() -> String:
	return player_language
