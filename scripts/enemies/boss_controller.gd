class_name BossController
extends EnemyController

signal boss_health_changed(cur_hp: float, max_hp: float)
signal boss_phase_changed(new_phase: int)
signal boss_defeated

enum BossPhase { HUNT = 1, RIFT = 2, ENRAGE = 3 }
var current_phase: int = BossPhase.HUNT

@export var chest_scene: PackedScene = preload("res://scenes/pickups/chest.tscn")
@export var projectile_scene: PackedScene = preload("res://scenes/combat/projectile.tscn")

var is_dashing: bool = false
var is_telegraphing_dash: bool = false
var dash_telegraph_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown: float = 5.5
var dash_direction: Vector2 = Vector2.ZERO

var pulse_cooldown: float = 6.0
var rift_hazard_cooldown: float = 7.0
var rift_bolt_cooldown: float = 5.5
var is_enraged: bool = false

func _ready() -> void:
	stats = EnemyStats.new()
	stats.max_health = 3000.0
	stats.move_speed = 85.0
	stats.contact_damage = 40.0
	stats.attack_cooldown = 0.8
	super._ready()
	current_health = stats.max_health
	add_to_group("boss")
	tags = ["enemy", "boss", "spatial"]
	call_deferred("_emit_initial_health")

func _emit_initial_health() -> void:
	boss_health_changed.emit(current_health, stats.max_health)
	if visual_node and visual_node.has_method("set_phase"):
		visual_node.set_phase(current_phase)

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
		var dash_spd = 440.0 if is_enraged else (390.0 if current_phase == BossPhase.RIFT else 360.0)
		velocity = dash_direction * dash_spd
		move_and_slide()
		check_player_contact()
		if dash_timer <= 0.0:
			is_dashing = false
			velocity = Vector2.ZERO
		return

	# Dash attack timing
	dash_cooldown -= delta
	if dash_cooldown <= 0.0 and is_instance_valid(target_player):
		start_dash_attack()
		return

	# Shadow Ring attack timing
	pulse_cooldown -= delta
	if pulse_cooldown <= 0.0:
		pulse_cooldown = 3.8 if is_enraged else (5.0 if current_phase == BossPhase.RIFT else 6.0)
		fire_shadow_ring()

	# Phase 2 & 3: Rift Hazard Zones
	if current_phase >= BossPhase.RIFT:
		rift_hazard_cooldown -= delta
		if rift_hazard_cooldown <= 0.0 and is_instance_valid(target_player):
			rift_hazard_cooldown = 5.0 if is_enraged else 7.0
			spawn_rift_hazards()

		# Targeted Rift Bolt bursts
		rift_bolt_cooldown -= delta
		if rift_bolt_cooldown <= 0.0 and is_instance_valid(target_player):
			rift_bolt_cooldown = 4.2 if is_enraged else 6.0
			fire_targeted_rift_bolts()

	super._physics_process(delta)

func start_dash_attack() -> void:
	if not is_instance_valid(target_player):
		return
	dash_cooldown = 3.2 if is_enraged else (4.5 if current_phase == BossPhase.RIFT else 5.5)
	dash_direction = (target_player.global_position - global_position).normalized()
	is_dashing = true
	is_telegraphing_dash = true
	dash_telegraph_timer = 0.45 if is_enraged else (0.55 if current_phase == BossPhase.RIFT else 0.65)
	dash_timer = 1.0

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_hazard_telegraph(container, global_position, dash_direction, 420.0, 70.0, dash_telegraph_timer)
	CombatEffects.spawn_shockwave(container, global_position, 90.0, Color(0.9, 0.2, 0.4, 0.8))
	CombatEffects.spawn_text_popup(container, global_position, "ЗАРЯД РАЗЛОМА...", Color(1.0, 0.3, 0.5, 1.0), true)

func execute_dash() -> void:
	is_dashing = true
	dash_timer = 1.0
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, global_position, 150.0, Color(0.85, 0.2, 1.0, 0.95))
	CombatEffects.spawn_text_popup(container, global_position, "РЫВОК РАЗЛОМА!", Color(0.9, 0.3, 1.0, 1.0))

