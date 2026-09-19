# Skill Action Builder Extraction Design

Date: 2026-09-19

## Purpose

Stage 3 reduces the parameter-building responsibilities inside `SkillActionExecutor` without changing gameplay or widening the refactor into damage, status, special-rule, or object-lifecycle behavior. The result should make projectile and area parameter transformations independently understandable and testable while preserving `SkillActionExecutor.execute_action()` as the stable runtime facade.

This is an architectural refactor, not a performance or gameplay batch.

## Current Evidence

- `scripts/skills/skill_action_executor.gd` is approximately 2,585 lines and handles action dispatch, runtime dependency resolution, side effects, and parameter construction.
- `scripts/skills/skill_action_projectile_builder.gd` already owns projectile launch geometry, target sequencing, and final spawn-dictionary construction.
- `scripts/skills/skill_action_area_builder.gd` already owns final area-effect spawn-dictionary construction.
- The executor still contains pure or nearly pure projectile transformations for repeated hits, action filtering, status normalization, and resolved runtime-data assembly.
- The executor still contains instant-area visual parameter merging that can be pure when the combat-object definition is supplied by the caller.
- Area damage, modifier resolution, special-rule handling, cast identity, metadata consumption, node creation, pooling, and scene-tree access remain stateful runtime responsibilities.

File length alone is not the reason for this work. The actionable cost is that deterministic transformations cannot be tested without entering the large executor, while stateful and stateless responsibilities remain interleaved.

## Goals

1. Move selected deterministic projectile transformations into `SkillActionProjectileBuilder`.
2. Move instant-area visual parameter merging into `SkillActionAreaBuilder`.
3. Keep runtime dependency resolution and all side effects inside `SkillActionExecutor`.
4. Preserve existing executor method names as thin compatibility delegates during this stage.
5. Add direct behavior tests for each new Builder interface and a structural delegation contract for the executor.
6. Keep every implementation batch independently verifiable and revertible.

## Non-Goals

- Do not change `execute_action()` or its action-type dispatch table.
- Do not split projectile, area, status, summon, or modifier execution into new executor objects.
- Do not change DamagePacket construction, damage formulas, status application, event order, or target selection.
- Do not move `ModifierResolver` calls into a Builder.
- Do not move special-rule branches or skill-instance metadata reads/writes into a Builder.
- Do not move parent lookup, cast-instance ID generation, scene-tree access, pooling, factory calls, or node metadata registration.
- Do not change JSON data, configuration IDs, schemas, numerical values, visuals, node paths, signals, or save behavior.
- Do not remove compatibility methods merely because their implementations become one-line delegates.
- Do not claim a performance improvement without a separate benchmark.

## Selected Approach

Extend the two existing stateless Builder classes in small batches. The executor resolves runtime dependencies and passes explicit inputs to pure static functions. Existing executor helpers remain as forwarding methods so call sites and any string-based internal access remain stable.

This is preferred over moving all projectile and area resolvers because several current resolvers consume runtime state or mutate skill metadata. It is also preferred over introducing action-family executors because that would change component ownership and dependency flow far beyond the low-risk Stage 3 goal.

## Architecture and Dependency Direction

The dependency direction remains one-way:

```text
SkillActionExecutor
    -> resolves context, modifiers, definitions, parent, and cast identity
    -> calls pure SkillActionProjectileBuilder functions
    -> calls pure SkillActionAreaBuilder functions
    -> invokes CombatObjectFactory and runtime side effects

SkillActionProjectileBuilder
    -> depends only on explicit values, dictionaries, arrays, vectors, and supplied nodes

SkillActionAreaBuilder
    -> depends only on explicit values, dictionaries, arrays, vectors, colors, and supplied nodes
```

Neither Builder may locate autoloads, inspect the SceneTree, consume skill metadata, generate cast IDs, call factories, or apply gameplay effects.

## Batch 3A: Projectile Pure Transformations

### New Builder Interfaces

`SkillActionProjectileBuilder` adds these static methods:

