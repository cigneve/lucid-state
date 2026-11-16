class_name Plate
extends Seal
## Pressure plate: only a SOLID body standing on it presses it.

@onready var pad: Polygon2D = $Pad


func _physics_process(_delta: float) -> void:
	if done or Game.state != Cfg.State.PLAY or Game.form != Cfg.Form.SOLID:
		return
	for body in get_overlapping_bodies():
		var player := body as Player
		if player and player.is_on_floor():
			complete()
			return


func _on_done() -> void:
	pad.color = Color(0.47, 1.0, 0.63, 0.9)
	pad.scale.y = 0.5
