class_name Lamp
extends Seal
## Dead lamp: only a GHOST's touch lights it. Lighting it wakes every dormant
## light zone in the level.

@onready var ring: Line2D = $Ring
@onready var glow: Sprite2D = $Glow


func _physics_process(_delta: float) -> void:
	if done or Game.state != Cfg.State.PLAY or Game.form != Cfg.Form.GHOST:
		return
	if has_overlapping_bodies():
		complete()


func _on_done() -> void:
	ring.default_color = Color(1.0, 0.9, 0.67, 0.95)
	glow.show()
	get_tree().call_group("dormant_zones", "wake")
