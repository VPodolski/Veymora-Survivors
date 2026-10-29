class_name ReactionContext
extends RefCounted

var source: Node = null
var target: EnemyController = null
var tags: Array = []
var hit_position: Vector2 = Vector2.ZERO
var damage: float = 0.0
var depth: int = 0

func _init(p_source: Node = null, p_target: EnemyController = null, p_tags: Array = [], p_pos: Vector2 = Vector2.ZERO, p_dmg: float = 0.0, p_depth: int = 0) -> void:
	source = p_source
	target = p_target
	tags = p_tags
	hit_position = p_pos
	damage = p_dmg
	depth = p_depth

func has_tag(tag_name: String) -> bool:
	return tags.has(tag_name)

