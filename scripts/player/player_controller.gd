class_name PlayerController
extends CharacterBody2D

signal health_changed(current_hp: float, max_hp: float)
signal died

@export var stats: PlayerStats

var current_health: float = 100.0
var invulnerable_timer: float = 0.0
var is_alive: bool = true

@onready var visual_node: Node2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var ability_controller: AbilityController = $Abilities

func _ready() -> void:
	add_to_group("player")
	if stats == null:
		stats = PlayerStats.new()
	else:
		stats = stats.duplicate() # Duplicate so runtime changes don't overwrite the original asset

	current_health = stats.max_health
	update_modifiers_meta()
	health_changed.emit(current_health, stats.max_health)

func update_modifiers_meta() -> void:
	set_meta("spell_power_mult", stats.spell_power_mult)
	set_meta("cooldown_mult", stats.cooldown_mult)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta

	var input_vector = get_input_direction()
	if input_vector != Vector2.ZERO:
		velocity = input_vector * stats.move_speed
		if visual_node and visual_node.has_method("update_facing"):
			visual_node.update_facing(input_vector)
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func get_input_direction() -> Vector2:
	var dir = Vector2.ZERO

	# Check custom action names if mapped
	if InputMap.has_action("move_left") and InputMap.has_action("move_right") and \
	   InputMap.has_action("move_up") and InputMap.has_action("move_down"):
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Fallback to ui_* actions if custom actions are zero
	if dir == Vector2.ZERO:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Explicit keyboard key fallback for WASD
	if dir == Vector2.ZERO:
		if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_A):
			dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_D):
			dir.x += 1.0
		if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_W):
			dir.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_S):
			dir.y += 1.0

	return dir.normalized()

func take_damage(amount: float) -> void:
	if not is_alive or invulnerable_timer > 0.0:
		return

	current_health = max(0.0, current_health - amount)
	invulnerable_timer = stats.invulnerability_duration

	if visual_node and visual_node.has_method("trigger_hit_flash"):
		visual_node.trigger_hit_flash()

	health_changed.emit(current_health, stats.max_health)

	if current_health <= 0.0:
		die()

func heal(amount: float) -> void:
	if not is_alive:
		return
	current_health = min(stats.max_health, current_health + amount)
	health_changed.emit(current_health, stats.max_health)

func increase_max_health(amount: float) -> void:
	stats.max_health += amount
	heal(amount)

func increase_move_speed(percentage: float) -> void:
	stats.move_speed *= (1.0 + percentage)

func increase_spell_power(percentage: float) -> void:
	stats.spell_power_mult += percentage
	update_modifiers_meta()

func reduce_cooldown(percentage: float) -> void:
	stats.cooldown_mult = max(0.35, stats.cooldown_mult - percentage)
	update_modifiers_meta()

func die() -> void:
	if not is_alive:
		return
	is_alive = false
	velocity = Vector2.ZERO
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if visual_node:
		var tween = create_tween()
		tween.tween_property(visual_node, "modulate", Color(0.2, 0.1, 0.1, 0.4), 0.5)
	died.emit()
