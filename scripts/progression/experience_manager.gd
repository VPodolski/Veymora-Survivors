class_name ExperienceManager
extends Node

signal experience_changed(current_xp: int, required_xp: int)
signal level_up(new_level: int)
signal experience_collected(amount: int)

@export var current_level: int = 1
@export var current_xp: int = 0
@export var base_required_xp: int = 25

var required_xp: int = 25

func _ready() -> void:
	add_to_group("experience_manager")
	required_xp = base_required_xp
	call_deferred("_emit_initial")

func _emit_initial() -> void:
	experience_changed.emit(current_xp, required_xp)

func add_experience(amount: int) -> void:
	if amount <= 0:
		return

	experience_collected.emit(amount)
	current_xp += amount

	while current_xp >= required_xp:
		current_xp -= required_xp
		current_level += 1
		required_xp = calculate_required_xp(current_level)
		level_up.emit(current_level)

	experience_changed.emit(current_xp, required_xp)

func calculate_required_xp(level: int) -> int:
	# Smooth scaling curve: 25, 48, 79, 121, 178...
	return int(round(base_required_xp * pow(level, 1.35)))

