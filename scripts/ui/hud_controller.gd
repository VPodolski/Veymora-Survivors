class_name HUDController
extends CanvasLayer

const RunStats = preload("res://scripts/game/run_stats.gd")
const ArchiveDialog = preload("res://scripts/ui/archive_dialog.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const ChestRewardPanel = preload("res://scripts/ui/chest_reward_panel.gd")
const GameFlowController = preload("res://scripts/game/game_flow_controller.gd")
const PauseManager = preload("res://scripts/game/pause_manager.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")
const YandexGamesBridge = preload("res://scripts/platform/yandex_games_bridge.gd")
const SecondChanceDialog = preload("res://scripts/ui/second_chance_dialog.gd")
const VirtualJoystick = preload("res://scripts/ui/virtual_joystick.gd")

signal restart_requested

@onready var hp_bar: ProgressBar = $TopBar/HBox/HealthContainer/HPBar
@onready var hp_label: Label = $TopBar/HBox/HealthContainer/HPHeader/HPLabel
@onready var heart_icon: Label = $TopBar/HBox/HealthContainer/HPHeader/HeartIcon
@onready var spells_container: HBoxContainer = $TopBar/HBox/SpellsContainer
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
@onready var pause_title: Label = get_node_or_null("PauseMenu/Center/Panel/VBox/Title")
@onready var resume_btn: Button = get_node_or_null("PauseMenu/Center/Panel/VBox/ResumeButton")
@onready var pause_archive_btn: Button = get_node_or_null("PauseMenu/Center/Panel/VBox/PauseArchiveButton")
@onready var pause_restart_btn: Button = get_node_or_null("PauseMenu/Center/Panel/VBox/PauseRestartButton")
@onready var pause_menu_btn: Button = get_node_or_null("PauseMenu/Center/Panel/VBox/PauseMenuButton")
@onready var volume_slider: HSlider = get_node_or_null("PauseMenu/Center/Panel/VBox/AudioSettings/VolumeSlider")
@onready var sfx_volume_slider: HSlider = get_node_or_null("PauseMenu/Center/Panel/VBox/AudioSettings/SfxVolumeSlider")
@onready var fx_intensity_btn: Button = get_node_or_null("PauseMenu/Center/Panel/VBox/FxIntensityButton")

# Mobile & Platform Nodes
@onready var mobile_pause_btn: Button = get_node_or_null("TopBar/HBox/MobilePauseButton")
@onready var virtual_joystick: VirtualJoystick = get_node_or_null("VirtualJoystick")
@onready var second_chance_dialog: SecondChanceDialog = get_node_or_null("SecondChanceDialog")
@onready var orientation_warning: Control = get_node_or_null("OrientationWarning")

# Level Up, Chest Reward & Archive Modals
@onready var level_up_panel: LevelUpPanel = $LevelUpPanel
@onready var chest_reward_panel: ChestRewardPanel = get_node_or_null("ChestRewardPanel")
@onready var archive_dialog: ArchiveDialog = get_node_or_null("ArchiveDialog")
@onready var toast_label: Label = $ToastLabel

var elapsed_time: float = 0.0
var is_game_active: bool = true
var total_kills: int = 0
var current_level: int = 1
var run_stats: RunStats = RunStats.new()

var has_used_second_chance: bool = false
var bound_player: PlayerController = null
var active_synergies_this_run: Dictionary = {}

var pending_chest_players: Array[PlayerController] = []
var pending_level_up_players: Array[Dictionary] = []

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
	if chest_reward_panel:
		chest_reward_panel.visible = false
		chest_reward_panel.reward_selected.connect(_on_chest_reward_closed)
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

	var is_touch = DisplayServer.is_touchscreen_available()
	var is_mob = OS.has_feature("mobile") or (YandexGamesBridge.instance and YandexGamesBridge.instance.is_mobile())
	var show_touch_controls = is_mob or is_touch

	if mobile_pause_btn:
		mobile_pause_btn.pressed.connect(toggle_pause)
		mobile_pause_btn.visible = show_touch_controls

	if virtual_joystick:
		virtual_joystick.visible = show_touch_controls

	if second_chance_dialog:
		second_chance_dialog.revived.connect(_on_second_chance_revived)
		second_chance_dialog.declined.connect(_on_second_chance_declined)

	if volume_slider:
		if AudioManager.instance:
			volume_slider.value = AudioManager.instance.master_volume
		volume_slider.value_changed.connect(_on_volume_changed)

	if sfx_volume_slider:
		if AudioManager.instance:
			sfx_volume_slider.value = AudioManager.instance.sfx_volume
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)

	if fx_intensity_btn:
		_update_fx_button_label()
		fx_intensity_btn.pressed.connect(_on_fx_intensity_toggle)

	if level_up_panel:
		level_up_panel.upgrade_picked.connect(_on_level_up_picked)
		level_up_panel.panel_closed.connect(_on_level_up_closed)

	if LocalizationManager.instance:
		LocalizationManager.instance.language_changed.connect(func(_l): _update_localized_ui())
	_update_localized_ui()

	if not bool(SaveManager.get_setting("tutorial_completed", false)):
		call_deferred("_show_starter_tutorial")

