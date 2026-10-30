class_name VirtualJoystick
extends Control

signal direction_changed(dir: Vector2)

@export var base_radius: float = 65.0
@export var stick_radius: float = 28.0
@export var base_color: Color = Color(0.2, 0.35, 0.55, 0.35)
@export var stick_color: Color = Color(0.35, 0.8, 1.0, 0.75)
@export var active_stick_color: Color = Color(0.65, 0.95, 1.0, 0.95)

var touch_index: int = -1
var stick_position: Vector2 = Vector2.ZERO
var output_direction: Vector2 = Vector2.ZERO
var is_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(base_radius * 2.4, base_radius * 2.4)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_index == -1:
				var local_pos = event.position - global_position
				if local_pos.length() <= base_radius * 1.5:
					touch_index = event.index
					is_active = true
					_update_stick_position(local_pos)
		else:
			if event.index == touch_index:
				_reset_joystick()

	elif event is InputEventScreenDrag:
		if event.index == touch_index:
			var local_pos = event.position - global_position
			_update_stick_position(local_pos)

	elif event is InputEventMouseButton:
		# Also support mouse drag for testing in desktop browser/editor
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local_pos = event.position - global_position
				if local_pos.length() <= base_radius * 1.5:
					is_active = true
					_update_stick_position(local_pos)
			else:
				if is_active:
					_reset_joystick()

	elif event is InputEventMouseMotion:
		if is_active and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			var local_pos = event.position - global_position
			_update_stick_position(local_pos)

func _update_stick_position(pos: Vector2) -> void:
	var dist = pos.length()
	if dist > base_radius:
		stick_position = pos.normalized() * base_radius
	else:
		stick_position = pos

	# Deadzone of 12% to prevent micro-drifts
	var deadzone = base_radius * 0.12
	if dist < deadzone:
		output_direction = Vector2.ZERO
	else:
		output_direction = (stick_position / base_radius).normalized() * clampf((dist - deadzone) / (base_radius - deadzone), 0.0, 1.0)

	direction_changed.emit(output_direction)
	queue_redraw()

func _reset_joystick() -> void:
	touch_index = -1
	is_active = false
	stick_position = Vector2.ZERO
	output_direction = Vector2.ZERO
	direction_changed.emit(Vector2.ZERO)
	queue_redraw()

func get_direction() -> Vector2:
	return output_direction

func _draw() -> void:
	# 1. Base ring & circle
	draw_circle(Vector2.ZERO, base_radius, base_color)
	draw_arc(Vector2.ZERO, base_radius, 0, TAU, 36, Color(stick_color.r, stick_color.g, stick_color.b, 0.4), 2.0)
	draw_arc(Vector2.ZERO, base_radius * 0.45, 0, TAU, 24, Color(stick_color.r, stick_color.g, stick_color.b, 0.2), 1.5)

	# 2. Stick knob
	var col = active_stick_color if is_active else stick_color
	draw_circle(stick_position, stick_radius, col)
	draw_arc(stick_position, stick_radius, 0, TAU, 28, Color.WHITE, 1.8)

