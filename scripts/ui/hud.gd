extends CanvasLayer
## Everything drawn on top of the game: vignette, form dots, messages,
## dialogue box, title screen, death / win / falling screens.
## It only listens to the Game autoload; it knows nothing about the player.

@onready var vignette: TextureRect = $Vignette
@onready var flash_rect: ColorRect = $Flash
@onready var falling: Control = $Falling
@onready var form_dots: Node2D = $FormDots
@onready var mirror_mark: Node2D = $MirrorMark
@onready var debug_label: Label = $Debug
@onready var message_label: Label = $Message
@onready var dialogue_box: Panel = $Dialogue
@onready var speaker_label: Label = $Dialogue/Speaker
@onready var text_label: Label = $Dialogue/Text
@onready var end_screen: ColorRect = $EndScreen
@onready var end_title: Label = $EndScreen/Title
@onready var end_sub: Label = $EndScreen/Sub
@onready var title_screen: ColorRect = $TitleScreen
@onready var title_label: Label = $TitleScreen/Title
@onready var start_label: Label = $TitleScreen/Start

var _msg_time: float = 0.0
var _pulse: float = 0.0
var _flash: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	Game.state_changed.connect(_on_state_changed)
	Game.message.connect(_on_message)
	Game.flashed.connect(_on_flashed)
	Game.heartbeat.connect(_on_heartbeat)
	Game.dialogue_changed.connect(_on_dialogue_changed)
	Game.dialogue_ended.connect(_on_dialogue_ended)
	dialogue_box.hide()
	debug_label.hide()
	message_label.hide()
	_on_state_changed(Game.state)


func _process(delta: float) -> void:
	_clock += delta
	if Input.is_action_just_pressed("toggle_debug"):
		debug_label.visible = not debug_label.visible

	if Game.state == Cfg.State.TITLE:
		title_label.modulate.a = 0.55 + sin(_clock * 1.2) * 0.35
		start_label.modulate.a = 0.5 + sin(_clock * 4.0) * 0.4
		return

	# Vignette grows with the curse and pulses with the heartbeat.
	var k: float = Game.curse / 100.0
	_pulse = maxf(0.0, _pulse - delta * 3.0)
	vignette.modulate = Color(40.0 * _pulse * k / 255.0, 0.0, 0.0, 0.35 + k * 0.5)
	_flash = maxf(0.0, _flash - delta * 2.0)
	flash_rect.color.a = _flash * 0.6

	# Three faint dots: which form you are in. No timer on purpose.
	for i in form_dots.get_child_count():
		var dot := form_dots.get_child(i) as CanvasItem
		dot.modulate.a = 0.8 if i == Game.form else 0.15
	mirror_mark.visible = Game.world == 1

	_msg_time -= delta
	message_label.visible = _msg_time > 0.0 and not Game.in_dialogue
	message_label.modulate.a = clampf(_msg_time, 0.0, 1.0)

	if debug_label.visible:
		debug_label.text = "curse %.1f  form %s  world %d  t %.1f" % [
			Game.curse, Cfg.FORM_NAMES[Game.form], Game.world, Game.level_time]

	var t: float = Game.state_time
	match Game.state:
		Cfg.State.DEAD, Cfg.State.WON:
			var a := minf(1.0, t * 2.0)
			end_screen.color.a = 0.6 * a
			end_title.modulate.a = a
			end_sub.modulate.a = a * 0.6
		Cfg.State.FALLING:
			end_screen.color.a = minf(0.85, t * 0.25)
			var a2 := clampf(t - 2.0, 0.0, 1.0)
			end_title.modulate.a = a2
			end_sub.modulate.a = a2 * 0.6


func _on_state_changed(new_state: int) -> void:
	title_screen.visible = new_state == Cfg.State.TITLE
	falling.visible = new_state == Cfg.State.FALLING
	vignette.visible = new_state != Cfg.State.FALLING
	end_screen.visible = new_state in [Cfg.State.DEAD, Cfg.State.WON, Cfg.State.FALLING]
	end_screen.color.a = 0.0
	end_title.modulate.a = 0.0
	end_sub.modulate.a = 0.0
	match new_state:
		Cfg.State.DEAD:
			end_title.text = Game.death_text
			end_sub.text = "R veya Boşluk: yeniden dene"
		Cfg.State.WON:
			var last: bool = Game.level_index >= Game.level_count - 1
			end_title.text = "Prototipin sonu. Teşekkürler!" if last else "Bölüm geçildi"
			var hint: String = "Boşluk: baştan oyna" if last else "Boşluk: sonraki bölüm · R: tekrar"
			end_sub.text = "%.1f sn · %s" % [Game.level_time, hint]
		Cfg.State.FALLING:
			end_title.text = "Sonsuza düşüyorsun..."
			end_sub.text = "R: yeniden dene"
		Cfg.State.PLAY:
			_flash = 0.0
			_pulse = 0.0


func _on_message(text: String, seconds: float) -> void:
	message_label.text = text
	_msg_time = seconds


func _on_flashed() -> void:
	_flash = 1.0


func _on_heartbeat() -> void:
	_pulse = 1.0


func _on_dialogue_changed(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	text_label.text = text
	dialogue_box.show()


func _on_dialogue_ended() -> void:
	dialogue_box.hide()
