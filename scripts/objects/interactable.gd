class_name Interactable
extends Area2D
## Base class for the things the player touches or uses with E.
## Give the scene a Label child named "Prompt" to get a floating key hint.

## If several things are in reach, the highest priority wins.
@export var interact_priority: int = 0

@onready var prompt: Label = get_node_or_null("Prompt") as Label

var _prompt_y: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	if prompt:
		_prompt_y = prompt.position.y
		prompt.hide()


func _process(delta: float) -> void:
	_clock += delta
	if prompt == null:
		return
	prompt.visible = (Game.state == Cfg.State.PLAY and not Game.in_dialogue
			and can_interact() and has_overlapping_bodies())
	prompt.position.y = _prompt_y + sin(_clock * 5.0) * 2.0


## Override: can the player press E on this right now?
func can_interact() -> bool:
	return false


## Override: the player pressed E on this.
func interact(_player: Player) -> void:
	pass
