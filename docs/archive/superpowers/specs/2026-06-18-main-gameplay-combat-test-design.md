# Main Gameplay Combat Test Design

Date: 2026-06-18

## Goal

Build a repeatable test suite for the current main gameplay loop that validates weapon branch upgrades against the full weapon branch design document. The suite must prove three things:

1. A selected branch upgrade is applied to runtime state.
2. Damage, status, and special-rule values match the authored design/config.
3. A concrete combat scene behaves correctly, not only the JSON table.

The first target scene is:

```text
character: mage
weapon: fire_staff
branch: fire_staff_branch_soulburn or fire_staff_branch_burst
level: Lv2
action: attack once
target: small_slime
assertions: damage, status, special rule, attack trace
```

## Source Of Truth

The test suite uses this priority order for expectations:

1. The attached full weapon branch design document.
2. Runtime config in `data/weapon_branches.json`, `data/primary_attack.json`, `data/status_effects.json`, and `data/enemies.json`.
3. Existing runtime behavior in `scripts/skills/*`, `scripts/combat/*`, and `scripts/enemies/*`.

When design and JSON disagree, the test should fail with a clear message rather than silently pick one.

## Test Architecture

Use three layers.

### Layer 1: Static Contract Tests

Node.js tests validate that the authored data can express every branch rule in the design document.

Existing examples:

```powershell
node tools\verify_fire_staff_branch_table.js
node tools\verify_soulburn_lv3_rule.js
node tools\verify_soulburn_lv4_rule.js
node tools\verify_soulburn_lv5_rule.js
node tools\validate_weapon_authoring_pipeline.js
node tools\validate_branch_design_alignment.js
```

Add or extend static tests so each branch level validates:

- branch id
- level path
- modifiers
- events_added
- status ids
- special_rules
- damage_origin
- damage_type
- element
- boss multiplier
- cooldown / recursion constraints

### Layer 2: Runtime Scene Tests

Godot headless tests create a deterministic combat scene and execute one scripted action. These tests must not rely on UI choices or random targeting.

The generic fixture should support:

- spawn player from `character_id`
- equip `weapon_id`
- select `branch_id`
- set branch level
- spawn target enemy from `enemy_id`
- force attack once
- record damage trace
- inspect target health/status
- inspect spawned combat objects

### Layer 3: Full Flow Smoke Test

Keep `scripts/debug/full_flow_autoplay.gd` as the final smoke test. It verifies that title, character selection, weapon selection, map selection, combat, level-up UI, and continued play do not break.

## Test Scene Format

Each runtime test case should be data-driven:

```gdscript
{
	"id": "mage_fire_staff_soulburn_lv2_small_slime_attack_once",
	"character_id": &"mage",
	"weapon_id": &"fire_staff",
	"branch_id": &"fire_staff_branch_soulburn",
	"branch_level": 2,
	"target_enemy_id": &"small_slime",
	"target_count": 1,
	"action": "attack_once",
	"expect": {
		"damage_events": [
			{
				"source_skill_id": &"fireball",
				"source_weapon_id": &"fire_staff",
				"damage_origin": "primary_attack",
				"damage_type": &"direct_magical",
				"element": &"fire",
				"final_amount": 16
			}
		],
		"statuses": [
			{
				"target": "primary",
				"status_id": &"soul_ember",
				"stacks": 1,
				"duration": 4
			}
		],
		"special_rules": [
			"soul_ember_on_direct_hit"
		]
	}
}
```

The exact final damage can remain 16 for `small_slime` because the enemy has 18 HP, 0 defense, and no listed resistance. If the damage pipeline later changes rounding or minimum damage, this test should point to the damage-stage mismatch.

## First Required Runtime Cases

### Case 1: Soulburn Lv2 Applies Soul Ember

Scene:

```text
mage + fire_staff + fire_staff_branch_soulburn Lv2
attack once
target: small_slime
```

Expected:

- one fireball projectile is spawned
- direct hit damage is 16
- target HP goes from 18 to 2
- target receives `soul_ember` x1
- `soul_ember` duration is 4s
- no `burn` is applied at Lv2
- no reaction damage is emitted
- damage packet keeps `source_weapon_id=fire_staff`
- damage packet keeps `source_skill_id=fireball`
- damage packet uses `damage_origin=primary_attack`
- damage packet uses `damage_type=direct_magical`
- damage packet uses `element=fire`

### Case 2A: Burst Fireball Lv2 Single Slime

Scene:

```text
mage + fire_staff + fire_staff_branch_burst Lv2
attack once
target: 1 impact small_slime
```

Expected:

- one fireball projectile is spawned
- primary target direct hit damage is 16
- primary target HP goes from 18 to 2 after the direct hit
- explosion area is created from `create_explosion`
- explosion uses `generic_explosion_area`
- explosion radius starts from configured 82 and receives +15% runtime radius modifier
- explosion max targets is 4
- explosion damage origin is `reaction`
- explosion damage type is `area_direct`
- explosion element is `fire`
- impact target receives configured impact target explosion multiplier
- no `burn` is applied because the explosion hit count is below 3
- special rule `explosion_multi_hit_burn` is present but not triggered