func fire_shadow_ring() -> void:
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_ring(container, global_position, 70.0, 14.0, Color(0.95, 0.1, 0.35, 0.9), 0.18, 2.0)
	CombatEffects.spawn_shockwave(container, global_position, 110.0, Color(0.9, 0.1, 0.3, 0.9))
	var msg = "ШКВАЛ ТЕНЕЙ!" if is_enraged else ("ТЕНЕВЫЕ КЛЫКИ!" if current_phase == BossPhase.RIFT else "КОЛЬЦО ПУСТОТЫ!")
	CombatEffects.spawn_text_popup(container, global_position, msg, Color(0.95, 0.2, 0.35, 1.0), true)

	var count = 12 if is_enraged else (10 if current_phase == BossPhase.RIFT else 8)
	for i in range(count):
		var angle = (float(i) / float(count)) * TAU
		var dir = Vector2(cos(angle), sin(angle))
		var proj = projectile_scene.instantiate() as Projectile
		proj.faction = Projectile.Faction.ENEMY
		proj.global_position = global_position + dir * 45.0
		proj.direction = dir
		proj.damage = 22.0
		proj.speed = 360.0 if is_enraged else 320.0
		proj.projectile_color = Color(1.0, 0.15, 0.35, 1.0) if is_enraged else Color(0.85, 0.2, 0.9, 1.0)
		container.add_child(proj)

func spawn_rift_hazards() -> void:
	if not is_instance_valid(target_player):
		return
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var count = 3 if is_enraged else 2
	for i in range(count):
		var offset = Vector2(randf_range(-180.0, 180.0), randf_range(-180.0, 180.0))
		var hazard_pos = target_player.global_position + offset
		# Warning telegraph
		CombatEffects.spawn_ring(container, hazard_pos, 10.0, 65.0, Color(0.9, 0.1, 0.4, 0.75), 0.8, 2.5)
		# Spawn delayed area hazard
		var timer = get_tree().create_timer(0.8)
		timer.timeout.connect(func():
			if not is_instance_valid(container):
				return
			CombatEffects.spawn_shockwave(container, hazard_pos, 70.0, Color(0.8, 0.1, 0.9, 0.85), 0.35)
			if is_instance_valid(target_player) and target_player.global_position.distance_to(hazard_pos) <= 70.0:
				target_player.take_damage(20.0)
		)

func fire_targeted_rift_bolts() -> void:
	if not is_instance_valid(target_player):
		return
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var dir = (target_player.global_position - global_position).normalized()
	CombatEffects.spawn_hazard_telegraph(container, global_position, dir, 500.0, 24.0, 0.4)
	var timer = get_tree().create_timer(0.4)
	timer.timeout.connect(func():
		if is_dead or not is_instance_valid(container):
			return
		var count = 3 if is_enraged else 2
		for i in range(count):
			var angle = dir.angle() + float(i - 1) * 0.15
			var shot_dir = Vector2(cos(angle), sin(angle))
			var proj = projectile_scene.instantiate() as Projectile
			proj.faction = Projectile.Faction.ENEMY
			proj.global_position = global_position + shot_dir * 45.0
			proj.direction = shot_dir
			proj.damage = 24.0
			proj.speed = 380.0
			proj.projectile_color = Color(0.95, 0.2, 0.5, 1.0)
			container.add_child(proj)
	)

func take_damage(amount: float) -> void:
	super.take_damage(amount)
	boss_health_changed.emit(current_health, stats.max_health)

	var hp_pct = current_health / max(1.0, stats.max_health)

	# Phase 2 Transition (Rift Phase at <= 70% HP)
	if hp_pct <= 0.70 and current_phase == BossPhase.HUNT and current_health > 0.0:
		current_phase = BossPhase.RIFT
		boss_phase_changed.emit(current_phase)
		if visual_node and visual_node.has_method("set_phase"):
			visual_node.set_phase(current_phase)
		var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
		CombatEffects.spawn_shockwave(container, global_position, 200.0, Color(0.6, 0.2, 1.0, 1.0))
		CombatEffects.spawn_text_popup(container, global_position, "ФАЗА РАЗЛОМА!", Color(0.7, 0.3, 1.0, 1.0))

	# Phase 3 Transition (Enrage Phase at <= 35% HP)
	if hp_pct <= 0.35 and current_phase != BossPhase.ENRAGE and current_health > 0.0:
		current_phase = BossPhase.ENRAGE
		is_enraged = true
		stats.move_speed = 105.0
		boss_phase_changed.emit(current_phase)
		if visual_node and visual_node.has_method("set_phase"):
			visual_node.set_phase(current_phase)
		var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
		CombatEffects.spawn_shockwave(container, global_position, 250.0, Color(1.0, 0.1, 0.3, 1.0))
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

	# Boss reward: drop super tier (Rare) XP gem (250 XP)
	if xp_gem_scene:
		var gem = xp_gem_scene.instantiate() as XPGem
		if gem:
			gem.xp_value = 250
			gem.global_position = global_position + Vector2(25.0, 0.0)
			var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
			container.call_deferred("add_child", gem)

	super.die()
