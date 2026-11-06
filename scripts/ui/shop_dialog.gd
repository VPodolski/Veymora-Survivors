class_name ShopDialog
extends Control

signal closed
signal gold_updated(new_amount: int)

const SaveManager = preload("res://scripts/game/save_manager.gd")
const MetaShopConfig = preload("res://scripts/progression/meta_shop_config.gd")
const MetaShopManager = preload("res://scripts/progression/meta_shop_manager.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")

@onready var gold_label: Label = $Panel/VBox/Header/GoldLabel
@onready var close_btn: Button = $Panel/VBox/Header/CloseButton
@onready var tab_container: HBoxContainer = $Panel/VBox/TabButtons
@onready var content_container: VBoxContainer = $Panel/VBox/Scroll/Content

var current_category: String = "vitality"
var tab_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if close_btn:
		close_btn.pressed.connect(close)

	_setup_category_tabs()
	refresh_shop()

func _setup_category_tabs() -> void:
	if not tab_container:
		return

	for child in tab_container.get_children():
		child.queue_free()

	tab_buttons.clear()
	for cat_id in MetaShopConfig.CATEGORIES.keys():
		var cat = MetaShopConfig.CATEGORIES[cat_id]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(160, 38)
		btn.text = "%s %s" % [cat.get("icon", "✦"), cat.get("name", "")]
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(func(): _select_category(cat_id))
		tab_container.add_child(btn)
		tab_buttons[cat_id] = btn

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
	_update_gold_display()
	_update_tab_buttons_style()
	_populate_upgrades()

func _update_gold_display() -> void:
	if gold_label:
		var current_gold = SaveManager.get_gold()
		gold_label.text = "🪙 %d" % current_gold

func _update_tab_buttons_style() -> void:
	for cat_id in tab_buttons.keys():
		var btn: Button = tab_buttons[cat_id]
		var is_active = (cat_id == current_category)
		var cat_data = MetaShopConfig.CATEGORIES.get(cat_id, {})
		var cat_col = cat_data.get("color", Color.WHITE)

		if is_active:
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1.0))
			btn.modulate = Color(1.2, 1.2, 1.2, 1.0)
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
	name_lbl.text = upgrade.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45, 1.0) if not is_maxed else Color(1.0, 0.85, 0.25, 1.0))
	row_header.add_child(name_lbl)

	# Pips indicator: [■■□□□] Ур. 2/5
	var pips_str = ""
	for i in range(max_lvl):
		pips_str += "■" if i < current_lvl else "□"
	var pips_lbl = Label.new()
	pips_lbl.text = "[ %s ] Ур. %d/%d" % [pips_str, current_lvl, max_lvl]
	pips_lbl.add_theme_font_size_override("font_size", 14)
	pips_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0) if not is_maxed else Color(1.0, 0.85, 0.3))
	row_header.add_child(pips_lbl)

	# Description
	var desc_lbl = Label.new()
	desc_lbl.text = upgrade.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 0.9))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_left.add_child(desc_lbl)

	# Effect Preview: Текущий эффект -> Следующий
	var eff_lbl = Label.new()
	if is_maxed:
		eff_lbl.text = "Эффект: %s (МАКСИМУМ)" % MetaShopConfig.get_effect_summary(u_id, current_lvl)
		eff_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6, 1.0))
	else:
		var cur_eff = MetaShopConfig.get_effect_summary(u_id, current_lvl) if current_lvl > 0 else "Нет"
		var nxt_eff = MetaShopConfig.get_effect_summary(u_id, current_lvl + 1)
		eff_lbl.text = "Текущий бонус: %s  ➜  Следующий: %s" % [cur_eff, nxt_eff]
		eff_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 1.0))
	eff_lbl.add_theme_font_size_override("font_size", 12)
	vbox_left.add_child(eff_lbl)

	# Right VBox: Buy Action Button
	var vbox_right = VBoxContainer.new()
	vbox_right.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_right.custom_minimum_size = Vector2(170, 0)
	hbox.add_child(vbox_right)

	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(160, 44)
	buy_btn.add_theme_font_size_override("font_size", 14)

	if is_maxed:
		buy_btn.text = "ИЗУЧЕНО"
		buy_btn.disabled = true
	else:
		buy_btn.text = "КУПИТЬ\n🪙 %d" % next_cost
		buy_btn.disabled = not can_afford
		if not can_afford:
			buy_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.5))
		else:
			buy_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5, 1.0))
		buy_btn.pressed.connect(func(): _on_buy_pressed(u_id))

	vbox_right.add_child(buy_btn)
	return panel

func _on_buy_pressed(upgrade_id: String) -> void:
	if MetaShopManager.purchase_upgrade(upgrade_id):
		if AudioManager.instance:
			AudioManager.instance.play_ui_click()
		refresh_shop()
		gold_updated.emit(SaveManager.get_gold())
