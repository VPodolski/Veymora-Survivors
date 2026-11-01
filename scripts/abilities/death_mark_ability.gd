class_name DeathMarkAbility
extends AbilityBase

@export var mark_targets_count: int = 1
@export var damage_amplification: float = 0.40 # +40% damage
@export var execute_ratio: float = 0.15 # 15% execution threshold
@export var mark_duration: float = 6.0

func _init() -> void:
	ability_id = "death_mark"
	ability_name = "Клеймо смерти"
	description = "Помечает сильнейших врагов печатью смерти. Помеченная цель получает увеличенный урон и немедленно погибает при низком здоровье."
	category = "single_target"
	current_level = 1
	max_level = 5
	base_cooldown = 3.5
	base_damage = 35.0 # Death burst damage
	mark_targets_count = 1
	damage_amplification = 0.40
	execute_ratio = 0.15

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
	var candidates: Array[EnemyController] = []
	var enemies = tree.get_nodes_in_group("enemies")

	for node in enemies:
		var enemy = node as EnemyController
		if is_instance_valid(enemy) and not enemy.is_dead and not enemy.has_status(StatusEffects.STATUS_MARKED):
			if player_owner.global_position.distance_to(enemy.global_position) <= 650.0:
				candidates.append(enemy)

	if candidates.is_empty():
		return false

	# Sort by health descending (prioritize boss/elite/highest HP)
	candidates.sort_custom(func(a, b): return a.current_health > b.current_health)

	var marks_applied = 0
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root

	for i in range(min(mark_targets_count, candidates.size())):
		var target = candidates[i]
		target.apply_status(StatusEffects.STATUS_MARKED, mark_duration)
		target.set_meta("death_mark_amp", damage_amplification)
		target.set_meta("death_mark_execute_ratio", execute_ratio)
		target.set_meta("death_mark_burst_dmg", get_effective_damage())

		CombatEffects.spawn_shockwave(container, target.global_position, 55.0, Color(0.9, 0.15, 0.3, 0.9))
		CombatEffects.spawn_text_popup(container, target.global_position, "КЛЕЙМО!", Color(1.0, 0.25, 0.35, 1.0))
		marks_applied += 1

	return marks_applied > 0

func apply_level_modifiers() -> void:
	match current_level:
		2:
			damage_amplification = 0.50
			execute_ratio = 0.15
			base_damage = 45.0
			base_cooldown = 3.5
		3:
			mark_targets_count = 2
			damage_amplification = 0.50
			execute_ratio = 0.20
			base_damage = 45.0
			base_cooldown = 3.5
		4:
			mark_targets_count = 2
			damage_amplification = 0.65
			execute_ratio = 0.20
			base_damage = 50.0
			base_cooldown = 2.8
		5:
			mark_targets_count = 3
			damage_amplification = 0.80
			execute_ratio = 0.25
			base_damage = 60.0
			base_cooldown = 2.8

func get_next_upgrade_description() -> String:
	match current_level + 1:
		2: return "+50% получаемого целью урона и взрыв 45"
		3: return "Помечает сразу 2 цели, порог казни 20% HP"
		4: return "+65% усиления урона и перезарядка 2.8с"
		5: return "Жатва рока: 3 цели, +80% урона, казнь при 25% HP, взрыв 60"
		_: return "Максимальный уровень"
