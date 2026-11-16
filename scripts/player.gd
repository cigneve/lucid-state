class_name Player
extends CharacterBody2D
## The cursed player. Movement is a CharacterBody2D; what blocks the body is
## decided by collision_mask, which changes with the form and the world
## (see _solid_mask). The curse itself lives in the Game autoload.

const GLOW_TEX_SIZE := 128.0

@onready var body_poly: Polygon2D = $Body
@onready var eyes: Node2D = $Eyes
@onready var eye_l: Polygon2D = $Eyes/EyeL
@onready var eye_r: Polygon2D = $Eyes/EyeR
@onready var glow: Sprite2D = $Glow
@onready var wisps: CPUParticles2D = $Wisps
@onready var burst: CPUParticles2D = $DashBurst
@onready var camera: Camera2D = $Camera2D
@onready var core: Area2D = $Core        # a tiny area at the centre: which zone am I in?
@onready var reach: Area2D = $Reach      # body-sized area: what can I interact with?
@onready var hurtbox: Area2D = $Hurtbox  # the feet: am I standing in spikes?

var facing: int = 1
var coyote: float = 0.0
var jump_buffer: float = 0.0
var air_jumps: int = 0
var air_dash: bool = true
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var wall_lock: float = 0.0
var wall_dir: int = 0
var form_flash: float = 0.0
var beat_timer: float = 0.5
var fall_limit: float = 100000.0


func _ready() -> void:
	Game.state_changed.connect(_on_state_changed)
	visible = false
	_update_mask()


