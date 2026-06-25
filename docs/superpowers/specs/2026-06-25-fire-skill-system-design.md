# Fire Skill System First-Version Design

Date: 2026-06-25

## Goal

Implement the first version of the new data-driven skill system around the fire school. The existing 60 fire god skill cards are obsolete and may be removed entirely. The implementation should reuse the current gameplay runtime where it fits instead of replacing working systems wholesale.

The first version includes 34 skills:

- 14 fire base skills: 灼热攻击, 烈焰疾行, 流星火雨, 熔岩裂涌, 焚风旋涡, 赤焰龙, 余烬狐群, 炽燃专注, 过热施法, 焦土亲和, 燃爆连锁, 余烬附着, 引燃核心, 炼狱循环.
- 20 fire-related fusion skills: all bidirectional pairings that include fire, covering fire x frost/thunder/curse/holy/chaos and frost/thunder/curse/holy/chaos x fire.

Non-fire base schools are not fully implemented in this version, but their core statuses and school counts must exist enough to unlock and exercise fire-related fusion rules.

## Current Project Fit

The project already has useful runtime pieces:

- `SkillManager` stores learned active/passive skills, levels, and passive payloads.
- `SkillEventBus` dispatches runtime events and executes configured skill actions.
- `SkillActionExecutor` already supports many generic actions, including damage, status application, projectile spawning, area spawning, summon spawning, healing, knockback, and temporary modifiers.
- `StatusEffectManager` already handles status duration, stacks, DOT ticks, vulnerability, movement control, and status snapshots.
- `UpgradePool` already generates level-up options and can synthesize skill-learn cards from `data/skills.json`.

The design keeps those pieces and changes the data contract around them. Old fire card assumptions in data, dev tools, and verification scripts are no longer constraints.

## Chosen Approach

Use a data-model replacement with runtime reuse.

`data/skills.json` becomes the source of truth for the new `SkillDefinition` shape from the attached design document. Existing old fire cards are removed instead of translated one by one. Runtime classes are extended to understand the new fields and adapt them into the existing execution pipeline.

Rejected approaches:

- Keeping old and new skill card schemas side by side would make offer rules and runtime payloads ambiguous.
- Building a brand-new parallel `SkillSystem` would duplicate too much of the current combat runtime and raise integration risk.

## Data Model

Each new skill definition uses these fields as the primary schema:

- `id`
- `name`
- `school`
- `fusion_school`
- `type`
- `rarity`
- `max_level`
- `exclusive_group`
- `tags`
- `mechanic_family`
- `offer_rule`
- `trigger_rules`
- `effects`

Compatibility fields such as `display_name`, `category`, `events`, and `skill_modifiers` may still be generated or read internally, but they are not the authoring source for the new fire skill set.

`SkillDefinition` should parse the new fields directly. A small adapter should convert `trigger_rules` and `effects` to the current event/action execution format so existing `SkillEventBus` and `SkillActionExecutor` remain useful.

## Status Model

`data/status_effects.json` should include the core status IDs from the new design:

- `burning`
- `chilled`
- `frozen`
- `conductive`
- `overload`
- `cursed`
- `judgment`
- `instability`

`burning` is the primary fire status. The existing `burn` status may be mapped during migration, but new skills should author against `burning`.

Core behavior required in this version:

- `burning`: 4 seconds, max 5 stacks, 0.5 second tick, fire DOT using `0.18P * stacks`.
- `chilled`: stackable slow, converts to `frozen` when threshold is reached.
- `frozen`: short movement stop or boss/elite interruption.
- `conductive`: stackable lightning vulnerability, triggers `overload` at max stacks.
- `cursed`: delayed curse damage on expiration.
- `judgment`: stackable holy mark, triggers divine punishment at max stacks.
- `instability`: stackable chaos mark, triggers fission at max stacks.
- `overload`: instant event, not a persistent status.

The status manager must emit or expose enough event context for status applied, ticked, expired, max stack reached, and removed rules.

## Offer Rules

Add a skill offer service behind `UpgradePool`. It should evaluate:

- already learned skill IDs and current levels
- `exclusive_group` blocks for `attack_school`, `dash_school`, and `core_school`
- `required_schools`
- `required_skills`
- `required_min_skill_count`
- whether any fusion skill has already been learned
- rarity weight and level-up eligibility

Base fire skills enter the pool when fire is an available school context. Fire-related fusion skills enter only when the player owns enough skills from both required schools. The initial fusion unlock rule is:

- main fire-side school count >= 2
- paired school count >= 1

If a player has already learned any fusion skill, no other fusion skill enters the pool in this version.

## Runtime Events

Use the existing event bus as the dispatch layer. The new trigger rule adapter maps design triggers to event names already used or newly standardized in the runtime:

