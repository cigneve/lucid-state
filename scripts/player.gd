class_name Player
extends CharacterBody2D
## The cursed player. Movement is a CharacterBody2D; what blocks the body is
## decided by collision_mask, which changes with the form and the world
## (see _solid_mask). The curse itself lives in the Game autoload.

const GLOW_TEX_SIZE := 128.0

enum Hook { NONE, FLYING, PULLING }

@onready var body_poly: Polygon2D = $Body
@onready var eyes: Node2D = $Eyes
@onready var eye_l: Polygon2D = $Eyes/EyeL
@onready var eye_r: Polygon2D = $Eyes/EyeR
@onready var glow: Sprite2D = $Glow
@onready var wisps: CPUParticles2D = $Wisps
@onready var burst: CPUParticles2D = $DashBurst
@onready var camera: Camera2D = $Camera2D
@onready var hook_line: Line2D = $Hook
@onready var hook_tip: Polygon2D = $HookTip
@onready var melee_arc: Line2D = $MeleeArc
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
var hook_state: int = Hook.NONE
var hook_pos: Vector2 = Vector2.ZERO
var hook_target: Vector2 = Vector2.ZERO
var hook_pull: float = 0.0
var hook_cooldown: float = 0.0
var melee_cooldown: float = 0.0
var melee_timer: float = 0.0
var melee_aim: Vector2 = Vector2.RIGHT
var lunge_timer: float = 0.0


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
	_release_hook()
	hook_cooldown = 0.0
	melee_cooldown = 0.0
	melee_timer = 0.0
	lunge_timer = 0.0
	melee_arc.visible = false
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
		_update_hook(delta)
		_move(delta, false)
		if Game.state != Cfg.State.PLAY:
			return
		_try_interact()
		_try_action()

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
	var next: int = Game.form_lock if Game.form_lock >= 0 else Cfg.form_for(Game.curse)
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


## Re-evaluate the form right now (used when a gate locks it).
func refresh_form() -> void:
	_set_form_from_curse()


func _move(delta: float, frozen: bool) -> void:
	var ghost: bool = Game.form == Cfg.Form.GHOST
	var solid: bool = Game.form == Cfg.Form.SOLID
	var hooked: bool = hook_state == Hook.PULLING
	var on_floor: bool = is_on_floor()

	# Timers.
	coyote -= delta
	jump_buffer -= delta
	dash_cooldown -= delta
	wall_lock -= delta
	melee_cooldown -= delta
	melee_timer -= delta
	lunge_timer -= delta
	var lunging: bool = lunge_timer > 0.0
	if not frozen and Input.is_action_just_pressed("jump"):
		jump_buffer = Cfg.JUMP_BUFFER

	# Horizontal control.
	var dir: int = 0
	if not frozen:
		dir = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	if dir != 0:
		facing = dir
	# Horizontal momentum (skipped during a dash, a wall-jump lock, or a grapple/launch).
	if dash_timer > 0.0:
		dash_timer -= delta
	elif wall_lock <= 0.0 and not hooked and not lunging:
		_apply_horizontal(delta, dir, on_floor)

	# Wall contact (only matters for SOLID).
	wall_dir = 0
	if solid and not on_floor:
		if test_move(global_transform, Vector2(2.0, 0.0)):
			wall_dir = 1
		elif test_move(global_transform, Vector2(-2.0, 0.0)):
			wall_dir = -1

	# Dash.
	if not frozen and not hooked and Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and (on_floor or air_dash):
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
	# Variable jump height: releasing early cuts the rise ONCE (never every frame).
	if dash_timer <= 0.0 and not lunging and Input.is_action_just_released("jump") and velocity.y < -Cfg.JUMP_CUT_MIN:
		velocity.y = -Cfg.JUMP_CUT_MIN

	# Gravity (none while dashing, being pulled, or launched): floatier while the jump is held, heavier to fall.
	if dash_timer <= 0.0 and not hooked and not lunging:
		var rising: bool = velocity.y < 0.0
		var holding: bool = Input.is_action_pressed("jump")
		var grav: float = Cfg.GRAVITY_JUMP if (rising and holding) else Cfg.GRAVITY_FALL
		velocity.y += grav * (Cfg.GHOST_GRAVITY_SCALE if ghost else 1.0) * delta
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


