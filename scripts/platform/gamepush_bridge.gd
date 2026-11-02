class_name GamePushBridge
extends "res://scripts/platform/base_platform_bridge.gd"

const PauseManager = preload("res://scripts/game/pause_manager.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")

static var instance: GamePushBridge = null

var _last_interstitial_time: float = -999.0
const INTERSTITIAL_COOLDOWN_SEC: float = 60.0

var _save_debounce_timer: float = 0.0
var _is_cloud_save_scheduled: bool = false
const CLOUD_SAVE_DEBOUNCE_INTERVAL: float = 1.5

var _pending_reward_callback: Callable = Callable()
var _pending_reward_close_callback: Callable = Callable()
var _pending_interstitial_callback: Callable = Callable()
var _ad_safety_timer: SceneTreeTimer = null

var _is_reward_granted: bool = false
var _reward_callback_consumed: bool = false
var _is_showing_ad: bool = false
@export var allow_debug_ad_fallback: bool = false

var gp_node_override: Node = null

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_web = OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge")

	var sys_lang = OS.get_locale_language().to_lower()
	player_language = "ru" if sys_lang in ["ru", "be", "uk", "kk", "ky", "uz"] else "en"
	device_type = "mobile" if OS.has_feature("mobile") else "desktop"

	if is_web or gp_node_override != null:
		call_deferred("_setup_gamepush_sdk")
	else:
		is_local_mode = true
		is_sdk_available = false
		is_sdk_initialized = true
		call_deferred("_emit_sdk_ready", true)
		call_deferred("_check_and_send_loading_ready")

func _process(delta: float) -> void:
	if _is_cloud_save_scheduled:
		_save_debounce_timer -= delta
		if _save_debounce_timer <= 0.0:
			_is_cloud_save_scheduled = false
			flush_cloud_save()

func get_platform_name() -> String:
	return "gamepush"

func _get_gp_node() -> Node:
	if gp_node_override != null and is_instance_valid(gp_node_override):
		return gp_node_override
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GP")
	return null

func _setup_gamepush_sdk() -> void:
	if is_sdk_initialized:
		return
	var gp = _get_gp_node()
	if not gp:
		# GP autoload not yet initialized or missing, fallback to local
		is_local_mode = true
		is_sdk_available = false
		is_sdk_initialized = true
		_emit_sdk_ready(true)
		_check_and_send_loading_ready()
		return

	if gp.get("is_inited") and gp.get("gp"):
		_on_gp_inited(true)
	else:
		if not gp.is_connected("inited", Callable(self, "_on_gp_inited")):
			gp.connect("inited", Callable(self, "_on_gp_inited"))
		# Safety fallback timeout if GP doesn't emit in 4 seconds
		get_tree().create_timer(4.0).timeout.connect(func():
			if not is_sdk_initialized:
				print("[GamePushBridge] SDK init timed out, falling back to local.")
				_on_gp_inited(false)
		)

func _on_gp_inited(success: bool) -> void:
	var gp = _get_gp_node()
	if success and gp and gp.get("gp"):
		is_sdk_initialized = true
		is_sdk_available = true
		is_local_mode = false
		print("[GamePushBridge] Official GamePush SDK initialized successfully.")

		# Sync player info
		if gp.get("player"):
			var p = gp.player
			player_name = str(p.get_player_name())
			if player_name.is_empty():
				player_name = "Исследователь"
			player_unique_id = str(p.get_id())
			is_authorized = bool(p.is_logged_in())

			if p.has_signal("logged_in") and not p.is_connected("logged_in", Callable(self, "_on_player_logged_in")):
				p.connect("logged_in", Callable(self, "_on_player_logged_in"))

		# Device & language
		if gp.get("device") and gp.device.has_method("is_mobile"):
			device_type = "mobile" if gp.device.is_mobile() else "desktop"
		if gp.get("language") and gp.language.has_method("current"):
			var cur_lang = str(gp.language.current()).to_lower()
			if cur_lang in ["ru", "en"]:
				player_language = cur_lang

		# Platform pause hooks
		if gp.get("game"):
			if gp.game.has_signal("paused") and not gp.game.is_connected("paused", Callable(self, "_on_gp_paused")):
				gp.game.connect("paused", Callable(self, "_on_gp_paused"))
			if gp.game.has_signal("resumed") and not gp.game.is_connected("resumed", Callable(self, "_on_gp_resumed")):
				gp.game.connect("resumed", Callable(self, "_on_gp_resumed"))

		# Sync cloud save immediately
		load_cloud_save()
		_emit_sdk_ready(false)
	else:
		is_sdk_initialized = true
		is_local_mode = true
		is_sdk_available = false
		print("[GamePushBridge] GamePush SDK unavailable or init failed. Using local mode.")
		_emit_sdk_ready(true)

	_check_and_send_loading_ready()

