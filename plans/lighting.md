

## Step 5 — Polish (skip on first pass)

- Animated/flicker lights: easiest as a per-frame jitter in `render`, not in the per-turn light grid.
- Player-carried light: just an entity with a `light` field that moves with the player.

