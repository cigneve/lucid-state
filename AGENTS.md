# AGENTS.md

Godot 4 game (GDScript, GL Compatibility). `README.md` is the design/level-building doc — read it before touching levels or objects.

## Toolchain
- Engine is **Godot 4.7** (`project.godot` `config/features` = "4.7"). The README's "4.3+" is stale; `.tscn` files use `format=4` and per-script `.uid` files, which need 4.4+.
- No build/lint/test config, no CI. There is no test suite.
- Verify scripts parse and resources load with headless mode (exits non-zero on GDScript errors):
  `godot --headless --path . --quit`
- Run the game: `godot --path .` (F5 in editor). `res://scenes/main.tscn` is the main scene.
- Godot auto-generates `.godot/` (gitignored). Do not hand-edit `.uid` files; Godot owns them.

## Architecture
- Autoloads are declared in `project.godot`, not per-scene: `Game` (`scripts/game.gd`, run state + event bus/signals) and `Sfx` (`scripts/sound.gd`, fully synthesized audio, no audio files).
- `Cfg` (`scripts/config.gd`) is a `class_name` (not autoload) holding **all** tuning numbers, enums (`State`, `Form`), physics layer bit values, and the timed-platform phase math. Put gameplay numbers here, not inline.
- The core mechanic is `Player._solid_mask()` (`scripts/player.gd:72`): what blocks the player is derived from form + world + door + timed phase. Physics layer names ↔ `Cfg.LAYER_*` bits must stay in sync (`project.godot` `[layer_names]`).
- Level rule (enforced by convention, see `README.md` and `scripts/level.gd`): **anything that blocks is painted on a `Terrain/*` TileMapLayer; anything you touch/use is a scene from `scenes/objects/`**. Collision comes from the tile, so each tile must stay on its own layer.
- Objects inherit `Interactable` (`scripts/objects/interactable.gd`); seals (plates/levers/lamps) additionally inherit `Seal` (`scripts/objects/seal.gd`). Levels auto-discover all `Seal`/`SealRunes` children in `_ready` — levels with no seals open the door immediately.
- Everything is 32 px tiles (editor grid snap 16 px); object origins are bottom-centre; `light_zone`/`shadow_zone` base is one tile, origin top-left, scaled to cover area.

## Known traps (verified in code — don't "fix" blindly)
- `scripts/main.gd:58` hardcodes `levels[0]` when loading a level, and `scenes/main.tscn` lists `level_0` + `level_2` twice (`level_1` is unwired). `Game.level_index` is set but unused for instantiation. Level select/next is effectively broken; touch this deliberately.
- `scripts/level.gd:81` `_refresh_terrain()` starts with `return` — the dimming/tint logic below is dead code. Same for the commented-out door/stone modulate lines.
- In-game text is **Turkish** (`Cfg.FORM_NAMES`, `Game.die`/`say` strings, NPC lines). Keep new player-facing strings in Turkish.
- `lucid-state-prototype.html` is a standalone JS prototype, unreferenced by the Godot project — reference only, not part of the game.
- Objects expose `interact_priority`; `player.gd` reads it via `.get(...)` because external `class_name` member resolution is flaky. Follow that pattern instead of direct property access.

## Editing .tscn/.tres
Prefer the editor or MCP Godot tools. If editing text by hand: external refs by `uid`+`path`, `TileMapLayer` (4.x) not `TileMap`, and a matching `.uid` must exist for every script — run a headless load after edits.
