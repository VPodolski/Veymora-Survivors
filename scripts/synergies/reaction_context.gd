class_name ReactionContext
extends RefCounted

var source: Node = null
var target: EnemyController = null
var tags: Array = []
var hit_position: Vector2 = Vector2.ZERO
var damage: float = 0.0
var depth: int = 0
var allow_reactions: bool = true
var excluded_targets: Array = []
var cascade_id: String = ""
var is_secondary: bool = false
var damage_type: String = "direct"

static var _next_cascade_int: int = 1

func _init(
	p_source: Node = null,
	p_target: EnemyController = null,
	p_tags: Array = [],
	p_pos: Vector2 = Vector2.ZERO,
	p_dmg: float = 0.0,
	p_depth: int = 0,
	p_allow: bool = true,
	p_excluded: Array = [],
	p_cascade_id: String = "",
	p_secondary: bool = false,
	p_dmg_type: String = "direct"
) -> void:
	source = p_source
	target = p_target
	tags = p_tags
	hit_position = p_pos
	damage = p_dmg
	depth = p_depth
	allow_reactions = p_allow
	excluded_targets = p_excluded.duplicate() if p_excluded else []
	if p_cascade_id.is_empty():
		_next_cascade_int += 1
		cascade_id = "cas_" + str(_next_cascade_int)
	else:
		cascade_id = p_cascade_id
	is_secondary = p_secondary
	damage_type = p_dmg_type

func has_tag(tag_name: String) -> bool:
	return tags.has(tag_name)

func create_sub_context(new_target: EnemyController, new_pos: Vector2, new_dmg: float, new_tags: Array = [], allow_sub_reactions: bool = false) -> ReactionContext:
	var sub_tags = new_tags if not new_tags.is_empty() else tags
	var sub = ReactionContext.new(
		source,
		new_target,
		sub_tags,
		new_pos,
		new_dmg,
		depth + 1,
		allow_sub_reactions,
		excluded_targets,
		cascade_id,
		true,
		"reaction"
	)
	return sub
