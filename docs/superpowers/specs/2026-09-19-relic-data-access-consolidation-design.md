# Phase 6 Relic Data Access Batch Design

## Status

Approved architecture and detailed design. This document defines the implementation boundary for the Phase 6 relic data access batch. It does not authorize production-code implementation until the written implementation plan is reviewed and its execution method is selected.

## Context

Stages 5A through 5D established the project data-access pattern:

- `DataManager` owns parsed normal-runtime configuration;
- `GameData` remains the stable public compatibility facade;
- JSON reads remain independent fallback paths while migration evidence is incomplete;
- manager, facade, and fallback results are isolated from caller mutation;
- every domain moves in a separately verifiable and reversible batch.

The relic domain already partially follows that pattern. `DataManager` loads and indexes `data/relics/relics.json`, and `GameData.get_relic_pool()` provides a manager-first pool facade. However, `RelicManager` bypasses the facade in two places:

1. `_load_relic_definitions()` directly resolves `/root/DataManager` and otherwise reads the JSON file through `JsonDataLoader`;
2. `_get_relic_definition()` directly resolves `/root/DataManager` again when its local index misses an ID.

This duplicates source-selection and fallback policy inside a gameplay manager. It also leaves the relic facade asymmetric: a pool facade exists, but there is no manager-first single-definition facade.

This Phase 6 batch consolidates only this evidenced consumer-owned fallback. It does not change relic effects, event handling, modifier registration, acquisition rules, configuration, UI, save data, or any other consumer-owned fallback.

## Goals

1. Make `GameData` the only configuration facade used by `RelicManager`.
2. Preserve `DataManager` as the normal-runtime owner of relic definitions.
3. Add a stable manager-first single-relic facade.
4. Preserve the existing independent JSON fallback for pool and single-definition reads.
5. Preserve `RelicManager`'s local ID index for repeated runtime lookups.
6. Preserve cache-miss refresh behavior for definitions not present in the local index.
7. Ensure manager, facade, fallback, and `RelicManager` results are isolated from nested caller mutation.
8. Prove the boundary with dedicated static and runtime verification.
9. Keep all gameplay, configuration, presentation, persistence, and signal behavior unchanged.

## Non-goals

This Phase 6 batch does not:

- change `data/relics/relics.json`;
- change relic IDs, order, rarity, tags, trigger conditions, cooldowns, limits, modifiers, text, or unlock fields;
- change relic selection, reward generation, capacity, duplicate prevention, acquisition, or persistence;
- change trigger-count or cooldown state;
- change modifier aggregation, source IDs, operations, scopes, or registration timing;
- change `relic_added` or `relics_changed` signal names, arguments, order, or timing;
- remove `RelicManager`'s local definition index;
- remove `DataManager` relic methods or the `GameData` document cache;
- change the generic `GameDataAccess` helpers;
- refactor `SynergyManager`, `SkillManager`, `StatusEffectManager`, enemy skill repositories, UI, player, damage, death, reward, or save pipelines;
- consolidate any other consumer-owned fallback in the same batch;
- claim a frame-time, allocation, startup-duration, or memory improvement without measurement.

## Current Evidence

### Existing owner

`scripts/core/data_manager.gd` loads `DataPaths.RELICS_PATH` during `load_all()` and indexes `relics.json.relics` by `id` into `_relic_definitions`.

It already exposes:

```gdscript
func get_relic_definition(relic_id: Variant) -> Dictionary
func get_relic_definitions() -> Array[Dictionary]
```

Both methods return deep copies through `DataDefinitionIndex`. This Phase 6 batch does not need to modify `DataManager`.

### Existing facade

`scripts/game/game_data.gd` already exposes:

```gdscript
static func get_relic_pool() -> Array[Dictionary]
```

The method prefers `DataManager.get_relic_definitions()` and otherwise reads `relics.json.relics` through the shared document cache. Its fallback outer array is new, but the nested dictionaries still refer to cached document values. This Phase 6 batch therefore hardens only this affected fallback with a deep duplicate.