func _on_gp_paused() -> void:
	if PauseManager.instance:
		PauseManager.instance.add_pause_reason(PauseManager.REASON_PLATFORM)

func _on_gp_resumed() -> void:
	if PauseManager.instance:
		PauseManager.instance.remove_pause_reason(PauseManager.REASON_PLATFORM)

func _emit_sdk_ready(local_mode: bool) -> void:
	sdk_ready.emit(local_mode)

func _check_and_send_loading_ready() -> void:
	if has_sent_loading_ready:
		return
	has_sent_loading_ready = true
	notify_game_ready()

func notify_game_ready() -> void:
	if has_notified_ready:
		return
	super.notify_game_ready()
	var gp = _get_gp_node()
	if is_sdk_available and gp and gp.get("game"):
		gp.game.game_start()
		print("[GamePushBridge] GP.game.game_start() called.")
	else:
		print("[GamePushBridge] Game ready in local mode.")

func reconcile_gameplay_state() -> void:
	var in_game = false
	if Engine.has_singleton("GameFlow"):
		var gf = Engine.get_main_loop().root.get_node_or_null("GameFlow") if Engine.get_main_loop() else null
		if gf and "current_state" in gf:
			in_game = (gf.current_state == "playing")
	is_gameplay_active = in_game
	var gp = _get_gp_node()
	if is_sdk_available and gp and gp.get("game"):
		if is_gameplay_active:
			gp.game.gameplay_start()
			print("[GamePushBridge] GP.game.gameplay_start()")
		else:
			gp.game.gameplay_stop()
			print("[GamePushBridge] GP.game.gameplay_stop()")
	else:
		if is_gameplay_active:
			print("[GamePushBridge] Gameplay started [Local]")
		else:
			print("[GamePushBridge] Gameplay stopped [Local]")

func can_show_interstitial() -> bool:
	if not is_sdk_available:
		return false
	var now = Time.get_ticks_msec() / 1000.0
	if (now - _last_interstitial_time) < INTERSTITIAL_COOLDOWN_SEC:
		return false
	var gp = _get_gp_node()
	if gp and gp.get("ads") and gp.ads.has_method("is_fullscreen_available"):
		return gp.ads.is_fullscreen_available()
	return true

func show_interstitial(on_complete: Callable = Callable()) -> void:
	if not can_show_interstitial():
		interstitial_completed.emit(false)
		if on_complete.is_valid():
			on_complete.call(false)
		return

	var gp = _get_gp_node()
	if not gp or not gp.get("ads"):
		interstitial_completed.emit(false)
		if on_complete.is_valid():
			on_complete.call(false)
		return

	_is_showing_ad = true
	_pending_interstitial_callback = on_complete
	if PauseManager.instance:
		PauseManager.instance.add_pause_reason(PauseManager.REASON_ADVERTISEMENT)

	var close_callable = Callable(self, "_on_fullscreen_closed")
	if not gp.ads.is_connected("fullscreen_close", close_callable):
		gp.ads.connect("fullscreen_close", close_callable, CONNECT_ONE_SHOT)

	# Safety timeout in case ad hangs or blocked
	_ad_safety_timer = get_tree().create_timer(5.0)
	_ad_safety_timer.timeout.connect(func():
		if _is_showing_ad:
			print("[GamePushBridge] Interstitial safety timeout triggered.")
			_on_fullscreen_closed(false)
	)

	gp.ads.show_fullscreen()

func _on_fullscreen_closed(was_shown: bool) -> void:
	if not _is_showing_ad:
		return
	_is_showing_ad = false
	_last_interstitial_time = Time.get_ticks_msec() / 1000.0

	if PauseManager.instance:
		PauseManager.instance.remove_pause_reason(PauseManager.REASON_ADVERTISEMENT)

	var cb = _pending_interstitial_callback
	_pending_interstitial_callback = Callable()

	interstitial_completed.emit(was_shown)
	if cb.is_valid():
		cb.call(was_shown)

