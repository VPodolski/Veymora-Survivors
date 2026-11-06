class_name RunStats
extends RefCounted

signal stats_updated

const SynergyRegistry = preload("res://scripts/synergies/synergy_registry.gd")

static var active_stats: RunStats = null

var arena_id: String = "forgotten_forest"
var arena_name: String = "Забытый лес"
var survival_time: float = 0.0
var total_kills: int = 0
var elite_kills: int = 0
var boss_kills: int = 0
var level_reached: int = 1
var defeated_boss: bool = false
var is_victory: bool = false
var damage_dealt: float = 0.0
var experience_gained: float = 0.0
var artifacts_collected: int = 0
var chests_opened: int = 0
var gold_collected: int = 0
var barrier_absorbed_damage: float = 0.0
var total_healing_done: float = 0.0
var spell_damage: Dictionary = {} # spell_id -> float total damage
var spell_hits: Dictionary = {} # spell_id -> int hits
var hit_count: int = 0
var unique_enemies_hit: Dictionary = {} # enemy_id -> true
var enemies_hit_count: int = 0
var total_dot_damage: float = 0.0
var projectiles_intercepted: int = 0
var damage_prevented: float = 0.0

# Rich Synergy Tracking (v0.4)
var synergy_counts: Dictionary = {} # synergy_id -> int activation count
var synergy_damage: Dictionary = {} # synergy_id -> float total damage
var synergy_targets: Dictionary = {} # synergy_id -> int total enemies struck
var synergy_kills: Dictionary = {} # synergy_id -> int kills caused by synergy
var synergy_max_targets: Dictionary = {} # synergy_id -> int peak targets in single reaction
var synergy_dot_damage: Dictionary = {} # synergy_id -> float periodic DoT damage

# Run Tracking & Deduplication (v0.5.2)
var run_id: String = ""
var character_id: String = "wizard"
var is_processed: bool = false

var _recorded_enemy_ids: Dictionary = {}

func _init() -> void:
	active_stats = self
	if run_id.is_empty():
		run_id = "run_%d_%d" % [Time.get_unix_time_from_system(), randi() % 1000000]

func record_kill(enemy: EnemyController) -> void:
	if not enemy:
		return
	var id = enemy.get_instance_id()
	if _recorded_enemy_ids.has(id):
		return
	_recorded_enemy_ids[id] = true

	total_kills += 1
	if enemy is BossController:
		boss_kills += 1
		defeated_boss = true
	elif enemy is EliteEnemyController:
		elite_kills += 1

	stats_updated.emit()

func record_damage(amount: float) -> void:
	if amount > 0.0:
		damage_dealt += amount

func record_hit(source_id: String, amount: float, enemy: EnemyController = null, is_dot: bool = false) -> void:
	if amount <= 0.0:
		return
	record_damage(amount)
	hit_count += 1

	if enemy:
		var eid = enemy.get_instance_id()
		if not unique_enemies_hit.has(eid):
			unique_enemies_hit[eid] = true
			enemies_hit_count += 1

	if is_dot:
		total_dot_damage += amount

	if SynergyRegistry.has_definition(source_id):
		synergy_damage[source_id] = synergy_damage.get(source_id, 0.0) + amount
		if is_dot:
			synergy_dot_damage[source_id] = synergy_dot_damage.get(source_id, 0.0) + amount
	else:
		var s_id = source_id if not source_id.is_empty() else "generic"
		spell_damage[s_id] = spell_damage.get(s_id, 0.0) + amount
		spell_hits[s_id] = spell_hits.get(s_id, 0) + 1

func record_spell_hit(spell_id: String, amount: float) -> void:
	record_hit(spell_id, amount, null, false)

func record_projectile_intercepted(amount: float = 0.0) -> void:
	projectiles_intercepted += 1
	if amount > 0.0:
		damage_prevented += amount
	stats_updated.emit()

func record_damage_absorbed(amount: float) -> void:
	if amount > 0.0:
		barrier_absorbed_damage += amount

func record_healing(amount: float) -> void:
	if amount > 0.0:
		total_healing_done += amount

func record_xp(amount: float) -> void:
	if amount > 0.0:
		experience_gained += amount

func record_gold(amount: int) -> void:
	if amount > 0:
		gold_collected += amount
		stats_updated.emit()

func record_chest_opened() -> void:
	chests_opened += 1
	stats_updated.emit()

func record_synergy_activation(synergy_id: String, targets_count: int = 1) -> void:
	if synergy_id.is_empty():
		return
	synergy_counts[synergy_id] = synergy_counts.get(synergy_id, 0) + 1
	var actual_targets = max(1, targets_count)
	synergy_targets[synergy_id] = synergy_targets.get(synergy_id, 0) + actual_targets
	synergy_max_targets[synergy_id] = max(synergy_max_targets.get(synergy_id, 0), actual_targets)

