class_name SynergyDefinition
extends RefCounted

var id: String = ""
var name_key: String = ""
var default_name: String = ""
var desc_key: String = ""
var default_desc: String = ""
var formula: String = ""
var participating_tags: Array[String] = []
var required_statuses: Array[String] = []
var consumed_statuses: Array[String] = []
var trigger_event: String = "hit" # "hit", "death", "aura"
var priority: int = 10 # Higher priority checked first
var cooldown: float = 0.35 # Per-target cooldown in seconds
var base_damage: float = 0.0
var area_radius: float = 0.0
var secondary_status: String = ""
var secondary_status_duration: float = 0.0
var visual_color: Color = Color.WHITE
var audio_sfx_key: String = ""
var badge_text: String = "СИНЕРГИЯ"

func _init(
	p_id: String,
	p_def_name: String,
	p_def_desc: String,
	p_formula: String,
	p_tags: Array[String],
	p_req_statuses: Array[String],
	p_consumed_statuses: Array[String],
	p_trigger_event: String,
	p_priority: int,
	p_cooldown: float,
	p_damage: float,
	p_radius: float,
	p_sec_status: String = "",
	p_sec_duration: float = 0.0,
	p_color: Color = Color.WHITE,
	p_sfx_key: String = ""
) -> void:
	id = p_id
	name_key = "syn_" + p_id + "_name"
	default_name = p_def_name
	desc_key = "syn_" + p_id + "_desc"
	default_desc = p_def_desc
	formula = p_formula
	participating_tags = p_tags
	required_statuses = p_req_statuses
	consumed_statuses = p_consumed_statuses
	trigger_event = p_trigger_event
	priority = p_priority
	cooldown = p_cooldown
	base_damage = p_damage
	area_radius = p_radius
	secondary_status = p_sec_status
	secondary_status_duration = p_sec_duration
	visual_color = p_color
	audio_sfx_key = p_sfx_key if not p_sfx_key.is_empty() else p_id

