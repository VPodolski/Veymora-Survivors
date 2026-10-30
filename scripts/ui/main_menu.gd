class_name MainMenu
extends Control

const SaveManager = preload("res://scripts/game/save_manager.gd")
const ArchiveDialog = preload("res://scripts/ui/archive_dialog.gd")
const ArchiveDialogScene = preload("res://scenes/ui/archive_dialog.tscn")
const SettingsDialogScene = preload("res://scenes/ui/settings_dialog.tscn")
const SettingsDialog = preload("res://scripts/ui/settings_dialog.gd")
const GameFlowController = preload("res://scripts/game/game_flow_controller.gd")

@onready var start_btn: Button = $Center/VBox/StartButton
@onready var archive_btn: Button = $Center/VBox/ArchiveButton
@onready var settings_btn: Button = $Center/VBox/SettingsButton
@onready var controls_btn: Button = $Center/VBox/ControlsButton
@onready var stats_label: Label = $Center/VBox/StatsLabel
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var close_controls_btn: Button = $ControlsPanel/Margin/VBox/CloseControlsBtn

var archive_dialog: ArchiveDialog = null
var settings_dialog: SettingsDialog = null

func _ready() -> void:
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	if archive_btn:
		archive_btn.pressed.connect(_on_archive_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if controls_btn:
		controls_btn.pressed.connect(_on_controls_pressed)
	if close_controls_btn:
		close_controls_btn.pressed.connect(func(): controls_panel.visible = false)

	if controls_panel:
		controls_panel.visible = false

	_update_stats_display()

func _update_stats_display() -> void:
	if not stats_label:
		return
	var data = SaveManager.load_data()
	var best_sec = int(data.get("best_survival_time", 0.0))
	var m = best_sec / 60
	var s = best_sec % 60
	var arenas = data.get("unlocked_arenas", ["forgotten_forest"])
	stats_label.text = "Всего забегов: %d   |   Рекорд: %02d:%02d   |   Повержено боссов: %d   |   Доступно арен: %d" % [
		int(data.get("total_runs", 0)),
		m,
		s,
		int(data.get("bosses_defeated", 0)),
		arenas.size()
	]

func _on_start_pressed() -> void:
	if GameFlowController.instance:
		GameFlowController.instance.open_arena_select()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/arena_select.tscn")

func _on_archive_pressed() -> void:
	if not archive_dialog:
		archive_dialog = ArchiveDialogScene.instantiate() as ArchiveDialog
		add_child(archive_dialog)
	archive_dialog.open_codex()

func _on_settings_pressed() -> void:
	if not settings_dialog:
		settings_dialog = SettingsDialogScene.instantiate() as SettingsDialog
		add_child(settings_dialog)
	settings_dialog.open()

func _on_controls_pressed() -> void:
	if controls_panel:
		controls_panel.visible = true
