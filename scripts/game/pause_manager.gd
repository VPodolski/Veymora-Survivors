class_name PauseManager
extends Node

signal pause_state_changed(is_paused: bool, reasons: Array)

const REASON_USER = "user"
const REASON_BROWSER_FOCUS = "browser_focus"
const REASON_PLATFORM = "platform"
const REASON_ADVERTISEMENT = "ad"
const REASON_MODAL = "modal"

static var instance: PauseManager = null

var active_reasons: Dictionary = {} # reason_id: true
var was_audio_muted_by_pause: bool = false

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func add_pause_reason(reason: String) -> void:
	if reason.is_empty():
		return
	var was_already_paused = is_paused()
	active_reasons[reason] = true

	get_tree().paused = true
	_update_audio_mute()

	if not was_already_paused:
		pause_state_changed.emit(true, active_reasons.keys())

func remove_pause_reason(reason: String) -> void:
	if not active_reasons.has(reason):
		return
	active_reasons.erase(reason)

	if active_reasons.is_empty():
		get_tree().paused = false
		_update_audio_mute()
		pause_state_changed.emit(false, [])
	else:
		_update_audio_mute()
		pause_state_changed.emit(true, active_reasons.keys())

func clear_reasons(keep_user_pause: bool = false) -> void:
	var user_paused = active_reasons.has(REASON_USER) and keep_user_pause
	active_reasons.clear()
	if user_paused:
		active_reasons[REASON_USER] = true
		get_tree().paused = true
	else:
		get_tree().paused = false
	_update_audio_mute()
	pause_state_changed.emit(is_paused(), active_reasons.keys())

func is_paused() -> bool:
	return not active_reasons.is_empty()

func has_pause_reason(reason: String) -> bool:
	return active_reasons.has(reason)

func get_active_reasons() -> Array:
	return active_reasons.keys()

func _update_audio_mute() -> void:
	# Mute if paused by user pause, browser blur, platform request, or ad
	var needs_mute = active_reasons.has(REASON_USER) or \
					 active_reasons.has(REASON_BROWSER_FOCUS) or \
					 active_reasons.has(REASON_PLATFORM) or \
					 active_reasons.has(REASON_ADVERTISEMENT)

	var audio_mgr = get_tree().root.get_node_or_null("AudioManager")
	if not audio_mgr and AudioManager.instance:
		audio_mgr = AudioManager.instance

	if audio_mgr and audio_mgr.has_method("set_temporary_mute"):
		audio_mgr.set_temporary_mute(needs_mute)
	else:
		AudioServer.set_bus_mute(0, needs_mute)

