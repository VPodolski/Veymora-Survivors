class_name HUDController
extends CanvasLayer

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
@onready var death_screen: Control = $SummaryScreen
@onready var summary_title: Label = $SummaryScreen/CenterContainer/Panel/VBox/Title
@onready var summary_time_label: Label = $SummaryScreen/CenterContainer/Panel/VBox/SurvivalTimeLabel
@onready var summary_stats_label: Label = $SummaryScreen/CenterContainer/Panel/VBox/StatsLabel
@onready var restart_button: Button = $SummaryScreen/CenterContainer/Panel/VBox/RestartButton

# Level Up
@onready var level_up_panel: LevelUpPanel = $LevelUpPanel

# Toast Notification
@onready var toast_label: Label = $ToastLabel

var elapsed_time: float = 0.0
var is_game_active: bool = true
var total_kills: int = 0
var current_level: int = 1

func _ready() -> void:
	add_to_group("hud")
	if summary_screen:
		summary_screen.visible = false
	if boss_container:
		boss_container.visible = false
	if toast_label:
		toast_label.modulate.a = 0.0
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

func _process(delta: float) -> void:
	if is_game_active:
		elapsed_time += delta
		update_timer_display()

func _unhandled_input(event: InputEvent) -> void:
	if not is_game_active:
		if event.is_action_pressed("restart") or (event is InputEventKey and event.pressed and event.keycode == KEY_R):
			_on_restart_pressed()

func update_health(current_hp: float, max_hp: float) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
	if hp_label:
		hp_label.text = "HP: %d / %d" % [int(ceil(current_hp)), int(ceil(max_hp))]

func update_experience(current_xp: int, required_xp: int) -> void:
	if xp_bar:
		xp_bar.max_value = required_xp
		xp_bar.value = current_xp

func update_level(new_level: int) -> void:
	current_level = new_level
	if level_label:
		level_label.text = "УР. %d" % new_level

func show_level_up(player: PlayerController, new_level: int) -> void:
	update_level(new_level)
	if level_up_panel:
		level_up_panel.open_panel(player, new_level)

func add_artifact_icon(item: ItemDefinition) -> void:
	if not artifacts_container:
		return
	var icon_panel = PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(28, 28)
	var style = StyleBoxFlat.new()
	style.bg_color = item.icon_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	icon_panel.add_theme_stylebox_override("panel", style)
	icon_panel.tooltip_text = "%s: %s" % [item.name, item.description]
	artifacts_container.add_child(icon_panel)

func show_chest_notification(reward_name: String) -> void:
	if toast_label:
		toast_label.text = "Сундук: получено [%s]" % reward_name
		var tween = create_tween()
		tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
		tween.tween_interval(2.0)
		tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)

func register_kill() -> void:
	total_kills += 1

func setup_boss_bar(boss: BossController) -> void:
	if not boss_container:
		return
	boss_container.visible = true
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
	# Show Victory Screen after brief delay
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
		summary_stats_label.text = "Уровень мага: %d\nУничтожено врагов: %d\nРекорд выживания: %02d:%02d\nВсего забегов: %d" % [
			current_level,
			total_kills,
			b_min,
			b_sec,
			int(saved_data.get("total_runs", 1))
		]

func _on_restart_pressed() -> void:
	restart_requested.emit()
