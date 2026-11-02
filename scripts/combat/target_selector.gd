class_name TargetSelector
extends RefCounted

static var active_enemies: Array[EnemyController] = []

static func register_enemy(enemy: EnemyController) -> void:
	if enemy and not active_enemies.has(enemy):
		active_enemies.append(enemy)

static func unregister_enemy(enemy: EnemyController) -> void:
	active_enemies.erase(enemy)

static func clear() -> void:
	active_enemies.clear()

static func find_nearest_enemy(tree: SceneTree, from_position: Vector2, max_range: float = 900.0) -> EnemyController:
	var list = active_enemies
	if list.is_empty() and tree:
		var nodes = tree.get_nodes_in_group("enemies")
		for n in nodes:
			var e = n as EnemyController
			if is_instance_valid(e) and not e.is_dead:
				list.append(e)

	var nearest: EnemyController = null
	var min_dist_sq = max_range * max_range

	for enemy in list:
		if is_instance_valid(enemy) and not enemy.is_dead:
			var e_pos = enemy.global_position
			var dx = abs(e_pos.x - from_position.x)
			if dx > max_range:
				continue
			var dy = abs(e_pos.y - from_position.y)
			if dy > max_range:
				continue
			var d_sq = dx * dx + dy * dy
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				nearest = enemy

	return nearest

static func find_enemies_in_radius(tree: SceneTree, from_position: Vector2, radius: float) -> Array[EnemyController]:
	var result: Array[EnemyController] = []
	var list = active_enemies
	if list.is_empty() and tree:
		var nodes = tree.get_nodes_in_group("enemies")
		for n in nodes:
			var e = n as EnemyController
			if is_instance_valid(e) and not e.is_dead:
				list.append(e)

	var r_sq = radius * radius

	for enemy in list:
		if is_instance_valid(enemy) and not enemy.is_dead:
			var e_pos = enemy.global_position
			var dx = abs(e_pos.x - from_position.x)
			if dx > radius:
				continue
			var dy = abs(e_pos.y - from_position.y)
			if dy > radius:
				continue
			if (dx * dx + dy * dy) <= r_sq:
				result.append(enemy)

	return result