- `attack_hit`
- `dash_start`
- `dash_end`
- `cast_skill`
- `projectile_hit`
- `area_tick`
- `enemy_death`
- `status_applied`
- `status_tick`
- `status_expired`
- `status_max_stack_reached`
- `shield_gained`
- `shield_broken`
- `summon_attack_hit`

Each event context should include source, target, position, source skill ID, tags, and payload values where available.

Trigger rules need generic support for:

- conditions
- internal cooldown
- max triggers per second
- counters and thresholds
- source ID matching

These features should live in a reusable rule router or adapter layer, not in individual skill scripts.

## Effects

Reuse current `SkillActionExecutor` actions where possible. Add only the missing generic actions required for the fire and fire-fusion set.

Already covered or mostly covered:

- damage
- apply status
- spawn projectile
- spawn area
- spawn summon
- heal owner/caster
- knockback
- temporary modifier

New or normalized actions likely needed:

- `grant_shield`
- `pull`
- `repeat_skill`
- `transform_area`
- `transfer_status`
- `consume_status_duration`
- `trigger_overload`
- `shatter_frozen`
- `spawn_projectile_burst`
- `repeat_area_path`
- `spawn_area_from_existing_area`

The implementation should prefer generic action parameters over skill-specific branches.

## Skill Coverage Strategy

The 34 skills are implemented in three tiers.

Tier 1: direct data-driven skills.

These use existing generic effects for damage, status, area, projectile, summon, shield, heal, pull, and knockback. Examples include 流星火雨, 熔岩裂涌, 焚风旋涡, 烈焰疾行, 赤焰龙, and straightforward fusion effects such as extra fire/lightning fields or holy-fire paths.

Tier 2: counter and cooldown driven skills.

These use reusable trigger counters and ICD support. Examples include 灼热攻击, 余烬狐群, 燃爆连锁, 余烬附着, and 引燃核心.

Tier 3: reusable special-effect skills.

These require new generic action support for behavior such as path replay, status duration consumption, status transfer, area overlap reactions, and frozen shatter effects. They should still be expressed as data rules plus generic actions rather than one-off classes.

Unique visual polish is not a first-version blocker. Existing projectile, area, and particle resources may stand in while gameplay rules are made verifiable.

## Error Handling

Invalid skill data should fail loudly in static validation and degrade safely at runtime:

- Unknown skill IDs are skipped from offers.
- Unknown status IDs produce a warning and do not apply.
- Unsupported effect/action types produce a validation failure before runtime.
- Trigger rules with missing triggers, malformed conditions, or invalid cooldowns are rejected by validation.
- Missing visual resources should not block gameplay execution.

## Verification

Use static Node scripts plus Godot runtime smoke tests.

Static data checks:

- `data/skills.json` contains exactly the first-version fire scope: 14 fire base skills and 20 fire-related fusion skills.
- Old 60 fire card IDs and old fire-card contract checks are removed or rewritten.
- Every skill has required fields from the new schema.
- Every fusion skill has `fusion_school` and `required_min_skill_count`.
- Every trigger, condition, and effect type is supported by runtime code.
- Every skill has an effective runtime payload.

Offer-rule checks:

- Fire base skills appear under fire context.
- `attack_school`, `dash_school`, and `core_school` exclusivity works.
- Fire-related fusion skills appear only after both school-count requirements are met.
- Learning one fusion skill blocks other fusion offers.
- Skill level-ups respect `max_level`.

Runtime smoke checks:

- `burning` stacks, ticks, expires, and emits status events.
- At least one representative skill from each fire base type works: attack, dash, cast, summon, passive, power, core.
- At least one representative fusion for each fire pairing direction works: fire-frost, frost-fire, fire-thunder, thunder-fire, fire-curse, curse-fire, fire-holy, holy-fire, fire-chaos, chaos-fire.
- Every one of the 34 skills can be learned, has a runtime payload, and can process its primary trigger without throwing errors.

## Out Of Scope

- Full implementation of all non-fire base school skills.
- Full implementation of all 60 non-fire fusion skills.
- Final bespoke visual effects for every new skill.
- Balancing beyond the numeric values in the provided design document.
- Preserving old fire god skill cards or their exact debug tooling.

## Acceptance Criteria

The first version is complete when:

1. Old fire god skill card data is removed.
2. The new fire scope has exactly 34 authored skill definitions.
3. The new skill schema is parsed by runtime code.
4. Offer rules correctly handle fire base skills, exclusivity, and fire-related fusion unlocks.
5. Core statuses needed by fire and fire-related fusions are available.
6. Representative combat smoke tests pass.
7. Static validation confirms every authored skill has supported triggers, conditions, effects, and payload.
