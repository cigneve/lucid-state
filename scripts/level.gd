class_name Level
extends Node2D
## Root of every level scene.
##
## Rule of thumb: anything that BLOCKS is painted on a Terrain layer,
## anything you TOUCH or USE is a scene from scenes/objects.
##
## Each Terrain layer is one kind of wall. What blocks the player is decided by
## the player's collision mask (see player.gd); this script only shows it:
## solid things look solid, things you can pass through look faint.
##
## Plates, levers and lamps are "seals". When every seal in the level is done,
## the Door layer opens.

@export var level_name: String = "Bölüm"
## If on, the curse speeds up once the door opens (the run to the exit).
@export var race_after_seals: bool = false

@onready var stone: TileMapLayer = $Terrain/Stone
@onready var world_a: TileMapLayer = $Terrain/WorldA
@onready var world_b: TileMapLayer = $Terrain/WorldB
@onready var bars: TileMapLayer = $Terrain/Bars
@onready var walls: TileMapLayer = $Terrain/Walls
@onready var bridge: TileMapLayer = $Terrain/Bridge
@onready var door: TileMapLayer = $Terrain/Door
@onready var timed_a: TileMapLayer = $Terrain/TimedA
@onready var timed_b: TileMapLayer = $Terrain/TimedB
@onready var spikes: TileMapLayer = $Terrain/Spikes
@onready var start: Marker2D = $PlayerStart

var seals: Array[Seal] = []
var runes: Array[SealRunes] = []
var _clock: float = 0.0


func _ready() -> void:
	for node in find_children("*", "", true, false):
		if node is Seal:
			var seal := node as Seal
			seals.append(seal)
			seal.completed.connect(_on_seal_completed)
		elif node is SealRunes:
			runes.append(node as SealRunes)
	for r in runes:
		r.set_progress(0, seals.size())
	Game.form_changed.connect(_refresh_terrain)
	Game.world_changed.connect(_refresh_terrain)
	_refresh_terrain()


## Where the player's centre goes. PlayerStart marks the feet.
func get_start() -> Vector2:
	return start.global_position - Vector2(0.0, Cfg.PLAYER_H / 2.0 + 0.1)


## The level rectangle in pixels (from the Stone layer). Used for camera limits.
func get_bounds() -> Rect2:
	var cells: Rect2i = stone.get_used_rect()
	return Rect2(Vector2(cells.position) * Cfg.TILE, Vector2(cells.size) * Cfg.TILE)


func _on_seal_completed(seal: Seal) -> void:
	var done: int = 0
	for s in seals:
		if s.done:
			done += 1
	var total: int = seals.size()
	for r in runes:
		r.set_progress(done, total)
	if done == total:
		Game.door_open = true
		if race_after_seals:
			Game.race_on = true
			Game.say("Kapı açıldı. Zaman hızlanıyor.", 3.0)
		else:
			Game.say("Uzakta ağır bir şey açıldı.", 3.0)
	else:
		Game.say("%s (%d/%d)" % [seal.done_text, done, total], 3.0)


func _refresh_terrain(_value: int = 0) -> void:
	return
	var mirror: bool = Game.world == 1
	var ghost: bool = Game.form == Cfg.Form.GHOST
	var tint: Color = Cfg.EDGE_TINTS[Game.world]
	var echo := Color(1.0, 1.0, 1.0, 0.3)   # stone that belongs to the other world
	# stone.modulate = tint
	world_a.modulate = echo if mirror else tint
	world_b.modulate = tint if mirror else echo
	bars.modulate.a = 0.9 if Game.form == Cfg.Form.SOLID else 0.25
	walls.modulate.a = 0.35 if ghost else 1.0
	bridge.modulate.a = 0.85 if ghost else 0.12
	spikes.modulate.a = 0.35 if ghost else 1.0


func _process(delta: float) -> void:
	_clock += delta
	# Door: pulses while shut, fades to an outline once open.
	# door.modulate.a = 0.12 if Game.door_open else 0.8 + sin(_clock * 3.0) * 0.2
	if Game.form == Cfg.Form.GHOST:
		bridge.modulate.a = 0.85 + sin(_clock * 4.0) * 0.1
	_show_timed(timed_a, false)
	_show_timed(timed_b, true)


## Timed platforms glow while solid, flicker red before they switch off.
func _show_timed(layer: TileMapLayer, phase_b: bool) -> void:
	var t: float = Game.level_time
	if not Cfg.timed_on(phase_b, t):
		layer.modulate = Color(1.0, 1.0, 1.0, 0.12)
	elif Cfg.timed_warning(phase_b, t) and int(_clock * 12.0) % 2 == 0:
		layer.modulate = Color(1.0, 0.55, 0.47, 0.6)
	else:
		layer.modulate = Color.WHITE
