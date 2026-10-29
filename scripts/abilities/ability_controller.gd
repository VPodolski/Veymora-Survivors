class_name AbilityController
extends Node2D

@export var max_abilities: int = 6

var active_abilities: Dictionary = {} # ability_id: AbilityBase
var available_scenes: Dictionary = {
	"magic_bolt": preload("res://scenes/abilities/magic_bolt.tscn"),
	"runic_blade": preload("res://scenes/abilities/runic_blade.tscn")
}

func _ready() -> void:
	# Unlock starting spell: Magic Bolt
	call_deferred("unlock_ability", "magic_bolt")

func has_ability(id: String) -> bool:
	return active_abilities.has(id)

func get_ability(id: String) -> AbilityBase:
	return active_abilities.get(id, null)

func get_active_abilities() -> Array[AbilityBase]:
	var list: Array[AbilityBase] = []
	for ability in active_abilities.values():
		list.append(ability)
	return list

func unlock_ability(id: String) -> AbilityBase:
	if has_ability(id) or active_abilities.size() >= max_abilities:
		return null

	if available_scenes.has(id):
		var scene = available_scenes[id] as PackedScene
		var ability_instance = scene.instantiate() as AbilityBase
		add_child(ability_instance)
		active_abilities[id] = ability_instance
		return ability_instance

	return null

func upgrade_ability(id: String) -> bool:
	var ability = get_ability(id)
	if ability and ability.current_level < ability.max_level:
		ability.upgrade()
		return true
	return false
