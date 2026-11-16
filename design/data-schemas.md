# Data schemas (assets/data)

All gameplay numbers live here; code reads them through `GameData.load_json`. Keys are snake_case; a key
starting with `_` is a comment and is ignored. `tests/integration/data/data_consistency_test.gd` checks that
every reference below resolves and that nothing is orphaned.

## run_config.json — per-run tuning

| Key | Meaning |
|---|---|
| `world.arena_half` | half-size of the square arena (px); the player is clamped inside |
| `world.sprite_scale` | integer draw scale of sprites |
| `world.spawn_ring` | `[min, max]` distance from the player where monsters spawn |
| `world.despawn_distance` | monsters farther than this are moved back into the spawn ring |
| `xp.base`, `xp.growth`, `xp.flat` | `xp_to_next(L) = round(base * growth^(L-1) + flat * (L-1))` (`XpCurve`) |
| `pickups.radius` | base magnet radius (× player `magnet` stat) |
| `pickups.magnet_speed`, `pickups.collect_radius` | pull speed (px/s) and pick-up distance |
| `pickups.gold_chance` | chance a kill also drops a coin |
| `player.hit_invuln` | seconds of invulnerability after a hit (the body circle is the class sprite's json `body`) |
| `separation.cell`, `separation.push` | spatial-hash cell size; how hard overlapping monsters push apart (px/s) |
| `max_enemies` | spawn cap |
| `ui.damage_number_time`, `ui.damage_number_rise`, `ui.damage_number_size` | floating damage number: lifetime (s), rise (px), font size |
| `ui.max_damage_numbers` | how many numbers can float at once (oldest reused) |
| `ui.hp_bar_time` | seconds a monster's hp bar stays visible after a hit (hidden otherwise) |

## classes.json — playable classes

`<class_id>: { name, sprite, stats{...}, start_skills{skill_id: level}, upgrades: "<file>.json" }`

The body circle (contact, pickups, attack pivot) is the `body` of the class sprite's json, measured from its
pixels in Sprite Lab (`SpriteHitbox.body`).

`stats`: `max_hp`, `move_speed` (px/s), `damage` (base hit), `cooldown` (s, auto attack), `area` (×),
`regen` (hp/s), `armor` (flat reduction per hit), `magnet` (× pickup radius).

## upgrades_<class>.json — level-up pool and skills

`upgrades[]`: `{ id, kind: "skill"|"stat", name, desc, max_level, weight, effects{stat: {add|mul}} }`.
`add` adds per level; `mul` adds per level to a multiplier starting at 1 (floored at 0.2), see `PlayerStats`.
A stat key `skill_damage.<skill>` / `skill_area.<skill>` scales one skill only.

`skills.<id>`: coefficients of each attack. The hit area is **not** here: it is the `hitbox` of the skill
sprite's animation (measured from the pixels in Sprite Lab), placed with the same anchor and scale as the drawn
effect (`SpriteHitbox`). Effect scale = `world.sprite_scale` × class `area` × `size_mul` (× `skill_area.<id>`).
`blade_arc`: `sprite`, `damage_mul`, `cooldown_mul`, `size_mul`, `back_damage_mul`, `back_damage_per_level`.
`whirlwind`: `sprite`, `damage_mul`, `size_mul`, `cooldown` (scaled by the class cooldown stat), `duration`,
`ticks`. Every `kind: "skill"` upgrade has a `skills` entry and vice versa.

## monsters.json — monster stats (stage 1)

`<monster_id>: { sprite, behaviour: chase|swarm|charge, hp, damage, speed, xp, scale, ... }`. The body circle
(contact, separation, being hit) is the sprite json `body` × `scale`; never a radius typed here.
`swarm` adds `wobble` (px/s sideways). `charge` adds `charge_range`, `windup`, `dash_speed`, `dash_time`,
`charge_cooldown`. Sprites need `move` and `death` animations.

## waves/stage_NNN.json — spawn schedule

`{ number, name, duration, waves[] }` (`number` and `name` are shown in the lobby and HUD); a wave is `{ monster, t_from, t_to, rate, rate_end }` (linear spawns/s) or
`{ monster, t_from, t_to, burst }` (that many at once at `t_from`). See `WaveScheduler`.

## gameplay_rules.json — design rules for skills and effects

`{ limits{...}, rules[] }`. `rules[]`: `{ id, severity: "must"|"should", title, text }`; ids are fixed (`auto`,
`hitbox`, `screen`, `snappy`, `directional`, `levels`, `small`, `class`, `dps`) because the checks are code.
`limits`: `cooldown_min/max` (s), `reach_min/max` (world px of the hit area at max level), `cast_range_max` (px),
`oneshot_max` (s, one-shot effect length), `active_start_max` (s, first damage frame), `frame_max` (px),
`levels_min/max`, `dps_ratio_min/max` (level-1 skill dps / class base dps). Meaning of every rule:
`design/gameplay-rules.md`. Checked by `tests/integration/data/gameplay_rules_test.gd` (must) and the studio
dashboard (all).

## items.json — every item in the game

`{ pickups{id: {name, sprite, desc}}, equipment{id: {name, sprite, desc, slot}} }`. `pickups.xp_gem` and
`pickups.gold` are the drops `src/run/run.gd` draws (sprite names come from here). `equipment` is empty until the
gear phase; its `slot` will be one of the sprite slots (`head`, `chest`, `arms`, `legs`, `weapon`). The studio
dashboard lists everything here in its Items tab.
