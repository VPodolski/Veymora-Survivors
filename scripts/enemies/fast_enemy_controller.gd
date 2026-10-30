class_name FastEnemyController
extends EnemyController

func _ready() -> void:
	stats = EnemyStats.new()
	stats.max_health = 16.0
	stats.move_speed = 155.0
	stats.contact_damage = 8.0
	super._ready()
	tags = ["enemy", "fast", "shadow"]

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