```gdscript
static func resolve_same_target_spawn_delay(params: Dictionary, same_target_hit_index: int) -> float

static func build_same_target_hit_params(params: Dictionary, same_target_hit_index: int) -> Dictionary

static func filter_damage_actions(actions: Array) -> Array

static func normalize_status_ids(values: Array) -> Array[StringName]

static func build_runtime_data(input: Dictionary) -> Dictionary
```

### Required Semantics

`resolve_same_target_spawn_delay()`:

- returns `0.0` for index `0` or any negative index;
- clamps a negative configured delay to `0.0`;
- multiplies the non-negative delay by the positive hit index.

`build_same_target_hit_params()`:

- returns the original parameter dictionary when the hit index is not positive;
- returns the original parameter dictionary when `same_target_repeat_damage_only` is false or absent;
- otherwise returns a deep duplicate;
- replaces `actions_on_hit` with deep-duplicated `deal_damage` actions only;
- ignores non-dictionary actions;
- does not mutate the input dictionary or its nested action dictionaries.

`filter_damage_actions()`:

- preserves the original order of valid `deal_damage` actions;
- deep-duplicates retained dictionaries;
- ignores non-dictionary entries and non-damage actions;
- does not mutate the input array.

`normalize_status_ids()`:

- converts each supplied value to `StringName` in its existing order;
- preserves duplicates because changing duplicate behavior would be a gameplay change;
- returns a typed `Array[StringName]`;
- does not mutate the input array.

`build_runtime_data()` accepts already resolved inputs and returns exactly these fields:

```gdscript
{
    "speed": float,
    "pierce": int,
    "radius": float,
    "lifetime": float,
    "damage": int,
    "source_id": StringName,
    "statuses_on_hit": Array,
    "parent": Node or null,
    "cast_instance_id": String
}
```

Its defaults must match the current executor implementation: speed `420.0`, pierce `0`, radius `10.0`, lifetime `2.0`, damage `0`, empty source ID, empty statuses, null parent, and empty cast-instance ID.

### Executor Compatibility Delegates

The following executor methods remain and delegate to the Builder:

- `_same_target_projectile_spawn_delay()`
- `_projectile_params_for_same_target_hit()`
- `_damage_only_actions()`
- `_build_projectile_runtime_data()` after the executor has resolved statuses, parent, and cast identity
- `_get_projectile_runtime_statuses_on_hit()`

`_resolve_projectile_runtime_stats()` remains in the executor because it uses `ModifierResolver` and scaled runtime stats.

## Batch 3B: Area Visual Parameter Transformation

### New Builder Interface

`SkillActionAreaBuilder` adds:

```gdscript
static func build_instant_hit_visual_params(
    params: Dictionary,
    definition: Dictionary,
    radius: float
) -> Dictionary
```

### Required Semantics

The returned dictionary always contains:

```gdscript
{
    "radius": radius,
    "duration": float(params.get("visual_duration", params.get("duration", 0.12)))
}
```

For `visual_color` and `visual_ring_color`:

1. An explicit value in `params` wins.
2. Otherwise, the value from `definition` is used.
3. If neither source contains the key, the result does not add that key.

The Builder does not look up `definition`. `SkillActionExecutor` continues using its existing DataManager lookup and passes the resulting dictionary to the Builder.

### Executor Compatibility Delegate

`_instant_area_hit_visual_params()` remains in the executor. It obtains the combat-object definition through the existing runtime path, then delegates the merge to `SkillActionAreaBuilder.build_instant_hit_visual_params()`.

No other area resolver moves in Stage 3. In particular, radius, damage, maximum-target, maximum-active, duration, tick interval, direction, special-rule, and metadata-registration logic remains in the executor.

## Batch 3C: Boundary Contract and Regression

Add a focused Godot headless behavior verifier that invokes both Builders directly. Add a Node.js structural contract that verifies:

- the new Builder methods exist;
- the executor preloads both Builders;
- the named compatibility helpers delegate to the appropriate Builder;
- the moved algorithm bodies do not remain duplicated in the executor;
- `execute_action()` and its dispatch cases remain present.

