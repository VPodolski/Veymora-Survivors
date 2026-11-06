class_name MainMenu
extends Control

const SaveManager = preload("res://scripts/game/save_manager.gd")
const ArchiveDialog = preload("res://scripts/ui/archive_dialog.gd")
const ArchiveDialogScene = preload("res://scenes/ui/archive_dialog.tscn")
const SettingsDialogScene = preload("res://scenes/ui/settings_dialog.tscn")
const SettingsDialog = preload("res://scripts/ui/settings_dialog.gd")
const ShopDialogScene = preload("res://scenes/ui/shop_dialog.tscn")
const ShopDialog = preload("res://scripts/ui/shop_dialog.gd")
const CharacterProgressionManager = preload("res://scripts/progression/character_progression_manager.gd")
const GameFlowController = preload("res://scripts/game/game_flow_controller.gd")
const PlatformManager = preload("res://scripts/platform/platform_manager.gd")
const YandexGamesBridge = preload("res://scripts/platform/yandex_games_bridge.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")

@onready var title_label: Label = $Center/VBox/HeaderContainer/Title
@onready var subtitle_label: Label = $Center/VBox/HeaderContainer/Subtitle
@onready var start_btn: Button = $Center/VBox/StartButton
@onready var shop_btn: Button = get_node_or_null("Center/VBox/ShopButton")
@onready var archive_btn: Button = $Center/VBox/ArchiveButton
@onready var settings_btn: Button = $Center/VBox/SettingsButton
@onready var controls_btn: Button = $Center/VBox/ControlsButton
@onready var stats_label: Label = $Center/VBox/StatsLabel
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var controls_heading: Label = $ControlsPanel/Margin/VBox/Heading
@onready var controls_body: Label = $ControlsPanel/Margin/VBox/Body
@onready var close_controls_btn: Button = $ControlsPanel/Margin/VBox/CloseControlsBtn
@onready var account_label: Label = get_node_or_null("TopRightBar/AccountLabel")
@onready var auth_btn: Button = get_node_or_null("TopRightBar/AuthButton")
@onready var gold_label: Label = get_node_or_null("TopRightBar/GoldLabel")
@onready var char_name_label: Label = get_node_or_null("Center/VBox/CharacterPanel/Margin/VBox/CharHeader/CharName")
@onready var char_level_label: Label = get_node_or_null("Center/VBox/CharacterPanel/Margin/VBox/CharHeader/CharLevel")
@onready var char_xp_bar: ProgressBar = get_node_or_null("Center/VBox/CharacterPanel/Margin/VBox/CharXPBar")
@onready var char_bonus_label: Label = get_node_or_null("Center/VBox/CharacterPanel/Margin/VBox/CharBonus")

var archive_dialog: ArchiveDialog = null
var settings_dialog: SettingsDialog = null
var shop_dialog: ShopDialog = null

