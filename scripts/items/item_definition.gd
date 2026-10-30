class_name ItemDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var icon_color: Color = Color.WHITE
@export var tags: Array = []
@export var icon_symbol: String = "gem"
@export var rarity: String = "РЕДКОЕ"

func _init(p_id: String = "", p_name: String = "", p_desc: String = "", p_color: Color = Color.WHITE, p_tags: Array = [], p_symbol: String = "gem", p_rarity: String = "РЕДКОЕ") -> void:
	id = p_id
	name = p_name
	description = p_desc
	icon_color = p_color
	tags = p_tags
	icon_symbol = p_symbol
	rarity = p_rarity
