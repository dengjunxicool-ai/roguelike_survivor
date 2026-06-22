# Codex Tasks

## Implemented

- Player movement with camera/background bounds.
- Runtime UI state machine for title, menu, selection, HUD, rewards, pause, and results.
- Character and single-weapon run setup.
- Weapon-bound starting skills.
- Data-driven skills through components, events, actions, and combat objects.
- Weapon branch progression at Lv2/Lv3/Lv4/Lv5.
- Weapon evolution after Lv5 branch completion.
- Status effects, synergies, passive items, and permanent upgrades.
- Enemy waves, elites, boss phase, experience collection, and soul rewards.
- Debug panels and automated check scenes.
- Data access consolidation through `DataManager`, with `GameData` retained as a compatibility facade.
- Removal of unused legacy panels and unused helper scripts.

## Next Candidates

- GDScript note: avoid using `trait` as a local variable name; use `trait_data` for character or weapon trait dictionaries.
- Finish UI text encoding cleanup across legacy Chinese strings.
- Replace placeholder icon visuals with real character, enemy, weapon, and VFX assets.
- Continue moving direct `GameData` callers to `DataManager` where node context is already available.
- Add CI-style Godot headless validation for progression, waves, and visual/debug checks.
- Expand audio, feedback, and polish passes after gameplay systems stabilize.
