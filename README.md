# Roguelike Survivor

A Godot 4.6 2D roguelike survivor prototype built around short runs, character selection, data-driven god skills, status reactions, enemy waves, and boss encounters.

## Current Features

Windows: double-click `run_game.cmd` to play in a separate window with working
fullscreen settings. This launcher stores saves and caches under
`E:/codex/roguelike-survivor`; it does not use the editor's embedded game view.
Godot game embedding does not support window mode changes. When playing from
the editor, disable **Embed Game on Next Play**, then restart the game.

The level-up skill selection has a free **Reroll Skills** button below the three
cards, limited to three free rerolls per pending upgrade. Rerolling keeps the
game paused and preserves the pending upgrade. Complete card effects appear
in a fixed details area below the cards, accessible with the mouse or keyboard.

Combat controls are shown before starting a run and in Settings/Pause:
WASD or arrows move, Space dashes, and Esc pauses. Attacks and skills trigger
automatically; dashing does not grant damage immunity.

Each character has a distinct starting attack: mage fireball, ranger piercing
arrow, paladin holy close-range strike, and alchemist status flask. Starting
attacks preserve both god-school choices. Character confirmation, map start,
and result retry remain visible outside scrolling information panels.

The battle HUD shows current wave time, character trait state (including shield
recharge and overload stacks), and a steady low-health warning. Empty skill
slots use compact markers; the skill bar keeps the ground visible underneath.
Pause includes expandable current attributes and learned-skill details, with
resume and exit actions fixed below the scroll area. Upgrade cards emphasize
readable conditions and actual current-to-next values, including summon timing.

开发者模式的 **Run Setup** 页提供「技能构筑」：选择角色与地图，按神系筛选并添加技能，
为每项设置等级和稀有度，支持移除与清空。未选替代攻击时保留角色默认攻击。
点击「使用构筑开始游戏」会重置本局、应用构筑并开启自动战斗与正常刷怪；按 F12 可再次显示工具栏。
构筑跳过学习等级和前置条件，仍限制两个神系及攻击、冲刺、主动、被动、核心、融合槽位与互斥技能。
原有 **Restart Run** 继续启动手动调试局。

- WASD player movement with camera and background bounds.
- Character selection before each run.
- Data-driven god skill execution through trigger rules, effects, components, events, and combat actions.
- Fire, frost, thunder, curse, holy, chaos, and fusion skill data contracts.
- Enemy wave timeline with normal waves, elites, rewards, and a final boss phase.
- Status effects, school synergies, passive items, and permanent upgrades.
- Runtime UI state machine for menus, HUD, level-up choices, rewards, pause, and results.
- Debug tooling for progression, wave checks, visual checks, and full-flow autoplay.

## Project Layout

- `scenes/app/main.tscn`: main runtime scene.
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
- [火焰神系特效](docs/FIRE_SCHOOL_VFX.md)：14 个基础技能的展示映射、生命周期、实际伤害验证和受控性能测量。
- [雷霆神系特效](docs/THUNDER_SCHOOL_VFX.md)：14 个基础技能的电弧、雷暴、召唤与真实蓄能反馈，以及伤害回归和性能测量。
- [诅咒神系特效](docs/CURSE_SCHOOL_VFX.md)：14 个基础技能的咒印、魂链、召唤与真实结算／资源展示，以及伤害修复和性能测量。
- [神圣神系特效](docs/HOLY_SCHOOL_VFX.md)：14 个基础技能的圣光、审判、护盾与召唤，以及真实格挡、伤害回归和性能测量。
- [混沌神系特效](docs/CHAOS_SCHOOL_VFX.md)：14 个基础技能的裂隙、奇点、复制召唤与真实失稳、熵增和施法进度。

## Validation Helpers

- `scripts/debug/wave_system_check.gd`
- `scripts/debug/enemy_skill_system_check.gd`
- `scripts/debug/enemy_timeline_system_check.gd`
- `tools/verify/verify_title_screen_runtime.gd`
- `tools/verify/verify_enemy_health_lag_bar_runtime.gd`
- `tools/verify/verify_fire_skill_runtime_smoke.gd`
- `scenes/app/full_flow_autoplay.tscn`
