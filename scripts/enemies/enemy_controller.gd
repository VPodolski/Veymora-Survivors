class_name EnemyController
extends CharacterBody2D

signal died(enemy: EnemyController)
signal status_applied(status_name: String)
signal damage_taken(amount: float)

@export var stats: EnemyStats
@export var xp_gem_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
@export var gold_coin_scene: PackedScene = preload("res://scenes/pickups/gold_coin.tscn")
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
	TargetSelector.register_enemy(self)
	if stats == null:
		stats = EnemyStats.new()
	else:
		stats = stats.duplicate()
	current_health = stats.max_health
	find_target()

static var _cached_player: PlayerController = null

func find_target() -> void:
	if is_instance_valid(_cached_player) and _cached_player.is_alive:
		target_player = _cached_player
		return
	var players = get_tree().get_nodes_in_group("player") if get_tree() else []
	if players.size() > 0:
		_cached_player = players[0] as PlayerController
		target_player = _cached_player

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
	if active_statuses.is_empty():
		return

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
			var burning_source = get_meta("burning_source", "fireball")
			var ctx = DamageContext.new(null, self, 4.0, ["fire", "burning", "dot"], burning_source, global_position, true)
			DamageResolver.apply_damage(ctx)
			var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
			CombatEffects.spawn_impact_sparks(container, global_position, Color(1.0, 0.5, 0.1, 0.9), 2)

	if expired.size() > 0 and visual_node and visual_node.has_method("set_statuses"):
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
	if visual_node and visual_node.has_method("set_statuses"):
		visual_node.set_statuses(active_statuses.keys())

func get_effective_speed() -> float:
	var spd = stats.move_speed
	if has_status(StatusEffects.STATUS_SLOWED):
		spd *= 0.65
	return spd

func check_player_contact() -> void:
	if attack_cooldown_timer > 0.0:
		return

	# Fast distance check against player, eliminating expensive get_overlapping_bodies physics queries
	if is_instance_valid(target_player) and target_player.is_alive:
		var contact_r = 30.0
		if stats and "contact_radius" in stats:
			contact_r = stats.contact_radius
		elif self is BossController:
			contact_r = 64.0
		elif self is EliteEnemyController:
			contact_r = 38.0

		if global_position.distance_squared_to(target_player.global_position) <= (contact_r * contact_r):
			target_player.take_damage(stats.contact_damage)
			attack_cooldown_timer = stats.attack_cooldown
			return

	if hit_area and not is_instance_valid(target_player):
		var overlapping_bodies = hit_area.get_overlapping_bodies()
		for body in overlapping_bodies:
			if body is PlayerController and body.is_alive:
				body.take_damage(stats.contact_damage)
				attack_cooldown_timer = stats.attack_cooldown
				break

const DamageResolver = preload("res://scripts/combat/damage_resolver.gd")
const DamageContext = preload("res://scripts/combat/damage_context.gd")

func take_damage_context(ctx: DamageContext) -> Dictionary:
	return DamageResolver.apply_damage(ctx)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	var ctx = DamageContext.new(null, self, amount, [], "generic", global_position, false, 0, "", false)
	DamageResolver.apply_damage(ctx)

func _exit_tree() -> void:
	TargetSelector.unregister_enemy(self)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	TargetSelector.unregister_enemy(self)
	velocity = Vector2.ZERO
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if hit_area and is_instance_valid(hit_area) and hit_area.has_node("CollisionShape2D"):
		hit_area.get_node("CollisionShape2D").set_deferred("disabled", true)

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_death_burst(container, global_position)

	died.emit(self)

	# Notify Font of Life on kill
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if p and p.has_node("Abilities"):
			var font = p.get_node("Abilities").get_ability("font_of_life")
			if font and font.has_method("notify_enemy_killed"):
				font.notify_enemy_killed()

	# Delegate death reactions cleanly to SynergyEngine
	var engine_nodes = get_tree().get_nodes_in_group("synergy_engine")
	if engine_nodes.size() > 0:
		engine_nodes[0].on_enemy_death(self)

	# Spawn regular drop (Gem or Coin)
	spawn_drop()

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func spawn_drop() -> void:
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var players = get_tree().get_nodes_in_group("player")
	var coin_chance = 0.12 # 12% base chance
	if players.size() > 0 and players[0].stats and "gold_drop_chance_bonus" in players[0].stats:
		coin_chance += players[0].stats.gold_drop_chance_bonus

	if gold_coin_scene and randf() < coin_chance:
		var coin = gold_coin_scene.instantiate() as Node2D
		coin.global_position = global_position
		container.call_deferred("add_child", coin)
	elif xp_gem_scene:
		var gem = xp_gem_scene.instantiate() as Node2D
		gem.global_position = global_position
		container.call_deferred("add_child", gem)
