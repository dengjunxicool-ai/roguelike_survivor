# Weapon Design Configs

This directory contains weapon branch design configs extracted from the full weapon branch design document.

These files are design-source configs, not the Godot runtime data files read directly from `data/*.json`. They are used as the structured source of truth when branch designs are migrated into `data/weapons.json`, `data/primary_attack.json`, `data/weapon_branches.json`, `data/weapon_evolutions.json`, and `data/combat_objects.json`.

See `SCHEMA_V2.md` for the unified structure.

## Files

| Weapon | Config |
| --- | --- |
| Fire Staff | `fire_staff.json` |
| Frost Staff | `frost_staff.json` |
| Lightning Whip | `lightning_whip.json` |
| Spellbook | `spellbook.json` |
| Throwing Knife Belt | `throwing_knife_belt.json` |
| Hunter Bow | `hunter_bow.json` |
| Trap Kit | `trap_kit.json` |
| Holy Shield | `holy_shield.json` |
| Warhammer | `warhammer.json` |
| Cross Relic | `cross_relic.json` |
| Toxic Vial | `toxic_vial.json` |
| Fire Oil Canister | `fire_oil_canister.json` |
| Acid Sprayer | `acid_sprayer.json` |

## Rules

- Each weapon has 4 branch archetypes: `coverage_clear`, `precision_hunt`, `status_reaction`, and `survival_control`.
- Each branch has fixed Lv2-Lv5 entries: direction, core engine, efficiency, and capstone.
- Each `level_path.<level>.runtime_modifiers` field uses structured modifier effects: `{ stat, op, value, scope }`.
- `design_modifiers` remains design-only and may contain values that are not yet runtime-supported.
- Damage ownership must distinguish `main_attack`, `dot`, `reaction`, `field`, `trap`, and `summon`.
- Boss compensation rules must be explicit and must not rely on generic area damage reductions.
- Derived attacks, bounces, reactions, fields, and summons must declare explicit limits to avoid unbounded recursion.
