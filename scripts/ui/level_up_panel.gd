class_name LevelUpPanel
extends Control

signal upgrade_picked(option: RewardGenerator.UpgradeOption)

@onready var cards_container: HBoxContainer = $CenterContainer/VBox/CardsContainer
@onready var title_label: Label = $CenterContainer/VBox/TitleLabel

var current_player: PlayerController = null
var current_options: Array[RewardGenerator.UpgradeOption] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open_panel(player: PlayerController, new_level: int) -> void:
	current_player = player
	current_options = RewardGenerator.generate_choices(player, 3)

	if title_label:
		title_label.text = "ПОВЫШЕНИЕ УРОВНЯ! (УР. %d)" % new_level

	populate_cards()
	visible = true
	get_tree().paused = true

func populate_cards() -> void:
	# Clear previous cards
	for child in cards_container.get_children():
		child.queue_free()

	for i in range(current_options.size()):
		var opt = current_options[i]
		var card = create_card_button(opt)
		cards_container.add_child(card)

func create_card_button(opt: RewardGenerator.UpgradeOption) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(250, 260)
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL

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

	# 1. Category / Badge
	var badge_label = Label.new()
	badge_label.text = opt.category_badge
	badge_label.add_theme_font_size_override("font_size", 12)
	if opt.type == "evolution":
		badge_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	elif opt.type == "artifact":
		badge_label.add_theme_color_override("font_color", Color(0.85, 0.4, 1.0, 1.0))
	else:
		badge_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 0.8))
	vbox.add_child(badge_label)

	# 2. Title
	var title_lbl = Label.new()
	title_lbl.text = opt.title
	title_lbl.add_theme_font_size_override("font_size", 18)
	if opt.type == "evolution":
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	else:
		title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_lbl)

	# 3. Level indicator
	var lvl_lbl = Label.new()
	lvl_lbl.text = opt.level_badge
	lvl_lbl.add_theme_font_size_override("font_size", 13)
	lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))
	vbox.add_child(lvl_lbl)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	# 4. Description
	var desc_lbl = Label.new()
	desc_lbl.text = opt.description
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 0.9))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	btn.pressed.connect(func(): _on_card_selected(opt))
	return btn

func _on_card_selected(opt: RewardGenerator.UpgradeOption) -> void:
	if current_player:
		RewardGenerator.apply_upgrade(current_player, opt)

	upgrade_picked.emit(opt)
	visible = false
	get_tree().paused = false

