# Lucid State (Godot 4)

Godot 4.3+ project, GDScript, GL Compatibility renderer.

## Run
1. Open Godot 4.3 or newer, click **Import**, pick `project.godot`.
2. Let the first import finish, then press **F5**. Any key starts the game.

## Controls
Edit them in **Project > Project Settings > Input Map**.

| Action | Keys |
|---|---|
| `move_left` / `move_right` | Arrows, A / D |
| `jump` | Space, Up, W |
| `dash` | Shift, X |
| `interact` (talk, lever, mirror) | E, Down, S |
| `restart` | R |
| `confirm` (after dying / winning) | Space, Enter |
| `toggle_debug` | F3 |

## Layout
```
scenes/main.tscn           Main: Background, World/Player, HUD. Holds the level list.
scenes/player.tscn         CharacterBody2D + camera, particles, sensor areas
scenes/background.tscn     sky + three parallax layers
scenes/ui/hud.tscn         title, messages, dialogue box, end screens, vignette
scenes/objects/*.tscn      things you place in a level
levels/level_1..3.tscn     the three levels
levels/level_template.tscn empty level to duplicate
art/terrain_tiles.tres     the TileSet (art/tiles.png)
scripts/config.gd          every tuning number (speeds, curse rates, timings)
scripts/game.gd            autoload "Game": curse, form, world, state + signals
scripts/sound.gd           autoload "Sfx": synthesized sounds
```

## Building a level
Duplicate `levels/level_template.tscn`, then add it to **Main > Levels** in the Inspector.

**Rule: anything that blocks is painted, anything you touch or use is a scene.**

### Paint: the Terrain layers
Select a layer under `Terrain`, open the TileMap panel, paint the matching tile.

| Layer | Tile (atlas order) | Blocks |
|---|---|---|
| Stone | 1-2 (plain, with top edge) | everyone |
| WorldA | 3-4 | only in the normal world |
| WorldB | 5-6 | only in the mirror world |
| Bars | 7-8 | SOLID only |
| Walls | 9 | SOLID and HALF |
| Bridge | 10 | GHOST only (a ghost can stand on it) |
| Door | 11 | everyone, until every seal is done |
| TimedA / TimedB | 12 / 13 | one-way platforms that blink in opposite phases |
| Spikes | 14 | nothing; kills anything that is not a ghost |

Collision comes from the tile, so a tile always behaves correctly. The layer only
controls how it is dimmed, so keep each tile on its own layer.
The Stone layer also sets the camera limits.

### Place: scenes from `scenes/objects`
Drag them into the level. Origin is the bottom-centre of the tile they stand on,
so a 16 px grid snap lines them up.

| Scene | What it does | Inspector |
|---|---|---|
| `light_zone` / `shadow_zone` | heal / feed the curse (swapped in the mirror world) | **Scale** it to cover tiles (1 = one tile, origin top-left). `dormant`: off until a lamp is lit |
| `plate` | seal: a SOLID body standing on it | `done_text` |
| `lever` | seal: press E while not a ghost | `done_text` |
| `lamp` | seal: a GHOST's touch; wakes dormant light zones | `done_text` |
| `mirror` | E switches worlds | |
| `npc` | talk with E | `npc_name`, `seen_by` (which forms see them), `lines` |
| `exit` | finishes the level | |
| `seal_runes` | dots showing seal progress (put it on a door) | |

`PlayerStart` marks the player's feet. Level settings (`level_name`,
`race_after_seals`) are on the level's root node.

## How the mechanic works
Each kind of wall is its own physics layer (named in Project Settings > Layer Names).
`player.gd` builds the player's `collision_mask` from form, world, door and timed
phase, so "what blocks you" is one function: `_solid_mask()`.
