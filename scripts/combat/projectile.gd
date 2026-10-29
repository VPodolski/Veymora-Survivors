class_name Projectile
extends Area2D

@export var speed: float = 480.0
@export var damage: float = 16.0
@export var lifetime: float = 2.2
@export var pierce_count: int = 1
@export var projectile_color: Color = Color(0.2, 0.8, 1.0, 1.0)

var direction: Vector2 = Vector2.RIGHT
var elapsed_lifetime: float = 0.0
var hits_remaining: int = 1
var hit_enemies: Array[EnemyController] = []

func _ready() -> void:
	hits_remaining = pierce_count
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	elapsed_lifetime += delta
	if elapsed_lifetime >= lifetime:
		queue_free()
		return

	global_position += direction * speed * delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is EnemyController and not body.is_dead:
		if not hit_enemies.has(body):
			hit_enemies.append(body)
			body.take_damage(damage)
			hits_remaining -= 1

			if hits_remaining <= 0:
				destroy()

func destroy() -> void:
	set_deferred("monitoring", false)
	# Mini impact flash
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.08)
	tween.tween_callback(queue_free)

func _draw() -> void:
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
