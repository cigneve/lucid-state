extends ParallaxBackground
## Sky gradient + three parallax silhouettes. Recoloured when the world flips.

@onready var sky: Sprite2D = $Sky/Gradient
@onready var far: Polygon2D = $Far/Silhouette
@onready var mid: Polygon2D = $Mid/Silhouette
@onready var near: Polygon2D = $Near/Silhouette

# [sky top, sky bottom, far, mid, near] for the normal and the mirror world.
var _palettes: Array = [
	[Color.html("#07080f"), Color.html("#1b1230"), Color.html("#120d22"), Color.html("#0d0a19"), Color.html("#08070f")],
	[Color.html("#050d0e"), Color.html("#2a0e1e"), Color.html("#1d0c18"), Color.html("#130812"), Color.html("#09050a")],
]


func _ready() -> void:
	Game.world_changed.connect(_on_world_changed)
	Game.state_changed.connect(_on_state_changed)
	_on_world_changed(Game.world)


func _on_world_changed(world_index: int) -> void:
	var pal: Array = _palettes[world_index]
	var tex := sky.texture as GradientTexture2D
	tex.gradient.set_color(0, pal[0])
	tex.gradient.set_color(1, pal[1])
	far.color = pal[2]
	mid.color = pal[3]
	near.color = pal[4]


func _on_state_changed(new_state: int) -> void:
	var show_hills: bool = new_state != Cfg.State.FALLING
	far.visible = show_hills
	mid.visible = show_hills
	near.visible = show_hills