## Horizontal momentum. Ease toward the target speed, skid hard when turning,
## stop fast on the ground and keep momentum in the air.
func _apply_horizontal(delta: float, dir: int, on_floor: bool) -> void:
	var target: float = float(dir) * Cfg.RUN_SPEED
	if dir != 0 and velocity.x != 0.0 and signf(velocity.x) != float(dir):
		var turn: float = Cfg.SKID_DECEL if on_floor else Cfg.TURN_ACCEL_AIR
		velocity.x = move_toward(velocity.x, target, turn * delta)
	else:
		var accel: float
		if dir != 0:
			accel = Cfg.ACCEL_GROUND if on_floor else Cfg.ACCEL_AIR
		else:
			accel = Cfg.DECEL_GROUND if on_floor else Cfg.DECEL_AIR
		velocity.x = move_toward(velocity.x, target, accel * delta)


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


# ------------------------------------------------------------ action (8-way)

## The aim direction follows the held 8-way input, falling back to facing.
func aim_dir() -> Vector2:
	var dx: float = float(int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left")))
	var dy: float = float(int(Input.is_action_pressed("aim_down")) - int(Input.is_action_pressed("aim_up")))
	if dx == 0.0 and dy == 0.0:
		return Vector2(float(facing), 0.0)
	return Vector2(dx, dy).normalized()


## The body's centre (its origin).
func player_center() -> Vector2:
	return global_position


## The `action` key (L) does one thing per form: grapple while HALF, melee while
## SOLID. A GHOST's hands pass through everything.
func _try_action() -> void:
	if not Input.is_action_just_pressed("action"):
		return
	if Game.form == Cfg.Form.HALF:
		_start_grapple()
	elif Game.form == Cfg.Form.SOLID:
		_start_melee()


func _start_grapple() -> void:
	if hook_state != Hook.NONE or hook_cooldown > 0.0:
		return
	var target: Variant = _find_hook_target(aim_dir())
	if target == null:
		Sfx.play("talk")
		return
	hook_pos = player_center()
	hook_target = target
	hook_pull = 0.0
	hook_state = Hook.FLYING
	Sfx.play("dash")
	_draw_hook()


## The nearest hook block within range that lies in `dir`, or null.
func _find_hook_target(dir: Vector2) -> Variant:
	var c: Vector2 = player_center()
	var best_dist: float = INF
	var best: Variant = null
	for node in get_tree().get_nodes_in_group("hook_blocks"):
		var n2d := node as Node2D
		if n2d == null:
			continue
		# Objects sit at the bottom-centre of their tile; the hook is at its centre.
		var p: Vector2 = n2d.global_position + Vector2(0.0, -Cfg.TILE / 2.0)
		var off: Vector2 = p - c
		var d: float = off.length()
		if d > Cfg.GRAPPLE_RANGE or d < 1.0:
			continue
		if off.normalized().dot(dir) < Cfg.GRAPPLE_CONE:
			continue
		if d < best_dist:
			best_dist = d
			best = p
	return best


## Advance the hook: fly to the anchor, then pull the body in.
func _update_hook(delta: float) -> void:
	if hook_cooldown > 0.0:
		hook_cooldown -= delta
	if hook_state == Hook.NONE:
		return
	if hook_state == Hook.FLYING:
		var off: Vector2 = hook_target - hook_pos
		var d: float = off.length()
		var step: float = Cfg.HOOK_SPEED * delta
		if d <= step:
			hook_pos = hook_target
			hook_state = Hook.PULLING
		else:
			hook_pos += off / d * step
	elif hook_state == Hook.PULLING:
		if Game.form != Cfg.Form.HALF:
			_release_hook()
			return
		var c: Vector2 = player_center()
		var off: Vector2 = hook_target - c
		var d: float = off.length()
		if d <= Cfg.GRAPPLE_STOP_DIST:
			_release_hook()
			return
		hook_pull = minf(Cfg.MAX_PULL, hook_pull + Cfg.PULL_ACCEL * delta)
		var speed: float = maxf(Cfg.PULL_SPEED, hook_pull)
		velocity = off / d * speed
		dash_timer = 0.0
	_draw_hook()


## Let go: keep a share of the pull velocity so you fling off the anchor.
func _release_hook() -> void:
	if hook_state == Hook.NONE:
		return
	velocity *= Cfg.GRAPPLE_KEEP
	hook_pull = 0.0
	hook_state = Hook.NONE
	hook_cooldown = Cfg.HOOK_COOLDOWN
	hook_line.visible = false
	hook_tip.visible = false


func _draw_hook() -> void:
	if hook_state == Hook.NONE:
		return
	var local: Vector2 = to_local(hook_pos)
	var col: Color = Cfg.PLAYER_COLORS[Game.world]
	hook_line.visible = true
	hook_tip.visible = true
	hook_line.points = PackedVector2Array([Vector2.ZERO, local])
	hook_line.default_color = Color(col, 0.8)
	hook_tip.position = local
	hook_tip.color = Color(col, 0.95)


func _start_melee(dir: Vector2 = Vector2.INF) -> void:
	if melee_cooldown > 0.0:
		return
	if dir == Vector2.INF:
		dir = aim_dir()
	melee_aim = dir
	melee_timer = Cfg.MELEE_FX_TIME
	melee_cooldown = Cfg.MELEE_COOLDOWN
	var c: Vector2 = player_center()
	var hits: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("knockback_blocks"):
		var n2d := node as Node2D
		if n2d == null:
			continue
		# Objects sit at the bottom-centre of their tile.
		var p: Vector2 = n2d.global_position + Vector2(0.0, -Cfg.TILE / 2.0)
		var off: Vector2 = p - c
		var d: float = off.length()
		if d > Cfg.MELEE_RANGE + Cfg.TILE / 2.0 or d < 0.001:
			continue
		if off.normalized().dot(dir) < cos(Cfg.MELEE_HALF_ANGLE):
			continue
		hits.append(n2d)
	if hits.is_empty():
		Sfx.play("talk")
		return
	melee_cooldown += Cfg.MELEE_HITSTOP
	for n2d in hits:
		if n2d.has_method("flash"):
			n2d.flash()
	# The strike throws you straight back along the aim, full 8-way.
	velocity.y = min(0, velocity.y)
	velocity -= dir * Cfg.MELEE_KNOCKBACK
	lunge_timer = Cfg.MELEE_LUNGE_TIME
	dash_timer = 0.0
	air_dash = true
	air_jumps = 1
	Sfx.play("plate")
	burst.restart()
	burst.emitting = true


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

	# Melee arc: a short-lived cone in the aim direction.
	if melee_timer > 0.0:
		var angle: float = melee_aim.angle()
		var pts := PackedVector2Array()
		var segs := 12
		for i in segs + 1:
			var a: float = angle - Cfg.MELEE_HALF_ANGLE + 2.0 * Cfg.MELEE_HALF_ANGLE * float(i) / float(segs)
			pts.append(Vector2(cos(a), sin(a)) * Cfg.MELEE_RANGE)
		melee_arc.points = pts
		melee_arc.visible = true
		melee_arc.default_color = Color(col, 0.7 * clampf(melee_timer / Cfg.MELEE_FX_TIME, 0.0, 1.0))
	else:
		melee_arc.visible = false
