class_name ChestRewardPanel
extends Control

signal reward_selected(option: Dictionary)

const MetaArchive = preload("res://scripts/game/meta_archive.gd")
const InventoryStateScript = preload("res://scripts/items/inventory_state.gd")

@onready var title_label: Label = $Center/VBox/TitleLabel
@onready var subtitle_label: Label = $Center/VBox/SubtitleLabel
@onready var cards_container: HBoxContainer = $Center/VBox/CardsContainer

var current_player: PlayerController = null
var current_options: Array[Dictionary] = []
var is_panel_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open_panel(player: PlayerController) -> void:
	if not player or not is_instance_valid(player):
		return

	current_player = player
	is_panel_open = true
	_generate_chest_options()
	_populate_cards()
	visible = true

	var tree = get_tree()
	if tree:
		tree.paused = true

func _generate_chest_options() -> void:
	current_options.clear()
	if not current_player or not current_player.inventory:
		return

	var inv = current_player.inventory
	var unowned = inv.get_unowned_artifacts()

	# If inventory is not full and there are unowned artifacts
	if not inv.is_full() and not unowned.is_empty():
		title_label.text = "СОКРОВИЩНИЦА РАЗЛОМА"
		subtitle_label.text = "Выберите одну древнюю реликвию (Слотов: %d/%d):" % [inv.artifacts.size(), inv.max_artifacts]

		# Shuffle and pick up to 3 distinct items
		unowned.shuffle()
		var count = min(3, unowned.size())
		for i in range(count):
			var art_id = unowned[i]
			var data = InventoryStateScript.ALL_ARTIFACTS[art_id]
			current_options.append({
				"id": art_id,
				"type": "artifact",
				"title": data["name"],
				"desc": data["desc"],
				"rarity": data.get("rarity", "РЕДКОЕ"),
				"color": data["color"],
				"icon_symbol": data.get("icon_symbol", "gem")
			})
	else:
		# Alternative rewards when inventory is full or all artifacts unlocked
		if inv.is_full():
			title_label.text = "ИНВЕНТАРЬ РЕЛИКВИЙ ПОЛОН (%d/%d)" % [inv.artifacts.size(), inv.max_artifacts]
			subtitle_label.text = "Выберите альтернативное благословение Разлома:"
		else:
			title_label.text = "ВСЕ АРТЕФАКТЫ СОБРАНЫ!"
			subtitle_label.text = "Разлом дарует высшую чародейскую награду:"

		current_options.append({
			"id": "alt_heal",
			"type": "alternative",
			"title": "Эликсир жизни",
			"desc": "+15 к максимальному здоровью и мгновенное исцеление на 40 HP.",
			"rarity": "БЛАГОСЛОВЕНИЕ",
			"color": Color(0.3, 0.95, 0.5, 1.0),
			"icon_symbol": "heart"
		})
		current_options.append({
			"id": "alt_xp",
			"type": "alternative",
			"title": "Фолиант озарения",
			"desc": "Мгновенно дарует +250 концентрированных очков опыта Разлома.",
			"rarity": "БЛАГОСЛОВЕНИЕ",
			"color": Color(0.3, 0.75, 1.0, 1.0),
			"icon_symbol": "book"
		})
		current_options.append({
			"id": "alt_power",
			"type": "alternative",
			"title": "Чародейский кристалл",
			"desc": "+12% к силе всех заклинаний мага до конца забега.",
			"rarity": "БЛАГОСЛОВЕНИЕ",
			"color": Color(0.95, 0.45, 1.0, 1.0),
			"icon_symbol": "lightning"
		})

func _populate_cards() -> void:
	if not cards_container:
		return

	for child in cards_container.get_children():
		child.queue_free()

	for opt in current_options:
		var btn = _create_card(opt)
		cards_container.add_child(btn)

func _create_card(opt: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(260, 280)
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var col = opt.get("color", Color(1.0, 0.85, 0.3))

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	btn.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# 1. Rarity Badge
	var badge_label = Label.new()
	badge_label.text = "[ " + opt.get("rarity", "РЕДКОЕ") + " ]"
	badge_label.add_theme_font_size_override("font_size", 12)
	badge_label.add_theme_color_override("font_color", col)
	vbox.add_child(badge_label)

	# 2. Title
	var title_lbl = Label.new()
	title_lbl.text = opt.get("title", "")
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_lbl)

	# 3. Geometric Symbol Container
	var symbol_panel = PanelContainer.new()
	symbol_panel.custom_minimum_size = Vector2(40, 40)
	symbol_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style = StyleBoxFlat.new()
	style.bg_color = Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = col
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	symbol_panel.add_theme_stylebox_override("panel", style)

	var symbol_lbl = Label.new()
	symbol_lbl.text = _get_symbol_glyph(opt.get("icon_symbol", "gem"))
	symbol_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol_lbl.add_theme_font_size_override("font_size", 20)
	symbol_lbl.add_theme_color_override("font_color", col)
	symbol_panel.add_child(symbol_lbl)
	vbox.add_child(symbol_panel)

	# 4. Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	# 5. Description
	var desc_lbl = Label.new()
	desc_lbl.text = opt.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 0.9))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# 6. Button prompt
	var pick_lbl = Label.new()
	pick_lbl.text = "ВЫБРАТЬ"
	pick_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick_lbl.add_theme_font_size_override("font_size", 13)
	pick_lbl.add_theme_color_override("font_color", col)
	vbox.add_child(pick_lbl)

	btn.pressed.connect(func(): _on_card_selected(opt))
	return btn

func _get_symbol_glyph(symbol: String) -> String:
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

func _on_card_selected(opt: Dictionary) -> void:
	if not is_panel_open:
		return

	if opt.get("type", "") == "artifact":
		var art_id = opt.get("id", "")
		if current_player and current_player.inventory:
			var added = current_player.inventory.add_artifact(art_id)
			if added:
				MetaArchive.record_discovery("artifacts", art_id)
				_notify_hud(opt.get("title", ""))
	else:
		# Alternative reward application
		var alt_id = opt.get("id", "")
		match alt_id:
			"alt_heal":
				if current_player:
					current_player.increase_max_health(15.0)
					current_player.heal(40.0)
			"alt_xp":
				var exp_managers = get_tree().get_nodes_in_group("experience_manager")
				if exp_managers.size() > 0:
					exp_managers[0].add_experience(250)
			"alt_power":
				if current_player:
					current_player.increase_spell_power(0.12)
		_notify_hud(opt.get("title", ""))

	is_panel_open = false
	visible = false

	reward_selected.emit(opt)

func _notify_hud(reward_name: String) -> void:
	var huds = get_tree().get_nodes_in_group("hud")
	if huds.size() > 0 and huds[0].has_method("show_chest_notification"):
		huds[0].show_chest_notification(reward_name)

