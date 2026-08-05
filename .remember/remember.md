# Handoff

## State
- Godot 4.7 project `ftl` (repo `Etienne-GN/FTL`, MIT, pushed to main).
- Full run loop is playable: menu -> sector map (rebel fleet pursuit, hazards) -> combat/event/store -> next sector -> flagship boss (sector 8) -> victory/game-over. Save/quit ANY time (incl. mid-battle) via Continue Run. Ship unlocks on win.

## Built
- Models: Ship/SystemState/Crew/Weapon/Drone (all RefCounted). CombatManager: laser/ion/missile/beam/flak/bomb, shields, dodge (nebula), drone swarms, enemy AI (targeting + boarding), fire spread, breaches, O2 suffocation.
- Crew: BFS pathing, manning, repair, firefighting, medbay, crew-vs-crew combat, boarders, teleporter send/recall, **skill XP** (man/repair/fight), **door locks** slow boarders.
- Run structure: SectorMap beacon grid, **rebel fleet pursuit (catch = intercept battle, repel on win)**, hazard zones + **sector themes** (8 themes bias hazards), events (18, incl. battle outcomes), stores (upgrades, **sector-tiered weapons**, **drones**, crew/fuel/repairs/battery), flagship boss with crew + teleporter.
- Systems: **backup battery**, power allocation, reactor upgrade.
- UI: ShipView (procedural rects, **scaled 0.35, layout overlap-checked**), MapView (tap beacons, jump range 1-3), reusable CombatScreen (touch-sized buttons, panels at computed safe positions).
- Content: ships kestrel/engi_a/mantis_raider; 16 weapons; 9 drones; 18 events; 8 themes.
- Sound: 19 synthesized SFX via `SFX` autoload.

## Tests
- `godot --headless res://tests/test_runner.tscn` — 21 tests (ALL PASSED).
- `godot --headless res://tests/flow.tscn` — end-to-end random run (ALL PASSED; tops up fuel so it can't stall).
- `godot --headless res://tests/boss.tscn` — boss win path + ship unlocks (ALL PASSED).
- `xvfb-run godot res://tests/smoke.tscn` — click-through of every screen; expect `smoke ok`.
- `xvfb-run godot res://tests/shot.tscn` — renders combat/map/store + asserts no panel/ship overlap (`LAYOUT OK`); stress-tests with 10 crew + battery + doors.

## Gotchas
- Systems JSON id is `weapons` (plural): keep it everywhere.
- `godot --headless --script` does NOT load autoloads; run tests as scenes.
- GDScript: no `:=` from Dictionary/Variant, no `Rect2.x/.y`, autoload singletons are accessible by global name (e.g. `SFX.play`) even in RefCounted classes — do NOT use has_node/get_node in RefCounted.
- Ship/CombatManager extend RefCounted (not Node).
- Enemy ships are generated at runtime (not in Content) — save/restore builds them from stored room/grid defs.
- Flow/smoke tests randomize: first encounter may be battle/event/store; drivers handle all states + top up fuel.

## Next
1. Android APK still BLOCKED: need Android SDK + export templates on this machine.
2. Flagship multi-stage; more weapon/drone content; balance pass on rewards/difficulty.
3. If changing random tests, keep fuel-topping guard.
4. shot.tscn stress-test is the layout guard — keep it green when touching UI.

## Run
- Editor: `godot --path /home/etienne/projects/ftl`
- Import check: `godot --headless --import --path .`