# Roguelike Survivor

A Godot 4.6 2D roguelike survivor prototype built around short runs, character selection, data-driven god skills, status reactions, enemy waves, and boss encounters.

## Current Features

- WASD player movement with camera and background bounds.
- Character selection before each run.
- Data-driven god skill execution through trigger rules, effects, components, events, and combat actions.
- Fire, frost, thunder, curse, holy, chaos, and fusion skill data contracts.
- Enemy wave timeline with normal waves, elites, rewards, and a final boss phase.
- Status effects, school synergies, passive items, and permanent upgrades.
- Runtime UI state machine for menus, HUD, level-up choices, rewards, pause, and results.
- Debug tooling for progression, wave checks, visual checks, and full-flow autoplay.

## Project Layout

- `scenes/main.tscn`: main runtime scene.
- `scenes/ui/ui_prototype.tscn`: current UI entry scene, driven by `UIManager`.
- `scripts/player/`: player runtime, stats, upgrades, and character setup.
- `scripts/characters/`: character definitions, runtime state, and traits.
- `scripts/skills/`: skill definitions, execution, events, actions, targeting, and synergies.
- `scripts/combat/`: combat object factory, projectiles, areas, orbit objects, and statuses.
- `scripts/enemies/`: enemy base behavior, wave spawning, and boss behavior.
- `scripts/ui/`: current in-game UI state machine.
- `scripts/core/data_manager.gd`: autoload data index and primary data access layer.
- `scripts/game/game_data.gd`: compatibility facade that falls back to file reads when the autoload is unavailable.
- `data/`: JSON configuration for characters, gods, skills, statuses, enemies, waves, upgrades, items, synergies, summons, and combat objects.

## Architecture Notes

- `docs/UI_SYSTEM_OVERVIEW.md`: UI entry points, state machine, controllers, data dependencies, theming, responsive layout, and safe modification paths.

## Validation Helpers

- `scripts/debug/wave_system_check.gd`
- `scripts/debug/enemy_skill_system_check.gd`
- `scripts/debug/enemy_timeline_system_check.gd`
- `tools/verify_title_screen_runtime.gd`
- `tools/verify_enemy_health_lag_bar_runtime.gd`
- `tools/verify_fire_skill_runtime_smoke.gd`
- `scenes/full_flow_autoplay.tscn`
