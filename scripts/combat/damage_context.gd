class_name DamageContext
extends RefCounted

var source: Node = null
var source_id: String = ""
var target: Node = null
var hit_position: Vector2 = Vector2.ZERO
var amount: float = 0.0
var tags: Array = []
var is_secondary: bool = false
var is_dot: bool = false
var depth: int = 0
var cascade_id: String = ""
var allow_reactions: bool = true
var excluded_targets: Array = []

func _init(
	p_source: Node = null,
	p_target: Node = null,
	p_amount: float = 0.0,
	p_tags: Array = [],
	p_source_id: String = "",
	p_hit_pos: Vector2 = Vector2.ZERO,
	p_is_secondary: bool = false,
	p_depth: int = 0,
	p_cascade_id: String = "",
	p_allow_reactions: bool = true,
	p_excluded_targets: Array = []
) -> void:
	source = p_source
	target = p_target
	amount = p_amount
	tags = p_tags.duplicate()
	source_id = p_source_id
	hit_position = p_hit_pos if p_hit_pos != Vector2.ZERO else (p_target.global_position if p_target else Vector2.ZERO)
	is_secondary = p_is_secondary
	depth = p_depth
	allow_reactions = p_allow_reactions
	excluded_targets = p_excluded_targets.duplicate()

	if p_cascade_id.is_empty():
		cascade_id = str(Time.get_ticks_usec()) + "_" + str(randi() % 10000)
	else:
		cascade_id = p_cascade_id

func has_tag(tag_name: String) -> bool:
	return tags.has(tag_name)

func add_tag(tag_name: String) -> void:
	if not tags.has(tag_name):
		tags.append(tag_name)

func create_sub_context(
	new_target: Node,
	new_pos: Vector2,
	new_amount: float,
	new_tags: Array = [],
	p_allow_reactions: bool = true
) -> DamageContext:
	var merged_tags = tags.duplicate()
	for t in new_tags:
		if not merged_tags.has(t):
			merged_tags.append(t)
	var sub = get_script().new(
		source,
		new_target,
		new_amount,
		merged_tags,
		source_id,
		new_pos,
		true, # is_secondary
		depth + 1,
		cascade_id,
		p_allow_reactions,
		excluded_targets
	)
	return sub
