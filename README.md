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
  main/                GameState, SaveManager, GameFlow (screen state machine)
  combat/              Ship, SystemState, Crew, Weapon, Drone, CombatManager
  fleet/               SectorMap (beacon grid, rebel fleet)
  events/              (event outcomes) — driven by data/events
  meta/                (ship unlocks, highscores)
  ui/                  ShipView, MapView, CombatScreen
  util/                ContentDB autoload, JSON helpers
data/
  systems/             system definitions + per-level stats
  weapons/             weapon definitions
  drone/               drone definitions
  ships/               player ship layouts
  events/              random event definitions
tests/                 headless test-runner + integration flow scenes
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

### Phase 2 — Ship management ✅
- Ship interior rendered live; power allocation, ship systems, hull/O2 bars

### Phase 3 — Crew ✅
- Crew pathfinding & movement, manning, auto-repair, firefighting, fires, breaches, O2, medbay, crew-vs-crew combat

### Phase 4 — Drones + boarding/teleporter ✅
- Combat/defense drones, drone parts; teleporter send/recall boarders; enemy boarding AI

### Phase 5 — Run structure ✅
- Generated sector map with branching beacons, rebel fleet advance, jumps (1/2/3)
- Random text events with choices; stores (system upgrades + weapons); ship selection
- Boss fight at sector 8; victory unlocks ships; save/quit

### Phase 6 — Hazards, boss, meta (in progress)
- Nebulas, ion storms, suns, asteroids; flagship boss; bestiary; Android export pass

---

## Controls (current desktop/touch build)

- **Menu**: start a run (multiple unlockable ships)
- **Sector map**: tap a highlighted beacon to jump (set jump range 1/2/3); rebel fleet advances each jump
- **Combat**: tap a weapon button then enemy rooms to target; `-`/`+` power; crew panel then tap rooms to move; teleporter send/recall; **Pause**
- **Events/Store**: pick a choice / buy upgrades or weapons

---

## Running

```
godot --path .                      # play in editor/default viewport
godot --headless res://tests/test_runner.tscn   # headless unit tests
godot --headless res://tests/flow.tscn          # end-to-end flow test
```

Requires Godot **4.7.x**.

## Building the Android APK

`export_presets.cfg` is already configured (landscape, immersive mode,
arm64). To produce an APK you need:

1. **Android SDK + NDK + JDK** installed locally.
2. **Godot Android export templates**: in the Godot editor menu
   *Editor → Manage Export Templates → Download and Install*.
3. Open the project in Godot → *Project → Export → Android* → point the
   preset at your SDK path → *Export Project* → `build/ftl.apk`.

Package id is `com.example.ftl` (change in `export_presets.cfg` before
shipping). Install with `adb install build/ftl.apk` or sideload the APK.

---

## Roadmap

1. ✅ Combat core, ship management, crew, drones/boarding, run structure
2. ✅ Boss fight, ship unlocks, save/quit, run-flow integration
3. ✅ Android export preset; full-screen flow + rendering verified headless
4. **In progress:** hazards (nebulas/ion storms/suns/asteroids), more events,
   difficulty tuning, meta/highscores UI, touch UX polish
5. **Remaining:** install Android SDK/templates and produce a release APK