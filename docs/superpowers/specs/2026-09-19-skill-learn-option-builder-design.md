# Skill Learn Option Builder Extraction Design

Date: 2026-09-19

## Purpose

Stage 4 reduces the option-construction responsibility inside `UpgradePool` without changing upgrade eligibility, randomness, weighting, guarantees, gameplay, or presentation. The result should make learn-skill card data independently understandable and testable while preserving `UpgradePool` as the stable orchestration facade.

This is an architectural refactor, not a performance or gameplay batch.

## Current Evidence

- `scripts/upgrades/upgrade_pool.gd` currently coordinates definition loading, player and skill-manager queries, eligibility checks, rarity selection, option construction, weighted selection, de-duplication, and guarantee replacement.
- `_build_god_skill_learn_options()` interleaves stateful orchestration with a deterministic dictionary transformation that produces the learn-skill card fields and payload.
- `scripts/upgrades/upgrade_selection_helper.gd` already owns weighted selection and de-duplication helpers.
- `scripts/upgrades/upgrade_offer_policy.gd` already owns offer conditions, phase-aware weights, and recommendation reasons.
- `scripts/upgrades/skill_learn_definition_repository.gd` already owns learn-skill definition filtering and synthetic upgrade construction.
- `scripts/upgrades/skill_offer_service.gd` already owns capacity, god-school, and fusion eligibility decisions.
- `scripts/upgrades/upgrade_option.gd` is the stable data object instantiated by `UpgradePool` from the constructed dictionary.

File length alone is not the reason for this work. The actionable cost is that deterministic learn-skill card construction is embedded in a stateful orchestration loop, so its fallback, payload, and non-mutation contracts cannot be verified directly without entering `UpgradePool`.

## Goals

1. Extract only the deterministic learn-skill option-data transformation into a pure `SkillLearnOptionBuilder`.
2. Keep definition access, player queries, eligibility, random rarity selection, weighting, de-duplication, and guarantees in their current owners.
3. Preserve `_build_god_skill_learn_options()` as the stable compatibility and orchestration method.
4. Preserve the exact option fields, fallback order, payload values, candidate order, and random-number consumption.
5. Add direct behavior tests for the Builder and a structural boundary test for `UpgradePool` delegation.
6. Keep the implementation independently verifiable and revertible as one Stage 4 batch.

## Non-Goals

- Do not change skill availability, ownership, capacity, god-school, or fusion rules.
- Do not change rarity generation, RNG call count, RNG call order, candidate iteration order, weights, de-duplication, or guarantee replacement.
- Do not move `GameData`, `Player`, `SkillManager`, `SkillOfferService`, `UpgradeOfferPolicy`, or SceneTree access into the Builder.
- Do not move `UpgradeOption` instantiation into the Builder.
- Do not change `_build_fire_skill_learn_options()` or the debug god-skill card builder beyond any necessary compatibility with the unchanged facade.
- Do not generalize all upgrade cards into a new framework.
- Do not change public methods, signals, scene paths, resource paths, configuration IDs, JSON schemas, save data, UI text, visual output, gameplay rules, or numerical balance.
- Do not remove compatibility helpers or duplicate data entry points in this stage.
- Do not claim a performance improvement without a separate benchmark.

## Selected Approach

Add one stateless Builder that accepts an already selected skill definition, its already constructed synthetic upgrade definition, and an already selected rarity. It returns the dictionary currently passed to `_make_option()`.

`UpgradePool` remains responsible for the loop and all runtime decisions. It calls the Builder only after the existing definition, eligibility, upgrade-ID, maximum-level, and rarity steps have run. It then instantiates `UpgradeOption` through the existing `_make_option()` path.

This is preferred over extracting the entire learn-skill loop because the loop owns runtime dependencies and randomness. It is also preferred over creating a generic option-builder framework because only one proven deterministic responsibility needs separation.

## Architecture and Dependency Direction

The dependency direction is one-way:

```text
UpgradePool
    -> loads learn-skill definitions
    -> queries player and SkillOfferService eligibility
    -> constructs the synthetic upgrade definition
    -> selects rarity with the existing RNG call
    -> calls SkillLearnOptionBuilder with explicit data
    -> instantiates UpgradeOption through _make_option()
    -> applies existing weight, de-duplication, and guarantee logic

SkillLearnOptionBuilder
    -> validates the two required IDs
    -> constructs and returns plain option data
    -> has no global, node, service, RNG, logging, or scene-tree dependency
```

The Builder must not preload or call `GameData`, `SkillOfferService`, `UpgradeOfferPolicy`, `SkillGrowthScaling`, `UpgradeSelectionHelper`, or `UpgradeOption`.

## New Builder Interface

Add `scripts/upgrades/skill_learn_option_builder.gd` with a stateless `RefCounted` class and this interface:

```gdscript
static func build_option_data(
    skill: Dictionary,
    upgrade: Dictionary,
    rarity: String
) -> Dictionary
```

