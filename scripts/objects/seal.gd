class_name Seal
extends Interactable
## Base class for plates, levers and lamps.
## When every Seal in a level is done, the level's door opens (see level.gd).

signal completed(seal: Seal)

## Shown at the bottom of the screen when this seal is done.
@export var done_text: String = ""

var done: bool = false


func complete() -> void:
	if done:
		return
	done = true
	Sfx.play("plate")
	_on_done()
	completed.emit(self)


## Override: change how the seal looks once it is done.
func _on_done() -> void:
	pass
