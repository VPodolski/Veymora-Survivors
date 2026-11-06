class_name EliteEnemyController
extends EnemyController

@export var chest_scene: PackedScene = preload("res://scenes/pickups/chest.tscn")

func _ready() -> void:
	stats = EnemyStats.new()
	stats.max_health = 500.0
	stats.move_speed = 90.0
	stats.contact_damage = 28.0
	stats.attack_cooldown = 0.8
	super._ready()
	current_health = stats.max_health
	add_to_group("elite_enemies")
	tags = ["enemy", "elite", "metal"]

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, global_position, 80.0, Color(1.0, 0.8, 0.2, 0.9), 0.3)
	CombatEffects.spawn_text_popup(container, global_position, "ЭЛИТНЫЙ ВРАГ!", Color(1.0, 0.85, 0.2, 1.0))

func die() -> void:
	if is_dead:
		return
	super.die()

func spawn_drop() -> void:
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root

	# Drop treasure chest on death
	if chest_scene:
		var chest = chest_scene.instantiate() as Node2D
		chest.global_position = global_position
		container.call_deferred("add_child", chest)

	# Elite reward: guaranteed high-tier (Greater) XP gem (50 XP)
	if xp_gem_scene:
		var gem = xp_gem_scene.instantiate() as Node2D
		if gem:
			if "xp_value" in gem:
				gem.xp_value = 50
			gem.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
			container.call_deferred("add_child", gem)

	# Elite reward: guaranteed gold drop (5 gold)
	if gold_coin_scene:
		var coin = gold_coin_scene.instantiate() as Node2D
		if coin:
			if "gold_value" in coin:
				coin.gold_value = 5
			coin.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
			container.call_deferred("add_child", coin)
