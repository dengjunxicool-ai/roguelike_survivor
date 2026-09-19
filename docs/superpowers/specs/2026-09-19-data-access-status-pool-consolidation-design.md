# Stage 5A Data Access Status Pool Consolidation Design

## Context

The runtime currently has two related configuration access layers:

- `DataManager` is the sole autoload and owns startup loading plus indexed runtime definitions.
- `GameData` is a static compatibility facade. It prefers `DataManager` when a matching accessor exists and falls back to direct JSON loading when the autoload or accessor is unavailable.

This is not yet a single ownership path. Some `GameData` methods have no matching `DataManager` accessor, so direct JSON fallback remains part of normal runtime behavior rather than only a compatibility path. The first confirmed example is the status pool:

- `GameData.get_status_pool()` asks for `DataManager.get_status_definitions()`;
- `DataManager` does not currently implement `get_status_definitions()`;
- consequently the status pool is read from `data/combat/status_effects.json` through the `GameData` document cache even when the autoload is available.

Stage 5A establishes the ownership contract with one low-risk data domain. It does not attempt to consolidate every configuration category at once.

## Decision

The configuration boundary is:

1. `DataManager` owns loaded and indexed runtime configuration.
2. `GameData` remains the stable public facade used by existing consumers.
3. In a normal project runtime, `GameData` delegates supported domains to `DataManager`.
4. Direct JSON loading remains an explicit compatibility fallback for environments without a usable `DataManager`, including isolated and headless verification contexts.
5. Fallback removal requires separate call-site and verification evidence. Stage 5A does not remove it.

The first consolidated domain is the status-definition pool.

## Goals

- Add the missing `DataManager.get_status_definitions() -> Array[Dictionary]` accessor.
- Make the existing `GameData.get_status_pool()` manager-first branch succeed during normal runtime.
- Prove that the manager path and JSON fallback expose the same status definitions in the same order.
- Preserve the fallback path for environments without `DataManager`.
- Establish repeatable runtime and static contract tests for later Stage 5 batches.
- Document the distinction between data ownership, the consumer facade, and compatibility fallback.

## Non-goals

Stage 5A does not:

- remove `GameData` or any public method;
- remove the JSON document cache or fallback helpers;
- migrate existing consumers between `DataManager` and `GameData`;
- consolidate progression goals, challenges, upgrade categories, rarity weights, or other remaining fallback domains;
- modify status definitions, JSON schema, IDs, paths, ordering, balance, or presentation;
- modify status application, stacking, tick scheduling, reactions, damage, visuals, or UI;
- change save data or save compatibility;
- introduce a dependency-injection framework or a new repository abstraction;
- claim a performance improvement without measurement.

## Runtime Flow

### Normal runtime

```text
data/combat/status_effects.json
  -> DataManager.load_all()
  -> DataManager status index
  -> DataManager.get_status_definitions()
  -> GameData.get_status_pool()
  -> existing consumers
```

### Compatibility runtime

```text
DataManager unavailable or missing the accessor
  -> GameData.get_status_pool()
  -> GameDataAccess document cache
  -> data/combat/status_effects.json
```

There is no third status-pool source in this batch.

## Production Changes

### `scripts/core/data_manager.gd`

Add:

```gdscript
func get_status_definitions() -> Array[Dictionary]:
    return _get_definition_values(_status_definitions)
```

The method must reuse the existing indexed source and `_get_definition_values()` helper. It must not reload JSON, expose the private index, or introduce status-specific transformation.

### `scripts/game/game_data.gd`

`get_status_pool()` already requests `get_status_definitions` through `GameDataAccess`. No new production branch is expected. The existing fallback must remain intact:

```gdscript
static func get_status_pool() -> Array[Dictionary]:
    var data: Array[Dictionary] = _get_pool_from_data_manager("get_status_definitions")
    if not data.is_empty():
        return data
    return _get_dictionary_array(STATUS_EFFECTS_PATH, "statuses")
```

If implementation reveals that this method must change, work stops and the design is revisited before expanding scope.

## Behavioral Contracts

The following behavior is invariant:

