# Statuses — high-level sketch

```
1. Decide the data model (do this first, on paper)
2. Add statuses module + status_types alongside entities
3. Hook tick/apply/remove into the turn loop
4. Route stat reads through a getter so buffs/debuffs work
5. Polish (UI feedback, visual hooks, stacking rules)
```

## Step 1 — Decisions to lock down before writing anything

- What's a status? Probably `{ name, duration, modifiers, on_apply, on_tick, on_remove }`. Templates live in `status_types.lua`, per-entity instances are deep-copied (matching the entity pattern).
- Duration unit: turns, not seconds. Game is turn-based — keep statuses on the same clock.
- **Stacking rules** (the trickiest call): if poison is applied to an already-poisoned entity, do you (a) refresh the duration, (b) stack a second instance, or (c) cap at N stacks? Pick one default; allow per-status override later.
- Modifier shape: `{ stat = "str", op = "add" | "mul", value = 2 }` covers most buff/debuff cases. Don't over-design — you can always add `op = "set"` or conditional modifiers later.
- **Naming caveat**: `effects` already means visual effects. Use `statuses` (or `conditions`) throughout — keeps the two systems unambiguous.

## Step 2 — Module layout

Match the existing entity pattern:

```
entities/
├── entities.lua
├── entity_types.lua
├── statuses.lua          ← handler (apply, tick, remove, get_modifier_sum)
└── status_types.lua      ← templates (poison, regen, str_buff)
```

API surface for `statuses`:
- `statuses:apply(entity, name, overrides)` — instantiate from template, push onto entity's status list, call `on_apply`.
- `statuses:tick(entity)` — decrement durations, fire `on_tick`, remove expired.
- `statuses:remove(entity, name)` — manual removal (e.g. cleanse).
- `statuses:get_modifier_sum(entity, stat_name)` — used by the stat getter (Step 4).

Each entity carries `statuses = {}`. Initialize in `entities:add_from_template` (already deep-copies).

## Step 3 — Lifecycle hook

- Apply: callable from anywhere — combat code, traps, items.
- Tick: fires **on the affected entity's turn**, not globally each round. With the speed-based scheduler, ticking globally would unfairly punish slow actors and reward fast ones. Easiest seam: in `engine/turn.lua`, call `statuses:tick(actor)` at the start of each actor's turn (before AI/input).
- Remove: triggered by tick when duration hits zero, or manually.

## Step 4 — Stat reads through a getter

This is the biggest-scope decision and the one to commit to early.

- Add `entities:get_stat(entity, stat_name)` that returns `base + statuses:get_modifier_sum(entity, stat_name)`.
- All gameplay code that reads stats (sight range, attack damage, speed, etc.) goes through this getter — never `entity.stats.x` directly.
- Without this, buffs/debuffs can't work without mutating base stats, which is fragile (removing a buff = subtracting the right amount = bugs).
- Order of operations for stacked modifiers: define once. Standard is `(base + sum_of_adds) * product_of_muls` — pick whatever, just be consistent.

Audit current stat reads now (`grep "stats\."`) so you know the blast radius before starting.

## Step 5 — Polish (skip on first pass)

- UI feedback: list active statuses on the status panel; reuse `ui:add_text_to_ui_by_name` for tick messages ("you are poisoned: -1 hp").
- Visual feedback: reuse the `effects` (visual) system for damage popups on tick — `effects:add_from_template("damage_number", ...)` next to the entity.
- Resistances/immunities: a tag on entities (`immune_to = { "poison" }`) checked in `apply`.
- Source tracking: optional `source_entity` field for attributing kills.

## The thing to build first

Hardcode a `poison` status: deals 1 damage per turn, lasts 3 turns, no UI, no modifiers. Apply it manually via a debug keypress (`p` on a target). Watch the tick fire, hp drop, status expire. That validates apply → tick → expire end-to-end. Everything after — buffs, stacking, UI — is iteration on the same machinery.
