class_name Npc
extends Interactable
## Someone to talk to. They only see you (and you only see them) in the forms
## ticked in `seen_by`.

@export var npc_name: String = "Biri"
@export_flags("Katı", "Yarı saydam", "Hayalet") var seen_by: int = 1
@export var lines: PackedStringArray = PackedStringArray()

@onready var visual: Node2D = $Visual
@onready var body_poly: Polygon2D = $Visual/Body
@onready var eye_l: Polygon2D = $Visual/EyeL
@onready var eye_r: Polygon2D = $Visual/EyeR

var _ghostly: bool = false


func _ready() -> void:
	super()
	_ghostly = (seen_by & (1 << Cfg.Form.GHOST)) != 0
	var eye_color := Color(1.0, 0.745, 0.353, 0.95)
	if _ghostly:
		body_poly.color = Color(0.588, 0.941, 1.0, 0.35)
		eye_color = Color(0.863, 1.0, 1.0, 0.9)
	eye_l.color = eye_color
	eye_r.color = eye_color


func _sees_player() -> bool:
	return (seen_by & (1 << Game.form)) != 0


func can_interact() -> bool:
	return _sees_player() and not lines.is_empty()


func interact(_player: Player) -> void:
	Game.start_dialogue(npc_name, lines)


func _process(delta: float) -> void:
	super(delta)
	visual.visible = _sees_player()
	if _ghostly:
		visual.position.y = sin(_clock * 2.0) * 3.0 - 4.0
