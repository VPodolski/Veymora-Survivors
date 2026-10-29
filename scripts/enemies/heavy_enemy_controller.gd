class_name HeavyEnemyController
extends EnemyController

func _ready() -> void:
	stats = EnemyStats.new()
	stats.max_health = 85.0
	stats.move_speed = 52.0
	stats.contact_damage = 22.0
	super._ready()
	tags = ["enemy", "heavy", "golem", "spatial"]
