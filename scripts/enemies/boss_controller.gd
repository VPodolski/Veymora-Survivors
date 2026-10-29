class_name BossController
extends EnemyController

signal boss_health_changed(cur_hp: float, max_hp: float)
signal boss_defeated

@export var chest_scene: PackedScene = preload("res://scenes/pickups/chest.tscn")
@export var projectile_scene: PackedScene = preload("res://scenes/combat/projectile.tscn")

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown: float = 5.0
var dash_direction: Vector2 = Vector2.ZERO

var pulse_cooldown: float = 6.5
var pulse_timer: float = 0.0

func _ready() -> void:
	stats = EnemyStats.new()
	stats.max_health = 700.0
	stats.move_speed = 85.0
	stats.contact_damage = 25.0
	super._ready()
	current_health = stats.max_health
	add_to_group("boss")
	tags = ["enemy", "boss", "spatial"]
	call_deferred("_emit_initial_health")

func _emit_initial_health() -> void:
	boss_health_changed.emit(current_health, stats.max_health)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Handle Dash Attack
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * 340.0
		move_and_slide()
		check_player_contact()
		if dash_timer <= 0.0:
			is_dashing = false
			velocity = Vector2.ZERO
		return

	dash_cooldown -= delta
	if dash_cooldown <= 0.0 and is_instance_valid(target_player):
		start_dash_attack()
		return

	pulse_cooldown -= delta
	if pulse_cooldown <= 0.0:
		pulse_cooldown = 6.5
		fire_shadow_ring()

	super._physics_process(delta)

func start_dash_attack() -> void:
	if not is_instance_valid(target_player):
		return
	dash_cooldown = 5.5
	dash_direction = (target_player.global_position - global_position).normalized()
	is_dashing = true
	dash_timer = 1.0

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, global_position, 130.0, Color(0.85, 0.2, 1.0, 0.95))
	CombatEffects.spawn_text_popup(container, global_position, "РЫВОК РАЗЛОМА!", Color(0.9, 0.3, 1.0, 1.0))

func fire_shadow_ring() -> void:
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, global_position, 90.0, Color(0.9, 0.1, 0.3, 0.9))

	var count = 8
	for i in range(count):
		var angle = (float(i) / float(count)) * TAU
		var dir = Vector2(cos(angle), sin(angle))
		var proj = projectile_scene.instantiate() as Projectile
		proj.global_position = global_position + dir * 30.0
		proj.direction = dir
		proj.damage = 18.0
		proj.projectile_color = Color(0.9, 0.15, 0.3, 1.0)
		proj.collision_mask = 1 # Hits player!
		container.add_child(proj)

func take_damage(amount: float) -> void:
	super.take_damage(amount)
	boss_health_changed.emit(current_health, stats.max_health)

func die() -> void:
	if is_dead:
		return

	boss_defeated.emit()

	# Drop legendary chest
	if chest_scene:
		var chest = chest_scene.instantiate() as Node2D
		chest.global_position = global_position
		var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
		container.call_deferred("add_child", chest)

	super.die()
