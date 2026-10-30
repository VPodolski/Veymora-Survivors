class_name RunConfig
extends RefCounted

var arena_id: String = "forgotten_forest"
var active_modifiers: Array[String] = []
var custom_params: Dictionary = {}

func _init(p_arena_id: String = "forgotten_forest", p_modifiers: Array[String] = [], p_params: Dictionary = {}) -> void:
	arena_id = p_arena_id
	active_modifiers = p_modifiers
	custom_params = p_params

func has_modifier(mod_id: String) -> bool:
	return active_modifiers.has(mod_id)

func duplicate_config() -> RefCounted:
	var copy = get_script().new(arena_id, active_modifiers.duplicate(), custom_params.duplicate())
	return copy
