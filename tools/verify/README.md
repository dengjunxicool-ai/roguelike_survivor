# Verification Scripts

`package.json` is the source of truth for runnable verification commands.

Most standalone `.js` and `.gd` checks in this directory have a matching
`npm run verify:*` entry. Scene-driven checks are registered through their
`.tscn` entry when the scene owns the script lifecycle:

- `verify_area_effect_visual_mode_runtime_scene.tscn`
- `verify_fireball_impact_target_explosion_runtime_scene.tscn`

`verify_fire_skill_card_selection_runtime.gd` is intentionally not part of the
package verification matrix. It still assumes that selecting a fire skill card
must also observe a damage trace or popup, while the current DevTools flow
selects and grants the skill without spawning a debug target. Keep it as a
historical diagnostic until that old smoke path is either rewritten around the
current no-spawn contract or explicitly removed.
