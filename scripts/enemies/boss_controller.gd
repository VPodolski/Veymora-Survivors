class_name BossController
extends EnemyController

signal boss_health_changed(cur_hp: float, max_hp: float)
signal boss_defeated

@export var chest_scene: PackedScene = preload("res://scenes/pickups/chest.tscn")
@export var projectile_scene: PackedScene = preload("res://scenes/combat/projectile.tscn")

var is_dashing: bool = false
var is_telegraphing_dash: bool = false
var dash_telegraph_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown: float = 5.0
var dash_direction: Vector2 = Vector2.ZERO

var pulse_cooldown: float = 6.5
var pulse_timer: float = 0.0
var is_enraged: bool = false

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

	# Handle Dash Telegraph
	if is_telegraphing_dash:
		dash_telegraph_timer -= delta
		velocity = Vector2.ZERO
		if dash_telegraph_timer <= 0.0:
			is_telegraphing_dash = false
			execute_dash()
		return

	# Handle Dash Attack Execution
	if is_dashing:
		dash_timer -= delta
		var dash_spd = 400.0 if is_enraged else 340.0
		velocity = dash_direction * dash_spd
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
		pulse_cooldown = 4.5 if is_enraged else 6.5
		fire_shadow_ring()

	super._physics_process(delta)

func start_dash_attack() -> void:
	if not is_instance_valid(target_player):
		return
	dash_cooldown = 3.8 if is_enraged else 5.5
	dash_direction = (target_player.global_position - global_position).normalized()
	is_dashing = true
	is_telegraphing_dash = true
	dash_telegraph_timer = 0.35 if is_enraged else 0.45
	dash_timer = 1.0

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, global_position, 70.0, Color(0.9, 0.2, 0.4, 0.8))
	CombatEffects.spawn_text_popup(container, global_position, "ЗАРЯД РАЗЛОМА...", Color(1.0, 0.3, 0.5, 1.0))

func execute_dash() -> void:
	is_dashing = true
	dash_timer = 1.0
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, global_position, 130.0, Color(0.85, 0.2, 1.0, 0.95))
	CombatEffects.spawn_text_popup(container, global_position, "РЫВОК РАЗЛОМА!", Color(0.9, 0.3, 1.0, 1.0))

func fire_shadow_ring() -> void:
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, global_position, 90.0, Color(0.9, 0.1, 0.3, 0.9))
	var msg = "ШКВАЛ ТЕНЕЙ!" if is_enraged else "ТЕНЕВЫЕ КЛЫКИ!"
	CombatEffects.spawn_text_popup(container, global_position, msg, Color(0.95, 0.2, 0.35, 1.0))

	var count = 12 if is_enraged else 8
	for i in range(count):
		var angle = (float(i) / float(count)) * TAU
		var dir = Vector2(cos(angle), sin(angle))
		var proj = projectile_scene.instantiate() as Projectile
		proj.faction = Projectile.Faction.ENEMY
		proj.global_position = global_position + dir * 30.0
		proj.direction = dir
		proj.damage = 18.0
		proj.speed = 360.0 if is_enraged else 340.0
		proj.projectile_color = Color(0.95, 0.15, 0.35, 1.0)
		container.add_child(proj)

func take_damage(amount: float) -> void:
	super.take_damage(amount)
	boss_health_changed.emit(current_health, stats.max_health)

	# Low Health Enrage Transition (Phase 3)
	if current_health <= stats.max_health * 0.35 and not is_enraged and current_health > 0.0:
		is_enraged = true
		stats.move_speed = 110.0
		var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
		CombatEffects.spawn_shockwave(container, global_position, 220.0, Color(1.0, 0.1, 0.3, 1.0))
		CombatEffects.spawn_text_popup(container, global_position, "ЯРОСТЬ РАЗЛОМА!", Color(1.0, 0.15, 0.2, 1.0))

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
