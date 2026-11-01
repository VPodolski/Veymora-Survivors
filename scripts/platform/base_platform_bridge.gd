class_name BasePlatformBridge
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

var is_web: bool = false
var is_sdk_available: bool = false
var is_local_mode: bool = true

var player_language: String = "ru"
var device_type: String = "desktop"
var is_authorized: bool = false
var player_name: String = "Исследователь"
var player_unique_id: String = ""

var has_notified_ready: bool = false
var has_sent_loading_ready: bool = false
var is_game_ready: bool = false
var is_sdk_initialized: bool = false
var is_gameplay_active: bool = false

func get_platform_name() -> String:
	return "base"

func is_web_build() -> bool:
	return is_web or OS.has_feature("web")

func is_mobile() -> bool:
	return device_type == "mobile" or OS.has_feature("mobile")

func notify_game_ready() -> void:
	has_notified_ready = true
	is_game_ready = true

func reconcile_gameplay_state() -> void:
	pass

func can_show_interstitial() -> bool:
	return false

func show_interstitial(on_complete: Callable = Callable()) -> void:
	interstitial_completed.emit(false)
	if on_complete.is_valid():
		on_complete.call(false)

func show_rewarded(reward_callback: Callable, close_callback: Callable = Callable()) -> void:
	rewarded_completed.emit(false)
	if close_callback.is_valid():
		close_callback.call(false)

func schedule_cloud_save() -> void:
	pass

func flush_cloud_save() -> void:
	pass

func load_cloud_save(on_loaded: Callable = Callable()) -> void:
	cloud_data_loaded.emit({})
	if on_loaded.is_valid():
		on_loaded.call({})

func submit_score(_score: int, _extra_data: String = "") -> void:
	leaderboard_score_submitted.emit(false)

func fetch_leaderboard(_max_entries: int = 10, _include_user: bool = true) -> void:
	leaderboard_entries_received.emit([])

func authorize_player() -> void:
	pass