func _ready() -> void:
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	if shop_btn:
		shop_btn.pressed.connect(_on_shop_pressed)
	if archive_btn:
		archive_btn.pressed.connect(_on_archive_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if controls_btn:
		controls_btn.pressed.connect(_on_controls_pressed)
	if close_controls_btn:
		close_controls_btn.pressed.connect(func(): controls_panel.visible = false)
	if auth_btn:
		auth_btn.pressed.connect(_on_auth_pressed)

	if controls_panel:
		controls_panel.visible = false

	if OS.has_feature("web"):
		var search = JavaScriptBridge.eval("window.location.search")
		if search and ("benchmark=1" in str(search) or "benchmark=true" in str(search)):
			call_deferred("_start_benchmark_scene")
			return

	if LocalizationManager.instance:
		LocalizationManager.instance.language_changed.connect(func(_l): _update_localized_texts())

	if PlatformManager.instance:
		PlatformManager.instance.auth_state_changed.connect(_on_auth_state_changed)
		PlatformManager.instance.cloud_sync_completed.connect(_on_cloud_sync_completed)
		_update_auth_display(PlatformManager.instance.is_authorized(), PlatformManager.instance.get_player_name())
	elif YandexGamesBridge.instance:
		YandexGamesBridge.instance.auth_state_changed.connect(_on_auth_state_changed)
		YandexGamesBridge.instance.cloud_sync_completed.connect(_on_cloud_sync_completed)
		_update_auth_display(YandexGamesBridge.instance.is_authorized, YandexGamesBridge.instance.player_name)
	else:
		_update_auth_display(false, "")

	_update_localized_texts()
	call_deferred("_notify_game_ready")

func _on_auth_pressed() -> void:
	if PlatformManager.instance:
		PlatformManager.instance.authorize_player()
	elif YandexGamesBridge.instance:
		YandexGamesBridge.instance.authorize_player()

func _on_auth_state_changed(is_auth: bool, p_name: String) -> void:
	_update_auth_display(is_auth, p_name)

func _on_cloud_sync_completed(_data: Dictionary) -> void:
	_update_stats_display()

func _update_auth_display(is_auth: bool, p_name: String) -> void:
	var loc = LocalizationManager.instance
	if not account_label or not auth_btn:
		return
	if is_auth:
		var display_name = p_name if not p_name.is_empty() else "Маг Вейморы"
		var fmt = loc.get_text("auth_logged_in", "👤 %s") if loc else "👤 %s"
		account_label.text = fmt % display_name
		auth_btn.visible = false
	else:
		account_label.text = loc.get_text("auth_guest", "Гость") if loc else "Гость"
		auth_btn.text = loc.get_text("auth_login_btn", "👤 Войти") if loc else "👤 Войти"
		auth_btn.visible = true

func _notify_game_ready() -> void:
	if PlatformManager.instance:
		PlatformManager.instance.notify_game_ready()
	elif YandexGamesBridge.instance:
		YandexGamesBridge.instance.notify_game_ready()

func _update_localized_texts() -> void:
	var loc = LocalizationManager.instance
	if not loc:
		_update_stats_display()
		return

	if title_label:
		title_label.text = loc.get_text("app_title", "VEYMORA SURVIVORS")
	if subtitle_label:
		subtitle_label.text = loc.get_text("app_subtitle", "Магические синергии • Разломы стихий • Версия 0.3")
	if start_btn:
		start_btn.text = loc.get_text("menu_start", "⚔ ВЫБОР АРЕНЫ")
	if shop_btn:
		shop_btn.text = loc.get_text("menu_shop", "🏛 МАГАЗИН УЛУЧШЕНИЙ")
	if archive_btn:
		archive_btn.text = loc.get_text("menu_codex", "📖 КОДЕКС И АТЛАС")
	if settings_btn:
		settings_btn.text = loc.get_text("menu_settings", "⚙ НАСТРОЙКИ")
	if controls_btn:
		controls_btn.text = loc.get_text("menu_controls", "✦ УПРАВЛЕНИЕ И ПРАВИЛА")
	if controls_heading:
		controls_heading.text = loc.get_text("controls_heading", "УПРАВЛЕНИЕ И ОСНОВЫ БОЯ")
	if controls_body:
		controls_body.text = loc.get_text("controls_body", "• Движение: [W, A, S, D]...")
	if close_controls_btn:
		close_controls_btn.text = loc.get_text("btn_understood", "Понятно")

	if PlatformManager.instance:
		_update_auth_display(PlatformManager.instance.is_authorized(), PlatformManager.instance.get_player_name())
	elif YandexGamesBridge.instance:
		_update_auth_display(YandexGamesBridge.instance.is_authorized, YandexGamesBridge.instance.player_name)
	else:
		_update_auth_display(false, "")

	_update_stats_display()

func _update_stats_display() -> void:
	var data = SaveManager.load_data()
	var current_gold = int(data.get("gold", 0))

	# Update Gold Counter in Header
	if gold_label:
		gold_label.text = "🪙 %d" % current_gold

	# Update Character Card Display
	var char_id = SaveManager.get_selected_character()
	var char_data = SaveManager.get_character_data(char_id)
	var char_lvl = int(char_data.get("level", 1))
	var char_xp = int(char_data.get("xp", 0))
	var req_xp = CharacterProgressionManager.get_required_xp(char_lvl)
	var bonuses = CharacterProgressionManager.get_character_bonuses(char_id)
	var loc = LocalizationManager.instance

	if char_name_label:
		char_name_label.text = loc.get_text("menu_char_card_title", "🧙 Маг Разлома") if loc else "🧙 Маг Разлома"
	if char_level_label:
		var lvl_fmt = loc.get_text("menu_char_lvl_fmt", "Ур. %d") if loc else "Ур. %d"
		char_level_label.text = lvl_fmt % char_lvl
	if char_xp_bar:
		char_xp_bar.max_value = req_xp
		char_xp_bar.value = char_xp
		var xp_fmt = loc.get_text("menu_char_xp_fmt", "Опыт мага: %d / %d XP") if loc else "Опыт мага: %d / %d XP"
		char_xp_bar.tooltip_text = xp_fmt % [char_xp, req_xp]
	if char_bonus_label:
		if char_lvl > 1:
			var bonus_fmt = loc.get_text("menu_char_bonus_fmt", "Магическая стрела: %s к базовому урону") if loc else "Магическая стрела: %s к базовому урону"
			char_bonus_label.text = bonus_fmt % bonuses.get("damage_percent_text", "+0%")
		else:
			char_bonus_label.text = loc.get_text("menu_char_bonus_base", "Магическая стрела: базовая форма") if loc else "Магическая стрела: базовая форма"

	if not stats_label:
		return
	var best_sec = int(data.get("best_survival_time", 0.0))
	var m = best_sec / 60
	var s = best_sec % 60
	var arenas = data.get("unlocked_arenas", ["forgotten_forest"])
	var total_runs = int(data.get("total_runs", 0))
	var bosses = int(data.get("bosses_defeated", 0))
	var loc = LocalizationManager.instance
	if loc:
		var fmt = loc.get_text("menu_stats", "Всего забегов: %d   |   Рекорд: %02d:%02d   |   Повержено боссов: %d   |   Доступно арен: %d")
		stats_label.text = fmt % [total_runs, m, s, bosses, arenas.size()]
	else:
		stats_label.text = "Всего забегов: %d   |   Рекорд: %02d:%02d   |   Повержено боссов: %d   |   Доступно арен: %d" % [
			total_runs, m, s, bosses, arenas.size()
		]

func _on_shop_pressed() -> void:
	if not shop_dialog:
		shop_dialog = ShopDialogScene.instantiate() as ShopDialog
		add_child(shop_dialog)
		shop_dialog.gold_updated.connect(func(_g): _update_stats_display())
	shop_dialog.open()

func _on_start_pressed() -> void:
	if GameFlowController.instance:
		GameFlowController.instance.open_arena_select()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/arena_select.tscn")

func _on_archive_pressed() -> void:
	if not archive_dialog:
		archive_dialog = ArchiveDialogScene.instantiate() as ArchiveDialog
		add_child(archive_dialog)
	archive_dialog.open_codex()

func _on_settings_pressed() -> void:
	if not settings_dialog:
		settings_dialog = SettingsDialogScene.instantiate() as SettingsDialog
		add_child(settings_dialog)
	settings_dialog.open()

func _on_controls_pressed() -> void:
	if controls_panel:
		controls_panel.visible = true

func _start_benchmark_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