func record_synergy_damage(synergy_id: String, dmg: float, is_kill: bool = false, is_dot: bool = false) -> void:
	if synergy_id.is_empty() or dmg <= 0.0:
		return
	synergy_damage[synergy_id] = synergy_damage.get(synergy_id, 0.0) + dmg
	if is_dot:
		synergy_dot_damage[synergy_id] = synergy_dot_damage.get(synergy_id, 0.0) + dmg
	if is_kill:
		synergy_kills[synergy_id] = synergy_kills.get(synergy_id, 0) + 1

# Backward-compatible bridge method
func record_synergy_trigger(synergy_id: String, dmg: float = 0.0) -> void:
	if synergy_id.is_empty():
		return
	record_synergy_activation(synergy_id, 1)
	if dmg > 0.0:
		record_synergy_damage(synergy_id, dmg)

func get_most_effective_synergy() -> String:
	var best_syn = ""
	var max_dmg = -1.0
	for syn in synergy_damage.keys():
		if synergy_damage[syn] > max_dmg:
			max_dmg = synergy_damage[syn]
			best_syn = syn

	if best_syn.is_empty():
		var max_count = -1
		for syn in synergy_counts.keys():
			if synergy_counts[syn] > max_count:
				max_count = synergy_counts[syn]
				best_syn = syn

	return best_syn if not best_syn.is_empty() else "—"

func get_total_synergy_damage() -> float:
	var total = 0.0
	for dmg in synergy_damage.values():
		total += float(dmg)
	return total

func get_synergy_damage_ratio() -> float:
	if damage_dealt <= 0.0:
		return 0.0
	return clampf(get_total_synergy_damage() / damage_dealt, 0.0, 1.0)

func to_dictionary() -> Dictionary:
	return {
		"run_id": run_id,
		"character_id": character_id,
		"is_processed": is_processed,
		"arena_id": arena_id,
		"arena_name": arena_name,
		"survival_time": survival_time,
		"total_kills": total_kills,
		"elite_kills": elite_kills,
		"boss_kills": boss_kills,
		"level_reached": level_reached,
		"defeated_boss": defeated_boss,
		"is_victory": is_victory,
		"damage_dealt": damage_dealt,
		"experience_gained": experience_gained,
		"artifacts_collected": artifacts_collected,
		"chests_opened": chests_opened,
		"gold_collected": gold_collected,
		"barrier_absorbed_damage": barrier_absorbed_damage,
		"total_healing_done": total_healing_done,
		"hit_count": hit_count,
		"enemies_hit_count": enemies_hit_count,
		"total_dot_damage": total_dot_damage,
		"projectiles_intercepted": projectiles_intercepted,
		"damage_prevented": damage_prevented,
		"spell_damage": spell_damage.duplicate(),
		"spell_hits": spell_hits.duplicate(),
		"synergy_counts": synergy_counts.duplicate(),
		"synergy_damage": synergy_damage.duplicate(),
		"synergy_targets": synergy_targets.duplicate(),
		"synergy_kills": synergy_kills.duplicate(),
		"synergy_max_targets": synergy_max_targets.duplicate(),
		"most_effective_synergy": get_most_effective_synergy(),
		"synergy_ratio": get_synergy_damage_ratio(),
		"timestamp": Time.get_unix_time_from_system()
	}

func reset() -> void:
	run_id = "run_%d_%d" % [Time.get_unix_time_from_system(), randi() % 1000000]
	character_id = "wizard"
	is_processed = false
	arena_id = "forgotten_forest"
	arena_name = "Забытый лес"
	survival_time = 0.0
	total_kills = 0
	elite_kills = 0
	boss_kills = 0
	level_reached = 1
	defeated_boss = false
	is_victory = false
	damage_dealt = 0.0
	experience_gained = 0.0
	artifacts_collected = 0
	chests_opened = 0
	gold_collected = 0
	barrier_absorbed_damage = 0.0
	total_healing_done = 0.0
	hit_count = 0
	enemies_hit_count = 0
	total_dot_damage = 0.0
	projectiles_intercepted = 0
	damage_prevented = 0.0
	unique_enemies_hit.clear()
	spell_damage.clear()
	spell_hits.clear()
	synergy_counts.clear()
	synergy_damage.clear()
	synergy_targets.clear()
	synergy_kills.clear()
	synergy_max_targets.clear()
	synergy_dot_damage.clear()
	_recorded_enemy_ids.clear()
	stats_updated.emit()
