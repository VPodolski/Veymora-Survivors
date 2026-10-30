class_name EnemyController
extends CharacterBody2D

signal died(enemy: EnemyController)
signal status_applied(status_name: String)
signal damage_taken(amount: float)

@export var stats: EnemyStats
@export var xp_gem_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
@export var tags: Array = ["enemy"]

var current_health: float = 30.0
var attack_cooldown_timer: float = 0.0
var target_player: PlayerController = null
var is_dead: bool = false
var active_statuses: Dictionary = {} # status_name: remaining_duration
var knockback_velocity: Vector2 = Vector2.ZERO
var burning_tick_timer: float = 0.0

@onready var visual_node: Node2D = $Visual
@onready var hit_area: Area2D = $HitArea

func apply_knockback(impulse: Vector2) -> void:
	knockback_velocity = impulse

func _ready() -> void:
	add_to_group("enemies")
	if stats == null:
		stats = EnemyStats.new()
	else:
		stats = stats.duplicate()
	current_health = stats.max_health
	find_target()

func find_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0] as PlayerController

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Update active status effects
	update_statuses(delta)

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if knockback_velocity.length_squared() > 10.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	elif is_instance_valid(target_player) and target_player.is_alive:
		var to_player = target_player.global_position - global_position
		var distance = to_player.length()

		if distance > 4.0:
			var dir = to_player.normalized()
			velocity = dir * get_effective_speed()
			if visual_node and visual_node.has_method("update_facing"):
				visual_node.update_facing(dir)
		else:
			velocity = Vector2.ZERO
	else:
		find_target()
		velocity = Vector2.ZERO

	move_and_slide()
	check_player_contact()

func update_statuses(delta: float) -> void:
	var expired: Array = []
	for s_name in active_statuses.keys():
		active_statuses[s_name] -= delta
		if active_statuses[s_name] <= 0.0:
			expired.append(s_name)

	for s_name in expired:
		active_statuses.erase(s_name)

	# Process Burning DoT ticks
	if has_status(StatusEffects.STATUS_BURNING):
		burning_tick_timer -= delta
		if burning_tick_timer <= 0.0:
			burning_tick_timer = 0.5
			take_damage(4.0)
			var was_killed = (is_dead or current_health <= 0.0)
			var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
			CombatEffects.spawn_impact_sparks(container, global_position, Color(1.0, 0.5, 0.1, 0.9), 2)
			var burning_source = get_meta("burning_source", "")
			if not burning_source.is_empty():
				var engines = get_tree().get_nodes_in_group("synergy_engine")
				if engines.size() > 0:
					engines[0].reaction_damage_dealt.emit(burning_source, 4.0, was_killed, true)

	if visual_node and visual_node.has_method("set_statuses"):
		visual_node.set_statuses(active_statuses.keys())

func apply_status(status_name: String, duration: float) -> void:
	if is_dead:
		return
	active_statuses[status_name] = max(active_statuses.get(status_name, 0.0), duration)
	status_applied.emit(status_name)
	if visual_node and visual_node.has_method("set_statuses"):
		visual_node.set_statuses(active_statuses.keys())

func has_status(status_name: String) -> bool:
	return active_statuses.has(status_name) and active_statuses[status_name] > 0.0

func remove_status(status_name: String) -> void:
	active_statuses.erase(status_name)

func get_effective_speed() -> float:
	var spd = stats.move_speed
	if has_status(StatusEffects.STATUS_SLOWED):
		spd *= 0.65
	return spd

func check_player_contact() -> void:
	if attack_cooldown_timer > 0.0:
		return

	if hit_area:
		var overlapping_bodies = hit_area.get_overlapping_bodies()
		for body in overlapping_bodies:
			if body is PlayerController and body.is_alive:
				body.take_damage(stats.contact_damage)
				attack_cooldown_timer = stats.attack_cooldown
				break

func take_damage(amount: float) -> void:
	if is_dead:
		return

	# Death mark damage amplification
	if has_status(StatusEffects.STATUS_MARKED):
		var amp = get_meta("death_mark_amp", 0.40)
		amount *= (1.0 + amp)

	current_health = max(0.0, current_health - amount)
	damage_taken.emit(amount)

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root

	# Visual effects
	if visual_node:
		if visual_node.has_method("trigger_hit_flash"):
			visual_node.trigger_hit_flash()
		if visual_node.has_method("update_health_display"):
			visual_node.update_health_display(current_health, stats.max_health)

	var num_col = Color(1.0, 0.3, 0.4, 1.0) if has_status(StatusEffects.STATUS_MARKED) else Color(1.0, 0.92, 0.5, 1.0)
	CombatEffects.spawn_damage_number(container, global_position, amount, num_col)
	CombatEffects.spawn_impact_sparks(container, global_position)

	if current_health <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	if hit_area and hit_area.has_node("CollisionShape2D"):
		hit_area.get_node("CollisionShape2D").set_deferred("disabled", true)

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_death_burst(container, global_position)

	died.emit(self)

	# Delegate death reactions cleanly to SynergyEngine
	var engine_nodes = get_tree().get_nodes_in_group("synergy_engine")
	if engine_nodes.size() > 0:
		engine_nodes[0].on_enemy_death(self)

	# Spawn XP Gem
	if xp_gem_scene:
		var gem = xp_gem_scene.instantiate() as Node2D
		gem.global_position = global_position
		container.call_deferred("add_child", gem)

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