func _show_starter_tutorial() -> void:
	SaveManager.set_setting("tutorial_completed", true)
	if toast_label:
		var loc = LocalizationManager.instance
		toast_label.text = loc.get_text("starter_tutorial", "✦ Движение: [W, A, S, D] или Джойстик • Заклинания срабатывают автоматически") if loc else "✦ Движение: [W, A, S, D] • Атака: заклинания применяются автоматически"
		var tween = create_tween()
		tween.tween_property(toast_label, "modulate:a", 1.0, 0.3)
		tween.tween_interval(4.5)
		tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)

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
		# If level up or chest modal is open, don't open pause menu
		if level_up_panel and level_up_panel.is_panel_open:
			return
		if chest_reward_panel and chest_reward_panel.is_panel_open:
			return
		if is_game_active:
			toggle_pause()
			return

	if not is_game_active:
		if event.is_action_pressed("restart") or (event is InputEventKey and event.pressed and event.keycode == KEY_R):
			_on_restart_pressed()

func toggle_pause() -> void:
	if PauseManager.instance:
		if PauseManager.instance.has_pause_reason(PauseManager.REASON_USER):
			PauseManager.instance.remove_pause_reason(PauseManager.REASON_USER)
			if pause_menu:
				pause_menu.visible = false
		else:
			PauseManager.instance.add_pause_reason(PauseManager.REASON_USER)
			if pause_menu:
				pause_menu.visible = true
	else:
		var next_pause = not get_tree().paused
		get_tree().paused = next_pause
		if pause_menu:
			pause_menu.visible = next_pause

func _open_archive() -> void:
	if archive_dialog:
		archive_dialog.open_codex()

func _on_pause_restart_pressed() -> void:
	if PauseManager.instance:
		PauseManager.instance.clear_reasons(false)
	else:
		get_tree().paused = false
	_on_restart_pressed()

func _go_to_menu() -> void:
	if PauseManager.instance:
		PauseManager.instance.clear_reasons(false)
	else:
		get_tree().paused = false
	if GameFlowController.instance:
		GameFlowController.instance.go_to_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_volume_changed(val: float) -> void:
	if AudioManager.instance:
		AudioManager.instance.set_master_volume(val)
	SaveManager.set_setting("master_volume", val)

func _on_sfx_volume_changed(val: float) -> void:
	if AudioManager.instance:
		AudioManager.instance.set_sfx_volume(val)
	SaveManager.set_setting("sfx_volume", val)