func show_rewarded(reward_callback: Callable, close_callback: Callable = Callable()) -> void:
	var gp = _get_gp_node()
	if not is_sdk_available or not gp or not gp.get("ads"):
		# Production safety: in production or when debug fallback is disabled, NEVER grant reward without SDK!
		var can_debug_fallback = OS.is_debug_build() and allow_debug_ad_fallback
		if can_debug_fallback:
			print("[GamePushBridge] Rewarded video in explicit debug fallback.")
			rewarded_completed.emit(true)
			if reward_callback.is_valid():
				reward_callback.call()
			if close_callback.is_valid():
				close_callback.call(true)
		else:
			print("[GamePushBridge] Rewarded video unavailable or SDK missing. Reward denied.")
			rewarded_completed.emit(false)
			if close_callback.is_valid():
				close_callback.call(false)
		return

	if _is_showing_ad:
		print("[GamePushBridge] Rewarded ad already active, request rejected.")
		rewarded_completed.emit(false)
		if close_callback.is_valid():
			close_callback.call(false)
		return

	_is_showing_ad = true
	_is_reward_granted = false
	_reward_callback_consumed = false
	_pending_reward_callback = reward_callback
	_pending_reward_close_callback = close_callback

	if PauseManager.instance:
		PauseManager.instance.add_pause_reason(PauseManager.REASON_ADVERTISEMENT)

	var reward_callable = Callable(self, "_on_rewarded_reward")
	if not gp.ads.is_connected("rewarded_reward", reward_callable):
		gp.ads.connect("rewarded_reward", reward_callable, CONNECT_ONE_SHOT)

	var close_callable = Callable(self, "_on_rewarded_closed")
	if not gp.ads.is_connected("rewarded_close", close_callable):
		gp.ads.connect("rewarded_close", close_callable, CONNECT_ONE_SHOT)

	# Safety timeout in case video hangs - strictly denies reward on timeout
	_ad_safety_timer = get_tree().create_timer(45.0)
	_ad_safety_timer.timeout.connect(func():
		if _is_showing_ad:
			print("[GamePushBridge] Rewarded video safety timeout triggered. Reward denied.")
			_is_reward_granted = false
			_on_rewarded_closed(false)
	)

	gp.ads.show_rewarded_video()

func _on_rewarded_reward() -> void:
	_is_reward_granted = true
	print("[GamePushBridge] Rewarded reward confirmed by GamePush SDK.")

func _on_rewarded_closed(success: bool) -> void:
	if not _is_showing_ad:
		return
	_is_showing_ad = false

	if PauseManager.instance:
		PauseManager.instance.remove_pause_reason(PauseManager.REASON_ADVERTISEMENT)

	var reward_cb = _pending_reward_callback
	var close_cb = _pending_reward_close_callback
	_pending_reward_callback = Callable()
	_pending_reward_close_callback = Callable()

	# Strictly enforce that reward is given ONLY if rewarded_reward fired, success is true, and not consumed
	var final_granted = _is_reward_granted and success and not _reward_callback_consumed
	if final_granted:
		_reward_callback_consumed = true
		if reward_cb.is_valid():
			reward_cb.call()

	rewarded_completed.emit(final_granted)
	if close_cb.is_valid():
		close_cb.call(final_granted)

func schedule_cloud_save() -> void:
	_is_cloud_save_scheduled = true
	_save_debounce_timer = CLOUD_SAVE_DEBOUNCE_INTERVAL

func flush_cloud_save() -> void:
	_is_cloud_save_scheduled = false
	var local_data = SaveManager.load_data()
	SaveManager.save_data(local_data) # Always preserve local progress on disk

	var gp = _get_gp_node()
	if not is_sdk_available or not gp or not gp.get("player"):
		print("[GamePushBridge] Cloud save in local mode (saved to local storage).")
		cloud_data_saved.emit(true)
		return

	var json_str = JSON.stringify(local_data)
	gp.player.set_value("veymora_save", json_str)

	# Await SDK confirmation via player.synced with timeout and single resolution
	var is_resolved = false
	var timer = get_tree().create_timer(5.0)

	var sync_callback: Callable
	sync_callback = func(success: bool):
		if is_resolved:
			return
		is_resolved = true
		if success:
			print("[GamePushBridge] Cloud save confirmed by GamePush player.synced(true).")
			cloud_data_saved.emit(true)
		else:
			print("[GamePushBridge] Cloud save failed to sync (player.synced(false)). Local progress preserved.")
			cloud_data_saved.emit(false)

	timer.timeout.connect(func():
		if is_resolved:
			return
		is_resolved = true
		if is_instance_valid(gp) and gp.get("player") and gp.player.is_connected("synced", sync_callback):
			gp.player.disconnect("synced", sync_callback)
		print("[GamePushBridge] Cloud save sync timed out. Local progress preserved.")
		cloud_data_saved.emit(false)
	)

	gp.player.connect("synced", sync_callback, CONNECT_ONE_SHOT)
	gp.player.sync()
	print("[GamePushBridge] Cloud save sync requested.")