The method returns an empty dictionary when either `skill.id` or `upgrade.id` is absent, null, or converts to an empty string. Otherwise it returns complete option data for the existing `UpgradeOption` constructor.

## Required Option-Data Semantics

For valid inputs, `build_option_data()` returns these fields with the current behavior:

```gdscript
{
    "id": "level_up_upgrade:<upgrade_id>:<rarity>",
    "type": "level_up_upgrade",
    "display_name": <upgrade display name, else skill display name, else skill ID>,
    "description": <first level description, else upgrade description, else empty>,
    "rarity": rarity,
    "background_texture": <skill background_texture, else skill card_background_texture, else empty>,
    "tags": <upgrade tags>,
    "affected_origin": "神系技能",
    "does_not_affect": "不替换角色初始技能。",
    "recommended_reason": "从神系技能池学习一个新技能。",
    "level_text": "Lv1 / <max_level>",
    "payload": {
        "upgrade_id": <StringName upgrade ID>,
        "learn_skill_id": <StringName skill ID>,
        "level": 1,
        "target_rarity": rarity
    }
}
```

Exact fallback rules are part of the contract:

- `display_name` first evaluates `upgrade.get("display_name", skill.get("display_name", skill_id))`; if that resulting value is null, it uses the skill ID. Therefore an absent upgrade key consults the skill display name, while an explicitly null upgrade value falls directly to the skill ID. Existing empty-string behavior is preserved rather than newly corrected.
- `description` uses element zero of `upgrade.level_descriptions` when the value is an array and is not empty. Otherwise it uses `upgrade.description`, then an empty string. An explicitly empty first description remains empty.
- `background_texture` checks only the supplied skill dictionary, first `background_texture`, then `card_background_texture`. The upgrade dictionary is not a new fallback source.
- `tags` is copied from `upgrade.tags` only when it is an array; otherwise it is empty.
- `max_level` is `max(int(skill.max_level with upgrade.max_level as its fallback), 1)`, matching the current expression and lower bound.
- `rarity` is copied exactly as supplied. The Builder neither selects nor normalizes it.
- IDs in the payload remain `StringName` values; the formatted option ID remains a string accepted by `UpgradeOption`.

## Ownership and Non-Mutation

- The Builder does not modify `skill`, `upgrade`, or nested caller-owned values.
- Mutable values placed in the result, including `tags` and `payload`, are newly owned by the result.
- The returned dictionary may be safely passed to `UpgradeOption.new()`, whose constructor retains its existing normalization and deep-copy behavior.
- The Builder performs no logging and creates no nodes or resources.

## UpgradePool Compatibility Delegate

`UpgradePool._build_god_skill_learn_options(player)` keeps its name, parameters, return shape, and orchestration responsibility. Its loop remains in the same order:

1. Read definitions from `_get_skill_learn_definitions()`.
2. Resolve `skill_id`.
3. Run `_is_learn_skill_upgrade_available()`.
4. Run `SkillOfferService.is_skill_available()`.
5. Construct the synthetic upgrade through `_make_god_skill_learn_upgrade()`.
6. Reject an empty upgrade ID.
7. Calculate the same maximum level.
8. Call `SkillGrowthScaling.pick_rarity_for_max_level()` exactly once at the same position.
9. Call `SkillLearnOptionBuilder.build_option_data()`.
10. Skip an empty Builder result; otherwise pass it to the existing `_make_option()` and append it.

The Builder call does not move before eligibility checks and does not add an RNG call. `_build_fire_skill_learn_options()` continues consuming the facade result unchanged.

## Weight, Guarantee, and Debug Boundaries

The following remain outside the Builder and retain their existing implementations:

- phase and condition policy evaluation;
- weight calculation and weighted selection;
- option de-duplication;
- active-skill or other guaranteed-offer replacement;
- ordinary non-learn upgrade construction;
- `_make_debug_god_skill_option()` and debug-only card text;
- current upgrade level queries;
- final `UpgradeOption` construction.

No generic card-data abstraction is introduced for these neighboring paths.

## Error and Edge-Case Handling

- Missing or empty skill IDs return `{}`.
- Missing or empty upgrade IDs return `{}`.
- Missing or non-array level descriptions fall back to the existing description field.
- Missing or non-array tags produce an empty array.
- Missing texture keys produce an empty string.
- Missing maximum levels still produce a minimum maximum level of `1` through the current fallback expression.
- Empty inputs do not log or raise new errors.
- `UpgradePool` skips an empty Builder result defensively. Under existing validated definitions, this path should be unreachable after the current upgrade-ID check; it does not alter valid candidate ordering.
- No new automatic correction, schema migration, or data repair is added.

## Behavior Invariants

