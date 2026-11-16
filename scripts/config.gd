class_name Cfg
extends RefCounted
## Lucid State tuning values. Change numbers here to adjust the feel.

enum State { TITLE, PLAY, DEAD, FALLING, WON }
enum Form { SOLID, HALF, GHOST }
const FORM_NAMES := ["Katı", "Yarı saydam", "Hayalet"]

const TILE := 32.0
const VIEW_W := 960.0
const VIEW_H := 544.0

# The curse goes from 0 (fully solid) to 100 (gone: you fall forever).
const BASE_RATE := 1.0         # per second, always (100 s from 0 to 100)
const SHADOW_RATE := 12.0      # per second inside a shadow zone (normal world)
const LIGHT_RATE := -25.0      # per second inside a light zone (normal world)
const RACE_BASE_RATE := 1.5    # per second after all seals of a "race" level are done
const HALF_AT := 33.0          # curse >= this -> HALF
const GHOST_AT := 66.0         # curse >= this -> GHOST
# In the mirror world light and shadow swap their effect.

# Player. SMW-style momentum: gradual acceleration, big skids, momentum in the air.
const PLAYER_W := 20.0
const PLAYER_H := 28.0
const RUN_SPEED := 260.0
const ACCEL_GROUND := 1600.0      # ground acceleration toward RUN_SPEED
const ACCEL_AIR := 700.0          # air acceleration (weaker control)
const SKID_DECEL := 2400.0        # hard brake when turning on the ground
const TURN_ACCEL_AIR := 600.0     # gentler turn in the air
const DECEL_GROUND := 1500.0      # no input on the ground: stop quickly (slides a bit)
const DECEL_AIR := 200.0          # no input in the air: keep momentum
# Jump arc: floatier while held, heavier once released or falling (short hop).
const JUMP_SPEED := 640.0
const GRAVITY_JUMP := 2200.0      # rising while jump is held
const GRAVITY_FALL := 3600.0      # falling, or rising after the jump is released
const JUMP_CUT_MIN := 200.0       # upward speed clamped once when jump is released early
const DOUBLE_JUMP_SPEED := 600.0  # HALF only
const WALL_SLIDE_SPEED := 120.0   # SOLID only
const WALL_JUMP_X := 300.0
const WALL_JUMP_Y := 600.0
const DASH_SPEED := 620.0
const DASH_TIME := 0.15
const DASH_COOLDOWN := 0.45
const MAX_FALL := 900.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const GHOST_GRAVITY_SCALE := 0.8
const GHOST_MAX_FALL := 620.0
const GHOST_JUMP_SPEED := 440.0
const GHOST_DASH_SCALE := 1.5

# Grapple (HALF only, 8-way, aimed in the held movement direction).
const GRAPPLE_RANGE := 300.0     # how far the hook can reach a hook block
const HOOK_SPEED := 2200.0       # speed the hook travels (px/s)
const PULL_SPEED := 900.0        # initial pull speed toward the anchor
const PULL_ACCEL := 2600.0       # the pull ramps up the longer you hold on
const MAX_PULL := 1400.0
const GRAPPLE_STOP_DIST := 18.0  # release distance from the anchor
const GRAPPLE_KEEP := 0.55       # share of pull velocity kept after release
const HOOK_COOLDOWN := 0.2
const GRAPPLE_CONE := 0.85       # cos: how close to the aim the target must be

# Melee (SOLID only, 8-way, aimed in the held movement direction).
const MELEE_RANGE := 80.0        # reach from the body centre toward the aim
const MELEE_HALF_ANGLE := 0.9    # cone half-width (radians)
const MELEE_COOLDOWN := 0.35
const MELEE_KNOCKBACK := 500.0   # launch speed thrown back along the aim
const MELEE_HITSTOP := 0.05      # extra cooldown on a hit
const MELEE_LUNGE_TIME := 0.18   # how long the launch outranks gravity
const MELEE_FX_TIME := 0.18      # the arc's on-screen lifetime

# Timed platforms (phase A and phase B blink in opposite phases).
const TIMED_PERIOD := 2.4      # seconds for one on/off cycle
const TIMED_ON_TIME := 1.5     # seconds lit (solid) in each cycle
const TIMED_WARN_TIME := 0.45  # flicker this long before switching off

# Heartbeat
const HEART_SLOW := 1.15       # seconds between beats at curse 0
const HEART_FAST := 0.32       # at curse 100
const HEART_MIN_VOL := 0.15
const HEART_MAX_VOL := 0.9

# Physics layers (bit values). The same names are in Project Settings > Layer Names.
const LAYER_STONE := 1       # blocks everyone, both worlds
const LAYER_WORLD_A := 2     # stone that exists only in the normal world
const LAYER_WORLD_B := 4     # stone that exists only in the mirror world
const LAYER_BARS := 8        # blocks SOLID only
const LAYER_WALLS := 16      # blocks SOLID and HALF
const LAYER_BRIDGE := 32     # blocks GHOST only
const LAYER_DOOR := 64       # blocks everyone until every seal is done
const LAYER_TIMED_A := 128   # one-way timed platforms, phase A
const LAYER_TIMED_B := 256   # one-way timed platforms, phase B
const LAYER_SPIKES := 512    # kills anything that is not a ghost
const LAYER_PLAYER := 1024
const LAYER_INTERACT := 2048 # plates, levers, lamps, mirrors, NPCs
const LAYER_ZONE := 4096     # light and shadow zones

# Colours per world: index 0 = normal world, 1 = mirror world.
const PLAYER_COLORS := [Color(0.922, 0.902, 1.0), Color(0.784, 1.0, 0.961)]
const LIGHT_COLORS := [Color(1.0, 0.804, 0.471), Color(1.0, 0.275, 0.314)]
const SHADOW_COLORS := [Color(0.235, 0.039, 0.353), Color(0.157, 0.627, 0.588)]
const EDGE_TINTS := [Color(0.745, 0.667, 1.0), Color(0.471, 1.0, 0.902)]


## Timed platforms: where in its on/off cycle a platform is.
static func timed_phase(phase_b: bool, level_time: float) -> float:
	return fposmod(level_time + (TIMED_PERIOD / 2.0 if phase_b else 0.0), TIMED_PERIOD)


static func timed_on(phase_b: bool, level_time: float) -> bool:
	return timed_phase(phase_b, level_time) < TIMED_ON_TIME


static func timed_warning(phase_b: bool, level_time: float) -> bool:
	var t := timed_phase(phase_b, level_time)
	return t < TIMED_ON_TIME and t > TIMED_ON_TIME - TIMED_WARN_TIME


static func form_for(curse: float) -> int:
	if curse >= GHOST_AT:
		return Form.GHOST
	if curse >= HALF_AT:
		return Form.HALF
	return Form.SOLID
