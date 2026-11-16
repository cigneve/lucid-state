class_name Lever
extends Seal
## Lever: press E while not a ghost (a ghost's hand passes through).

@onready var arm: Line2D = $Arm


func can_interact() -> bool:
	return not done


func interact(_player: Player) -> void:
	if Game.form == Cfg.Form.GHOST:
		Game.say("Elin şalterin içinden geçiyor.", 2.0)
		return
	complete()


func _on_done() -> void:
	arm.set_point_position(1, Vector2(9.0, -24.0))
	arm.default_color = Color(0.47, 1.0, 0.63, 0.95)
