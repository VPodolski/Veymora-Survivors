class_name ArenaSelect
extends Control

const ArenaConfig = preload("res://scripts/arena/arena_config.gd")
const RunConfig = preload("res://scripts/game/run_config.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const MainMenuBackground = preload("res://scripts/ui/main_menu_background.gd")
const GameFlowController = preload("res://scripts/game/game_flow_controller.gd")

@onready var cards_container: HBoxContainer = $Center/VBox/CardsScroll/CardsContainer
@onready var details_title: Label = $Center/VBox/DetailsPanel/Margin/HBox/InfoVBox/TitleLabel
@onready var details_desc: Label = $Center/VBox/DetailsPanel/Margin/HBox/InfoVBox/DescLabel
@onready var details_stats: Label = $Center/VBox/DetailsPanel/Margin/HBox/StatsVBox/StatsLabel
@onready var start_run_btn: Button = $Center/VBox/BottomBar/StartRunButton
@onready var back_btn: Button = $Center/VBox/BottomBar/BackButton

var selected_arena_id: String = "forgotten_forest"
var card_nodes: Dictionary = {} # arena_id -> Button/Panel

func _ready() -> void:
	if start_run_btn:
		start_run_btn.pressed.connect(_on_start_run_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)

	_build_arena_cards()
	select_arena("forgotten_forest")

func _build_arena_cards() -> void:
	if not cards_container:
		return

	for child in cards_container.get_children():
		child.queue_free()
	card_nodes.clear()

	var catalog = ArenaConfig.get_catalog()
	var arena_order = ["forgotten_forest", "frost_necropolis", "ash_citadel", "void_rift"]

	for arena_id in arena_order:
		if not catalog.has(arena_id):
			continue
		var cfg: ArenaConfig = catalog[arena_id]
		var is_unlocked = SaveManager.is_arena_unlocked(arena_id) and cfg.is_unlocked

		var card = _create_card(cfg, is_unlocked)
		cards_container.add_child(card)
		card_nodes[arena_id] = card

func _create_card(cfg: ArenaConfig, is_unlocked: bool) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(250, 310)
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 310)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(panel)

	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Status Badge
	var status_lbl = Label.new()
	status_lbl.text = "[ ДОСТУПНО ]" if is_unlocked else "[ ЗАБЛОКИРОВАНО ]"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", cfg.border_color if is_unlocked else Color(0.6, 0.6, 0.6))
	vbox.add_child(status_lbl)

	# Rune Icon / Glyph
	var glyph = Label.new()
	glyph.text = _get_arena_glyph(cfg.id)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 34)
	glyph.add_theme_color_override("font_color", cfg.ambient_color if is_unlocked else Color(0.4, 0.4, 0.4))
	vbox.add_child(glyph)

	# Arena Title
	var title = Label.new()
	title.text = cfg.name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(1, 1, 1) if is_unlocked else Color(0.65, 0.65, 0.65))
	vbox.add_child(title)

	# Difficulty badge
	var diff = Label.new()
	diff.text = "Сложность: %s" % cfg.difficulty
	diff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff.add_theme_font_size_override("font_size", 12)
	diff.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95) if is_unlocked else Color(0.5, 0.5, 0.5))
	vbox.add_child(diff)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Short description / Features
	var desc = Label.new()
	desc.text = cfg.features[0] if not cfg.features.is_empty() else ""
	if cfg.features.size() > 1:
		desc.text += "\n• " + cfg.features[1]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8) if is_unlocked else Color(0.45, 0.45, 0.45))
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	# Unlock condition if locked
	if not is_unlocked:
		var lock_lbl = Label.new()
		lock_lbl.text = "🔒 " + cfg.unlock_condition
		lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock_lbl.add_theme_font_size_override("font_size", 10)
		lock_lbl.add_theme_color_override("font_color", Color(0.85, 0.6, 0.4))
		vbox.add_child(lock_lbl)

	btn.pressed.connect(func(): select_arena(cfg.id))
	return btn

func _get_arena_glyph(arena_id: String) -> String:
	match arena_id:
		"forgotten_forest": return "🌿"
		"frost_necropolis": return "❄"
		"ash_citadel": return "🔥"
		"void_rift": return "🔮"
		_: return "✦"

func select_arena(arena_id: String) -> void:
	selected_arena_id = arena_id
	var catalog = ArenaConfig.get_catalog()
	var cfg = catalog.get(arena_id, catalog["forgotten_forest"])
	var is_unlocked = SaveManager.is_arena_unlocked(arena_id) and cfg.is_unlocked

	# Update card highlights
	for id in card_nodes.keys():
		var btn = card_nodes[id] as Button
		if id == arena_id:
			btn.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			btn.modulate = Color(0.8, 0.8, 0.8, 0.85)

	# Update Details Panel
	if details_title:
		details_title.text = "%s [%s]" % [cfg.name, cfg.difficulty]
		details_title.add_theme_color_override("font_color", cfg.border_color)

	if details_desc:
		var txt = cfg.description + "\n\n"
		txt += "Особенности: " + ", ".join(cfg.features) + "\n"
		txt += "Угрозы: " + ", ".join(cfg.threats)
		if not is_unlocked:
			txt += "\n\n⚠ " + cfg.unlock_condition
		details_desc.text = txt

	# Update per-arena stats
	if details_stats:
		var save_data = SaveManager.load_data()
		var a_stats = save_data.get("arena_stats", {}).get(arena_id, {"runs": 0, "wins": 0, "best_time": 0.0, "kills": 0})
		var best_sec = int(a_stats.get("best_time", 0.0))
		var m = best_sec / 60
		var s = best_sec % 60
		details_stats.text = "Статистика арены:\n• Забегов: %d\n• Побед: %d\n• Рекорд: %02d:%02d\n• Уничтожено врагов: %d" % [
			int(a_stats.get("runs", 0)),
			int(a_stats.get("wins", 0)),
			m,
			s,
			int(a_stats.get("kills", 0))
		]

	# Enable / Disable start button
	if start_run_btn:
		start_run_btn.disabled = not is_unlocked
		if is_unlocked:
			start_run_btn.text = "⚔ ВОЙТИ В РАЗЛОМ"
			start_run_btn.modulate = Color(1, 1, 1, 1)
		else:
			start_run_btn.text = "🔒 ЗАБЛОКИРОВАНО"
			start_run_btn.modulate = Color(0.6, 0.6, 0.6, 0.8)

func _on_start_run_pressed() -> void:
	var catalog = ArenaConfig.get_catalog()
	var cfg = catalog.get(selected_arena_id, catalog["forgotten_forest"])
	if not (SaveManager.is_arena_unlocked(selected_arena_id) and cfg.is_unlocked):
		return

	var run_config = RunConfig.new(selected_arena_id)
	if GameFlowController.instance:
		GameFlowController.instance.start_run_with_config(run_config)
	else:
		get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")

func _on_back_pressed() -> void:
	if GameFlowController.instance:
		GameFlowController.instance.go_to_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