There is currently no `GameData.get_relic(id)` method.

### Existing consumer duplication

`scripts/relics/relic_manager.gd` directly preloads `DataPaths` and `JsonDataLoader`, stores `RELIC_DATA_PATH`, resolves `/root/DataManager`, and owns `_load_relics_from_file()`. It therefore duplicates policy already present in `GameData`.

`RelicManager` also owns legitimate runtime responsibilities that remain in place:

- owned relic IDs;
- maximum capacity;
- the local definition index;
- trigger counts and cooldown deadlines;
- applicability checks;
- modifier registration;
- public acquisition and query methods;
- relic signals.

The batch changes only how definitions enter that local index.

## Chosen Architecture

The data flow becomes:

```text
data/relics/relics.json
          |
          v
DataManager (normal-runtime owner)
          |
          v
GameData (stable owner-first facade with JSON fallback)
  - get_relic_pool()
  - get_relic(relic_id)
          |
          v
RelicManager (run state, local index, effects, and signals)
```

`RelicManager` must not know whether a result came from `DataManager` or the JSON fallback.

## Facade Design

### Relic pool

`GameData.get_relic_pool()` remains public with its existing signature. It must:

1. call `_get_pool_from_data_manager("get_relic_definitions")`;
2. return a non-empty manager result;
3. otherwise read only `relics` from `RELICS_PATH`;
4. return a deep duplicate of the fallback pool.

The generic helper is not changed because doing so would broaden mutation semantics across unrelated data domains.

### Single relic

Add:

```gdscript
static func get_relic(relic_id: StringName) -> Dictionary
```

It must:

1. call `_get_definition_from_data_manager("get_relic_definition", relic_id)`;
2. return a non-empty manager result;
3. otherwise search only `relics.json.relics` for the exact ID;
4. return a deep duplicate of the fallback definition;
5. return `{}` for an empty or missing ID.

No generic string-keyed definition API is added.

## RelicManager Design

### Dependencies

`RelicManager` will preload `scripts/game/game_data.gd` and stop directly depending on:

- `scripts/core/data_paths.gd`;
- `scripts/core/json_data_loader.gd`;
- `RELIC_DATA_PATH`;
- the `/root/DataManager` node path.

`ModifierSourceScript` and every runtime dependency unrelated to configuration loading remain unchanged.

### Initial pool load

`_load_relic_definitions()` will:

1. clear `_relic_definitions` exactly as before;
2. iterate `GameData.get_relic_pool()`;
3. normalize each ID through the existing `_to_relic_id()` helper;
4. ignore empty IDs exactly as before;
5. place valid definitions in the local dictionary.

The local index remains private and continues to avoid repeated global source selection during ordinary combat-event and stat queries.

### Cache-miss lookup

`_get_relic_definition()` keeps its current sequence:

1. if the local index is empty, call `_load_relic_definitions()`;
2. if the requested ID is absent, call `GameData.get_relic(id)`;
3. if the facade returns a non-empty definition, store a deep copy in the local index;
4. return `{}` if the ID remains absent;
5. otherwise return a deep copy of the locally indexed definition.

This preserves the existing ability to resolve a definition after initial indexing without reloading the entire pool.

### Removed helper

`_load_relics_from_file()` is removed because JSON fallback ownership moves entirely behind `GameData`. No replacement file-loader helper is introduced in `RelicManager`.

## Behavioral Invariants

The Phase 6 relic batch must preserve all of the following:

