class_name OrientationWarning
extends Control

const LocalizationManager = preload("res://scripts/game/localization_manager.gd")

@onready var label: Label = $Center/VBox/Label
@onready var icon: Label = $Center/VBox/Icon

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()

func _check_orientation() -> void:
	var vp_size = get_viewport_rect().size
	# Portrait orientation detected
	if vp_size.y > vp_size.x and vp_size.x > 0:
		visible = true
		_update_text()
	else:
		visible = false

func _update_text() -> void:
	if label and LocalizationManager.instance:
		label.text = LocalizationManager.instance.get_text("rotate_device_warning", "Пожалуйста, поверните устройство горизонтально для комфортной игры.")