func _update_fx_button_label() -> void:
	if fx_intensity_btn:
		var loc = LocalizationManager.instance
		var is_standard = CombatEffects.fx_intensity == "standard"
		if loc:
			fx_intensity_btn.text = "%s %s" % [
				loc.get_text("settings_fx", "Визуальные эффекты:"),
				loc.get_text("settings_fx_full", "Стандартные") if is_standard else loc.get_text("settings_fx_reduced", "Сниженные")
			]
		else:
			fx_intensity_btn.text = "Эффекты: Стандартные" if is_standard else "Эффекты: Сниженные"

func _on_fx_intensity_toggle() -> void:
	var next_mode = "reduced" if CombatEffects.fx_intensity == "standard" else "standard"
	CombatEffects.set_fx_intensity(next_mode)
	SaveManager.set_setting("fx_intensity", next_mode)
	_update_fx_button_label()

func _update_localized_ui() -> void:
	var loc = LocalizationManager.instance
	if not loc:
		return
	if pause_title:
		pause_title.text = loc.get_text("pause_title", "ПАУЗА")
	if resume_btn:
		resume_btn.text = loc.get_text("pause_resume", "Продолжить")
	if pause_archive_btn:
		pause_archive_btn.text = loc.get_text("pause_archive", "📖 Кодекс и Атлас")
	if pause_restart_btn:
		pause_restart_btn.text = loc.get_text("pause_restart", "Начать заново")
	if pause_menu_btn:
		pause_menu_btn.text = loc.get_text("pause_menu", "В главное меню")
	if restart_button:
		restart_button.text = loc.get_text("btn_retry", "Повторить забег")
	if summary_archive_btn:
		summary_archive_btn.text = loc.get_text("btn_codex", "Кодекс и Атлас")
	if summary_menu_btn:
		summary_menu_btn.text = loc.get_text("btn_menu", "В главное меню")

# Unified Modal Coordination: Level Up & Chest Rewards
func request_chest_reward(player: PlayerController) -> void:
	if not is_game_active or not player:
		return

	if level_up_panel and level_up_panel.is_panel_open:
		pending_chest_players.append(player)
		return

	if chest_reward_panel and chest_reward_panel.is_panel_open:
		pending_chest_players.append(player)
		return

	if chest_reward_panel:
		if PauseManager.instance:
			PauseManager.instance.add_pause_reason(PauseManager.REASON_MODAL)
		chest_reward_panel.open_panel(player)

func _on_chest_reward_closed(_opt: Dictionary) -> void:
	# Priority 1: Check if another chest is queued
	if pending_chest_players.size() > 0:
		var next_player = pending_chest_players.pop_front()
		if chest_reward_panel and is_instance_valid(next_player) and next_player.is_alive:
			chest_reward_panel.open_panel(next_player)
			return

	# Priority 2: Check if a level up was queued while chest was open
	if pending_level_up_players.size() > 0:
		var next_req = pending_level_up_players.pop_front()
		var p = next_req.get("player")
		var lvl = next_req.get("level", 1)
		if level_up_panel and is_instance_valid(p) and p.is_alive:
			level_up_panel.open_panel(p, lvl)
			return

	# If no more chests or level-ups pending
	if level_up_panel and level_up_panel.is_panel_open:
		return

	if PauseManager.instance:
		PauseManager.instance.remove_pause_reason(PauseManager.REASON_MODAL)
	var tree = get_tree()
	if tree and (PauseManager.instance == null or not PauseManager.instance.is_paused()):
		tree.paused = false

func _on_level_up_picked(_opt: RewardGenerator.UpgradeOption) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].get("ability_controller"):
		update_active_spells(players[0].ability_controller)

