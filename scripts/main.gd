extends Node
## Game flow: title -> play -> dead / falling / won -> next level.
## Add or reorder level scenes in the `levels` list in the Inspector.

@export var levels: Array[PackedScene] = []

@onready var world: Node2D = $World
@onready var player: Player = $World/Player

var level: Level = null


func _ready() -> void:
	Game.level_count = levels.size()
	Game.state_changed.connect(_on_state_changed)
	Game.set_state(Cfg.State.TITLE)


func _unhandled_input(event: InputEvent) -> void:
	# Any key starts the game from the title screen.
	if Game.state != Cfg.State.TITLE:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and not event.is_action("toggle_debug"):
		start_game()


func _process(_delta: float) -> void:
	if Game.state == Cfg.State.TITLE:
		return
	if Input.is_action_just_pressed("restart"):
		load_level(Game.level_index)
		return
	var ended: bool = Game.state == Cfg.State.DEAD or Game.state == Cfg.State.WON
	if ended and Game.state_time > 0.6 and Input.is_action_just_pressed("confirm"):
		var next: int = Game.level_index
		if Game.state == Cfg.State.WON:
			next = (next + 1) % levels.size()
		load_level(next)
		Game.say(level.level_name, 3.0)


func start_game() -> void:
	if levels.is_empty():
		push_error("Main: the 'levels' list is empty.")
		return
	load_level(0)
	Game.say("Ok tuşları / A D: yürü · Boşluk: zıpla · Shift: atıl · E: etkileşim", 5.0)


func load_level(index: int) -> void:
	if level:
		world.remove_child(level)
		level.queue_free()
	Game.level_index = index
	Game.reset_run()
	
	level = levels[index].instantiate() as Level
	world.add_child(level)
	world.move_child(level, 0)
	player.respawn(level.get_start(), level.get_bounds())
	Game.set_state(Cfg.State.PLAY)


func _on_state_changed(new_state: int) -> void:
	# Falling forever: the world drops away, only you and the dark remain.
	if level:
		level.visible = new_state != Cfg.State.FALLING
