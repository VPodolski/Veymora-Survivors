class_name SettingsDialog
extends Control

signal closed

const SaveManager = preload("res://scripts/game/save_manager.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const CombatEffects = preload("res://scripts/combat/combat_effects.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")

@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var lang_label: Label = get_node_or_null("Panel/VBox/Content/Language/Label")
@onready var lang_btn: Button = get_node_or_null("Panel/VBox/Content/Language/LangButton")
@onready var master_label: Label = $Panel/VBox/Content/MasterVolume/Label
@onready var master_slider: HSlider = $Panel/VBox/Content/MasterVolume/Slider
@onready var master_val_label: Label = $Panel/VBox/Content/MasterVolume/ValueLabel
@onready var sfx_label: Label = $Panel/VBox/Content/SfxVolume/Label
@onready var sfx_slider: HSlider = $Panel/VBox/Content/SfxVolume/Slider
@onready var sfx_val_label: Label = $Panel/VBox/Content/SfxVolume/ValueLabel
@onready var fx_label: Label = $Panel/VBox/Content/FxIntensity/Label
@onready var fx_btn: Button = $Panel/VBox/Content/FxIntensity/FxButton
@onready var shake_label: Label = $Panel/VBox/Content/ScreenShake/Label
@onready var shake_check: CheckBox = $Panel/VBox/Content/ScreenShake/CheckBox
@onready var dmg_num_label: Label = $Panel/VBox/Content/DamageNumbers/Label
@onready var dmg_num_check: CheckBox = $Panel/VBox/Content/DamageNumbers/CheckBox
@onready var vsync_label: Label = $Panel/VBox/Content/VSync/Label
@onready var vsync_check: CheckBox = $Panel/VBox/Content/VSync/CheckBox
@onready var close_btn: Button = $Panel/VBox/Header/CloseButton
@onready var apply_btn: Button = $Panel/VBox/BottomBar/ApplyButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if close_btn:
		close_btn.pressed.connect(close)
	if apply_btn:
		apply_btn.pressed.connect(close)

	if lang_btn:
		lang_btn.pressed.connect(_on_lang_toggle_pressed)
	if master_slider:
		master_slider.value_changed.connect(_on_master_slider_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	if fx_btn:
		fx_btn.pressed.connect(_on_fx_toggle_pressed)
	if shake_check:
		shake_check.toggled.connect(_on_shake_toggled)
	if dmg_num_check:
		dmg_num_check.toggled.connect(_on_dmg_num_toggled)
	if vsync_check:
		vsync_check.toggled.connect(_on_vsync_toggled)

	if LocalizationManager.instance:
		LocalizationManager.instance.language_changed.connect(func(_l): _update_localized_texts())

	load_settings()

func _on_lang_toggle_pressed() -> void:
	var loc = LocalizationManager.instance
	if not loc:
		return
	var next_lang = "en" if loc.current_language == "ru" else "ru"
	loc.set_language(next_lang)
	_update_language_button_text(next_lang)
	_update_localized_texts()

func _update_language_button_text(lang: String) -> void:
	if lang_btn:
		if lang == "en":
			lang_btn.text = "English (EN)"
			lang_btn.modulate = Color(0.4, 0.8, 1.0, 1.0)
		else:
			lang_btn.text = "Русский (RU)"
			lang_btn.modulate = Color(0.7, 0.9, 1.0, 1.0)

func _update_localized_texts() -> void:
	var loc = LocalizationManager.instance
	if not loc:
		return
	if title_label:
		title_label.text = loc.get_text("settings_title", "⚙ НАСТРОЙКИ")
	if lang_label:
		lang_label.text = loc.get_text("settings_lang", "Язык (Language):")
	if master_label:
		master_label.text = loc.get_text("settings_master", "Общая громкость:")
	if sfx_label:
		sfx_label.text = loc.get_text("settings_sfx", "Эффекты (SFX):")
	if fx_label:
		fx_label.text = loc.get_text("settings_fx", "Визуальные эффекты:")
	if shake_label:
		shake_label.text = loc.get_text("settings_shake", "Тряска экрана:")
	if shake_check:
		shake_check.text = loc.get_text("settings_shake_on", "Включена")
	if dmg_num_label:
		dmg_num_label.text = loc.get_text("settings_dmg_num", "Числа урона:")
	if dmg_num_check:
		dmg_num_check.text = loc.get_text("settings_dmg_num_on", "Показывать")
	if vsync_label:
		vsync_label.text = loc.get_text("settings_vsync", "Вертикальная синхр.:")
	if vsync_check:
		vsync_check.text = loc.get_text("settings_vsync_on", "Включена (VSync)")
	if apply_btn:
		apply_btn.text = loc.get_text("btn_apply", "Готово")

	var current_mode = SaveManager.get_setting("fx_intensity", "standard")
	_update_fx_button_text(current_mode)

func load_settings() -> void:
	var data = SaveManager.load_data()

	var cur_lang = "ru"
	if LocalizationManager.instance:
		cur_lang = LocalizationManager.instance.current_language
	_update_language_button_text(cur_lang)
	_update_localized_texts()

	var m_vol = float(data.get("master_volume", 1.0))
	if master_slider:
		master_slider.value = m_vol
	if master_val_label:
		master_val_label.text = "%d%%" % int(m_vol * 100.0)

	var s_vol = float(data.get("sfx_volume", 0.8))
	if sfx_slider:
		sfx_slider.value = s_vol
	if sfx_val_label:
		sfx_val_label.text = "%d%%" % int(s_vol * 100.0)

	var fx_mode = str(data.get("fx_intensity", "standard"))
	_update_fx_button_text(fx_mode)

	if shake_check:
		shake_check.button_pressed = bool(data.get("screen_shake", true))
	if dmg_num_check:
		dmg_num_check.button_pressed = bool(data.get("damage_numbers", true))
	if vsync_check:
		vsync_check.button_pressed = bool(data.get("vsync", true))

func _on_master_slider_changed(val: float) -> void:
	if master_val_label:
		master_val_label.text = "%d%%" % int(val * 100.0)
	SaveManager.set_setting("master_volume", val)
	if AudioManager.instance:
		AudioManager.instance.set_master_volume(val)

func _on_sfx_slider_changed(val: float) -> void:
	if sfx_val_label:
		sfx_val_label.text = "%d%%" % int(val * 100.0)
	SaveManager.set_setting("sfx_volume", val)
	if AudioManager.instance:
		AudioManager.instance.set_sfx_volume(val)

func _on_fx_toggle_pressed() -> void:
	var current = SaveManager.get_setting("fx_intensity", "standard")
	var next_mode = "reduced" if current == "standard" else "standard"
	SaveManager.set_setting("fx_intensity", next_mode)
	CombatEffects.set_fx_intensity(next_mode)
	_update_fx_button_text(next_mode)

func _update_fx_button_text(mode: String) -> void:
	if fx_btn:
		var loc = LocalizationManager.instance
		if mode == "reduced":
			fx_btn.text = loc.get_text("settings_fx_reduced", "Сниженные (Reduced)") if loc else "Сниженные (Reduced)"
			fx_btn.modulate = Color(0.6, 0.9, 0.7, 1.0)
		else:
			fx_btn.text = loc.get_text("settings_fx_full", "Стандартные (Full)") if loc else "Стандартные (Full)"
			fx_btn.modulate = Color(0.4, 0.8, 1.0, 1.0)

func _on_shake_toggled(enabled: bool) -> void:
	SaveManager.set_setting("screen_shake", enabled)

func _on_dmg_num_toggled(enabled: bool) -> void:
	SaveManager.set_setting("damage_numbers", enabled)

func _on_vsync_toggled(enabled: bool) -> void:
	SaveManager.set_setting("vsync", enabled)
	if DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_TRANSPARENCY) or OS.get_name() != "Web":
		var mode = DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
		DisplayServer.window_set_vsync_mode(mode)

func open() -> void:
	load_settings()
	visible = true

func close() -> void:
	visible = false
	closed.emit()

