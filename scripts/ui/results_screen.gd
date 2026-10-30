class_name ResultsScreen
extends Control

const RunStats = preload("res://scripts/game/run_stats.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const ArchiveDialog = preload("res://scripts/ui/archive_dialog.gd")
const ArchiveDialogScene = preload("res://scenes/ui/archive_dialog.tscn")
const MainMenuBackground = preload("res://scripts/ui/main_menu_background.gd")
const GameFlowController = preload("res://scripts/game/game_flow_controller.gd")
const YandexGamesBridge = preload("res://scripts/platform/yandex_games_bridge.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")

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

	var loc = LocalizationManager.instance

	# Title & outcome styling
	if title_label:
		if run_data.defeated_boss:
			title_label.text = loc.get_text("results_victory", "РАЗЛОМ ЗАКРЫТ! ПОБЕДА") if loc else "РАЗЛОМ ЗАКРЫТ! ПОБЕДА"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
		else:
			title_label.text = loc.get_text("results_defeat", "МАГ ПОГИБ") if loc else "МАГ ПОГИБ"
			title_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.3, 1.0))

	if arena_label:
		var arena_fmt = loc.get_text("results_space", "Пространство: %s") if loc else "Пространство: %s"
		arena_label.text = arena_fmt % run_data.arena_name

	if retry_btn:
		retry_btn.text = loc.get_text("btn_retry", "Повторить забег") if loc else "Повторить забег"
	if arena_btn:
		arena_btn.text = loc.get_text("menu_start", "Выбор арены") if loc else "Выбор арены"
	if menu_btn:
		menu_btn.text = loc.get_text("btn_menu", "Главное меню") if loc else "Главное меню"
	if codex_btn:
		codex_btn.text = loc.get_text("btn_codex", "Кодекс и Атлас") if loc else "Кодекс и Атлас"

	# Submit run score to Yandex Games leaderboard
	var final_score = int(run_data.survival_time * 10.0 + run_data.total_kills * 5.0)
	if YandexGamesBridge.instance:
		YandexGamesBridge.instance.submit_score(final_score)

	# Metrics Grid
	_populate_metrics(run_data)

	# Synergies Panel
	_populate_synergies(run_data)

func get_synergy_name(syn_id: String) -> String:
	var loc = LocalizationManager.instance
	if loc:
		var key = "syn_" + syn_id + "_name"
		var val = loc.get_text(key, "")
		if not val.is_empty():
			return val
	return syn_id

