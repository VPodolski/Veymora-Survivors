class_name HUDController
extends CanvasLayer

const RunStats = preload("res://scripts/game/run_stats.gd")
const ArchiveDialog = preload("res://scripts/ui/archive_dialog.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")

signal restart_requested

@onready var hp_bar: ProgressBar = $TopBar/HBox/HealthContainer/HPBar
@onready var hp_label: Label = $TopBar/HBox/HealthContainer/HPLabel
@onready var timer_label: Label = $TopBar/HBox/TimerContainer/TimerLabel
@onready var level_label: Label = $TopBar/HBox/LevelContainer/LevelLabel
@onready var artifacts_container: HBoxContainer = $TopBar/HBox/ArtifactsContainer
@onready var xp_bar: ProgressBar = $XPBarContainer/XPBar

# Boss Bar
@onready var boss_container: Control = $BossContainer
@onready var boss_hp_bar: ProgressBar = $BossContainer/VBox/BossHPBar
@onready var boss_name_label: Label = $BossContainer/VBox/BossNameLabel

# Death & Victory Screens
@onready var summary_screen: Control = $SummaryScreen
@onready var death_screen: Control = $SummaryScreen # backward compatibility alias
@onready var summary_title: Label = $SummaryScreen/CenterContainer/Panel/VBox/Title
@onready var summary_time_label: Label = $SummaryScreen/CenterContainer/Panel/VBox/SurvivalTimeLabel
@onready var summary_stats_label: Label = $SummaryScreen/CenterContainer/Panel/VBox/StatsLabel
@onready var restart_button: Button = $SummaryScreen/CenterContainer/Panel/VBox/RestartButton
@onready var summary_archive_btn: Button = get_node_or_null("SummaryScreen/CenterContainer/Panel/VBox/SummaryArchiveButton")
@onready var summary_menu_btn: Button = get_node_or_null("SummaryScreen/CenterContainer/Panel/VBox/SummaryMenuButton")

# Pause Menu
@onready var pause_menu: Control = get_node_or_null("PauseMenu")
@onready var resume_btn: Button = get_node_or_null("PauseMenu/Center/Panel/VBox/ResumeButton")
@onready var pause_archive_btn: Button = get_node_or_null("PauseMenu/Center/Panel/VBox/PauseArchiveButton")
@onready var pause_restart_btn: Button = get_node_or_null("PauseMenu/Center/Panel/VBox/PauseRestartButton")
@onready var pause_menu_btn: Button = get_node_or_null("PauseMenu/Center/Panel/VBox/PauseMenuButton")

# Level Up & Archive
@onready var level_up_panel: LevelUpPanel = $LevelUpPanel
@onready var archive_dialog: ArchiveDialog = get_node_or_null("ArchiveDialog")
@onready var toast_label: Label = $ToastLabel

var elapsed_time: float = 0.0
var is_game_active: bool = true
var total_kills: int = 0
var current_level: int = 1
var run_stats: RunStats = RunStats.new()

func _ready() -> void:
	add_to_group("hud")
	if summary_screen:
		summary_screen.visible = false
	if boss_container:
		boss_container.visible = false
	if pause_menu:
		pause_menu.visible = false
	if archive_dialog:
		archive_dialog.visible = false
	if toast_label:
		toast_label.modulate.a = 0.0

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if summary_archive_btn:
		summary_archive_btn.pressed.connect(_open_archive)
	if summary_menu_btn:
		summary_menu_btn.pressed.connect(_go_to_menu)

	if resume_btn:
		resume_btn.pressed.connect(toggle_pause)
	if pause_archive_btn:
		pause_archive_btn.pressed.connect(_open_archive)
	if pause_restart_btn:
		pause_restart_btn.pressed.connect(_on_pause_restart_pressed)
	if pause_menu_btn:
		pause_menu_btn.pressed.connect(_go_to_menu)

func set_run_stats(stats: RunStats) -> void:
	if stats:
		run_stats = stats
		total_kills = run_stats.total_kills

func _process(delta: float) -> void:
	if is_game_active and not get_tree().paused:
		elapsed_time += delta
		if run_stats:
			run_stats.survival_time = elapsed_time
		update_timer_display()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if archive_dialog and archive_dialog.visible:
			archive_dialog.visible = false
			return
		if level_up_panel and level_up_panel.visible:
			return
		if is_game_active:
			toggle_pause()
			return

	if not is_game_active:
		if event.is_action_pressed("restart") or (event is InputEventKey and event.pressed and event.keycode == KEY_R):
			_on_restart_pressed()

func toggle_pause() -> void:
	var next_pause = not get_tree().paused
	get_tree().paused = next_pause
	if pause_menu:
		pause_menu.visible = next_pause

func _open_archive() -> void:
	if archive_dialog:
		archive_dialog.open_codex()

