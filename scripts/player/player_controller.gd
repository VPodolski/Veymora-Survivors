class_name PlayerController
extends CharacterBody2D

signal health_changed(current_hp: float, max_hp: float)
signal died

@export var stats: PlayerStats

var current_health: float = 100.0
var invulnerable_timer: float = 0.0
var is_alive: bool = true
var phoenix_revives_remaining: int = 0

var shake_intensity: float = 0.0
var shake_duration: float = 0.0

@onready var visual_node: Node2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D
@onready var ability_controller: AbilityController = $Abilities
@onready var inventory: InventoryState = $Inventory

func _ready() -> void:
	add_to_group("player")
	if stats == null:
		stats = PlayerStats.new()
	else:
		stats = stats.duplicate()

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

	# Process screen shake
	if shake_duration > 0.0:
		shake_duration -= delta
		if camera:
			camera.offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
		if shake_duration <= 0.0 and camera:
			camera.offset = Vector2.ZERO

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

	if InputMap.has_action("move_left") and InputMap.has_action("move_right") and \
	   InputMap.has_action("move_up") and InputMap.has_action("move_down"):
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if dir == Vector2.ZERO:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

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

func trigger_camera_shake(intensity: float = 6.0, duration: float = 0.2) -> void:
	if CombatEffects.fx_intensity == "reduced":
		intensity *= 0.35
		duration *= 0.5
	shake_intensity = intensity
	shake_duration = duration

func take_damage(amount: float) -> void:
	if not is_alive or invulnerable_timer > 0.0:
		return

	current_health = max(0.0, current_health - amount)
	invulnerable_timer = stats.invulnerability_duration

	trigger_camera_shake(7.0, 0.22)

	if visual_node and visual_node.has_method("trigger_hit_flash"):
		visual_node.trigger_hit_flash()

	# Obsidian heart defensive pulse
	if has_meta("has_obsidian_heart"):
		trigger_obsidian_pulse()

	health_changed.emit(current_health, stats.max_health)

	if current_health <= 0.0:
		if phoenix_revives_remaining > 0:
			phoenix_revives_remaining -= 1
			current_health = stats.max_health * 0.5
			invulnerable_timer = 2.0
			trigger_camera_shake(12.0, 0.35)
			var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
			CombatEffects.spawn_shockwave(container, global_position, 220.0, Color(1.0, 0.45, 0.1, 0.95))
			CombatEffects.spawn_text_popup(container, global_position, "ВОЗРОЖДЕНИЕ ФЕНИКСА!", Color(1.0, 0.7, 0.2, 1.0))
			health_changed.emit(current_health, stats.max_health)
			return
		die()

func trigger_obsidian_pulse() -> void:
	trigger_camera_shake(10.0, 0.28)
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, global_position, 110.0, Color(0.9, 0.2, 0.35, 0.95))
	CombatEffects.spawn_text_popup(container, global_position, "ОБСИДИАН!", Color(1.0, 0.3, 0.4, 1.0))

	var enemies = TargetSelector.find_enemies_in_radius(get_tree(), global_position, 110.0)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			var push_dir = (enemy.global_position - global_position).normalized()
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(push_dir * 380.0)
			else:
				enemy.global_position += push_dir * 30.0
			enemy.take_damage(16.0)

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
	if camera:
		camera.offset = Vector2.ZERO
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if visual_node:
		var tween = create_tween()
		tween.tween_property(visual_node, "modulate", Color(0.2, 0.1, 0.1, 0.4), 0.5)
	died.emit()