1. Every valid relic definition contains the same fields and nested values as before.
2. The initial pool preserves the order currently supplied by the selected source.
3. `DataManager` remains the preferred source during normal runtime.
4. An unavailable or unusable manager result still permits independent JSON fallback.
5. `RelicManager.add_relic()`, `has_relic()`, `can_add_relic()`, `get_relic_definition()`, `get_owned_relic_definitions()`, `get_relic_modifiers_for_skill()`, `handle_combat_event()`, and `reset_run_effect_state()` retain their signatures and behavior.
6. Missing and empty IDs remain unresolved and cannot be added.
7. Duplicate relics and relics beyond `max_relics` remain rejected.
8. `owned_relics` order remains acquisition order.
9. `relic_added` fires before `relics_changed`, with the same argument and only after successful acquisition.
10. Skill-manager notification occurs at the same point after a successful acquisition or trigger.
11. Negative, passive, and triggered modifier blocks retain the same source IDs, values, scopes, merge mode, and timing.
12. Trigger limits and cooldown calculations remain unchanged.
13. Local cache misses still perform one single-definition source query before returning empty.
14. Definitions returned from manager, facade, fallback, and `RelicManager` queries are deeply isolated from caller mutation.
15. A valid project configuration produces no new warning or error.
16. No save, UI, skill, damage, reward, or configuration output changes.

## Verification Design

### Static boundary verifier

Add `tools/verify/verify_data_access_relics_boundary.js` and register `verify:data-access-relics-boundary` in `package.json`.

The verifier must check at least:

- `GameData.get_relic_pool()` remains manager-first and retains a deep-copy JSON fallback;
- `GameData.get_relic()` exists, delegates to `get_relic_definition`, uses a relic-only fallback, and deep-copies that fallback;
- `RelicManager` preloads `GameData`;
- `_load_relic_definitions()` calls `GameData.get_relic_pool()`;
- `_get_relic_definition()` calls `GameData.get_relic()` on a local miss;
- `RelicManager` no longer references `DataManager`, `DataPaths`, `JsonDataLoader`, `RELIC_DATA_PATH`, or `_load_relics_from_file()`;
- the public methods, signals, runtime state fields, and modifier dependency remain present;
- `DataManager` and `data/relics/relics.json` are not implementation targets.

The checks must enforce architectural boundaries without snapshotting unrelated formatting or whole functions.

### Runtime contract verifier

Add `tools/verify/verify_data_access_relics.gd` and register `verify:data-access-relics` in `package.json`.

The verifier must cover:

1. independently load the source relic array;
2. obtain the real `DataManager` autoload;
3. compare the manager pool and each manager lookup with source definitions;
4. compare `GameData.get_relic_pool()` and every `GameData.get_relic(id)` result with source data;
5. verify counts, IDs, selected-source order, fields, and nested values;
6. verify empty and missing IDs return `{}`;
7. mutate nested `modifiers`, `scope`, `trigger_condition`, and `unlock` values returned by manager and facade methods, then prove fresh reads are unchanged;
8. install recognizable non-empty manager sentinel data and prove both facades use it without populating the JSON cache;
9. make the manager relic index empty and prove pool and single-definition facades independently fall back to JSON;
10. temporarily hide the fixed root manager path using the established autoload isolation pattern and prove full fallback still works;
11. mutate nested fallback results and prove later fallback reads are unchanged;
12. instantiate `RelicManager` with a minimal safe parent and prove it builds its local index through the facade;
13. prove a valid relic can be added once, a duplicate cannot be added, a missing relic cannot be added, and capacity remains enforced;
14. record `relic_added` and `relics_changed` and prove the existing emission order and count;
15. probe a nested definition returned by `RelicManager`, mutate it, and prove a later query is unchanged;
16. prove a local cache miss can be satisfied through the new single-definition facade;
17. restore the autoload name, manager relic index, document cache, temporary nodes, and all sentinel state before reporting completion.

The isolation section must contain no `await` and no early return while shared state is replaced. Cleanup must run before final assertions and process termination.

### Regression gate

The Phase 6 relic batch gate must include at least:

- `node tools/validate/check_text_encoding.js`;
- the project configuration validator used by the existing data-access gates;
- the previously completed Phase 6 static and runtime data-access verifiers;
- `verify:upgrade-pool-no-relic-fireball-god-mix`;
- the relevant modifier and damage contract checks selected by the implementation plan;
- direct Godot headless startup;
- `git diff --check`;
- an explicit protected-file diff check.

