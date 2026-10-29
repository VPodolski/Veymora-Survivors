class_name EliteEnemyController
extends EnemyController

@export var chest_scene: PackedScene = preload("res://scenes/pickups/chest.tscn")

func _ready() -> void:
	stats = EnemyStats.new()
	stats.max_health = 180.0
	stats.move_speed = 90.0
	stats.contact_damage = 20.0
	super._ready()
	current_health = stats.max_health
	add_to_group("elite_enemies")
	tags = ["enemy", "elite", "metal"]

func die() -> void:
	if is_dead:
		return

	# Drop treasure chest on death
	if chest_scene:
		var chest = chest_scene.instantiate() as Node2D
		chest.global_position = global_position
		var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
		container.call_deferred("add_child", chest)

	super.die()