### Case 2B: Burst Fireball Lv2 Burn Threshold

Scene:

```text
mage + fire_staff + fire_staff_branch_burst Lv2
attack once
targets: 1 impact small_slime + 2 nearby small_slimes
```

Expected:

- one fireball projectile is spawned
- explosion area is created from `create_explosion`
- explosion hit count reaches 3 normal enemies
- if 3 or more normal enemies are hit, each normal target receives `burn` x1 for 3s
- special rule `explosion_multi_hit_burn` triggers exactly once for the attack

### Case 3: Soulburn Lv3 Converts Ember To Burn

Scene:

```text
mage + fire_staff + fire_staff_branch_soulburn Lv3
attack same small_slime twice with cooldown bypassed or controlled time advance
```

Expected:

- first hit applies `soul_ember` x1
- second valid hit reaches 2 ember stacks
- rule `soul_ember_to_burn_on_full_stack_hit` consumes 2 ember stacks
- target receives `burn` x1
- direct fireball damage is reduced by 15%
- burn damage modifier is +30%
- no soulburn burst occurs before Lv5

### Case 4: Soulburn Lv5 Full Burn Burst

Scene:

```text
mage + fire_staff + fire_staff_branch_soulburn Lv5
preload target with burn x5
attack once
target: small_slime
```

Expected:

- direct hit happens first
- soulburn burst triggers once
- burst consumes all burn stacks
- burst is true-percent damage
- normal target damage is 3% max HP
- burst does not crit
- burst does not use primary attack damage bonuses
- burst cannot trigger death explosion
- same target cooldown is 2s

For `small_slime` max HP 18, 3% max HP is 0.54 before rounding. The test should assert the pipeline result and include the raw amount in trace output, so rounding regressions are visible.

### Case 5: Burst Fireball Lv5 Burning Death Explosion

Scene:

```text
mage + fire_staff + fire_staff_branch_burst Lv5
preload target with burn
kill target with fireball
nearby targets: 2 small_slimes
```

Expected:

- death explosion triggers only for burning target death
- explosion base damage is 35% of fireball direct base damage: 5.6
- damage origin is `reaction`
- element is `fire`
- max targets is 6
- same source cooldown is 0.25s
- explosion cannot trigger itself recursively

## Harness Design

Create one reusable script:

```text
scripts/debug/weapon_combat_scene_check.gd
```

Responsibilities:

- load game data
- construct deterministic player/enemy nodes
- configure character runtime and weapon runtime slot
- apply branch selection and level
- start debug combat trace
- force the skill event or combat-object hit
- collect:
  - target health
  - target status manager state
  - debug damage records
  - spawned projectile / area / orbit nodes
  - runtime branch state
- compare against case expectations
- print `[PASS]` / `[FAIL]` lines
- write a result file to `reports/combat-scene-checks/*.txt`

The script should avoid the full UI path for precision. Full UI remains covered by `full_flow_autoplay`.

## Assertion Rules

Every failure must include:

```text
case id
character id
weapon id
branch id
branch level
target enemy id
assertion name
expected value
actual value
source config path
```

Example:

```text
[FAIL] mage_fire_staff_soulburn_lv2_small_slime_attack_once status soul_ember stacks
expected: 1
actual: 0
source: data/weapon_branches.json fire_staff_branch_soulburn.level_path.2.special_rules.soul_ember_on_direct_hit
```

## Expansion Strategy

After the first five fire-staff cases pass, expand in this order:

1. One Lv2 scene test for every fire staff branch.
2. One representative Lv2 scene test for every weapon.
3. Lv3-Lv5 scene tests for status/reaction branches.
4. Boss/elite-specific branches using `giant_slime` and `dungeon_heart`.
5. Full 13 weapons x 4 branches x Lv2-Lv5 matrix.

Static contract tests should cover the full matrix immediately. Runtime scene tests can grow incrementally.

## Commands

Static gate:

```powershell
node tools\validate_weapon_authoring_pipeline.js
node tools\validate_branch_design_alignment.js
node tools\verify_fire_staff_branch_table.js
node tools\verify_soulburn_lv3_rule.js
node tools\verify_soulburn_lv4_rule.js
node tools\verify_soulburn_lv5_rule.js
```

Runtime gate:

```powershell
godot --headless --path . --quit
godot --headless --path . --script res://scripts/debug/weapon_combat_scene_check.gd
godot --headless --path . --script res://scripts/debug/full_flow_autoplay.gd
```

If `godot --headless --path . --quit` crashes, runtime scene tests are blocked and the report must say so. Static tests can still run.

## Acceptance Criteria

The work is complete when:

- the spec-backed fire staff scene tests exist
- the Lv2 soulburn small-slime scene checks damage/status/source fields
- the Lv2 burst fireball scene checks explosion shape and burn threshold
- at least one Lv3, Lv5 status/reaction rule is covered by runtime scene tests
- all existing static weapon contract tests still pass
- runtime commands either pass or report a Godot headless blocker clearly
