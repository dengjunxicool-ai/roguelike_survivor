# Full Weapon Branch Matrix Test Design

Date: 2026-06-18

## Goal

Build a complete automated test strategy for all current main-weapon progression combinations:

```text
4 characters x their allowed weapons x each weapon's 4 branches x Lv1-Lv5
```

The current data set contains:

```text
characters: 4
weapons: 13
branches: 52
levels per branch: 5
total test combinations: 260
```

The suite must prove three things for every combination:

1. The character can enter combat with the weapon and branch.
2. The branch level is applied to the real runtime state.
3. The weapon's attack form, damage/status output, and special rules match the authored data.

## Source Of Truth

Use this priority order:

1. Current design documents and weapon branch templates.
2. Runtime data files:
   - `data/characters.json`
   - `data/weapons.json`
   - `data/weapon_branches.json`
   - `data/primary_attack.json`
   - `data/combat_objects.json`
   - `data/status_effects.json`
   - `data/enemies.json`
3. Runtime behavior in:
   - `scripts/ui/ui_manager.gd`
   - `scripts/skills/*`
   - `scripts/combat/*`
   - `scripts/debug/debug_combat_trace.gd`

If design text and runtime JSON disagree, the test should fail with both values and the source paths. It must not silently choose one.

## Coverage Matrix

### Mage

```text
mage total: 4 weapons, 16 branches, 80 level cases
```

| Weapon | Skill | Branch | Levels |
| --- | --- | --- | --- |
| fire_staff | fireball | fire_staff_branch_burst | Lv1-Lv5 |
| fire_staff | fireball | fire_staff_branch_rapid | Lv1-Lv5 |
| fire_staff | fireball | fire_staff_branch_soulburn | Lv1-Lv5 |
| fire_staff | fireball | fire_staff_branch_lava | Lv1-Lv5 |
| frost_staff | hailstorm | frost_staff_branch_dense | Lv1-Lv5 |
| frost_staff | hailstorm | frost_staff_branch_lockdown | Lv1-Lv5 |
| frost_staff | hailstorm | frost_staff_branch_shatter | Lv1-Lv5 |
| frost_staff | hailstorm | frost_staff_branch_icicle | Lv1-Lv5 |
| lightning_whip | lightning_orb | lightning_whip_branch_chain | Lv1-Lv5 |
| lightning_whip | lightning_orb | lightning_whip_branch_overload_core | Lv1-Lv5 |
| lightning_whip | lightning_orb | lightning_whip_branch_lash | Lv1-Lv5 |
| lightning_whip | lightning_orb | lightning_whip_branch_dual_orb | Lv1-Lv5 |
| spellbook | arcane_pages | spellbook_branch_copy | Lv1-Lv5 |
| spellbook | arcane_pages | spellbook_branch_barrage | Lv1-Lv5 |
| spellbook | arcane_pages | spellbook_branch_forbidden | Lv1-Lv5 |
| spellbook | arcane_pages | spellbook_branch_guardian_page | Lv1-Lv5 |

### Ranger

```text
ranger total: 3 weapons, 12 branches, 60 level cases
```

| Weapon | Skill | Branch | Levels |
| --- | --- | --- | --- |
| throwing_knife_belt | throwing_knife | throwing_knife_belt_branch_thousand | Lv1-Lv5 |
| throwing_knife_belt | throwing_knife | throwing_knife_belt_branch_execution | Lv1-Lv5 |
| throwing_knife_belt | throwing_knife | throwing_knife_belt_branch_bloodshadow | Lv1-Lv5 |
| throwing_knife_belt | throwing_knife | throwing_knife_belt_branch_cloudpiercer | Lv1-Lv5 |
| hunter_bow | piercing_arrow | hunter_bow_branch_volley | Lv1-Lv5 |
| hunter_bow | piercing_arrow | hunter_bow_branch_snipe | Lv1-Lv5 |
| hunter_bow | piercing_arrow | hunter_bow_branch_explosive | Lv1-Lv5 |
| hunter_bow | piercing_arrow | hunter_bow_branch_boomerang | Lv1-Lv5 |
| trap_kit | bear_trap | trap_kit_branch_toxic_spike | Lv1-Lv5 |
| trap_kit | bear_trap | trap_kit_branch_hunter_mark | Lv1-Lv5 |
| trap_kit | bear_trap | trap_kit_branch_blast | Lv1-Lv5 |
| trap_kit | bear_trap | trap_kit_branch_ice_lock | Lv1-Lv5 |

### Paladin

```text
paladin total: 3 weapons, 12 branches, 60 level cases
```