- The set, count, order, IDs, fields, nested values, and value types of status definitions do not change.
- `DataManager.get_status_definition(id)` retains its existing behavior.
- Unknown status IDs still return an empty dictionary.
- `GameData.get_status_pool()` keeps its method name, arguments, and return type.
- With a usable `DataManager`, `GameData.get_status_pool()` returns the manager-owned status data.
- Without a usable `DataManager`, the existing JSON fallback remains functional.
- Returned normal-runtime definitions retain the documented consumer-mutation isolation: mutating one returned result must not affect later reads.
- No consumer receives a reference to `DataManager._status_definitions`.
- No status gameplay, damage, reaction, visual, UI, or persistence behavior changes.

The existing JSON fallback cache is not redesigned in Stage 5A. Its internal aliasing behavior is not broadened into a new public contract; fallback verification checks data equivalence and availability.

## Verification Design

### Runtime contract verifier

Add `tools/verify/verify_data_access_status_pool.gd`.

The verifier runs in an isolated Godot headless process and must check:

1. The root `DataManager` exists and implements `get_status_definitions`.
2. The manager pool is non-empty and contains dictionary entries.
3. Manager IDs, order, values, and types match `data/combat/status_effects.json`.
4. `GameData.get_status_pool()` with the autoload present matches the manager pool.
5. Mutating a nested value in one manager/facade result does not alter a later normal-runtime read.
6. Temporarily making the manager unavailable at its fixed root path makes `GameData.get_status_pool()` use the existing fallback and return data equivalent to the source document.
7. The manager name/path is restored during cleanup even if an assertion fails.
8. After restoration, the facade again returns the normal manager-backed result.

The verifier must not modify project files or persist configuration changes.

### Static boundary verifier

Add `tools/verify/verify_data_access_status_pool_boundary.js`.

It must assert that:

- `DataManager` exposes `get_status_definitions`;
- the accessor delegates to `_get_definition_values(_status_definitions)`;
- `GameData.get_status_pool()` still attempts the DataManager accessor first;
- `GameData.get_status_pool()` still retains the status JSON fallback;
- no new direct status-pool source is introduced in that method.

The static verifier supplements runtime behavior tests; it is not sufficient by itself.

### Package commands

Add focused commands for both new verifiers to `package.json`.

### Regression verification

At minimum, run sequentially:

- `node tools/validate/check_text_encoding.js`
- the relevant configuration validators;
- the new static boundary verifier;
- the new Godot runtime contract verifier;
- `npm run verify:fire-status-contract`
- `npm run verify:burn-status-table`
- `npm run verify:burn-status-runtime`
- a Godot headless startup check.

Any broader validation required by the implementation plan is additive. Godot commands run sequentially on Windows to avoid cache/import contention.

## Documentation Changes

Update the project systems overview, engineering guidelines, and stability/boundary report to state:

- `DataManager` is the runtime data owner;
- `GameData` is the stable consumer facade;
- fallback is compatibility behavior, not the preferred normal-runtime source;
- Stage 5A has consolidated the status pool only;
- other fallback domains remain future work and must be migrated separately.

Documentation must not claim that all configuration access has been consolidated.

## Risks and Controls

### Accessor name mismatch

`GameData` invokes the accessor by string. Runtime and static tests both verify the exact name.

### Ordering drift

The current JSON fallback exposes document order, while the manager exposes index insertion order. The runtime contract compares the exact ID sequence and full values.

### Mutable result leakage

The new accessor uses the existing deep-copy helper. A nested-mutation test proves that consumers cannot mutate the manager's stored definitions.

### Autoload restoration during fallback testing

The verifier must not remove the autoload from the SceneTree. It temporarily changes the node name so `/root/DataManager` lookup is unavailable, then restores the original name before quitting. The test process is isolated, but cleanup is still mandatory.

### Accidental scope expansion

No external consumer migration and no additional data domain are part of 5A. Discoveries concerning other domains are recorded for 5B rather than folded into this batch.

## Rollback

Stage 5A is independently reversible:

1. Remove `DataManager.get_status_definitions()`.
2. Remove the two focused verifiers and their package commands.
3. Revert the Stage 5A documentation statements.

The pre-existing `GameData` fallback then resumes normal status-pool loading. No configuration or save migration is required.

## Success Criteria

Stage 5A is complete only when:

- the accessor exists and uses the existing indexed status store;
- manager, facade, and fallback data-equivalence tests pass;
- normal-runtime mutation isolation is proven;
- status and startup regression checks pass;
- no status data, gameplay behavior, schema, resource path, UI, or save result changes;
- no unrelated user files or untracked `.uid` files are modified;
- documentation accurately describes the remaining dual-path scope.
