class_name Zone
extends Area2D
## A light or shadow zone.
##
## In the level editor: place it, then SCALE it. Its base size is one tile
## (32x32, origin at the top-left corner), so scale (4, 3) covers 4x3 tiles.
##
## Normal world: light heals the curse, shadow feeds it.
## Mirror world: the two swap.

enum Kind { LIGHT, SHADOW }

const BASE := 32.0
const GLOW_TEX := 128.0

@export var kind: Kind = Kind.LIGHT
## A dormant light zone does nothing until a Lamp is lit somewhere in the level.
@export var dormant: bool = false

@onready var tint: Polygon2D = $Tint
@onready var glow: Sprite2D = get_node_or_null("Glow") as Sprite2D
@onready var bulb: Polygon2D = get_node_or_null("Bulb") as Polygon2D
@onready var mist: CPUParticles2D = get_node_or_null("Mist") as CPUParticles2D

var _clock: float = 0.0


func _ready() -> void:
	if dormant:
		add_to_group("dormant_zones")
	# The node is scaled to cover its tiles; undo that for the round things
	# inside so glows stay circular and mist blobs keep their size.
	var size: Vector2 = Vector2(BASE, BASE) * scale
	var undo := Vector2(1.0 / scale.x, 1.0 / scale.y)
	if glow:
		var radius := maxf(size.x, size.y) * 0.9
		glow.scale = undo * (radius * 2.0 / GLOW_TEX)
	if bulb:
		bulb.scale = undo
		bulb.position = Vector2(BASE / 2.0, 6.0 / scale.y)
	if mist:
		mist.scale = undo
		mist.emission_rect_extents = size / 2.0
		mist.restart()
	Game.world_changed.connect(_refresh)
	_refresh()


func is_light() -> bool:
	return kind == Kind.LIGHT


func is_active() -> bool:
	return not dormant


## Called on every dormant zone when a Lamp is lit.
func wake() -> void:
	dormant = false
	_refresh()


func _refresh(_world: int = 0) -> void:
	if kind == Kind.LIGHT:
		var c: Color = Cfg.LIGHT_COLORS[Game.world]
		tint.color = Color(c, 0.04 if dormant else 0.07)
		if glow:
			glow.visible = not dormant
			glow.modulate = Color(c, 0.45)
		if bulb:
			bulb.color = Color(c, 0.25 if dormant else 0.9)
	else:
		var c: Color = Cfg.SHADOW_COLORS[Game.world]
		tint.color = Color(c, 0.28)
		if mist:
			mist.modulate = Color(c, 0.35)


func _process(delta: float) -> void:
	_clock += delta
	if glow and glow.visible:
		glow.modulate.a = 0.45 * (0.9 + sin(_clock * 3.0 + global_position.x) * 0.05)
