class_name Gate
extends Area2D
## A form gate. Crossing it pins your form (SOLID or HALF) until the next gate.
## The curse keeps ticking underneath — measure the route, then step through.

const COLORS := [Color(1.0, 0.804, 0.471), Color(0.549, 0.941, 1.0)]

## 0 = Solid, 1 = Half (matches Cfg.Form.SOLID / Cfg.Form.HALF).
@export_enum("Solid", "Half") var lock_form: int = 0
## Shown when the lock takes; empty uses a default line.
@export var lock_text: String = ""

@onready var glow: Polygon2D = $Glow
@onready var line: Line2D = $Line

var _clock: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	if Game.form_lock == lock_form:
		return
	Game.form_lock = lock_form
	player.refresh_form()
	if lock_text != "":
		Game.say(lock_text, 2.5)
	else:
		Game.say("Hâlin mühürlendi: %s" % ["opak" if lock_form == 0 else "yarı saydam"], 2.5)


func _process(delta: float) -> void:
	_clock += delta
	var locked: bool = Game.form_lock == lock_form
	var a: float = 0.9 if locked else 0.4 + sin(_clock * 3.0) * 0.1
	var c: Color = COLORS[lock_form]
	line.default_color = Color(c, a)
	glow.color = Color(c, 0.28 * a)
