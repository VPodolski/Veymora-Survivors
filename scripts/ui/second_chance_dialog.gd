class_name SecondChanceDialog
extends Control

signal revived
signal declined

const YandexGamesBridge = preload("res://scripts/platform/yandex_games_bridge.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")
const PauseManager = preload("res://scripts/game/pause_manager.gd")

@onready var title_label: Label = $Panel/VBox/Title
@onready var prompt_label: Label = $Panel/VBox/Prompt
@onready var watch_btn: Button = $Panel/VBox/Buttons/WatchAdButton
@onready var decline_btn: Button = $Panel/VBox/Buttons/DeclineButton

var is_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if watch_btn:
		watch_btn.pressed.connect(_on_watch_pressed)
	if decline_btn:
		decline_btn.pressed.connect(_on_decline_pressed)

	_update_localized_texts()
	if LocalizationManager.instance:
		LocalizationManager.instance.language_changed.connect(func(_l): _update_localized_texts())

func _update_localized_texts() -> void:
	var loc = LocalizationManager.instance
	if not loc:
		return
	if title_label:
		title_label.text = loc.get_text("second_chance_title", "ВТОРОЙ ШАНС")
	if prompt_label:
		prompt_label.text = loc.get_text("second_chance_prompt", "Маг пал в бою, но древний Разлом дарует шанс восстать!\nПосмотрите короткую рекламу и продолжите текущий забег с 50% здоровья.")
	if watch_btn:
		watch_btn.text = loc.get_text("second_chance_btn_watch", "✦ ВОСКРЕСНУТЬ ЗА ПРОСМОТР")
	if decline_btn:
		decline_btn.text = loc.get_text("second_chance_btn_decline", "Завершить забег")

func open_dialog() -> void:
	is_open = true
	visible = true
	if watch_btn:
		watch_btn.disabled = false
	if decline_btn:
		decline_btn.disabled = false
	_update_localized_texts()
	if PauseManager.instance:
		PauseManager.instance.add_pause_reason(PauseManager.REASON_MODAL)

func close_dialog() -> void:
	is_open = false
	visible = false
	if watch_btn:
		watch_btn.disabled = false
	if decline_btn:
		decline_btn.disabled = false
	if PauseManager.instance:
		PauseManager.instance.remove_pause_reason(PauseManager.REASON_MODAL)

func _on_watch_pressed() -> void:
	if watch_btn:
		watch_btn.disabled = true
	if decline_btn:
		decline_btn.disabled = true

	var bridge = YandexGamesBridge.instance
	if bridge:
		bridge.show_rewarded(
			func(): # Reward callback (ONLY on verified onRewarded)
				close_dialog()
				revived.emit(),
			func(granted): # Close callback
				if not granted:
					close_dialog()
					declined.emit()
		)
	else:
		# Fallback if bridge not found
		close_dialog()
		declined.emit()

func _on_decline_pressed() -> void:
	close_dialog()
	declined.emit()