| Weapon | Skill | Branch | Levels |
| --- | --- | --- | --- |
| holy_shield | holy_shield | holy_shield_branch_charge | Lv1-Lv5 |
| holy_shield | holy_shield | holy_shield_branch_purify | Lv1-Lv5 |
| holy_shield | holy_shield | holy_shield_branch_counter | Lv1-Lv5 |
| holy_shield | holy_shield | holy_shield_branch_wall | Lv1-Lv5 |
| warhammer | judgement_hammer | warhammer_branch_quake | Lv1-Lv5 |
| warhammer | judgement_hammer | warhammer_branch_heaven | Lv1-Lv5 |
| warhammer | judgement_hammer | warhammer_branch_punish | Lv1-Lv5 |
| warhammer | judgement_hammer | warhammer_branch_combo | Lv1-Lv5 |
| cross_relic | holy_field | cross_relic_branch_pulse | Lv1-Lv5 |
| cross_relic | holy_field | cross_relic_branch_judgement | Lv1-Lv5 |
| cross_relic | holy_field | cross_relic_branch_purify_field | Lv1-Lv5 |
| cross_relic | holy_field | cross_relic_branch_shelter | Lv1-Lv5 |

### Alchemist

```text
alchemist total: 3 weapons, 12 branches, 60 level cases
```

| Weapon | Skill | Branch | Levels |
| --- | --- | --- | --- |
| toxic_vial | poison_bottle | toxic_vial_branch_spread | Lv1-Lv5 |
| toxic_vial | poison_bottle | toxic_vial_branch_corrosion | Lv1-Lv5 |
| toxic_vial | poison_bottle | toxic_vial_branch_toxic_burst | Lv1-Lv5 |
| toxic_vial | poison_bottle | toxic_vial_branch_paralyze | Lv1-Lv5 |
| fire_oil_canister | burning_oil_pot | fire_oil_canister_branch_carpet | Lv1-Lv5 |
| fire_oil_canister | burning_oil_pot | fire_oil_canister_branch_sticky | Lv1-Lv5 |
| fire_oil_canister | burning_oil_pot | fire_oil_canister_branch_detonate | Lv1-Lv5 |
| fire_oil_canister | burning_oil_pot | fire_oil_canister_branch_blackfire | Lv1-Lv5 |
| acid_sprayer | acid_spray | acid_sprayer_branch_pressure | Lv1-Lv5 |
| acid_sprayer | acid_spray | acid_sprayer_branch_melt_armor | Lv1-Lv5 |
| acid_sprayer | acid_spray | acid_sprayer_branch_acid_burst | Lv1-Lv5 |
| acid_sprayer | acid_spray | acid_sprayer_branch_fan | Lv1-Lv5 |

## Test Layers

Use three layers. All 260 combinations must appear in the report, but not every layer has the same cost.

### Layer 1: Static Matrix Contract

This layer is fast and should run for all 260 combinations.

For each combination, assert:

- `character_id` exists.
- `weapon_id` exists.
- `weapon_id` is listed in `character.allowed_weapon_ids`.
- `weapon.character_id` matches the character.
- `weapon.starting_skill_id` exists in `data/primary_attack.json`.
- `branch_id` exists.
- `branch.weapon_id` matches the weapon.
- Lv1 is treated as the base weapon state.
- Lv2-Lv5 all exist in `branch.level_path`.
- Every `modifier` has legal `stat`, `op`, `value`, and `scope`.
- Every `events_added` action references valid event/action/object ids.
- Every `special_rules` entry has valid status ids, damage fields, cooldown fields, and recursion flags when relevant.

This layer catches authoring mistakes before Godot runtime tests start.

### Layer 2: Runtime Smoke Matrix

This layer also runs for all 260 combinations, but uses one short deterministic scene per case.

For each combination:

1. Start a developer debug run through `UIManager.start_developer_debug_run`.
2. Use the real character, weapon, skill manager, branch system, and skill executor.
3. Apply the branch and requested level.
4. Spawn deterministic targets.
5. Trigger one controlled action:
   - `attack_once` for projectile, melee, chain, area, field, and cone weapons.
   - `tick_once` or `wait_ticks` for field, trap, oil, poison, and DOT weapons when one attack does not immediately hit.
   - `player_damaged_once` for defensive branches.
   - `kill_target_once` for death-trigger branches.
6. Read `DebugCombatTrace` and enemy/player state.

Minimum runtime assertions:

- The real player exists.
- `SkillExecutor` exists.
- `WeaponBranchSystem` exists.
- The weapon skill exists.
- The weapon skill current level equals the requested level.
- The selected branch has been applied through the runtime branch system.
- The action does not crash or hang.
- `source_weapon_id` is correct when damage is produced.
- `source_skill_id` is correct when damage is produced.
- At least one expected runtime artifact exists:
  - damage record
  - status stack
  - projectile
  - area object
  - field object
  - trap object
  - shield state
  - player buff/debuff
  - reaction trace