The implementation plan must resolve the exact existing script names from `package.json` and the repository before execution. It must not invent a validator or silently substitute a narrower check.

### Godot execution environment

Godot commands must run one at a time as direct executable invocations. They must not be launched through npm, Node.js, Python, `cmd /c`, or a second PowerShell inside the managed Windows sandbox.

The established project diagnostic still applies:

- a sandboxed Godot 4.6.3 initialization crash with `signal 11` / `0xC0000005` must be compared with the identical direct command outside the sandbox;
- a fresh isolated worktree must receive one direct headless editor scan before ordinary tests if its ignored Godot class cache is missing;
- only exact newly generated untracked UID files may be removed after inspection;
- exit code alone is insufficient: output must be checked for script parse errors and unexpected error lines.

## Failure Handling

If any validation fails:

1. stop Phase 6 relic-batch scope expansion;
2. record the exact command and relevant output;
3. classify the failure as pre-existing, environment-related, or introduced by the Phase 6 relic batch;
4. do not weaken assertions, thresholds, or protected-file checks;
5. reproduce the failure with the smallest relevant contract before changing production code;
6. fix only the evidenced root cause;
7. rerun the smallest affected gate and then the complete Phase 6 relic-batch gate.

## Protected Files

The implementation must not modify:

- `scripts/core/data_manager.gd`;
- `scripts/relics/synergy_manager.gd`;
- `scripts/skills/skill_manager.gd`;
- `scripts/combat/status_effect_manager.gd`;
- `scripts/player/player_controller.gd`;
- `scripts/ui/ui_manager.gd`;
- `scripts/ui/ui_command_dispatcher.gd`;
- `scripts/modifiers/modifier_aggregator.gd`;
- `data/relics/relics.json`;
- any other file under `data/`;
- any scene or resource file.

If implementation appears to require one of these files, stop and return to design approval rather than expanding scope.

## Expected Modified Files

The implementation batch is expected to touch only:

- `scripts/game/game_data.gd`;
- `scripts/relics/relic_manager.gd`;
- `package.json`;
- `tools/verify/verify_data_access_relics_boundary.js`;
- `tools/verify/verify_data_access_relics.gd`;
- `docs/PROJECT_SYSTEMS_OVERVIEW.md`;
- `docs/PROJECT_ENGINEERING_GUIDELINES.md`;
- `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`;
- the Phase 6 relic-batch implementation plan.

The specification is reviewed before the implementation plan is written. No production-code implementation is authorized by this document alone.

## Rollback

The Phase 6 relic batch is independently reversible:

1. restore the previous `GameData.get_relic_pool()` fallback return;
2. remove `GameData.get_relic()`;
3. restore `RelicManager`'s direct manager and JSON loading path;
4. restore `_load_relics_from_file()` and its constants;
5. remove the two relic-batch verifiers and package entries;
6. revert only the Phase 6 relic-batch engineering-document statements.

No configuration migration, save migration, resource conversion, or consumer rollback is required.

## Completion Criteria

The Phase 6 relic batch is complete only when:

- `RelicManager` obtains all definitions exclusively through `GameData`;
- `GameData` supplies manager-first pool and single-definition relic facades;
- both facades retain independent JSON fallback;
- manager, facade, fallback, and local-manager results pass nested mutation-isolation checks;
- acquisition, capacity, missing-ID, signal-order, and modifier contracts remain unchanged;
- the previously completed Phase 6 data-access regression gates still pass;
- relevant relic, modifier, configuration, and startup gates pass;
- protected files have no diff;
- the implementation diff contains no configuration, gameplay, UI, save, or unrelated refactor;
- documentation matches the implemented boundary;
- an independent whole-branch review finds no unresolved Critical or Important issues.
