class_name Exit
extends Area2D
## Touch it to finish the level.

@onready var ring: Line2D = $Ring

var _clock: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		Game.win()


func _process(delta: float) -> void:
	_clock += delta
	ring.modulate.a = 0.6 + sin(_clock * 4.0) * 0.3
