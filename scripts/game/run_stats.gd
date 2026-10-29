class_name RunStats
extends RefCounted

signal stats_updated

var survival_time: float = 0.0
var total_kills: int = 0
var elite_kills: int = 0
var boss_kills: int = 0
var level_reached: int = 1
var defeated_boss: bool = false

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

func reset() -> void:
	survival_time = 0.0
	total_kills = 0
	elite_kills = 0
	boss_kills = 0
	level_reached = 1
	defeated_boss = false
	_recorded_enemy_ids.clear()
	stats_updated.emit()

