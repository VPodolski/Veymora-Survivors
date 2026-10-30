class_name RunStats
extends RefCounted

signal stats_updated

var arena_id: String = "forgotten_forest"
var arena_name: String = "Забытый лес"
var survival_time: float = 0.0
var total_kills: int = 0
var elite_kills: int = 0
var boss_kills: int = 0
var level_reached: int = 1
var defeated_boss: bool = false
var damage_dealt: float = 0.0
var experience_gained: float = 0.0
var artifacts_collected: int = 0

# Rich Synergy Tracking (v0.4)
var synergy_counts: Dictionary = {} # synergy_id -> int activation count
var synergy_damage: Dictionary = {} # synergy_id -> float total damage
var synergy_targets: Dictionary = {} # synergy_id -> int total enemies struck
var synergy_kills: Dictionary = {} # synergy_id -> int kills caused by synergy
var synergy_max_targets: Dictionary = {} # synergy_id -> int peak targets in single reaction
var synergy_dot_damage: Dictionary = {} # synergy_id -> float periodic DoT damage

var _recorded_enemy_ids: Dictionary = {}

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

func record_xp(amount: float) -> void:
	if amount > 0.0:
		experience_gained += amount

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
		"arena_id": arena_id,
		"arena_name": arena_name,
		"survival_time": survival_time,
		"total_kills": total_kills,
		"elite_kills": elite_kills,
		"boss_kills": boss_kills,
		"level_reached": level_reached,
		"defeated_boss": defeated_boss,
		"damage_dealt": damage_dealt,
		"experience_gained": experience_gained,
		"artifacts_collected": artifacts_collected,
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
	arena_id = "forgotten_forest"
	arena_name = "Забытый лес"
	survival_time = 0.0
	total_kills = 0
	elite_kills = 0
	boss_kills = 0
	level_reached = 1
	defeated_boss = false
	damage_dealt = 0.0
	experience_gained = 0.0
	artifacts_collected = 0
	synergy_counts.clear()
	synergy_damage.clear()
	synergy_targets.clear()
	synergy_kills.clear()
	synergy_max_targets.clear()
	synergy_dot_damage.clear()
	_recorded_enemy_ids.clear()
	stats_updated.emit()
