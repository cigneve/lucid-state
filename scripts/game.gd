extends Node
## Autoload "Game": the shared state of the run, plus a small event bus.
## Any script can read Game.curse / Game.form / Game.world, and can listen to
## the signals below without needing a reference to the player.

signal state_changed(state: int)                 # Cfg.State
signal form_changed(form: int)                   # Cfg.Form
signal world_changed(world: int)                 # 0 = normal, 1 = mirror
signal message(text: String, seconds: float)     # a line at the bottom of the screen
signal flashed                                   # white screen flash (mirror)
signal heartbeat                                 # one heartbeat happened
signal dialogue_changed(speaker: String, text: String)
signal dialogue_ended

var state: int = Cfg.State.TITLE
var state_time: float = 0.0      # seconds since the state last changed
var curse: float = 0.0
var form: int = Cfg.Form.SOLID
var world: int = 0
var door_open: bool = false      # true once every seal of the level is done
var form_lock: int = -1          # -1 = none; a Cfg.Form value pins the form (gates)
var race_on: bool = false        # the curse runs faster once a "race" level's door opens
var level_time: float = 0.0
var level_index: int = 1
var level_count: int = 1
var death_text: String = ""
var in_dialogue: bool = false

var _speaker: String = ""
var _lines: PackedStringArray = PackedStringArray()
var _line: int = 0


func _process(delta: float) -> void:
	state_time += delta


func set_state(new_state: int) -> void:
	state = new_state
	state_time = 0.0
	if new_state != Cfg.State.PLAY:
		end_dialogue()
	state_changed.emit(new_state)


func reset_run() -> void:
	curse = 0.0
	door_open = false
	form_lock = -1
	race_on = false
	level_time = 0.0
	end_dialogue()
	set_form(Cfg.Form.SOLID)
	set_world(0)


func set_form(new_form: int) -> void:
	form = new_form
	form_changed.emit(new_form)


func set_world(new_world: int) -> void:
	world = new_world
	world_changed.emit(new_world)


func say(text: String, seconds: float = 3.0) -> void:
	message.emit(text, seconds)


func die(text: String) -> void:
	if state != Cfg.State.PLAY:
		return
	death_text = text
	Sfx.play("die")
	set_state(Cfg.State.DEAD)


func fall_forever() -> void:
	if state != Cfg.State.PLAY:
		return
	Sfx.play("fall")
	set_state(Cfg.State.FALLING)


func win() -> void:
	if state != Cfg.State.PLAY:
		return
	Sfx.play("win")
	set_state(Cfg.State.WON)


# ------------------------------------------------------------ dialogue

func start_dialogue(speaker: String, lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	_speaker = speaker
	_lines = lines
	_line = 0
	in_dialogue = true
	Sfx.play("talk")
	dialogue_changed.emit(_speaker, _lines[0])


func advance_dialogue() -> void:
	if not in_dialogue:
		return
	_line += 1
	Sfx.play("talk")
	if _line >= _lines.size():
		end_dialogue()
	else:
		dialogue_changed.emit(_speaker, _lines[_line])


func end_dialogue() -> void:
	if not in_dialogue:
		return
	in_dialogue = false
	dialogue_ended.emit()
