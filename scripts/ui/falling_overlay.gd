extends Control
## Streaks rushing upward: you are falling through everything.


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var t: float = Game.state_time
	var base: Color = Cfg.PLAYER_COLORS[Game.world]
	var col := Color(base, 0.25)
	for i in 40:
		var x := fposmod(i * 97.0, Cfg.VIEW_W)
		var y := Cfg.VIEW_H - fposmod(t * (600.0 + (i % 7) * 120.0) + i * 53.0, Cfg.VIEW_H + 200.0)
		draw_line(Vector2(x, y), Vector2(x, y + 40.0 + (i % 5) * 20.0), col, 1.0)
