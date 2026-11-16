class_name KnockbackBlock
extends Area2D
## Anchored prop. A SOLID melee hit (`action` / L) only makes it flash and
## throws the player straight back along the aim; it never moves.

const ORANGE := Color(1.0, 0.706, 0.353)

@onready var pad: Polygon2D = $Pad
@onready var ring: Line2D = $Ring

var _flash: float = 0.0


func _ready() -> void:
	add_to_group("knockback_blocks")


## Called by the player when a melee strike lands on this block.
func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 6.0)
	var a: float = 0.85 + _flash * 0.15
	ring.default_color = Color(ORANGE, a)
	pad.color = Color(0.141, 0.102, 0.071, 1.0).lerp(Color(ORANGE, 1.0), _flash)
