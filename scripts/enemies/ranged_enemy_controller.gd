class_name RangedEnemyController
extends EnemyController

@export var projectile_scene: PackedScene = preload("res://scenes/combat/projectile.tscn")

var shoot_cooldown: float = 3.2
var shoot_timer: float = 0.0
var is_casting: bool = false
var cast_timer: float = 0.0
var telegraph_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	stats = EnemyStats.new()
	stats.max_health = 26.0
	stats.move_speed = 75.0
	stats.contact_damage = 8.0
	super._ready()
	tags = ["enemy", "ranged", "cultist"]
	shoot_timer = randf_range(1.5, 3.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_casting:
		cast_timer -= delta
		velocity = Vector2.ZERO
		if is_instance_valid(target_player):
			telegraph_dir = (target_player.global_position - global_position).normalized()
		queue_redraw()
		if cast_timer <= 0.0:
			is_casting = false
			_fire_projectile()
		move_and_slide()
		return

	shoot_timer -= delta
	if shoot_timer <= 0.0 and is_instance_valid(target_player) and target_player.is_alive:
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= 550.0:
			start_casting()
			return

	# Kite movement: maintain distance around 320px
	if is_instance_valid(target_player) and target_player.is_alive:
		var to_player = target_player.global_position - global_position
		var dist = to_player.length()
		var dir = to_player.normalized()

		if dist < 220.0:
			# Back away from player
			velocity = -dir * get_effective_speed()
		elif dist > 380.0:
			# Advance towards player
			velocity = dir * get_effective_speed()
		else:
			# Strafe / hold position
			velocity = Vector2(-dir.y, dir.x) * (get_effective_speed() * 0.4)

		if visual_node and visual_node.has_method("update_facing"):
			visual_node.update_facing(dir)

		move_and_slide()
		check_player_contact()
	else:
		super._physics_process(delta)

func start_casting() -> void:
	is_casting = true
	cast_timer = 0.40
	shoot_timer = shoot_cooldown
	if is_instance_valid(target_player):
		telegraph_dir = (target_player.global_position - global_position).normalized()
	if visual_node and visual_node.has_method("set_casting"):
		visual_node.set_casting(true)
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_ring(container, global_position, 6.0, 22.0, Color(1.0, 0.2, 0.35, 0.8), 0.35, 1.8)
	CombatEffects.spawn_impact_sparks(container, global_position, Color(1.0, 0.2, 0.4, 0.9), 4)
	queue_redraw()

func _fire_projectile() -> void:
	if visual_node and visual_node.has_method("set_casting"):
		visual_node.set_casting(false)
	queue_redraw()
	if not is_instance_valid(target_player) or not projectile_scene:
		return
	var dir = (target_player.global_position - global_position).normalized()
	var proj = projectile_scene.instantiate() as Projectile
	proj.faction = Projectile.Faction.ENEMY
	proj.global_position = global_position + dir * 18.0
	proj.direction = dir
	proj.damage = 9.0
	proj.speed = 245.0
	proj.projectile_color = Color(0.92, 0.15, 0.35, 1.0)
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	container.add_child(proj)

func _draw() -> void:
	if is_casting and not is_dead:
		# Telegraphing targeting laser line
		var line_end = telegraph_dir * 140.0
		draw_line(Vector2.ZERO, line_end, Color(1.0, 0.15, 0.3, 0.75), 1.6)
		# Reticle crosshair dot at the tip
		draw_circle(line_end, 3.5, Color(1.0, 0.2, 0.35, 0.9))
		draw_circle(line_end, 1.5, Color.WHITE)
