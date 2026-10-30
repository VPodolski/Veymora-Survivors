class_name SettingsDialog
extends Control

signal closed

const SaveManager = preload("res://scripts/game/save_manager.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const CombatEffects = preload("res://scripts/combat/combat_effects.gd")

@onready var master_slider: HSlider = $Panel/VBox/Content/MasterVolume/Slider
@onready var master_val_label: Label = $Panel/VBox/Content/MasterVolume/ValueLabel
@onready var sfx_slider: HSlider = $Panel/VBox/Content/SfxVolume/Slider
@onready var sfx_val_label: Label = $Panel/VBox/Content/SfxVolume/ValueLabel
@onready var fx_btn: Button = $Panel/VBox/Content/FxIntensity/FxButton
@onready var shake_check: CheckBox = $Panel/VBox/Content/ScreenShake/CheckBox
@onready var dmg_num_check: CheckBox = $Panel/VBox/Content/DamageNumbers/CheckBox
@onready var vsync_check: CheckBox = $Panel/VBox/Content/VSync/CheckBox
@onready var close_btn: Button = $Panel/VBox/Header/CloseButton
@onready var apply_btn: Button = $Panel/VBox/BottomBar/ApplyButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if close_btn:
		close_btn.pressed.connect(close)
	if apply_btn:
		apply_btn.pressed.connect(close)

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

	load_settings()

func load_settings() -> void:
	var data = SaveManager.load_data()

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
		if mode == "reduced":
			fx_btn.text = "Сниженные (Reduced)"
			fx_btn.modulate = Color(0.6, 0.9, 0.7, 1.0)
		else:
			fx_btn.text = "Стандартные (Full)"
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
