class_name FontOfLifeAbility
extends AbilityBase

const DamageResolver = preload("res://scripts/combat/damage_resolver.gd")
const DamageContext = preload("res://scripts/combat/damage_context.gd")

@export var heal_interval: float = 5.0
@export var heal_amount: float = 3.0
@export var kills_for_pulse: int = 20
@export var kill_heal_amount: float = 3.0
@export var overheal_armor_duration: float = 2.5

const OVERHEAL_ARMOR_VALUE: float = 0.10

var heal_timer: float = 0.0
var kill_counter: int = 0
var pulse_anim_time: float = 0.0
var overheal_armor_timer: float = 0.0

func _init() -> void:
	ability_id = "font_of_life"
	ability_name = "Источник жизни"
	description = "Автоматически восстанавливает здоровье с течением времени и испускает целебные импульсы за убийства врагов."
	category = "healing"
	current_level = 1
	max_level = 5
	base_cooldown = 5.0
	heal_interval = 5.0
	heal_amount = 3.0
	kills_for_pulse = 20
	kill_heal_amount = 3.0

func get_effective_heal() -> float:
	var h = heal_amount
	if player_owner and player_owner.has_meta("has_life_crystal"):
		h *= 1.20
	return h

func get_effective_kill_heal() -> float:
	var h = kill_heal_amount
	if player_owner and player_owner.has_meta("has_life_crystal"):
		h *= 1.20
	return h

func _physics_process(delta: float) -> void:
	pulse_anim_time += delta
	heal_timer += delta

	if overheal_armor_timer > 0.0:
		overheal_armor_timer -= delta
		if overheal_armor_timer <= 0.0:
			overheal_armor_timer = 0.0
			_expire_overheal_armor()

	if heal_timer >= heal_interval:
		heal_timer = 0.0
		_trigger_interval_heal()

	queue_redraw()

func _apply_overheal_armor() -> void:
	overheal_armor_timer = overheal_armor_duration
	if player_owner:
		player_owner.set_meta("font_overheal_armor", OVERHEAL_ARMOR_VALUE)
		player_owner.set_meta("font_overheal_armor_duration", overheal_armor_duration)

func _expire_overheal_armor() -> void:
	if player_owner and player_owner.has_meta("font_overheal_armor"):
		player_owner.remove_meta("font_overheal_armor")
		if player_owner.has_meta("font_overheal_armor_duration"):
			player_owner.remove_meta("font_overheal_armor_duration")

func has_overheal_armor() -> bool:
	return overheal_armor_timer > 0.0

func get_overheal_armor_time_remaining() -> float:
	return max(0.0, overheal_armor_timer)

func _trigger_interval_heal() -> void:
	if not player_owner or not player_owner.is_alive:
		return

	var amount = get_effective_heal()
	var was_full_hp = (player_owner.current_health >= (player_owner.stats.max_health if player_owner.stats else 100.0))
	player_owner.heal(amount)

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_ring(container, player_owner.global_position, 12.0, 40.0, Color(0.2, 0.9, 0.4, 0.75), 0.22, 2.0)
	CombatEffects.spawn_text_popup(container, player_owner.global_position, "+%d" % int(amount), Color(0.25, 0.95, 0.45, 1.0))

	# Level 5 overheal buff: 15% temporary damage resistance
	if current_level >= 5 and was_full_hp:
		_apply_overheal_armor()
		CombatEffects.spawn_text_popup(container, player_owner.global_position, "БРОНЯ ЖИЗНИ!", Color(0.4, 1.0, 0.6, 1.0))

func notify_enemy_killed() -> void:
	kill_counter += 1
	if kill_counter >= kills_for_pulse:
		kill_counter = 0
		_trigger_kill_pulse()

func _trigger_kill_pulse() -> void:
	if not player_owner or not player_owner.is_alive:
		return

	var amount = get_effective_kill_heal()
	player_owner.heal(amount)

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, player_owner.global_position, 120.0, Color(0.2, 0.95, 0.5, 0.8), 0.28)
	CombatEffects.spawn_text_popup(container, player_owner.global_position, "+%d ИМПУЛЬС ЖИЗНИ!" % int(amount), Color(0.3, 1.0, 0.5, 1.0))

	# Level 3+: Pulse damages nearby enemies
	if current_level >= 3:
		var enemies = TargetSelector.find_enemies_in_radius(get_tree(), player_owner.global_position, 120.0)
		for enemy in enemies:
			if is_instance_valid(enemy) and not enemy.is_dead:
				var ctx = DamageContext.new(self, enemy, 15.0, ["healing", "pulse", "area"], "font_of_life", enemy.global_position, true)
				DamageResolver.apply_damage(ctx)
				CombatEffects.spawn_hit_flash(container, enemy.global_position, Color(0.3, 1.0, 0.5), 10.0)

func apply_level_modifiers() -> void:
	match current_level:
		2:
			heal_interval = 4.5
			heal_amount = 4.0
			kill_heal_amount = 3.0
		3:
			heal_interval = 4.5
			heal_amount = 5.0
			kill_heal_amount = 3.0
		4:
			heal_interval = 4.0
			heal_amount = 5.0
			kill_heal_amount = 3.0
		5:
			heal_interval = 4.0
			heal_amount = 6.0
			kill_heal_amount = 3.0

func get_next_upgrade_description() -> String:
	match current_level + 1:
		2: return "+4 HP каждые 4.5с; +3 HP за 20 убийств"
		3: return "+5 HP каждые 4.5с; импульс наносит 15 урона врагам"
		4: return "+5 HP каждые 4.0с; +3 HP за 20 убийств"
		5: return "Живой Исток: +6 HP каждые 4.0с, избыток дает +10% брони"
		_: return "Максимальный уровень"

func _draw() -> void:
	if not player_owner:
		return
	# Gentle rotating emerald light particles around player
	var pulse_sin = sin(pulse_anim_time * 3.0) * 0.15 + 0.25
	draw_arc(Vector2.ZERO, 22.0, 0, TAU, 16, Color(0.2, 0.9, 0.45, pulse_sin), 1.5)
