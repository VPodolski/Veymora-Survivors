class_name LightningAbility
extends AbilityBase

const DamageResolver = preload("res://scripts/combat/damage_resolver.gd")
const DamageContext = preload("res://scripts/combat/damage_context.gd")

var tags: Array = ["lightning", "chain"]
@export var is_evolved: bool = false
@export var chain_jumps: int = 2
@export var search_radius: float = 160.0

func _init() -> void:
	ability_id = "lightning_strike"
	ability_name = "Грозовой разряд"
	description = "Призывает цепную молнию, поражающую группу врагов зарядом статического электричества."
	category = "chain"
	current_level = 1
	max_level = 5
	base_cooldown = 2.6
	base_damage = 24.0
	chain_jumps = 2
	search_radius = 160.0

func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		return

	if try_cast():
		cooldown_timer = get_effective_cooldown()

func try_cast() -> bool:
	if not player_owner:
		return false

	var tree = get_tree()
	if not tree:
		return false

	var enemy = TargetSelector.find_nearest_enemy(tree, player_owner.global_position, 650.0)
	if not enemy or not is_instance_valid(enemy):
		return false

	cast_lightning(enemy)
	return true

func cast_lightning(target: EnemyController) -> void:
	if not is_instance_valid(target) or not player_owner:
		return

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var dmg = get_effective_damage()
	var pos = target.global_position
	var chained_targets: Array = [target]

	# Primary strike visuals & damage
	var arc_col = Color(0.8, 0.95, 1.0, 1.0) if is_evolved else Color(0.4, 0.85, 1.0, 1.0)
	var arc_w = 3.8 if is_evolved else 2.4
	CombatEffects.spawn_lightning_arc(container, player_owner.global_position, pos, arc_col, arc_w)
	CombatEffects.spawn_hit_flash(container, pos, arc_col, 16.0 if is_evolved else 12.0)
	var prim_ctx = DamageContext.new(self, target, dmg, tags, "lightning_strike", pos, false, 0, "", false)
	DamageResolver.apply_damage(prim_ctx)
	if is_instance_valid(target) and not target.is_dead:
		target.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	# 1. Establish and execute base chain targets
	var extra_jumps = 2 if (player_owner and player_owner.get_meta("has_lightning_rod", false)) else 0
	var max_targets = (8 if is_evolved else (1 + chain_jumps)) + extra_jumps
	var current_pos = pos

	var effective_radius = search_radius * (1.3 if (player_owner and player_owner.get_meta("has_lightning_rod", false)) else 1.0)
	if is_evolved:
		effective_radius = max(effective_radius, 220.0)

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, effective_radius)
	for next_enemy in nearby:
		if chained_targets.size() >= max_targets:
			break
		if not chained_targets.has(next_enemy) and is_instance_valid(next_enemy) and not next_enemy.is_dead:
			chained_targets.append(next_enemy)
			var sub_w = max(1.2, arc_w * (1.0 - float(chained_targets.size()) * 0.08))
			CombatEffects.spawn_lightning_arc(container, current_pos, next_enemy.global_position, arc_col, sub_w)
			CombatEffects.spawn_hit_flash(container, next_enemy.global_position, arc_col, 10.0)
			var chain_dmg = dmg * (0.9 if is_evolved else 0.75)
			var sub_ctx = DamageContext.new(self, next_enemy, chain_dmg, tags, "lightning_strike", next_enemy.global_position, true, 0, "", false)
			DamageResolver.apply_damage(sub_ctx)
			if is_instance_valid(next_enemy) and not next_enemy.is_dead:
				next_enemy.apply_status(StatusEffects.STATUS_CHARGED, 3.5)
			current_pos = next_enemy.global_position

	# 2. Trigger synergy AFTER base chain targets are established
	# All base chain targets are passed in excluded_targets, preventing any double-damage
	var engines = get_tree().get_nodes_in_group("synergy_engine")
	if engines.size() > 0:
		var ctx = ReactionContext.new(self, target, tags, pos, dmg, 0, true, chained_targets)
		engines[0].on_hit_landed(ctx)

func apply_level_modifiers() -> void:
	match current_level:
		2:
			base_damage = 30.0
			chain_jumps = 3
		3:
			base_damage = 36.0
			chain_jumps = 4
			base_cooldown = 2.2
		4:
			base_damage = 36.0
			chain_jumps = 5
			search_radius = 200.0
			base_cooldown = 2.2
		5:
			base_damage = 45.0
			chain_jumps = 6
			base_cooldown = 1.8
			search_radius = 200.0

func evolve() -> void:
	is_evolved = true
	ability_name = "Ярость Небес"
	description = "★ ЭВОЛЮЦИЯ! Штормовой каскад небесных молний (до 8 скачков, урон 45, интервал 1.4 сек)."
	base_damage = 45.0
	base_cooldown = 1.4

func get_next_upgrade_description() -> String:
	match current_level + 1:
		2: return "+Урон (30) и +1 перескок (4 цели)"
		3: return "+Урон (36), +1 перескок (5 целей), кд 2.2с"
		4: return "+1 перескок (6 целей) и радиус поиска +25%"
		5: return "Каскад бури: 7 целей, урон 45, кд 1.8с"
		_: return "Максимальный уровень"
