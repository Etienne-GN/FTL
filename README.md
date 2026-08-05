# FTL — Faster Than Light (open reimplementation)

A fan-made, from-scratch reimplementation of the *Faster Than Light* roguelike
starship-management concept, built with **Godot 4** and targeting **Android**.

The goal is a faithful, offline, single-player run structure faithful to the
original: real-time combat with pause, ship interior management, crew, drones,
boarding, sector map, random events, stores, hazards, and the flagship boss.

---

## License

This project is released under the **MIT License** — free and open to everyone,
forever. See [LICENSE](LICENSE).

> **Disclaimer:** This is an independent, non-commercial fan project inspired by
> the *concept* of FTL. It is not affiliated with or endorsed by Subset Games.
> No original FTL assets are used.

---

## Tech stack

| Layer      | Choice                                        |
|------------|-----------------------------------------------|
| Engine     | Godot **4.7** (`gl_compatibility` renderer)    |
| Language   | **GDScript**                                  |
| Target     | **Android** (landscape, save/quit anytime)     |
| Content    | JSON data-driven (weapons, systems, ships, events, drones) |
| Testing    | Headless Godot test-runner scenes             |

Design choices for a faithful feel:
- **Real-time combat with pause** — the signature FTL mechanic.
- **Landscape orientation**, wide two-ship battle view.
- Runnable headless for automated smoke tests.

---

## Project structure

```
project.godot          Godot project + autoloads
src/
  main/                GameState, SaveManager, main scene/loop
  combat/              Ship, SystemState, Crew, Weapon, Drone, CombatManager
  fleet/               (sector map, rebel fleet)
  events/              (event system)
  meta/                (ship unlocks, highscores)
  ui/                  ShipView (rendering), HUD
  util/                ContentDB autoload, JSON helpers
data/
  systems/             system definitions + per-level stats
  weapons/             weapon definitions
  drone/               drone definitions
  ships/               player ship layouts
  events/              random event definitions
tests/                 headless test-runner scenes
assets/                shaders, fonts, icons
```

---

## Data model

A ship is built from a JSON definition: a **grid** of tiles, a list of
**rooms** (rectangles that may hold a **system**), starting systems/levels,
weapons, drones, crew, hull, reactor and starting power allocation.

Systems are fully data-driven. Each has a `max_level`, per-level stat arrays,
and a power model where the player allocates reactor pips per system:

| System       | per-level effect                              |
|--------------|-----------------------------------------------|
| shields      | shield bubbles + recharge time                |
| engines      | dodge % + FTL charge speed                     |
| weapons      | power pool that powers mounted weapons         |
| drones       | power pool that powers mounted drones          |
| oxygen       | O2 generation rate                            |
| medbay       | crew heal rate                                |
| teleporter   | boarding charge time                          |
| doors        | door/venting speed                            |
| cloak        | temp evasion charge/duration                  |
| battery      | temporary extra power                         |

## Combat resolution

1. Weapons charge; a projectile travels to its target room.
2. **Defense drones** may shoot it down.
3. Target ship rolls **dodge** (engine % + piloting + cloak).
4. **Shields** block if bubbles remain above the weapon's `pierce`.
5. Otherwise the room/system is hit: hull damage, system damage, and rolls for
   **fire** and **hull breach**. Ion weapons disrupt systems instead.

Weapons, drones, shields, engines, oxygen, fires, breaches, O2, crew movement,
repair, manning and ion are all modelled in pure GDScript (`Ship`, `SystemState`)
so combat runs headless and is testable.

---

## Feature spec & build status

### Phase 1 — Combat core ✅
- Ships from JSON layouts; rooms + systems + power allocation
- Weapons: laser / ion / missile / beam / flak / bomb
- Shields, engines (dodge), projectiles, targeting, enemy AI
- Real-time with **pause**; win/lose with rewards
- Headless unit tests passing

### Phase 2 — Ship management (in progress)
- Power allocation UI, system status, hull/O2 readouts

### Phase 3 — Crew
- Crew entities, movement, manning, repair, fires, breaches, O2, medbay

### Phase 4 — Drones + boarding/teleporter
- Combat/defense drones, drone parts, teleporter, boarders

### Phase 5 — Run structure
- Sector map, rebel fleet advance, jumps (1/2/3), random events, stores

### Phase 6 — Hazards, boss, meta
- Nebulas, ion storms, suns, asteroids; flagship boss; ship unlocks; save/quit

---

## Controls (current desktop/touch build)

- **Tap enemy ship room** (after selecting a weapon) to target it — auto-fires on charge
- **Tap player ship room** to select crew, then tap a room to move them
- **Systems panel**: `-` / `+` to allocate reactor power
- **Pause** toggle top-right

---

## Running

```
godot --path .                      # play in editor/default viewport
godot --headless res://tests/test_runner.tscn   # headless tests
```

Requires Godot **4.7.x**. Android export settings are configured via the
editor (landscape, stretch `canvas_items`); the Android SDK/export template is
needed to produce an APK.

---

## Roadmap

1. Finish ship-management UX (power, crew, O2 readouts).
2. Implement crew behaviour (Phase 3,4).
3. Implement run structure (sector map, events, stores).
4. Hazards + flagship boss + meta progression.
5. Android export pass + touch polish.