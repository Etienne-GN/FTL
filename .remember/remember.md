# Handoff

## State
- Godot 4.7 project `ftl` (repo `Etienne-GN/FTL`, MIT, pushed to main).
- Full run loop is playable: menu -> sector map (rebel fleet pursuit, hazards) -> combat/event/store -> next sector -> flagship boss (sector 8) -> victory/game-over. Save/quit ANY time (incl. mid-battle) via Continue Run. Ship unlocks on win.

## Built
- Models: Ship/SystemState/Crew/Weapon/Drone (all RefCounted). CombatManager: laser/ion/missile/beam/flak/bomb, shields, dodge (nebula), drone swarms, enemy AI (targeting + boarding), fire spread, breaches, O2 suffocation.
- Crew: BFS pathing, manning, repair, firefighting, medbay, crew-vs-crew combat, boarders, teleporter send/recall, **skill XP** (man/repair/fight), **door locks** slow boarders.
- Run structure: SectorMap beacon grid, rebel fleet, hazard zones (nebula/asteroid/sun/ion), events (8), stores (upgrades, weapons, **crew/fuel/repairs/battery**), flagship boss with crew + teleporter.
- Systems: **backup battery** (buyable, +1 power 12s/30s recharge), power allocation, reactor upgrade.
- UI: ShipView (procedural rects), MapView (tap beacons, jump range 1-3), reusable CombatScreen (resource/systems/weapons/crew/teleporter panels, pause, battery & door & flee/quit buttons, targeting, log).
- Content data in `data/` (weapons/drones/ships/events/systems). Ships: kestrel, engi_a, mantis_raider.
- Sound: 19 synthesized SFX via `SFX` autoload (assets/sfx/*.wav), wired into combat/store/flow.

## Tests
- `godot --headless res://tests/test_runner.tscn` — 18 tests (ALL PASSED).
- `godot --headless res://tests/flow.tscn` — end-to-end random run (ALL PASSED; tops up fuel so it can't stall).
- `xvfb-run godot res://tests/smoke.tscn` — click-through of every screen; expect `smoke ok`.

## Gotchas
- Systems JSON id is `weapons` (plural): keep it everywhere.
- `godot --headless --script` does NOT load autoloads; run tests as scenes.
- GDScript: no `:=` from Dictionary/Variant, no `Rect2.x/.y`, autoload singletons are accessible by global name (e.g. `SFX.play`) even in RefCounted classes — do NOT use has_node/get_node in RefCounted.
- Ship/CombatManager extend RefCounted (not Node).
- Enemy ships are generated at runtime (not in Content) — save/restore builds them from stored room/grid defs.
- Flow/smoke tests randomize: first encounter may be battle/event/store; drivers handle all states + top up fuel.

## Next
1. Android APK still BLOCKED: need Android SDK + export templates on this machine.
2. More events + sector-type theming; flagship multi-stage; tuning for difficulty curve.
3. If changing random tests, keep fuel-topping guard.

## Run
- Editor: `godot --path /home/etienne/projects/ftl`
- Import check: `godot --headless --import --path .`