func _on_level_up_closed() -> void:
	# Priority 1: Check pending chests
	if pending_chest_players.size() > 0:
		var next_player = pending_chest_players.pop_front()
		if chest_reward_panel and is_instance_valid(next_player) and next_player.is_alive:
			chest_reward_panel.open_panel(next_player)
			return

	# Priority 2: Check pending level ups
	if pending_level_up_players.size() > 0:
		var next_req = pending_level_up_players.pop_front()
		var p = next_req.get("player")
		var lvl = next_req.get("level", 1)
		if level_up_panel and is_instance_valid(p) and p.is_alive:
			level_up_panel.open_panel(p, lvl)
			return

	if PauseManager.instance:
		PauseManager.instance.remove_pause_reason(PauseManager.REASON_MODAL)
	var tree = get_tree()
	if tree and (PauseManager.instance == null or not PauseManager.instance.is_paused()):
		tree.paused = false

func update_health(current_hp: float, max_hp: float) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
	if hp_label:
		hp_label.text = "%d / %d" % [int(ceil(current_hp)), int(ceil(max_hp))]

		# Low HP warning feedback with pulse
		if current_hp <= max_hp * 0.25:
			hp_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.3, 1.0))
			if heart_icon:
				heart_icon.add_theme_color_override("font_color", Color(1.0, 0.15, 0.2, 1.0))
		else:
			hp_label.add_theme_color_override("font_color", Color.WHITE)
			if heart_icon:
				heart_icon.add_theme_color_override("font_color", Color(1.0, 0.3, 0.35, 1.0))

func update_experience(current_xp: int, required_xp: int) -> void:
	if xp_bar:
		xp_bar.max_value = required_xp
		xp_bar.value = current_xp

func update_level(new_level: int) -> void:
	current_level = new_level
	if run_stats:
		run_stats.level_reached = new_level
	if level_label:
		var loc = LocalizationManager.instance
		var pref = loc.get_text("lvl_prefix", "УР. %d") if loc else "УР. %d"
		level_label.text = pref % new_level

func show_level_up(player: PlayerController, new_level: int) -> void:
	update_level(new_level)
	if AudioManager.instance:
		AudioManager.instance.play_level_up()
	if chest_reward_panel and chest_reward_panel.is_panel_open:
		pending_level_up_players.append({"player": player, "level": new_level})
		return
	if level_up_panel:
		if PauseManager.instance:
			PauseManager.instance.add_pause_reason(PauseManager.REASON_MODAL)
		level_up_panel.open_panel(player, new_level)

func update_active_spells(ability_controller: AbilityController) -> void:
	if not spells_container or not ability_controller:
		return

	for child in spells_container.get_children():
		child.queue_free()

	for ability in ability_controller.get_active_abilities():
		var chip = PanelContainer.new()
		chip.custom_minimum_size = Vector2(28, 28)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.12, 0.18, 0.9)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4

		var is_evo = ability.get("is_evolved") == true
		style.border_color = Color(1.0, 0.85, 0.3, 1.0) if is_evo else Color(0.3, 0.7, 1.0, 0.8)
		chip.add_theme_stylebox_override("panel", style)

		var lbl = Label.new()
		var evo_mark = "★" if is_evo else ""
		lbl.text = "%d%s" % [ability.current_level, evo_mark]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4) if is_evo else Color(0.8, 0.9, 1.0))
		chip.add_child(lbl)
		var loc = LocalizationManager.instance
		var lvl_fmt = loc.get_text("lvl_format", "Ур. %d") if loc else "Ур. %d"
		chip.tooltip_text = "%s (%s)" % [ability.ability_name, lvl_fmt % ability.current_level]
		spells_container.add_child(chip)

