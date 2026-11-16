class_name Mirror
extends Interactable
## Mirror: press E to step into the other world.

@onready var shine: Polygon2D = $Shine


func can_interact() -> bool:
	return true


func interact(player: Player) -> void:
	Game.set_world(1 - Game.world)
	Game.flashed.emit()
	Sfx.play("mirror")
	Game.say("Aynanın öte yanı" if Game.world == 1 else "Bu taraf", 2.0)
	if player.is_embedded():
		Game.die("Aynadan geçerken taşa saplandın.")


func _process(delta: float) -> void:
	super(delta)
	shine.position.y = lerpf(-64.0, -14.0, (sin(_clock * 1.5) + 1.0) / 2.0)
