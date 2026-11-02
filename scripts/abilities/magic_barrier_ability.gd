class_name MagicBarrierAbility
extends AbilityBase

const DamageResolver = preload("res://scripts/combat/damage_resolver.gd")
const DamageContext = preload("res://scripts/combat/damage_context.gd")

@export var max_shield: float = 30.0
@export var current_shield: float = 30.0
@export var recharge_cooldown: float = 12.0
@export var pulse_damage: float = 20.0
@export var pulse_radius: float = 120.0

var recharge_timer: float = 0.0
var is_active: bool = true
var pulse_angle: float = 0.0

func _init() -> void:
	ability_id = "magic_barrier"
	ability_name = "Магический барьер"
	description = "Пассивно формирует рунический щит, поглощающий входящий урон и взрывающийся волной отталкивания при разрушении."
	category = "defense"
	current_level = 1
	max_level = 5
	base_cooldown = 12.0
	max_shield = 30.0
	current_shield = 30.0
	recharge_cooldown = 12.0
	pulse_damage = 20.0
	pulse_radius = 120.0

func _ready() -> void:
	super._ready()
	current_shield = get_effective_max_shield()

func get_effective_max_shield() -> float:
	var s = max_shield
	if player_owner and player_owner.has_meta("has_warding_rune"):
		s *= 1.40
	return s

func get_effective_recharge_cooldown() -> float:
	var cd = recharge_cooldown
	if player_owner and player_owner.has_meta("has_warding_rune"):
		cd = max(3.0, cd - 2.0)
	if player_owner and player_owner.has_meta("cooldown_mult"):
		cd *= player_owner.get_meta("cooldown_mult")
	return max(2.0, cd)

func _physics_process(delta: float) -> void:
	pulse_angle += 2.0 * delta
	if pulse_angle > TAU:
		pulse_angle -= TAU

	if not is_active:
		recharge_timer -= delta
		if recharge_timer <= 0.0:
			restore_barrier()

	queue_redraw()

func absorb_damage(incoming: float) -> float:
	if not is_active or current_shield <= 0.0:
		return 0.0

	var absorbed = min(incoming, current_shield)
	current_shield -= absorbed

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root

	# Delegate defense event to SynergyEngine (handles Thunder Shield accumulation and retaliation)
	var engines = get_tree().get_nodes_in_group("synergy_engine")
	if engines.size() > 0:
		engines[0].on_barrier_absorbed(player_owner, absorbed)

	if current_shield <= 0.0:
		_break_barrier()
	else:
		CombatEffects.spawn_hit_flash(container, player_owner.global_position, Color(0.4, 0.85, 1.0), 18.0)
		CombatEffects.spawn_ring(container, player_owner.global_position, 16.0, 36.0, Color(0.4, 0.8, 1.0, 0.8), 0.15, 2.0)

	return absorbed

func _break_barrier() -> void:
	current_shield = 0.0
	is_active = false
	recharge_timer = get_effective_recharge_cooldown()

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, player_owner.global_position, pulse_radius, Color(0.3, 0.75, 1.0, 0.95), 0.3)
	CombatEffects.spawn_ring(container, player_owner.global_position, 10.0, pulse_radius, Color(0.5, 0.9, 1.0, 0.85), 0.25, 3.0)
	CombatEffects.spawn_text_popup(container, player_owner.global_position, "БАРЬЕР СЛОМАН!", Color(0.4, 0.8, 1.0, 1.0))

	var enemies = TargetSelector.find_enemies_in_radius(get_tree(), player_owner.global_position, pulse_radius)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			var push_dir = (enemy.global_position - player_owner.global_position).normalized()
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(push_dir * 420.0)
			else:
				enemy.global_position += push_dir * 35.0

			var ctx = DamageContext.new(self, enemy, pulse_damage, ["barrier", "force"], "magic_barrier", enemy.global_position)
			DamageResolver.apply_damage(ctx)

			if current_level >= 5:
				enemy.apply_status(StatusEffects.STATUS_SLOWED, 3.5)

	# Delegate barrier broken synergy (e.g. Glacial Ward) to SynergyEngine
	var engines = get_tree().get_nodes_in_group("synergy_engine")
	if engines.size() > 0:
		engines[0].on_barrier_broken(player_owner, pulse_radius)

func restore_barrier() -> void:
	current_shield = get_effective_max_shield()
	is_active = true
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, player_owner.global_position, 60.0, Color(0.3, 0.85, 1.0, 0.85), 0.22)
	CombatEffects.spawn_text_popup(container, player_owner.global_position, "БАРЬЕР ВОССТАНОВЛЕН!", Color(0.5, 0.9, 1.0, 1.0))

func apply_level_modifiers() -> void:
	match current_level:
		2:
			max_shield = 45.0
			recharge_cooldown = 10.5
		3:
			max_shield = 60.0
			recharge_cooldown = 10.5
			pulse_damage = 25.0
		4:
			max_shield = 75.0
			recharge_cooldown = 8.5
			pulse_damage = 30.0
		5:
			max_shield = 90.0
			recharge_cooldown = 7.0
			pulse_damage = 40.0

	if is_active:
		current_shield = get_effective_max_shield()

func get_next_upgrade_description() -> String:
	match current_level + 1:
		2: return "+Прочность щита (45 HP) и быстрее зарядка (10.5с)"
		3: return "+Прочность (60 HP) и урон взрыва разрыва 25"
		4: return "+Прочность (75 HP) и быстрая зарядка (8.5с)"
		5: return "Эгида Арканы: 90 HP, зарядка 7.0с, оглушающий импульс 40 урона"
		_: return "Максимальный уровень"

func _draw() -> void:
	if not is_active or not player_owner:
		return

	# Draw glowing runic shield circle centered at local origin (ability is child of player or abilities)
	var shield_ratio = clamp(current_shield / max(1.0, get_effective_max_shield()), 0.0, 1.0)
	var alpha = 0.2 + 0.3 * shield_ratio
	var barrier_col = Color(0.25, 0.75, 1.0, alpha)

	# Outer faint aura
	draw_circle(Vector2.ZERO, 34.0, Color(0.2, 0.6, 1.0, alpha * 0.4))
	# Segmented runic arc
	draw_arc(Vector2.ZERO, 32.0, pulse_angle, pulse_angle + TAU * 0.85, 24, barrier_col, 2.5)
	# 4 pulsing orbital nodes
	for i in range(4):
		var ang = pulse_angle + float(i) * (TAU * 0.25)
		var pt = Vector2(cos(ang), sin(ang)) * 32.0
		draw_circle(pt, 2.8, Color(0.7, 0.95, 1.0, alpha * 1.5))
