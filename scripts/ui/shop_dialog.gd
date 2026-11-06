class_name ShopDialog
extends Control

signal closed
signal gold_updated(new_amount: int)

const SaveManager = preload("res://scripts/game/save_manager.gd")
const MetaShopConfig = preload("res://scripts/progression/meta_shop_config.gd")
const MetaShopManager = preload("res://scripts/progression/meta_shop_manager.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")

@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var gold_label: Label = $Panel/VBox/Header/GoldLabel
@onready var close_btn: Button = $Panel/VBox/Header/CloseButton
@onready var progress_label: Label = get_node_or_null("Panel/VBox/SubHeader/ProgressLabel")
@onready var tab_container: HBoxContainer = get_node_or_null("Panel/VBox/TabScroll/TabButtons")
@onready var content_container: VBoxContainer = $Panel/VBox/Scroll/Content

var current_category: String = "vitality"
var tab_buttons: Dictionary = {}
var _is_purchasing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if close_btn:
		close_btn.pressed.connect(close)

	if LocalizationManager.instance:
		LocalizationManager.instance.language_changed.connect(func(_l): refresh_shop())

	# Fallback if old tab_container path is used
	if not tab_container:
		tab_container = get_node_or_null("Panel/VBox/TabButtons")

	_setup_category_tabs()
	refresh_shop()

func _setup_category_tabs() -> void:
	if not tab_container:
		return

	for child in tab_container.get_children():
		child.queue_free()

	tab_buttons.clear()
	for cat_id in MetaShopConfig.CATEGORIES.keys():
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(170, 38)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(func(): _select_category(cat_id))
		tab_container.add_child(btn)
		tab_buttons[cat_id] = btn

	_update_tab_buttons_text()

func _update_tab_buttons_text() -> void:
	var loc = LocalizationManager.instance
	var lang = loc.current_language if loc else "ru"
	var shop_data = SaveManager.get_shop_upgrades()

	for cat_id in tab_buttons.keys():
		var btn: Button = tab_buttons[cat_id]
		var cat = MetaShopConfig.CATEGORIES[cat_id]
		var c_name = cat.get("name_en", cat.get("name", "")) if lang == "en" else cat.get("name", "")
		var purchased = MetaShopConfig.get_category_levels_purchased(cat_id, shop_data)
		var max_levels = MetaShopConfig.get_category_max_levels(cat_id)
		var is_maxed = (purchased >= max_levels and max_levels > 0)

		var badge = " [✓]" if is_maxed else ""
		btn.text = "%s %s (%d/%d)%s" % [cat.get("icon", "✦"), c_name, purchased, max_levels, badge]

func _select_category(cat_id: String) -> void:
	current_category = cat_id
	refresh_shop()

func open() -> void:
	visible = true
	refresh_shop()

func close() -> void:
	visible = false
	closed.emit()

func refresh_shop() -> void:
	_update_header()
	_update_tab_buttons_text()
	_update_tab_buttons_style()
	_populate_upgrades()

func _update_header() -> void:
	var loc = LocalizationManager.instance
	var lang = loc.current_language if loc else "ru"
	var current_gold = SaveManager.get_gold()
	var shop_upgrades = SaveManager.get_shop_upgrades()

	if title_label:
		title_label.text = loc.get_text("shop_title", "МАГАЗИН РАЗЛОМА: ПОСТОЯННЫЕ УЛУЧШЕНИЯ") if loc else "МАГАЗИН РАЗЛОМА: ПОСТОЯННЫЕ УЛУЧШЕНИЯ"

	if gold_label:
		gold_label.text = "🪙 %d" % current_gold

	if progress_label:
		var total_spent = MetaShopConfig.get_total_spent_for_upgrades(shop_upgrades)
		var total_levels = 0
		for u in shop_upgrades.values():
			total_levels += int(u)
		var max_levels = MetaShopConfig.get_total_available_levels()
		var maxed_count = MetaShopConfig.get_maxed_upgrades_count(shop_upgrades)
		var total_count = MetaShopConfig.UPGRADES.size()
		var pct = int(round(float(total_levels) / float(max(1, max_levels)) * 100.0))

		var fmt = loc.get_text("shop_progress_fmt", "Общий прогресс: %d / %d (%d%%) • Завершено: %d / %d") if loc else "Общий прогресс: %d / %d (%d%%) • Завершено: %d / %d"
		progress_label.text = fmt % [total_levels, max_levels, pct, maxed_count, total_count]

func _update_tab_buttons_style() -> void:
	var shop_data = SaveManager.get_shop_upgrades()
	for cat_id in tab_buttons.keys():
		var btn: Button = tab_buttons[cat_id]
		var is_active = (cat_id == current_category)
		var is_maxed = MetaShopConfig.is_category_maxed(cat_id, shop_data)

		if is_active:
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5, 1.0))
			btn.modulate = Color(1.2, 1.2, 1.2, 1.0)
		elif is_maxed:
			btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4, 0.9))
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.8))
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _populate_upgrades() -> void:
	if not content_container:
		return

	for child in content_container.get_children():
		content_container.remove_child(child)
		child.queue_free()

	var upgrades = MetaShopConfig.get_upgrades_by_category(current_category)
	var current_gold = SaveManager.get_gold()

	for u in upgrades:
		var card = _create_upgrade_card(u, current_gold)
		content_container.add_child(card)

