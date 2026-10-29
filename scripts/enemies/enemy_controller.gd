class_name EnemyController
extends CharacterBody2D

signal died(enemy: EnemyController)

@export var stats: EnemyStats

var current_health: float = 30.0
var attack_cooldown_timer: float = 0.0
var target_player: PlayerController = null
var is_dead: bool = false

@onready var visual_node: Node2D = $Visual
@onready var hit_area: Area2D = $HitArea

func _ready() -> void:
	add_to_group("enemies")
	if stats == null:
		stats = EnemyStats.new()
	current_health = stats.max_health
	find_target()

func find_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0] as PlayerController

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if not is_instance_valid(target_player) or not target_player.is_alive:
		find_target()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player = target_player.global_position - global_position
	var distance = to_player.length()

	if distance > 4.0:
		var dir = to_player.normalized()
		velocity = dir * stats.move_speed
		if visual_node and visual_node.has_method("update_facing"):
			visual_node.update_facing(dir)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	check_player_contact()

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

	current_health = max(0.0, current_health - amount)

	if visual_node and visual_node.has_method("trigger_hit_flash"):
		visual_node.trigger_hit_flash()

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

	died.emit(self)

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