func _on_pause_restart_pressed() -> void:
	get_tree().paused = false
	_on_restart_pressed()

func _go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func update_health(current_hp: float, max_hp: float) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
	if hp_label:
		hp_label.text = "HP: %d / %d" % [int(ceil(current_hp)), int(ceil(max_hp))]

		if current_hp <= max_hp * 0.3:
			hp_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.3, 1.0))
		else:
			hp_label.add_theme_color_override("font_color", Color.WHITE)

func update_experience(current_xp: int, required_xp: int) -> void:
	if xp_bar:
		xp_bar.max_value = required_xp
		xp_bar.value = current_xp

func update_level(new_level: int) -> void:
	current_level = new_level
	if run_stats:
		run_stats.level_reached = new_level
	if level_label:
		level_label.text = "УР. %d" % new_level

func show_level_up(player: PlayerController, new_level: int) -> void:
	update_level(new_level)
	if AudioManager.instance:
		AudioManager.instance.play_level_up()
	if level_up_panel:
		level_up_panel.open_panel(player, new_level)

func add_artifact_icon(item: ItemDefinition) -> void:
	if not artifacts_container:
		return

	var icon_panel = PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(30, 30)
	var style = StyleBoxFlat.new()
	style.bg_color = item.icon_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.6)
	icon_panel.add_theme_stylebox_override("panel", style)
	icon_panel.tooltip_text = "%s: %s" % [item.name, item.description]
	artifacts_container.add_child(icon_panel)

func show_chest_notification(reward_name: String) -> void:
	if AudioManager.instance:
		AudioManager.instance.play_chest()
	if toast_label:
		toast_label.text = "Сундук: получено [%s]" % reward_name
		var tween = create_tween()
		tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
		tween.tween_interval(2.0)
		tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)

func register_kill(enemy: EnemyController = null) -> void:
	if enemy and run_stats:
		run_stats.record_kill(enemy)
		total_kills = run_stats.total_kills
	else:
		total_kills += 1
		if run_stats:
			run_stats.total_kills = total_kills

func setup_boss_bar(boss: BossController) -> void:
	if not boss_container:
		return
	boss_container.visible = true
	if AudioManager.instance:
		AudioManager.instance.play_boss_alert()
	if boss_hp_bar:
		boss_hp_bar.max_value = boss.stats.max_health
		boss_hp_bar.value = boss.current_health
	boss.boss_health_changed.connect(_on_boss_health_changed)
	boss.boss_defeated.connect(_on_boss_defeated)

func _on_boss_health_changed(cur: float, max_hp: float) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_hp
		boss_hp_bar.value = cur

func _on_boss_defeated() -> void:
	if boss_container:
		boss_container.visible = false
	if run_stats:
		run_stats.defeated_boss = true
	if AudioManager.instance:
		AudioManager.instance.play_synergy()
	get_tree().create_timer(1.2).timeout.connect(show_victory_screen)

func update_timer_display() -> void:
	if timer_label:
		var minutes = int(elapsed_time) / 60
		var seconds = int(elapsed_time) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func show_victory_screen() -> void:
	is_game_active = false
	var saved_data = SaveManager.record_run(elapsed_time, total_kills, true)
	if summary_screen:
		summary_screen.visible = true
	if summary_title:
		summary_title.text = "ПОБЕДА: РАЗЛОМ ЗАКРЫТ!"
		summary_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	populate_summary_stats(saved_data)

func show_death_screen() -> void:
	is_game_active = false
	var saved_data = SaveManager.record_run(elapsed_time, total_kills, false)
	if summary_screen:
		summary_screen.visible = true
	if summary_title:
		summary_title.text = "МАГ ПОГИБ"
		summary_title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.25, 1.0))
	populate_summary_stats(saved_data)

func populate_summary_stats(saved_data: Dictionary) -> void:
	var minutes = int(elapsed_time) / 60
	var seconds = int(elapsed_time) % 60
	if summary_time_label:
		summary_time_label.text = "Время выживания: %02d:%02d" % [minutes, seconds]

	if summary_stats_label:
		var best_sec = int(saved_data.get("best_survival_time", 0.0))
		var b_min = best_sec / 60
		var b_sec = best_sec % 60
		var elite_txt = (" (Элита: %d, Боссы: %d)" % [run_stats.elite_kills, run_stats.boss_kills]) if run_stats else ""
		summary_stats_label.text = "Уровень мага: %d\nУничтожено врагов: %d%s\nРекорд выживания: %02d:%02d\nВсего забегов: %d" % [
			current_level,
			total_kills,
			elite_txt,
			b_min,
			b_sec,
			int(saved_data.get("total_runs", 1))
		]

func _on_restart_pressed() -> void:
	restart_requested.emit()
