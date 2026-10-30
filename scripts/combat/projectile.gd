class_name Projectile
extends Area2D

enum Faction { PLAYER, ENEMY }

@export var faction: Faction = Faction.PLAYER
@export var speed: float = 480.0
@export var damage: float = 16.0
@export var lifetime: float = 2.2
@export var pierce_count: int = 1
@export var projectile_color: Color = Color(0.2, 0.8, 1.0, 1.0)
@export var tags: Array = ["arcane", "projectile"]
@export var is_returning: bool = false
@export var is_evolved: bool = false

var direction: Vector2 = Vector2.RIGHT
var elapsed_lifetime: float = 0.0
var hits_remaining: int = 1
var hit_enemies: Array[EnemyController] = []
var has_hit_player: bool = false
var has_turned_back: bool = false
var player_ref: Node2D = null

func _ready() -> void:
	hits_remaining = pierce_count
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()

	# Configure collision layer and mask according to faction
	collision_layer = 8 # Layer 4 (Projectiles)
	if faction == Faction.PLAYER:
		collision_mask = 4 # Layer 3 (Enemies)
		find_player()
	else:
		collision_mask = 1 # Layer 1 (Player)

func find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0] as Node2D

func _physics_process(delta: float) -> void:
	elapsed_lifetime += delta

	# Returning trajectory logic (Hourglass artifact / Evolution) - Player only
	if faction == Faction.PLAYER and is_returning and elapsed_lifetime >= lifetime * 0.45:
		if not has_turned_back:
			has_turned_back = true
			hit_enemies.clear() # Allow hitting enemies again on the way back

		if is_instance_valid(player_ref):
			var to_player = (player_ref.global_position - global_position).normalized()
			direction = direction.lerp(to_player, 6.0 * delta).normalized()
			rotation = direction.angle()

	if elapsed_lifetime >= lifetime or abs(global_position.x) > 1300.0 or abs(global_position.y) > 950.0:
		queue_free()
		return

	global_position += direction * speed * delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if faction == Faction.PLAYER:
		_handle_player_projectile_hit(body)
	elif faction == Faction.ENEMY:
		_handle_enemy_projectile_hit(body)

func _handle_player_projectile_hit(body: Node2D) -> void:
	if body is EnemyController and not body.is_dead:
		if not hit_enemies.has(body):
			hit_enemies.append(body)
			body.take_damage(damage)

			# Trigger synergy reaction
			var engines = get_tree().get_nodes_in_group("synergy_engine")
			if engines.size() > 0:
				var ctx = ReactionContext.new(self, body, tags, global_position, damage, 0)
				engines[0].on_hit_landed(ctx)

			hits_remaining -= 1
			if hits_remaining <= 0 and not is_returning:
				destroy()

func _handle_enemy_projectile_hit(body: Node2D) -> void:
	if has_hit_player:
		return

	if body is PlayerController and body.is_alive:
		has_hit_player = true
		body.take_damage(damage)

		var tree = get_tree()
		if tree:
			var container = tree.current_scene if tree.current_scene else tree.root
			CombatEffects.spawn_impact_sparks(container, global_position)
		destroy()

func destroy() -> void:
	set_deferred("monitoring", false)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.08)
	tween.tween_callback(queue_free)

func _draw() -> void:
	if faction == Faction.ENEMY:
		_draw_enemy_projectile()
		return

	# Evolved prismatic / rift visual
	if is_evolved:
		draw_circle(Vector2.ZERO, 13.0, Color(0.9, 0.3, 1.0, 0.35))
		draw_circle(Vector2.ZERO, 9.0, Color(0.3, 0.9, 1.0, 0.5))
		# Star prism shape
		var p1 = Vector2(10, 0)
		var p2 = Vector2(-12, -5)
		var p3 = Vector2(-6, 0)
		var p4 = Vector2(-12, 5)
		draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), Color(1.0, 0.85, 0.3, 1.0))
		draw_line(Vector2(-10, 0), Vector2(10, 0), Color.WHITE, 3.0)
	else:
		# Glow halo
		draw_circle(Vector2.ZERO, 8.0, Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.35))
		# Inner elongated bolt
		var front = Vector2(6, 0)
		var back = Vector2(-10, 0)
		var top = Vector2(-2, -3)
		var bot = Vector2(-2, 3)
		var pts = PackedVector2Array([front, top, back, bot])
		draw_colored_polygon(pts, projectile_color)
		# Center bright core
		draw_line(Vector2(-4, 0), Vector2(4, 0), Color.WHITE, 2.0)

func _draw_enemy_projectile() -> void:
	# Barbed crimson needle/dagger silhouette (distinct from diamonds and round gems)
	var needle_pts = PackedVector2Array([
		Vector2(14, 0),       # Needle sharp tip
		Vector2(1, -4.5),     # Upper barb
		Vector2(-2, -2.0),    # Narrow waist
		Vector2(-12, -4.0),   # Upper directional fin
		Vector2(-7, 0),       # Tail notch
		Vector2(-12, 4.0),    # Lower directional fin
		Vector2(-2, 2.0),     # Narrow waist
		Vector2(1, 4.5)       # Lower barb
	])
	draw_colored_polygon(needle_pts, Color(0.92, 0.12, 0.32, 1.0))

	# Bright razor-sharp spine
	draw_line(Vector2(-6, 0), Vector2(13, 0), Color(1.0, 0.8, 0.9, 0.95), 1.8)

	# Subtle trailing speed whisps along trajectory
	draw_line(Vector2(-12, -2.5), Vector2(-18, -3.2), Color(0.8, 0.1, 0.3, 0.45), 1.2)
	draw_line(Vector2(-12, 2.5), Vector2(-18, 3.2), Color(0.8, 0.1, 0.3, 0.45), 1.2)