## Put the player at `at` and reset everything. `bounds` is the level rectangle.
func respawn(at: Vector2, bounds: Rect2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	facing = 1
	coyote = 0.0
	jump_buffer = 0.0
	air_jumps = 0
	air_dash = true
	dash_timer = 0.0
	dash_cooldown = 0.0
	wall_lock = 0.0
	wall_dir = 0
	form_flash = 0.0
	beat_timer = 0.5
	fall_limit = bounds.end.y + 40.0
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.position = Vector2(60.0, 0.0)
	camera.reset_smoothing()
	wisps.restart()
	_update_mask()


# ------------------------------------------------------------ collision

## The heart of the mechanic: what blocks you depends on your form and world.
## Every kind of wall is its own physics layer; this picks the ones that are
## solid for you right now.
func _solid_mask() -> int:
	var mask: int = Cfg.LAYER_STONE
	if not Game.door_open:
		mask |= Cfg.LAYER_DOOR
	if Game.world == 0:
		mask |= Cfg.LAYER_WORLD_A
	else:
		mask |= Cfg.LAYER_WORLD_B
	if Game.form == Cfg.Form.SOLID:
		mask |= Cfg.LAYER_BARS
	if Game.form == Cfg.Form.GHOST:
		mask |= Cfg.LAYER_BRIDGE
	else:
		mask |= Cfg.LAYER_WALLS
	if Cfg.timed_on(false, Game.level_time):
		mask |= Cfg.LAYER_TIMED_A
	if Cfg.timed_on(true, Game.level_time):
		mask |= Cfg.LAYER_TIMED_B
	return mask


func _update_mask() -> void:
	collision_mask = _solid_mask()


## True if the body is inside something that is solid for the current form/world
## (you turned solid inside bars, or stepped through a mirror into stone).
func is_embedded() -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(Cfg.PLAYER_W - 2.0, Cfg.PLAYER_H - 2.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = _solid_mask() & ~(Cfg.LAYER_TIMED_A | Cfg.LAYER_TIMED_B)
	var hits: Array = get_world_2d().direct_space_state.intersect_shape(query, 1)
	return not hits.is_empty()


func _on_state_changed(new_state: int) -> void:
	visible = new_state != Cfg.State.TITLE and new_state != Cfg.State.DEAD
	if new_state == Cfg.State.FALLING:
		velocity = Vector2.ZERO


# ------------------------------------------------------------ update

func _physics_process(delta: float) -> void:
	if Game.state == Cfg.State.FALLING:
		_beat(delta, 100.0 + Game.state_time * 30.0)
		return
	if Game.state != Cfg.State.PLAY:
		return

	Game.level_time += delta
	_update_curse(delta)
	if Game.state != Cfg.State.PLAY:
		return
	_update_mask()

	# Dialogue freezes your body, but the curse keeps ticking.
	if Game.in_dialogue:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
			Game.advance_dialogue()
		velocity.x = 0.0
		jump_buffer = 0.0
		_move(delta, true)
	else:
		_move(delta, false)
		if Game.state != Cfg.State.PLAY:
			return
		_try_interact()

	# Spikes kill anything that is not a ghost.
	if Game.form != Cfg.Form.GHOST and hurtbox.has_overlapping_bodies():
		Game.die("Dikenler katı bedenini buldu.")
		return
	if global_position.y > fall_limit:
		Game.die("Boşluğa düştün.")
		return
	camera.position.x = facing * 60.0   # look ahead; the camera's smoothing does the rest
	_beat(delta, Game.curse)


func _update_curse(delta: float) -> void:
	var rate: float = Cfg.RACE_BASE_RATE if Game.race_on else Cfg.BASE_RATE
	for area in core.get_overlapping_areas():
		var zone := area as Zone
		if zone and zone.is_active():
			# In the mirror world light and shadow swap their effect.
			var healing: bool = zone.is_light() == (Game.world == 0)
			rate += Cfg.LIGHT_RATE if healing else Cfg.SHADOW_RATE
			break
	Game.curse = maxf(0.0, Game.curse + rate * delta)
	if Game.curse >= 100.0:
		Game.curse = 100.0
		Game.fall_forever()
		return
	_set_form_from_curse()


func _set_form_from_curse() -> void:
	var next: int = Cfg.form_for(Game.curse)
	if next == Game.form:
		return
	var prev: int = Game.form
	Game.set_form(next)
	form_flash = 1.0
	Sfx.play("state_up" if next > prev else "state_down")
	Game.say(Cfg.FORM_NAMES[next], 1.5)
	_update_mask()
	if is_embedded():
		Game.die("Bir duvarın içinde katılaştın.")


func _move(delta: float, frozen: bool) -> void:
	var ghost: bool = Game.form == Cfg.Form.GHOST
	var solid: bool = Game.form == Cfg.Form.SOLID
	var on_floor: bool = is_on_floor()

	# Timers.
	coyote -= delta
	jump_buffer -= delta
	dash_cooldown -= delta
	wall_lock -= delta
	if not frozen and Input.is_action_just_pressed("jump"):
		jump_buffer = Cfg.JUMP_BUFFER

	# Horizontal control.
	var dir: int = 0
	if not frozen:
		dir = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	if dir != 0:
		facing = dir
	if dash_timer > 0.0:
		dash_timer -= delta
	elif wall_lock <= 0.0:
		var accel: float = Cfg.ACCEL if dir != 0 else Cfg.FRICTION
		velocity.x = move_toward(velocity.x, dir * Cfg.RUN_SPEED, accel * delta)

	# Wall contact (only matters for SOLID).
	wall_dir = 0
	if solid and not on_floor:
		if test_move(global_transform, Vector2(2.0, 0.0)):
			wall_dir = 1
		elif test_move(global_transform, Vector2(-2.0, 0.0)):
			wall_dir = -1

	# Dash.
	if not frozen and Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and (on_floor or air_dash):
		dash_timer = Cfg.DASH_TIME
		dash_cooldown = Cfg.DASH_COOLDOWN
		velocity.x = facing * Cfg.DASH_SPEED * (Cfg.GHOST_DASH_SCALE if ghost else 1.0)
		velocity.y = 0.0
		if not on_floor:
			air_dash = false
		Sfx.play("dash")
		burst.restart()
		burst.emitting = true

	# Jumps.
	if jump_buffer > 0.0:
		if on_floor or coyote > 0.0:
			velocity.y = -(Cfg.GHOST_JUMP_SPEED if ghost else Cfg.JUMP_SPEED)
			jump_buffer = 0.0
			coyote = 0.0
			Sfx.play("jump")
		elif solid and wall_dir != 0:
			velocity.x = -wall_dir * Cfg.WALL_JUMP_X
			velocity.y = -Cfg.WALL_JUMP_Y
			facing = -wall_dir
			wall_lock = 0.16
			jump_buffer = 0.0
			Sfx.play("jump")
		elif Game.form == Cfg.Form.HALF and air_jumps > 0:
			velocity.y = -Cfg.DOUBLE_JUMP_SPEED
			air_jumps -= 1
			jump_buffer = 0.0
			Sfx.play("jump")
			burst.restart()
			burst.emitting = true
	# Short hop: let go of jump early to cut the jump.
	if not Input.is_action_pressed("jump") and velocity.y < 0.0 and dash_timer <= 0.0:
		velocity.y *= pow(0.02, delta)

	# Gravity (none while dashing).
	if dash_timer <= 0.0:
		velocity.y += Cfg.GRAVITY * (Cfg.GHOST_GRAVITY_SCALE if ghost else 1.0) * delta
		var max_fall: float = Cfg.GHOST_MAX_FALL if ghost else Cfg.MAX_FALL
		if solid and wall_dir != 0 and velocity.y > 0.0 and dir == wall_dir:
			max_fall = Cfg.WALL_SLIDE_SPEED
		velocity.y = minf(velocity.y, max_fall)

	move_and_slide()

	if is_on_wall():
		dash_timer = 0.0
	if is_on_floor():
		coyote = Cfg.COYOTE_TIME
		air_jumps = 1
		air_dash = true
	elif on_floor and velocity.y >= 0.0:
		coyote = Cfg.COYOTE_TIME


func _try_interact() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	var best: Interactable = null
	for area in reach.get_overlapping_areas():
		var thing := area as Interactable
		# Use .get("priority") to safely bypass the external class member resolution error
		if thing and thing.can_interact() and (best == null or thing.get("interact_priority") > best.get("interact_priority")):
			best = thing
	if best:
		best.interact(self)
		
func _beat(delta: float, curse_value: float) -> void:
	var k := minf(1.0, curse_value / 100.0)
	beat_timer -= delta
	if beat_timer <= 0.0:
		Sfx.heartbeat(lerpf(Cfg.HEART_MIN_VOL, Cfg.HEART_MAX_VOL, k))
		beat_timer = lerpf(Cfg.HEART_SLOW, Cfg.HEART_FAST, k)
		Game.heartbeat.emit()


# ------------------------------------------------------------ looks

func _process(delta: float) -> void:
	var k: float = Game.curse / 100.0
	var falling: bool = Game.state == Cfg.State.FALLING
	var alpha := maxf(0.18, 1.0 - k * 0.85)
	var col: Color = Cfg.PLAYER_COLORS[Game.world]
	body_poly.color = Color(col, alpha)
	var eye_col := Color(0.04, 0.04, 0.08, maxf(0.3, alpha))
	eye_l.color = eye_col
	eye_r.color = eye_col
	eyes.position.x = 1.0 if facing > 0 else -6.0

	form_flash = maxf(0.0, form_flash - delta * 1.5)
	var radius := 28.0 + k * 14.0 + form_flash * 20.0
	glow.scale = Vector2.ONE * (radius * 2.0 / GLOW_TEX_SIZE)
	glow.modulate = Color(col, 0.5 * alpha)

	# The more cursed you are, the more of you drifts away.
	wisps.emitting = falling or (Game.state == Cfg.State.PLAY and k > 0.03)
	wisps.modulate = Color(col, 1.0 if falling else k)
	burst.modulate = col