The structural contract protects the architecture boundary; the Godot verifier protects actual Dictionary, Array, type, default, and non-mutation behavior.

## Behavior Invariants

- `SkillActionExecutor.execute_action(action, context)` keeps its signature and action dispatch behavior.
- Projectile counts, timing, trajectories, damage packets, statuses, source identities, parents, and factory inputs remain unchanged.
- Repeated-hit damage-only behavior keeps the same filtering and deep-copy behavior.
- Instant-area radius, duration, colors, pooling, metadata, and factory behavior remain unchanged.
- Input dictionaries and arrays receive no new mutation.
- No public method, signal, node path, resource path, configuration ID, JSON schema, save result, UI, or visual output changes.
- No compatibility helper is deleted in this stage.

## Error and Edge-Case Handling

- Builder methods use the same fallback values as the current executor rather than raising new errors.
- Invalid or heterogeneous action arrays continue to ignore entries that are not dictionaries.
- Empty status arrays return a valid empty typed array.
- Null parent values are carried through runtime data without scene-tree lookup.
- Negative repeated-hit indexes behave like the first hit and receive no delay or filtering.
- Negative delay values are clamped to zero, matching current behavior.
- Missing visual definitions produce radius and duration only.
- Neither Builder logs, reports, or swallows runtime errors from external services because neither calls an external service.

## Verification Strategy

### Test-First Builder Verification

Before changing production code, create direct tests that fail because the new methods do not exist or the boundary has not moved. The tests cover:

- first, negative, and later repeated-hit indexes;
- disabled and enabled damage-only behavior;
- deep-copy and input non-mutation behavior;
- mixed valid and invalid action entries;
- status order, duplicates, empty input, and `StringName` typing;
- runtime-data explicit values, exact keys, types, and defaults;
- instant-area explicit color precedence;
- definition fallback;
- absence of optional color keys;
- input non-mutation for both visual dictionaries.

### Focused Regression

Run the new Builder verifier and delegation contract, followed by existing projectile and area checks, including:

- homing projectile swept hit;
- projectile factory physics-frame safety;
- dash area path filtering;
- area motion, max-targets, and visual-mode checks;
- fire tornado and Mars Spark Missile runtime checks where applicable.

### System Regression

Run the established Stage 1 static baseline and the 11 sequential Godot baseline tests covering elemental skills, fusion skills, summons, targeting, pooling, and player dash. Run Godot checks sequentially on this Windows host to avoid known concurrency instability.

Also run:

- `node tools/validate/check_text_encoding.js`;
- script parse checks for each modified GDScript;
- project headless startup;
- `git diff --check`.

Any failing baseline stops the batch. Tests may not be weakened, skipped, or have thresholds relaxed to force a pass.

## Success Criteria

- Every new Builder function is exercised by a direct behavior test that was observed failing before implementation and passing afterward.
- The executor retains its facade and compatibility helpers.
- The selected algorithms have one implementation in a Builder rather than duplicate implementations.
- All focused and system regression checks pass without new warnings.
- No production gameplay output changes.
- No performance claim is made; performance comparison is recorded as not applicable.
- The diff contains only Stage 3 Builder extraction, tests, package validation entries if required, and its documentation.

## Rollback

Each batch is committed separately. Reverting Batch 3A restores projectile helper bodies to the executor without affecting Batch 3B. Reverting Batch 3B restores the instant-area visual merge without affecting projectile construction. The compatibility methods keep call sites stable in both directions, so rollback does not require project-wide edits.

## Deferred Work

The following work requires separate evidence, design, and approval:

- moving modifier-backed projectile or area stat resolution;
- moving special-rule branches;
- splitting full projectile, area, status, summon, or modifier action executors;
- removing executor compatibility helpers;
- performance changes or allocation optimization;
- changes to DamageSystem, status processing, enemy death, rewards, spawning, or save/settlement flows.