- Candidate definition order is unchanged.
- Eligibility checks and their order are unchanged.
- RNG seed handling, call count, call order, and rarity values are unchanged.
- Option IDs, types, names, descriptions, rarities, texture paths, tags, fixed Chinese text, level text, and payload values are unchanged.
- The number and order of valid options are unchanged.
- Weighting, de-duplication, guarantee replacement, debug-card behavior, and fire-school filtering are unchanged.
- `_build_god_skill_learn_options()` and `_build_fire_skill_learn_options()` remain available with their current signatures.
- No public API, signal, node path, configuration ID, JSON schema, resource path, save result, UI layout, visual presentation, gameplay rule, or numerical value changes.

## Verification Strategy

### Test-First Builder Verification

Before production extraction, add a Godot headless verifier for `SkillLearnOptionBuilder.build_option_data()`. Observe it fail because the Builder does not yet exist or does not yet satisfy the contract. Cover:

- the complete valid result and exact key set;
- option-ID and payload `StringName` types;
- display-name fallback order, including existing empty-string behavior;
- first-level-description selection and description fallback;
- background-texture precedence and the absence of an upgrade-texture fallback;
- tag copying, heterogeneous values as currently accepted, and input non-mutation;
- maximum-level selection and minimum of one;
- exact fixed Chinese strings and level text;
- exact rarity pass-through;
- missing skill-ID and upgrade-ID rejection;
- missing or malformed optional arrays;
- result ownership across repeated calls.

### Structural Boundary Verification

Add or update a Node.js structural contract that verifies:

- the Builder file and static interface exist;
- `UpgradePool` preloads the Builder;
- `_build_god_skill_learn_options()` delegates option-data construction to it;
- `UpgradePool` still performs eligibility and rarity selection before delegation;
- `UpgradePool` still creates the final option through `_make_option()`;
- the moved option dictionary is not duplicated in `UpgradePool`;
- weighting, selection, guarantee, debug-card, and fire-filter methods remain present.

`tools/verify/verify_fire_skill_upgrade_pool.js` currently checks implementation markers inside `_build_god_skill_learn_options()`. Its structural expectation may be updated to require delegation while preserving all behavioral and boundary assertions. Assertions must not be removed merely to make the refactor pass.

### Focused Regression

Run the new Builder behavior verifier and boundary contract, then the existing checks most directly covering the learn-skill path:

- skill growth and upgrade-pool behavior;
- no relic/fireball/god-pool mixing;
- god-school learning rules;
- skill-card scaled values and rarity;
- fire skill upgrade-pool behavior;
- missing-rarity handling;
- active-skill guarantee behavior.

### System Regression

Run the established Stage 1 static baseline, the 11 sequential Godot behavior baseline tests, and the Stage 3 focused Builder tests. Godot checks run sequentially on this Windows host to avoid known concurrency instability.

Also run:

- `node tools/validate/check_text_encoding.js`;
- script parse checks for each modified GDScript;
- project headless startup;
- `git diff --check`.

Any failing baseline stops the batch. Record whether a failure is pre-existing, environmental, or introduced by Stage 4. Tests may not be weakened, skipped, or have thresholds relaxed to force a pass.

## Expected Implementation Scope

The implementation plan may include only the minimum files needed for this boundary:

- add `scripts/upgrades/skill_learn_option_builder.gd`;
- modify `scripts/upgrades/upgrade_pool.gd` to preload and delegate;
- add one focused Godot Builder verifier;
- add one focused structural boundary verifier;
- update `tools/verify/verify_fire_skill_upgrade_pool.js` only where its old inline-construction expectation must become a delegation expectation;
- update `package.json` only if named verification entries are needed;
- update the stability/boundary report after verified implementation.

File names for new verification scripts may be refined in the implementation plan, but their responsibilities may not expand.

## Completion Criteria

- The direct Builder behavior test was observed failing before implementation and passing afterward.
- The structural boundary test proves delegation without removing existing behavioral protections.
- `UpgradePool` retains all runtime decisions and its compatibility facade.
- Learn-skill card data has one production implementation in the Builder rather than a duplicate in `UpgradePool`.
- All focused, Stage 1, Stage 3, and 11 sequential Godot regression checks pass without new unexplained warnings.
- No user-owned untracked files are staged, modified, deleted, or overwritten.
- No production gameplay output changes.
- No performance claim is made; performance comparison is recorded as not applicable.
- The diff contains only the Stage 4 Builder extraction, its tests, required validation entries, and its documentation.

## Rollback

Stage 4 is implemented as a dedicated commit or a small ordered commit series on `codex/stage4-skill-learn-option-builder`. Reverting the Stage 4 implementation restores the inline dictionary construction in `_build_god_skill_learn_options()` and removes the Builder and its focused contracts. Because the facade, loop, and final `_make_option()` path remain stable, rollback does not require project-wide call-site changes or data migration.

## Deferred Work

The following require separate evidence, design, and approval:

- extracting ordinary upgrade-card construction;
- changing upgrade weights or offer policy;
- changing active-skill guarantees or replacement order;
- consolidating `DataManager` and `GameData` access;
- removing compatibility facades;
- optimizing allocation or option-pool performance;
- changing damage, status, enemy death, rewards, spawning, save, or settlement flows.