### Layer 3: Rule-Template Combat Scene Checks

This layer verifies the actual branch behavior. It should still cover all 260 combinations, but it should generate the expected scene type from the branch data instead of hand-writing 260 bespoke cases.

Scene templates:

| Template | Use When | Required Checks |
| --- | --- | --- |
| `base_attack` | Lv1 and pure damage branches | damage origin, damage type, element, raw/final amount |
| `direct_hit_status` | rule applies status on direct hit | status id, stacks, duration, max stacks, cooldown |
| `multi_target_area` | explosion, splash, field, or area rule | radius, max targets, hit count, area damage, area status |
| `elite_boss_rule` | rule mentions elite, boss, poise, mark, core, or strong target | elite/Boss status, bonus damage, boss multiplier |
| `stack_conversion` | rule consumes one status and applies another | pre-stack, consume count, resulting status, max stack |
| `reaction_burst` | rule creates reaction damage or burst | raw amount, final amount, element, origin, cooldown, crit flags |
| `field_tick` | poison, oil, holy field, lava, trap tick | tick interval, duration, tick count, per-tick value |
| `spawn_object` | rule creates projectile, trap, zone, page, orb, wall, shield, or cloud | object id, count, lifetime, position, radius |
| `player_defense` | rule modifies shield, damage taken, heal, speed, or survival | player status, shield amount, damage taken modifier |
| `death_trigger` | rule triggers on kill/death | trigger condition, non-recursion, cooldown, spawned effect |
| `every_n_casts` | rule triggers on nth cast/hit/tick | counter before/after, trigger interval, reset behavior |

For a branch level with multiple rule types, generate one primary scene and optional sub-assertions in the same scene. Example: a Lv5 reaction branch can use `reaction_burst` and also assert `stack_conversion` prerequisites.

## Case Naming

Use stable ids:

```text
<character_id>__<weapon_id>__<branch_id>__lv<level>__<template>
```

Examples:

```text
mage__fire_staff__fire_staff_branch_soulburn__lv2__direct_hit_status
mage__fire_staff__fire_staff_branch_burst__lv2__multi_target_area
ranger__hunter_bow__hunter_bow_branch_snipe__lv3__elite_boss_rule
paladin__holy_shield__holy_shield_branch_counter__lv5__player_defense
alchemist__acid_sprayer__acid_sprayer_branch_acid_burst__lv5__reaction_burst
```

## Lv1 Semantics

Lv1 means:

- The character equips the weapon.
- The weapon's starting skill is present.
- No Lv2-Lv5 branch effects are applied.
- The branch id may be selected as the intended future branch, but no branch level effect should be active.

Lv1 checks:

- base attack form works
- base damage/status/field output matches `primary_attack.json`
- no branch-only `special_rules` fire
- no branch-only `events_added` output exists
- trace still carries correct `source_weapon_id` and `source_skill_id`

## Target Scene Selection

Use a deterministic enemy set. The harness should choose targets based on rule needs:

| Need | Target Setup |
| --- | --- |
| single direct hit | one `small_slime` |
| multi-target area | three to five `small_slime` instances inside expected radius |
| max target cap | more enemies than max target count |
| elite-only rule | one elite enemy from current enemy data |
| boss-only rule | one boss enemy from current enemy data |
| status conversion | one durable target with preloaded stacks or repeated controlled hits |
| kill trigger | one low-HP target plus nearby durable targets |
| player defense | player plus one enemy or direct damage packet |
| field/trap tick | durable target inside field/trap for controlled time |

The test report must record which enemy id was used for each case.

## Assertions

Every failure must include:

```text
case_id
character_id
weapon_id
starting_skill_id
branch_id
level
template
target_enemy_ids
assertion_name
expected
actual
source_config_path
trace_summary
```

Damage assertions:

- raw amount
- final amount
- source weapon id
- source skill id
- source instance id when available
- damage origin
- damage type
- element
- crit allowed / not allowed
- character multiplier used / not used
- skill level coefficient used / not used

Status assertions:

- status id
- stacks
- max stacks
- duration
- consume count
- target type constraints
- cooldown constraints

Object assertions:

- object id
- object type
- radius
- duration
- tick interval
- max targets
- count
- spawn position rule

Special-rule assertions:

- trigger condition
- preconditions
- cooldown
- non-recursion
- boss/elite/normal differences
- rule-specific numeric values

## Reports

Generate at least two reports.

Machine-readable report:

```text
reports/combat-scene-checks/full_weapon_branch_matrix.json
```

Human-readable report:

```text
reports/combat-scene-checks/full_weapon_branch_matrix.txt
```

Each report groups results by:

```text
character -> weapon -> branch -> level
```

The summary must include:

```text
total_cases: 260
passed_cases
failed_cases
skipped_cases
static_failures
runtime_failures
rule_template_failures
duration_ms
```

Skipped cases are only allowed when the report names a concrete blocker, such as a missing runtime API or missing enemy type. A skipped case still counts as incomplete.

## Execution Strategy

Phase 1: Matrix generator

- Read characters, weapons, branches, primary attacks.
- Generate all 260 combinations.
- Fail if the count is not 260.
- Write the matrix JSON.

Phase 2: Static full-matrix validation

- Validate ownership and schema for all combinations.
- Integrate existing `verify_*_branch_table.js` checks.
- Keep existing `validate_weapon_authoring_pipeline.js` as a static gate.

Phase 3: Runtime smoke full-matrix validation

- Run all 260 combinations through the Dev Mode runtime.
- Keep the scene short.
- Assert runtime branch application and minimum attack artifact.

Phase 4: Rule-template validation

- Classify each branch level by `modifiers`, `events_added`, and `special_rules`.
- Pick the matching scene template.
- Assert exact numeric and state behavior.

Phase 5: Manual representative scene catalog

- Keep a curated set of high-signal fixed scenes for debugging and design review.
- At minimum, include one representative scene per weapon.
- For complex weapons, include one scene per branch archetype.

## Representative Fixed Scenes

These scenes are not the whole suite; they are the human-readable debugging set.

| Character | Weapon | Branch | Level | Scene |
| --- | --- | --- | --- | --- |
| mage | fire_staff | fire_staff_branch_burst | Lv2 | attack once into three small slimes |
| mage | frost_staff | frost_staff_branch_shatter | Lv3 | build frostbite then trigger shatter |
| mage | lightning_whip | lightning_whip_branch_chain | Lv2 | chain between several enemies |
| mage | spellbook | spellbook_branch_barrage | Lv3 | verify extra pages/projectiles |
| ranger | throwing_knife_belt | throwing_knife_belt_branch_execution | Lv3 | elite/Boss execution condition |
| ranger | hunter_bow | hunter_bow_branch_snipe | Lv3 | boss/elite precision hit |
| ranger | trap_kit | trap_kit_branch_blast | Lv3 | trap explosion area |
| paladin | holy_shield | holy_shield_branch_counter | Lv5 | player damaged then counter rule |
| paladin | warhammer | warhammer_branch_quake | Lv3 | area quake hit count |
| paladin | cross_relic | cross_relic_branch_shelter | Lv5 | field shelter defensive behavior |
| alchemist | toxic_vial | toxic_vial_branch_toxic_burst | Lv3 | poison stack reaction |
| alchemist | fire_oil_canister | fire_oil_canister_branch_detonate | Lv5 | oil stack secondary deflagration |
| alchemist | acid_sprayer | acid_sprayer_branch_acid_burst | Lv5 | full acid residue spread |

## Commands

Static gate:

```powershell
node tools\validate_weapon_authoring_pipeline.js
```

Runtime smoke gate:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://scripts/debug/full_weapon_branch_matrix_check.gd -- --mode smoke
```

Rule-template gate:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://scripts/debug/full_weapon_branch_matrix_check.gd -- --mode rules
```

Curated scene gate:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://scripts/debug/weapon_combat_scene_check.gd
```

## Acceptance Criteria

The testing work is complete when:

- The generated matrix contains exactly 260 cases.
- Every case has a stable id.
- Every case maps to one of the 4 characters.
- Every case maps to one allowed weapon for that character.
- Every case maps to one valid branch for that weapon.
- Every branch appears at Lv1, Lv2, Lv3, Lv4, and Lv5.
- Static validation reports all 260 combinations.
- Runtime smoke validation reports all 260 combinations.
- Rule-template validation reports all 260 combinations.
- The human-readable report can answer:
  - did the upgrade apply?
  - did the attack form match?
  - did damage/status/special rules match expected values?
- Any failure points to source config and trace output.
- No case is silently skipped.

## Known Current Risks

The existing static authoring pipeline currently has known failures around fire staff design/config alignment and area visual mode. The full-matrix suite should surface those failures clearly rather than hide them.

The existing Godot runtime emits warnings for legacy `damage_type='fire'` configuration and area-effect monitor-state changes during physics callbacks. The matrix suite should record these as runtime warnings. They should become hard failures only after the underlying runtime behavior is fixed or the team decides warnings should block CI.