func _populate_metrics(data: RunStats) -> void:
	if not stats_grid:
		return

	var loc = LocalizationManager.instance
	for child in stats_grid.get_children():
		stats_grid.remove_child(child)
		child.queue_free()

	var sec = int(data.survival_time)
	var m = sec / 60
	var s = sec % 60
	var time_str = "%02d:%02d" % [m, s]
	var lvl_fmt = loc.get_text("lvl_format", "Ур. %d") if loc else "Ур. %d"

	var metrics = [
		{"label": loc.get_text("metric_time", "Время выживания:") if loc else "Время выживания:", "value": time_str, "color": Color(0.4, 0.8, 1.0)},
		{"label": loc.get_text("metric_lvl", "Достигнутый уровень:") if loc else "Достигнутый уровень:", "value": lvl_fmt % data.level_reached, "color": Color(1.0, 0.9, 0.4)},
		{"label": loc.get_text("metric_kills", "Уничтожено теней:") if loc else "Уничтожено теней:", "value": "%d" % data.total_kills, "color": Color(0.9, 0.9, 0.9)},
		{"label": loc.get_text("metric_elites", "Элитные монстры:") if loc else "Элитные монстры:", "value": "%d" % data.elite_kills, "color": Color(1.0, 0.6, 0.2)},
		{"label": loc.get_text("metric_bosses", "Повержено боссов:") if loc else "Повержено боссов:", "value": "%d" % data.boss_kills, "color": Color(1.0, 0.3, 0.5)},
		{"label": loc.get_text("metric_damage", "Общий нанесённый урон:") if loc else "Общий нанесённый урон:", "value": "%d" % int(data.damage_dealt), "color": Color(0.95, 0.7, 1.0)},
		{"label": loc.get_text("metric_xp", "Собрано маны (XP):") if loc else "Собрано маны (XP):", "value": "%d XP" % int(data.experience_gained), "color": Color(0.4, 1.0, 0.7)},
		{"label": loc.get_text("metric_artifacts", "Артефакты в сумке:") if loc else "Артефакты в сумке:", "value": "%d" % data.artifacts_collected, "color": Color(0.5, 0.85, 1.0)}
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

	var loc = LocalizationManager.instance
	for child in synergy_cards_container.get_children():
		synergy_cards_container.remove_child(child)
		child.queue_free()

	var most_effective = data.get_most_effective_synergy()
	var ratio = data.get_synergy_damage_ratio() * 100.0

	var headline_fmt = loc.get_text("synergy_share", "✦ Вклад синергий в общий урон: %d%%") if loc else "✦ Вклад синергий в общий урон: %d%%"
	var headline = headline_fmt % int(ratio)
	if most_effective != "—":
		var star_fmt = loc.get_text("synergy_star", "   |   Ключевая синергия: %s") if loc else "   |   Ключевая синергия: %s"
		var display_best = get_synergy_name(most_effective)
		headline += star_fmt % display_best
	synergy_headline_label.text = headline

	if data.synergy_counts.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = loc.get_text("synergy_empty", "В этом забеге магические реакции не были активированы.\nКомбинируйте школы магии для активации мощных стихийных резонансов!") if loc else "В этом забеге магические реакции не были активированы.\nКомбинируйте школы магии для активации мощных стихийных резонансов!"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
		synergy_cards_container.add_child(empty_lbl)
		return

	for syn_id in data.synergy_counts.keys():
		var count = data.synergy_counts[syn_id]
		var dmg = data.synergy_damage.get(syn_id, 0.0)
		var display_name = get_synergy_name(syn_id)
		var is_star = (syn_id == most_effective)

		var card = _create_synergy_card(display_name, count, dmg, is_star)
		synergy_cards_container.add_child(card)

func _create_synergy_card(title: String, count: int, dmg: float, is_star: bool) -> Control:
	var loc = LocalizationManager.instance
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
	var act_fmt = loc.get_text("synergy_activations", "Активаций: %d") if loc else "Активаций: %d"
	count_lbl.text = act_fmt % count
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	vbox.add_child(count_lbl)

	var dmg_lbl = Label.new()
	var dmg_fmt = loc.get_text("synergy_dmg", "Урон: %d") if loc else "Урон: %d"
	dmg_lbl.text = dmg_fmt % int(dmg)
	dmg_lbl.add_theme_font_size_override("font_size", 11)
	dmg_lbl.add_theme_color_override("font_color", Color(0.9, 0.65, 1.0))
	vbox.add_child(dmg_lbl)

	return panel

var _is_navigating: bool = false

func _navigate_with_ad(action: Callable) -> void:
	if _is_navigating:
		return
	_is_navigating = true

	if retry_btn:
		retry_btn.disabled = true
	if arena_btn:
		arena_btn.disabled = true
	if menu_btn:
		menu_btn.disabled = true
	if codex_btn:
		codex_btn.disabled = true

	var bridge = YandexGamesBridge.instance
	if bridge and bridge.has_method("can_show_interstitial") and bridge.can_show_interstitial():
		bridge.show_interstitial(func(_was_shown): action.call())
	else:
		action.call()

func _on_retry_pressed() -> void:
	_navigate_with_ad(func():
		if GameFlowController.instance:
			GameFlowController.instance.restart_run()
		else:
			get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	)

func _on_arena_pressed() -> void:
	_navigate_with_ad(func():
		if GameFlowController.instance:
			GameFlowController.instance.open_arena_select()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/arena_select.tscn")
	)

func _on_menu_pressed() -> void:
	_navigate_with_ad(func():
		if GameFlowController.instance:
			GameFlowController.instance.go_to_main_menu()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)

func _on_codex_pressed() -> void:
	if not archive_dialog:
		archive_dialog = ArchiveDialogScene.instantiate() as ArchiveDialog
		add_child(archive_dialog)
	archive_dialog.open_codex()
