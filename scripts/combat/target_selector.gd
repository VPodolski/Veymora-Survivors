class_name TargetSelector
extends RefCounted

static func find_nearest_enemy(tree: SceneTree, from_position: Vector2, max_range: float = 900.0) -> EnemyController:
	if not tree:
		return null

	var enemies = tree.get_nodes_in_group("enemies")
	var nearest: EnemyController = null
	var min_dist_sq = max_range * max_range

	for node in enemies:
		var enemy = node as EnemyController
		if is_instance_valid(enemy) and not enemy.is_dead:
			var d_sq = from_position.distance_squared_to(enemy.global_position)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				nearest = enemy

	return nearest

static func find_enemies_in_radius(tree: SceneTree, from_position: Vector2, radius: float) -> Array[EnemyController]:
	var result: Array[EnemyController] = []
	if not tree:
		return result

	var enemies = tree.get_nodes_in_group("enemies")
	var r_sq = radius * radius

	for node in enemies:
		var enemy = node as EnemyController
		if is_instance_valid(enemy) and not enemy.is_dead:
			if from_position.distance_squared_to(enemy.global_position) <= r_sq:
				result.append(enemy)

	return result
