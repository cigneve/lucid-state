class_name SealRunes
extends Marker2D
## Glowing dots, one per seal in the level. Put it on a door so the player can
## see how many seals are left. (Only shown when the level has 2+ seals.)

var done: int = 0
var total: int = 0


func set_progress(done_count: int, total_count: int) -> void:
	done = done_count
	total = total_count
	queue_redraw()


func _draw() -> void:
	if total < 2:
		return
	for i in total:
		var y := (i - (total - 1) / 2.0) * 22.0
		var color := Color(0.55, 1.0, 0.745, 0.95) if i < done else Color(1.0, 1.0, 1.0, 0.12)
		draw_circle(Vector2(0.0, y), 5.0, color)
