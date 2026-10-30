class_name ResultsScreen
extends Control

const RunStats = preload("res://scripts/game/run_stats.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const ArchiveDialog = preload("res://scripts/ui/archive_dialog.gd")
const ArchiveDialogScene = preload("res://scenes/ui/archive_dialog.tscn")
const MainMenuBackground = preload("res://scripts/ui/main_menu_background.gd")
const GameFlowController = preload("res://scripts/game/game_flow_controller.gd")

const SYNERGY_NAMES = {
	"resonance": "Чародейский резонанс",
	"frost_shatter": "Ледяные осколки",
	"lightning_chain": "Грозовая дуга",
	"steam_rift": "Паровой разлом",
	"thermal_conflagration": "Термодинамическая перегрузка",
	"unstable_explosion": "Взрыв нестабильности",
	"soul_harvest": "Жатва душ",
	"returning_pierce": "Возвратный разлом"
}

@onready var title_label: Label = $Center/VBox/TitleLabel
@onready var arena_label: Label = $Center/VBox/ArenaLabel
@onready var stats_grid: GridContainer = $Center/VBox/MetricsPanel/Margin/StatsGrid
@onready var synergy_headline_label: Label = $Center/VBox/SynergyPanel/Margin/VBox/HeadlineLabel
@onready var synergy_cards_container: HBoxContainer = $Center/VBox/SynergyPanel/Margin/VBox/Scroll/CardsContainer
@onready var retry_btn: Button = $Center/VBox/Actions/RetryButton
@onready var arena_btn: Button = $Center/VBox/Actions/ArenaButton
@onready var menu_btn: Button = $Center/VBox/Actions/MenuButton
@onready var codex_btn: Button = $Center/VBox/Actions/CodexButton

var stats: RunStats = null
var archive_dialog: ArchiveDialog = null

func _ready() -> void:
	if retry_btn:
		retry_btn.pressed.connect(_on_retry_pressed)
	if arena_btn:
		arena_btn.pressed.connect(_on_arena_pressed)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)
	if codex_btn:
		codex_btn.pressed.connect(_on_codex_pressed)

	if GameFlowController.instance and GameFlowController.instance.last_run_stats:
		stats = GameFlowController.instance.last_run_stats
	else:
		stats = RunStats.new()

	display_stats(stats)

func display_stats(run_data: RunStats) -> void:
	if not run_data:
		return

	# Title & outcome styling
	if title_label:
		if run_data.defeated_boss:
			title_label.text = "РАЗЛОМ ЗАКРЫТ! ПОБЕДА"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
		else:
			title_label.text = "МАГ ПОГИБ"
			title_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.3, 1.0))

	if arena_label:
		arena_label.text = "Пространство: %s" % run_data.arena_name

	# Metrics Grid
	_populate_metrics(run_data)

	# Synergies Panel
	_populate_synergies(run_data)

func _populate_metrics(data: RunStats) -> void:
	if not stats_grid:
		return

	for child in stats_grid.get_children():
		stats_grid.remove_child(child)
		child.queue_free()

	var sec = int(data.survival_time)
	var m = sec / 60
	var s = sec % 60
	var time_str = "%02d:%02d" % [m, s]

	var metrics = [
		{"label": "Время выживания:", "value": time_str, "color": Color(0.4, 0.8, 1.0)},
		{"label": "Достигнутый уровень:", "value": "Ур. %d" % data.level_reached, "color": Color(1.0, 0.9, 0.4)},
		{"label": "Уничтожено теней:", "value": "%d" % data.total_kills, "color": Color(0.9, 0.9, 0.9)},
		{"label": "Элитные монстры:", "value": "%d" % data.elite_kills, "color": Color(1.0, 0.6, 0.2)},
		{"label": "Повержено боссов:", "value": "%d" % data.boss_kills, "color": Color(1.0, 0.3, 0.5)},
		{"label": "Общий нанесённый урон:", "value": "%d" % int(data.damage_dealt), "color": Color(0.95, 0.7, 1.0)},
		{"label": "Собрано маны (XP):", "value": "%d XP" % int(data.experience_gained), "color": Color(0.4, 1.0, 0.7)},
		{"label": "Артефакты в сумке:", "value": "%d" % data.artifacts_collected, "color": Color(0.5, 0.85, 1.0)}
	]

	for item in metrics:
		var lbl = Label.new()
		lbl.text = item["label"]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
		stats_grid.add_child(lbl)

		var val = Label.new()
		val.text = item["value"]
		val.add_theme_font_size_override("font_size", 14)
		val.add_theme_color_override("font_color", item["color"])
		stats_grid.add_child(val)

func _populate_synergies(data: RunStats) -> void:
	if not synergy_headline_label or not synergy_cards_container:
		return

	for child in synergy_cards_container.get_children():
		synergy_cards_container.remove_child(child)
		child.queue_free()

	var most_effective = data.get_most_effective_synergy()
	var ratio = data.get_synergy_damage_ratio() * 100.0

	var headline = "✦ Вклад синергий в общий урон: %d%%" % int(ratio)
	if most_effective != "—":
		var display_best = SYNERGY_NAMES.get(most_effective, most_effective)
		headline += "   |   Ключевая синергия: %s" % display_best
	synergy_headline_label.text = headline

	if data.synergy_counts.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "В этом забеге магические реакции не были активированы.\nКомбинируйте школы магии для активации мощных стихийных резонансов!"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
		synergy_cards_container.add_child(empty_lbl)
		return

	for syn_id in data.synergy_counts.keys():
		var count = data.synergy_counts[syn_id]
		var dmg = data.synergy_damage.get(syn_id, 0.0)
		var display_name = SYNERGY_NAMES.get(syn_id, syn_id)
		var is_star = (syn_id == most_effective)

		var card = _create_synergy_card(display_name, count, dmg, is_star)
		synergy_cards_container.add_child(card)

func _create_synergy_card(title: String, count: int, dmg: float, is_star: bool) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(175, 95)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = ("★ " if is_star else "✦ ") + title
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if is_star else Color(0.4, 0.8, 1.0))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var count_lbl = Label.new()
	count_lbl.text = "Активаций: %d" % count
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	vbox.add_child(count_lbl)

	var dmg_lbl = Label.new()
	dmg_lbl.text = "Урон: %d" % int(dmg)
	dmg_lbl.add_theme_font_size_override("font_size", 11)
	dmg_lbl.add_theme_color_override("font_color", Color(0.9, 0.65, 1.0))
	vbox.add_child(dmg_lbl)

	return panel

func _on_retry_pressed() -> void:
	if GameFlowController.instance:
		GameFlowController.instance.restart_run()
	else:
		get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_arena_pressed() -> void:
	if GameFlowController.instance:
		GameFlowController.instance.open_arena_select()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/arena_select.tscn")

func _on_menu_pressed() -> void:
	if GameFlowController.instance:
		GameFlowController.instance.go_to_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_codex_pressed() -> void:
	if not archive_dialog:
		archive_dialog = ArchiveDialogScene.instantiate() as ArchiveDialog
		add_child(archive_dialog)
	archive_dialog.open_codex()
