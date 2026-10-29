class_name HUDController
extends CanvasLayer

signal restart_requested

@onready var hp_bar: ProgressBar = $TopBar/HBox/HealthContainer/HPBar
@onready var hp_label: Label = $TopBar/HBox/HealthContainer/HPLabel
@onready var timer_label: Label = $TopBar/HBox/TimerContainer/TimerLabel
@onready var level_label: Label = $TopBar/HBox/LevelContainer/LevelLabel
@onready var artifacts_container: HBoxContainer = $TopBar/HBox/ArtifactsContainer
@onready var xp_bar: ProgressBar = $XPBarContainer/XPBar
@onready var death_screen: Control = $DeathScreen
@onready var death_time_label: Label = $DeathScreen/CenterContainer/Panel/VBox/SurvivalTimeLabel
@onready var restart_button: Button = $DeathScreen/CenterContainer/Panel/VBox/RestartButton
@onready var level_up_panel: LevelUpPanel = $LevelUpPanel

var elapsed_time: float = 0.0
var is_game_active: bool = true

func _ready() -> void:
	if death_screen:
		death_screen.visible = false
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

func update_timer_display() -> void:
	if timer_label:
		var minutes = int(elapsed_time) / 60
		var seconds = int(elapsed_time) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func show_death_screen() -> void:
	is_game_active = false
	if death_screen:
		death_screen.visible = true
	if death_time_label:
		var minutes = int(elapsed_time) / 60
		var seconds = int(elapsed_time) % 60
		death_time_label.text = "Время выживания: %02d:%02d" % [minutes, seconds]

func _on_restart_pressed() -> void:
	restart_requested.emit()
