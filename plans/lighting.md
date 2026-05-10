# Lighting — high-level sketch

```
1. Decide the data model (do this first, on paper)
2. Add light_handler module that owns a per-cell light grid
3. Hook gathering + propagation into the turn loop
4. Hook the light grid into painter
5. Polish (ambient, animation, perf)
```

## Step 1 — Decisions to lock down before writing anything

- What's a "light"? Probably `{ color = {r,g,b}, intensity, radius, falloff }`. Falloff can be linear, quadratic, or LUT — pick one and move on.
- Where do lights live? Cleanest: a `light` field on tile templates and on entities. The handler scans both each tick.
- **Z behavior** (the trickiest call): is light per-z-slice, or does it leak up/down? Easiest first cut: light only affects its own z layer. Revisit later. Be deliberate — this decision sets the ceiling for what visuals look like.
- Blending model: additive RGB (clamped at 1.0) is standard and works fine. Decide once.

## Step 2 — `light_handler` module

- Lives alongside `fov/` or under `visuals/` (lean toward `lighting/light_handler.lua`).
- Owns `light_grid[y][x] = {r, g, b}`, sized like the visibility grid.
- API: `gather_emitters()`, `recompute(map, entities)`, `get_light_at(x, y)`.

## Step 3 — Propagation

- For each emitter: run shadowcasting from its origin (reuse `fov_handler` — it already handles this, you'd extend it to write into a light buffer instead of/in addition to a boolean).
- For each visited cell, compute contribution = `color * intensity * falloff(distance)`.
- Add into `light_grid[y][x]`.
- Recompute trigger: same place `update_visibility` fires from `main.lua`. You can be lazier and only recompute when emitters/world actually change, but simplest first is recompute-on-turn.

## Step 4 — Render integration

- `painter:emit_tile_at_z` and `emit_entity` already pass color through `render_utils.scale_color`. Add a step: multiply (or modulate) by `light_handler:get_light_at(x, y)` before scaling.
- Decide what "unlit but visible" means. Two options:
  - Ambient floor (e.g. `light = max(light, ambient_color)`) — cells you can see are always at least dimly lit. Simplest.
  - True dark — visible cells with no light render near-black. More dramatic, but means player without a light can't see anything.
- Existing height/distance brightness scaling stacks on top of this. Don't fight it; let them compose.

## Step 5 — Polish (skip on first pass)

- Animated/flicker lights: easiest as a per-frame jitter in `render`, not in the per-turn light grid.
- Player-carried light: just an entity with a `light` field that moves with the player.
- Performance: cache the light grid, only recompute when an emitter moves or world changes. Don't optimize until you measure.

## The thing to build first

Hardcode one static torch tile, get its glow showing as a colored circle in the renderer. That validates Steps 1–4 end-to-end with the simplest possible data. Everything after is iteration.
