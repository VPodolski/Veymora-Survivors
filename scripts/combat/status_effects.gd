class_name StatusEffects
extends RefCounted

const STATUS_CHARGED = "charged"
const STATUS_SLOWED = "slowed"
const STATUS_UNSTABLE = "unstable"
const STATUS_MARKED = "marked"
const STATUS_BURNING = "burning"

# Helper data for status visual colors
static func get_status_color(status_name: String) -> Color:
	match status_name:
		STATUS_CHARGED:
			return Color(0.4, 0.7, 1.0, 0.9) # Electric cyan
		STATUS_SLOWED:
			return Color(0.2, 0.9, 0.9, 0.8) # Frost cyan
		STATUS_UNSTABLE:
			return Color(0.85, 0.25, 1.0, 0.9) # Void purple
		STATUS_MARKED:
			return Color(1.0, 0.3, 0.2, 0.9) # Crimson skull
		STATUS_BURNING:
			return Color(1.0, 0.55, 0.1, 0.9) # Blaze amber
		_:
			return Color.WHITE

