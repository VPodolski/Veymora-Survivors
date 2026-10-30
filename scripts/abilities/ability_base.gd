class_name AbilityBase
extends Node2D

@export var ability_id: String = ""
@export var ability_name: String = ""
@export_multiline var description: String = ""
@export var category: String = "general"
@export var current_level: int = 1
@export var max_level: int = 5
@export var base_cooldown: float = 1.0
@export var base_damage: float = 15.0

var cooldown_timer: float = 0.0
var player_owner: PlayerController = null

func _ready() -> void:
	find_owner()

func find_owner() -> void:
	if not player_owner:
		var parent = get_parent()
		while parent != null:
			if parent is PlayerController:
				player_owner = parent
				break
			parent = parent.get_parent()

func get_effective_cooldown() -> float:
	var mult = 1.0
	if player_owner and player_owner.has_meta("cooldown_mult"):
		mult = player_owner.get_meta("cooldown_mult")
	if player_owner and player_owner.get_meta("in_rune_zone", false):
		mult *= 0.75
	return max(0.2, base_cooldown * mult)

func get_effective_damage() -> float:
	var mult = 1.0
	if player_owner and player_owner.has_meta("spell_power_mult"):
		mult = player_owner.get_meta("spell_power_mult")
	if player_owner and player_owner.has_meta("obsidian_heart_bonus"):
		mult += player_owner.get_meta("obsidian_heart_bonus")
	if player_owner and player_owner.get_meta("in_rune_zone", false):
		mult += 0.20
	return base_damage * mult

func upgrade() -> void:
	if current_level < max_level:
		current_level += 1
		apply_level_modifiers()

func apply_level_modifiers() -> void:
	pass

func get_next_upgrade_description() -> String:
	return "Увеличение характеристик заклинания"

