class_name HookBlock
extends Area2D
## A grapple anchor. Only a HALF body can latch onto it: press `action` (L) with
## it in the aim direction to fire a hook and be pulled in.

const CYAN := Color(0.549, 0.941, 1.0)

@onready var pad: Polygon2D = $Pad
@onready var ring: Line2D = $Ring


func _ready() -> void:
	add_to_group("hook_blocks")


func _process(_delta: float) -> void:
	var half: bool = Game.form == Cfg.Form.HALF
	pad.color = Color(CYAN, 0.28 if half else 0.12)
	ring.default_color = Color(CYAN, 0.95 if half else 0.35)