func load_cloud_save(on_loaded: Callable = Callable()) -> void:
	var gp = _get_gp_node()
	if not is_sdk_available or not gp or not gp.get("player"):
		var local = SaveManager.load_data()
		cloud_data_loaded.emit(local)
		cloud_sync_completed.emit(local)
		if on_loaded.is_valid():
			on_loaded.call(local)
		return

	var raw_save = gp.player.get_value("veymora_save")
	var cloud_dict: Dictionary = {}
	if raw_save is String and not raw_save.is_empty():
		var json = JSON.new()
		if json.parse(raw_save) == OK and json.data is Dictionary:
			cloud_dict = json.data

	var merged = SaveManager.merge_with_cloud(cloud_dict)
	SaveManager.save_data(merged) # Preserve merged save locally
	cloud_data_loaded.emit(cloud_dict)
	cloud_sync_completed.emit(merged)
	if on_loaded.is_valid():
		on_loaded.call(merged)

func submit_score(score: int, _extra_data: String = "") -> void:
	var gp = _get_gp_node()
	if not is_sdk_available or not gp or not gp.get("player"):
		print("[GamePushBridge] Leaderboard unavailable in local mode. Score: %d." % score)
		leaderboard_score_submitted.emit(false)
		return

	gp.player.set_value("score", score)
	if gp.get("leaderboard") and gp.leaderboard.has_method("publish_record"):
		gp.leaderboard.publish_record("", {"score": score})

	# Await SDK confirmation via player.synced
	var is_resolved = false
	var timer = get_tree().create_timer(5.0)

	var sync_cb: Callable
	sync_cb = func(success: bool):
		if is_resolved:
			return
		is_resolved = true
		if success:
			print("[GamePushBridge] Score %d confirmed by GamePush." % score)
			leaderboard_score_submitted.emit(true)
		else:
			print("[GamePushBridge] Score %d submission failed." % score)
			leaderboard_score_submitted.emit(false)

	timer.timeout.connect(func():
		if is_resolved:
			return
		is_resolved = true
		if is_instance_valid(gp) and gp.get("player") and gp.player.is_connected("synced", sync_cb):
			gp.player.disconnect("synced", sync_cb)
		print("[GamePushBridge] Score submission timed out.")
		leaderboard_score_submitted.emit(false)
	)

	gp.player.connect("synced", sync_cb, CONNECT_ONE_SHOT)
	gp.player.sync()

func fetch_leaderboard(max_entries: int = 10, include_user: bool = true) -> void:
	var gp = _get_gp_node()
	if not is_sdk_available or not gp or not gp.get("leaderboard"):
		print("[GamePushBridge] Leaderboard unavailable, returning empty list.")
		leaderboard_entries_received.emit([])
		return

	var is_resolved = false
	var timer = get_tree().create_timer(5.0)

	var fetch_cb: Callable
	fetch_cb = func(result: Dictionary):
		if is_resolved:
			return
		is_resolved = true

		var entries: Array = []
		var raw_list = []
		if result.has("players") and result["players"] is Array:
			raw_list = result["players"]
		elif result.has("top") and result["top"] is Array:
			raw_list = result["top"]
		elif result.has("records") and result["records"] is Array:
			raw_list = result["records"]

		for p in raw_list:
			if p is Dictionary:
				entries.append({
					"rank": p.get("position", p.get("rank", 0)),
					"name": p.get("name", p.get("player_name", "Игрок")),
					"score": p.get("score", 0)
				})
		print("[GamePushBridge] Leaderboard entries received: ", entries.size())
		leaderboard_entries_received.emit(entries)

	timer.timeout.connect(func():
		if is_resolved:
			return
		is_resolved = true
		if is_instance_valid(gp) and gp.get("leaderboard") and gp.leaderboard.is_connected("fetched", fetch_cb):
			gp.leaderboard.disconnect("fetched", fetch_cb)
		print("[GamePushBridge] Leaderboard fetch timed out.")
		leaderboard_entries_received.emit([])
	)

	gp.leaderboard.connect("fetched", fetch_cb, CONNECT_ONE_SHOT)
	gp.leaderboard.fetch(["score"], "DESC", max_entries, [], "all" if include_user else "")

func open_leaderboard_overlay(max_entries: int = 10) -> void:
	var gp = _get_gp_node()
	if is_sdk_available and gp and gp.get("leaderboard") and gp.leaderboard.has_method("open"):
		gp.leaderboard.open(["score"], "DESC", max_entries)

func authorize_player() -> void:
	var gp = _get_gp_node()
	if is_sdk_available and gp and gp.get("player"):
		gp.player.login()
	else:
		is_authorized = true
		player_name = "Исследователь"
		auth_state_changed.emit(true, player_name)

func _on_player_logged_in(success: bool) -> void:
	var gp = _get_gp_node()
	if success and gp and gp.get("player"):
		is_authorized = true
		var new_name = str(gp.player.get_player_name())
		if not new_name.is_empty():
			player_name = new_name
	auth_state_changed.emit(is_authorized, player_name)
