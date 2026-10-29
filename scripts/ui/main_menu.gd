class_name MainMenu
extends Control

const SaveManager = preload("res://scripts/game/save_manager.gd")
const ArchiveDialog = preload("res://scripts/ui/archive_dialog.gd")
const ArchiveDialogScene = preload("res://scenes/ui/archive_dialog.tscn")

@onready var start_btn: Button = $Center/VBox/StartButton
@onready var archive_btn: Button = $Center/VBox/ArchiveButton
@onready var controls_btn: Button = $Center/VBox/ControlsButton
@onready var stats_label: Label = $Center/VBox/StatsLabel
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var close_controls_btn: Button = $ControlsPanel/Margin/VBox/CloseControlsBtn

var archive_dialog: ArchiveDialog = null

func _ready() -> void:
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	if archive_btn:
		archive_btn.pressed.connect(_on_archive_pressed)
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
	stats_label.text = "Всего забегов: %d   |   Рекорд выживания: %02d:%02d   |   Повержено боссов: %d" % [
		int(data.get("total_runs", 0)),
		m,
		s,
		int(data.get("bosses_defeated", 0))
	]

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_archive_pressed() -> void:
	if not archive_dialog:
		archive_dialog = ArchiveDialogScene.instantiate() as ArchiveDialog
		add_child(archive_dialog)
	archive_dialog.open_codex()

func _on_controls_pressed() -> void:
	if controls_panel:
		controls_panel.visible = true