func add_artifact_icon(item: ItemDefinition) -> void:
	if not artifacts_container:
		return

	var icon_panel = PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(30, 30)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(item.icon_color.r * 0.25, item.icon_color.g * 0.25, item.icon_color.b * 0.25, 0.92)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = item.icon_color
	icon_panel.add_theme_stylebox_override("panel", style)
	icon_panel.tooltip_text = "%s: %s" % [item.name, item.description]

	var glyph_label = Label.new()
	glyph_label.text = _get_artifact_glyph(item.icon_symbol)
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph_label.add_theme_font_size_override("font_size", 15)
	glyph_label.add_theme_color_override("font_color", item.icon_color)
	icon_panel.add_child(glyph_label)

	artifacts_container.add_child(icon_panel)

	# Pop-in scale bounce animation
	icon_panel.scale = Vector2(1.35, 1.35)
	var tween = create_tween()
	tween.tween_property(icon_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _get_artifact_glyph(symbol: String) -> String:
	match symbol:
		"hourglass": return "⏳"
		"heart": return "❤"
		"compass": return "🧭"
		"ice": return "❄"
		"feather": return "🪶"
		"lightning": return "⚡"
		"wing": return "🪽"
		"book": return "📖"
		_: return "✦"

func show_chest_notification(reward_name: String) -> void:
	if AudioManager.instance:
		AudioManager.instance.play_chest()
	if toast_label:
		var loc = LocalizationManager.instance
		var toast_fmt = loc.get_text("toast_acquired", "Получено: [%s]") if loc else "Получено: [%s]"
		toast_label.text = toast_fmt % reward_name
		var tween = create_tween()
		tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
		tween.tween_interval(2.2)
		tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)

func notify_synergy(synergy_name: String) -> void:
	if not active_synergies_this_run.has(synergy_name):
		active_synergies_this_run[synergy_name] = true
		if toast_label:
			var loc = LocalizationManager.instance
			var syn_key = "syn_" + synergy_name + "_name"
			var syn_name = loc.get_text(syn_key, synergy_name) if loc else synergy_name
			var toast_fmt = loc.get_text("toast_synergy_unlocked", "✦ Открыта синергия: [%s]!") if loc else "✦ Открыта синергия: [%s]!"
			toast_label.text = toast_fmt % syn_name
			toast_label.add_theme_color_override("font_color", Color(0.85, 0.5, 1.0, 1.0))
			var tween = create_tween()
			tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
			tween.tween_interval(2.5)
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
	if run_stats:
		run_stats.survival_time = elapsed_time
		run_stats.total_kills = total_kills
		run_stats.level_reached = current_level
		run_stats.defeated_boss = true
	var saved_data = SaveManager.record_run(elapsed_time, total_kills, true, run_stats.to_dictionary() if run_stats else {})
	if summary_screen:
		summary_screen.visible = true
	if summary_title:
		summary_title.text = "ПОБЕДА: РАЗЛОМ ЗАКРЫТ!"
		summary_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	populate_summary_stats(saved_data)
	if GameFlowController.instance:
		GameFlowController.instance.open_results_screen(run_stats)

func trigger_player_death_flow(player: PlayerController = null, force_second_chance: bool = false) -> void:
	bound_player = player
	var is_web = OS.has_feature("web")
	if not has_used_second_chance and second_chance_dialog != null and (force_second_chance or is_web):
		has_used_second_chance = true
		second_chance_dialog.open_dialog()
	else:
		show_death_screen()

func _on_second_chance_revived() -> void:
	if bound_player and is_instance_valid(bound_player):
		bound_player.revive_second_chance(0.5)
		is_game_active = true

func _on_second_chance_declined() -> void:
	show_death_screen()

func show_death_screen() -> void:
	is_game_active = false
	if run_stats:
		run_stats.survival_time = elapsed_time
		run_stats.total_kills = total_kills
		run_stats.level_reached = current_level
		run_stats.defeated_boss = false
	var saved_data = SaveManager.record_run(elapsed_time, total_kills, false, run_stats.to_dictionary() if run_stats else {})
	if summary_screen:
		summary_screen.visible = true
	if summary_title:
		summary_title.text = "МАГ ПОГИБ"
		summary_title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.25, 1.0))
	populate_summary_stats(saved_data)
	if GameFlowController.instance:
		GameFlowController.instance.open_results_screen(run_stats)

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
