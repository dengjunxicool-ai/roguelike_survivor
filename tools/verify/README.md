# Verification Scripts

`package.json` is the source of truth for runnable verification commands.

Most standalone `.js` and `.gd` checks in this directory have a matching
`npm run verify:*` entry. Scene-driven checks are registered through their
`.tscn` entry when the scene owns the script lifecycle:

- `verify_area_effect_visual_mode_runtime_scene.tscn`
- `verify_fireball_impact_target_explosion_runtime_scene.tscn`

`verify_fire_skill_card_selection_runtime.gd` covers the current DevTools card
selection contract: selecting a fire skill grants it, can cast once, and does
not spawn debug targets or enemies just to manufacture damage traces.
