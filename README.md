# Roguelike Survivor

A Godot 4.6 2D roguelike survivor prototype built around short runs, single-weapon specialization, branch choices, and weapon evolutions.

## Current Features

- WASD player movement with camera and background bounds.
- Character and weapon selection before each run.
- One equipped weapon per run, with a weapon-bound starting skill.
- Data-driven skill execution through components, events, and combat actions.
- Lv2 weapon branch lock, Lv3/Lv4/Lv5 branch progression, and Lv5 evolution options.
- Enemy wave timeline with normal waves, elites, rewards, and a final boss phase.
- Status effects, weapon base statuses, synergies, passive items, and permanent upgrades.
- Runtime UI state machine for menus, HUD, level-up choices, rewards, pause, and results.
- Debug tooling for progression, wave checks, visual checks, and full-flow autoplay.

## Project Layout

- `scenes/main.tscn`: main runtime scene.
- `scenes/ui/ui_prototype.tscn`: current UI entry scene, driven by `UIManager`.
- `scripts/player/`: player runtime, stats, upgrades, character/weapon setup.
- `scripts/characters/`: character definitions, runtime state, and traits.
- `scripts/weapons/`: weapon equip, branch, evolution, binding, and visual systems.
- `scripts/skills/`: skill definitions, execution, events, actions, targeting, and synergies.
- `scripts/combat/`: combat object factory, projectiles, areas, orbit objects, and statuses.
- `scripts/enemies/`: enemy base behavior, wave spawning, and boss behavior.
- `scripts/ui/`: current in-game UI state machine.
- `scripts/core/data_manager.gd`: autoload data index and primary data access layer.
- `scripts/game/game_data.gd`: compatibility facade that falls back to file reads when the autoload is unavailable.
- `data/`: JSON configuration for characters, weapons, branches, evolutions, skills, statuses, enemies, waves, upgrades, items, synergies, and combat objects.

## Architecture Notes

- `docs/UI_SYSTEM_OVERVIEW.md`: UI entry points, state machine, controllers, data dependencies, theming, responsive layout, and safe modification paths.

## Validation Helpers

- `scripts/debug/skill_progression_check.gd`
- `scripts/debug/wave_system_check.gd`
- `scripts/debug/visual_config_check.gd`
- `scenes/full_flow_autoplay.tscn`
