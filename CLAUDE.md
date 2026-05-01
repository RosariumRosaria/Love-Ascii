# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

LÖVE (love2d) game in Lua — a turn-based, ASCII-styled roguelike with a layered (3D) tile grid, FOV via recursive shadowcasting, and an entity/template system. Runtime is LuaJIT (see `.vscode/settings.json`).

## Run

This repo runs via the Flatpak LÖVE on Aurora:

```
flatpak run org.love2d.love2d /var/home/Rosarium/Documents/Love-Ascii
```

The VSCode "Run LÖVE" task wraps this in `flatpak-spawn --host`. There are no tests, lint, or build commands configured.

`conf.lua` enables `t.console = true`, so `print(...)` output goes to the launching terminal — useful for debugging. There is also an in-game `_G.deep_print` defined in `main.lua` that mirrors output to the on-screen terminal UI panel.

## Architecture

### Frame loop and turn cadence

`main.lua` is the LÖVE entrypoint (`love.load`/`love.update`/`love.draw`). The game is turn-based but driven by `love.update`:

- `input_handler:update(dt)` accumulates `dt`; only ticks once per `game_config.timing.turn_delay` seconds.
- A tick returns `took_action = true` only when the player verb actually succeeded. Then `main.lua` calls `map:update_visibility`, `ai_handler:process_turn`, and `ui_handler:update_status` — in that order.
- `render_handler:update` and `visuals:update` run every frame regardless (camera lerp, decaying visual effects).

When adding a new player verb, route it through `input_handler:update` and have it return whether a turn was consumed; the AI/visibility/UI updates are gated on that return value.

### Module style

Every subsystem is a singleton table returned by its module (`local x = {}; ... return x`). Modules require each other directly — there is no DI. Most have a `:load(...)` that must run inside `love.load` because it touches `love.graphics`. In particular, `config:load()` builds fonts and derives `tile_size` from font height; `render_handler:load` then caches those locally. `tile_size` and `small_tile_size` are font-derived, so changing `render_config.font_scale`/`font_base_size` rescales the whole game.

### Map: 3D tile grid

`map.tiles[y][x][z]` — note Y-major. `z` ranges over `[game_config.map.min_z, game_config.map.max_z]`; ground is `z = 1`, underground is negative, above-ground is `>= 2`. `map:load` seeds every cell with `types.grass` at z=1, then `city_generator:make_town` overwrites for buildings.

**Important:** tiles are stored as direct references to the shared templates in `map/tile_types.lua` (no deep-copy on assignment). Do not mutate a tile's fields in place — mutate the cell by replacing the reference (`tiles[y][x][z] = types.something`). Entities, by contrast, *are* deep-copied on creation (`entities:add_from_template` → `utils.deep_copy`), so per-entity mutation is safe.

`map:update_visibility` clears only the previously-visible cells (tracked in `prev_visible`) before recomputing — this is an optimization, not a full grid clear. FOV lives in `fov/fov_handler.lua` and is Bob Nystrom's recursive-shadowcasting (link in source). The same function is reused by AI for line-of-sight checks: pass `is_player=false` and a `target_x,target_y` and it short-circuits to a boolean instead of writing into `visibility_grid`.

### Entities, tags, and actions

Entities are templates in `entities/entity_types.lua`, instantiated via `entities:add_from_template(name, x, y, z, overrides)`. The player is built inline in `main.lua` (not a template). Entity behavior is driven by:

- `tags` — `blocks`, `walkable`, `solid` (blocks line of sight), `moveable`, `attackable`, `interactable`, `tilelike` (rendered while merely *explored*, not just *visible*).
- `default_action` — one of `attackable` / `moveable` / `interactable`. `engine:move` falls back to `engine:default_interact` when the target tile isn't free, which dispatches to `attack`/`push`/`interact` based on the target's `default_action` *and* the actor's `allowed_actions`.
- `interaction` (optional) — a table whose keys are *swapped* with the entity's fields when interacted with (see `entities:interact_with_entity`). This is how doors/windows toggle: open/closed states are defined as the swap-target table, not as separate states.

Entity lookups (`entities:get_entity(x,y,z)`) are O(N) linear scans. Fine for current scale; will need spatial indexing if entity counts grow.

`entities.entities_by_z_level` is maintained in parallel with `entity_list`. Keep both in sync if you add removal/move paths.

### Rendering passes

`render_handler:draw` runs three tile passes plus entities and visuals:

1. Tiles `min_z .. 0` (underground)
2. Tiles `z = 1` (ground)
3. All entities (each rendered as a vertical stack of chars at `z .. z + #chars - 1`)
4. Tiles `2 .. max_z` (above-ground, drawn *over* entities so e.g. roofs occlude)
5. Visuals (effects)
6. UI panels (switch to `small_font` for these, then back to `default_font`)

Per-z visual offset (`get_offset`) creates the parallax/tilt effect; `offset_type` is cycled with the `z` key.

### Config split

Runtime tunables are split across `config/*.lua` by domain (`game_config`, `render_config`, `generation_config`, `ai_config`). The root `config.lua` is *not* tunables — it owns font/tile-size construction and must be `:load`'d after LÖVE is up. When adding new tunables, place them in the matching domain config rather than in `config.lua`.

### Debug toggles

Wired in `input_handler.lua` `love.keypressed`:

- `g` — grid overlay
- `b` — black-and-white mode
- `l` — per-tile brightness debug numbers
- `v` — voronoi visualizer (`voroni/visualizer.lua`)
- `z` — cycle render offset_type (1/2/3)
- `x` — switch status panel between `stats` and `inventory`
- `escape` — quit

When adding a new keybinding, grep `love.keypressed` and the `love.keyboard.isDown` calls in `input_handler:update` to avoid stomping an existing one.