func _create_upgrade_card(upgrade: Dictionary, current_gold: int) -> Control:
	var loc = LocalizationManager.instance
	var lang = loc.current_language if loc else "ru"

	var u_id = upgrade["id"]
	var current_lvl = MetaShopManager.get_upgrade_level(u_id)
	var max_lvl = int(upgrade.get("max_level", 5))
	var is_maxed = current_lvl >= max_lvl
	var next_cost = MetaShopConfig.get_upgrade_cost(u_id, current_lvl)
	var can_afford = not is_maxed and (current_gold >= next_cost)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.45, 0.65, 0.45) if not is_maxed else Color(0.85, 0.75, 0.3, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.theme_override_constants.separation = 16
	margin.add_child(hbox)

	# Left VBox: Info & Description
	var vbox_left = VBoxContainer.new()
	vbox_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_left.theme_override_constants.separation = 6
	hbox.add_child(vbox_left)

	# Header: Name + Level Pips
	var row_header = HBoxContainer.new()
	row_header.theme_override_constants.separation = 12
	vbox_left.add_child(row_header)

	var name_lbl = Label.new()
	var u_name = upgrade.get("name_en", upgrade["name"]) if lang == "en" else upgrade["name"]
	name_lbl.text = u_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45, 1.0) if not is_maxed else Color(1.0, 0.85, 0.25, 1.0))
	row_header.add_child(name_lbl)

	# Pips indicator: [■■□□□] Ур. 2/5
	var pips_str = ""
	for i in range(max_lvl):
		pips_str += "■" if i < current_lvl else "□"
	var pips_lbl = Label.new()
	var lvl_fmt = ("Lv. %d/%d" if lang == "en" else "Ур. %d/%d")
	pips_lbl.text = "[ %s ] %s" % [pips_str, lvl_fmt % [current_lvl, max_lvl]]
	pips_lbl.add_theme_font_size_override("font_size", 13)
	pips_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0) if not is_maxed else Color(1.0, 0.85, 0.3))
	row_header.add_child(pips_lbl)

	# Description
	var desc_lbl = Label.new()
	var u_desc = upgrade.get("description_en", upgrade["description"]) if lang == "en" else upgrade["description"]
	desc_lbl.text = u_desc
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 0.9))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_left.add_child(desc_lbl)

	# Effect Preview: Текущий эффект -> Следующий
	var eff_lbl = Label.new()
	if is_maxed:
		var max_eff = MetaShopConfig.get_effect_summary(u_id, current_lvl, lang)
		var eff_fmt = loc.get_text("shop_effect_max_fmt", "Эффект: %s (МАКСИМУМ)") if loc else "Эффект: %s (МАКСИМУМ)"
		eff_lbl.text = eff_fmt % max_eff
		eff_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6, 1.0))
	else:
		var none_str = loc.get_text("shop_effect_none", "Нет") if loc else "Нет"
		var cur_eff = MetaShopConfig.get_effect_summary(u_id, current_lvl, lang) if current_lvl > 0 else none_str
		var nxt_eff = MetaShopConfig.get_effect_summary(u_id, current_lvl + 1, lang)
		var eff_fmt = loc.get_text("shop_effect_fmt", "Текущий бонус: %s  ➜  Следующий: %s") if loc else "Текущий бонус: %s  ➜  Следующий: %s"
		eff_lbl.text = eff_fmt % [cur_eff, nxt_eff]
		eff_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 1.0))
	eff_lbl.add_theme_font_size_override("font_size", 12)
	vbox_left.add_child(eff_lbl)

	# Right VBox: Buy Action Button
	var vbox_right = VBoxContainer.new()
	vbox_right.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_right.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(vbox_right)

	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(150, 44)
	buy_btn.add_theme_font_size_override("font_size", 13)

	if is_maxed:
		buy_btn.text = loc.get_text("shop_btn_maxed", "ИЗУЧЕНО") if loc else "ИЗУЧЕНО"
		buy_btn.disabled = true
	else:
		var buy_fmt = loc.get_text("shop_buy_btn", "КУПИТЬ\n🪙 %d") if loc else "КУПИТЬ\n🪙 %d"
		buy_btn.text = buy_fmt % next_cost
		buy_btn.disabled = (not can_afford) or _is_purchasing
		if not can_afford:
			buy_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.5))
			buy_btn.tooltip_text = loc.get_text("shop_insufficient_gold", "Недостаточно золота") if loc else "Недостаточно золота"
		else:
			buy_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5, 1.0))
		buy_btn.pressed.connect(func(): _on_buy_pressed(u_id))

	vbox_right.add_child(buy_btn)
	return panel

func _on_buy_pressed(upgrade_id: String) -> void:
	if _is_purchasing:
		return
	_is_purchasing = true

	var success = MetaShopManager.purchase_upgrade(upgrade_id)
	if success:
		if AudioManager.instance:
			AudioManager.instance.play_ui_click()
		gold_updated.emit(SaveManager.get_gold())

	_is_purchasing = false
	refresh_shop()
