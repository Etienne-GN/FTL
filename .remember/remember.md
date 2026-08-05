# Handoff

## State
- Godot 4.7 project `ftl` (repo `Etienne-GN/FTL`, MIT, pushed to main). Scaffold + content data + full combat model + playable combat scene. Headless tests all pass. Three commits pushed.
- Built: Ship/SystemState/Crew/Weapon/Drone models, CombatManager (laser/ion/missile/beam/flak/bomb, dodge, shields, drones, enemy AI), ContentDB autoload, GameState/SaveManager autoloads, ShipView renderer + Main scene HUD (power allocation, weapon targeting, pause, log, rewards). JSON data in `data/`.

## Next
1. Crew behaviour (Phase 3): movement pathing, manning bonuses, repair, fires/breaches, O2 suffocation, medbay heal, boarders.
2. Drones + teleporter/boarding (Phase 4) — drone power already modelled, needs UI + boarder combat.
3. Run structure (Phase 5): sector map generation, rebel fleet advance, jumps, event/store screens.

## Context
- Systems JSON id is `weapons` (plural) — ship defs, enemy gen and code all use `weapons`. Don't rename back to `weapon`.
- `godot --headless --script` does NOT load autoloads; tests must run as scenes: `godot --headless res://tests/test_runner.tscn`.
- GDScript strictness: no `:=` inference from Dictionary/Variant values, no `Rect2.x`/`.y` (use `.position`/`.size`), no method named `has_meta` (collides with Object).
- Ships start with power allocation from JSON `power` dict; enemy defs generate it in `GameState._enemy_def`.
- Run headless combat quickly: `godot --headless res://tests/test_runner.tscn`. Import check: `godot --headless --import`.
- User wants faithful original FTL for ALL mechanics, Android, landscape, save/quit anytime, ship unlocks on win.