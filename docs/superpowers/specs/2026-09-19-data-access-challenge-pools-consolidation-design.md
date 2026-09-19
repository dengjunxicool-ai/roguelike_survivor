# Stage 5C Data Access Challenge Pools Consolidation Design

## Status

Approved architecture and design. This document defines the implementation boundary for Stage 5C. It does not authorize production-code implementation or migration of adjacent upgrade domains.

## Context

Stage 5A established the configuration ownership pattern for status definitions. Stage 5B extended the same pattern to the complete progression-goals document:

- `DataManager` owns normal-runtime configuration loading;
- manager accessors return deeply isolated values;
- `GameData` remains the stable consumer-facing facade;
- JSON loading remains a compatibility fallback when the autoload or a usable manager result is unavailable;
- runtime verification proves both value equivalence and the actual source path.

The next confirmed normal-runtime fallbacks are the two ordered arrays in `res://data/progression/challenges.json`:

- `daily_challenges`;
- `weekly_challenges`.

`GameData.get_daily_challenge_pool()` and `GameData.get_weekly_challenge_pool()` currently read these arrays directly through the `GameDataAccess` document cache. `RunProgressionService._update_fixed_challenges()` combines the returned pools only while evaluating a victorious run. The service compares the configured character and map IDs, then writes completion through `SaveManager`.

Stage 5C consolidates ownership of both arrays in one batch because they share one source document, one consumer, one fallback mechanism, and the same behavioral risk. It does not change challenge rules, completion behavior, save keys, configuration values, or adjacent upgrade data.

## Goals

1. Make `DataManager` the normal-runtime owner of both ordered challenge pools.
2. Load `challenges.json` once per `DataManager.load_all()` call.
3. Preserve the two existing `GameData` public methods and their return types.
4. Preserve independent JSON fallback behavior for each pool.
5. Preserve exact array order, challenge values, modifier order, and nested scope values.
6. Prove deep mutation isolation for manager, facade, and fallback results.
7. Keep `RunProgressionService`, `SaveManager`, challenge configuration, and save behavior unchanged.

## Non-goals

Stage 5C does not:

- add, remove, rename, merge, or reorder challenges;
- change `challenge_id`, `character_id`, `map_id`, `display_name`, modifiers, scopes, or numeric values;
- change victory requirements or fixed-challenge evaluation;
- add daily or weekly rotation, expiration, scheduling, seeding, or remote content;
- change challenge completion text or result-screen behavior;
- modify challenge save sections, keys, serialization, or migration;
- consolidate curse choices, level-up upgrades, permanent upgrades, rarity weights, or consumer-owned upgrade fallbacks;
- index challenges by ID or introduce a registry, repository, resource type, or generic data framework;
- remove the `GameData` document cache or compatibility fallback;
- claim a performance improvement.

## Current Evidence

### Source document

`data/progression/challenges.json` contains two top-level arrays. Each challenge has a `challenge_id`, character and map constraints, a display name, and an ordered `modifiers` array. Modifier entries may contain nested `scope` dictionaries.

The source currently has one daily and one weekly challenge. The design must not depend on those counts. Both arrays remain ordered configuration pools rather than ID-indexed definition stores.

### Current facade

`scripts/game/game_data.gd` currently exposes:

```gdscript
static func get_daily_challenge_pool() -> Array[Dictionary]:
	return _get_dictionary_array(CHALLENGES_PATH, "daily_challenges")


static func get_weekly_challenge_pool() -> Array[Dictionary]:
	return _get_dictionary_array(CHALLENGES_PATH, "weekly_challenges")
```

Both methods therefore use JSON loading as their normal path.

### Current consumer

`scripts/game/run_progression_service.gd` calls both `GameData` methods from `_update_fixed_challenges()`. The consumer appends both pools to a local array, compares configured character and map IDs, then calls `SaveManager.mark_challenge_completed()`.

Neither that consumer nor `SaveManager` requires a direct `DataManager` dependency.

### Existing fallback ownership risk

`GameDataAccess.get_dictionary_array()` creates a new outer typed array but retains the dictionaries from the cached source document. Stage 5C must deeply duplicate the two challenge fallback results locally so mutations to nested modifiers or scopes cannot contaminate later fallback reads. This hardening is limited to the two challenge facade methods and does not change the generic helper or other data domains.

## Architecture

### Normal runtime

```text
challenges.json
      |
      v
DataManager.load_all() -- one document load
      |
      +--> _daily_challenge_definitions
      |
      +--> _weekly_challenge_definitions
                  |
                  v
deep-copy accessors
                  |
                  v
GameData daily/weekly facades
                  |
                  v
RunProgressionService
```

### Compatibility environment

```text
DataManager unavailable, method missing, or selected pool empty
      |
      v
GameData selected pool facade
      |
      v
existing GameDataAccess JSON cache
      |
      v
local deep duplicate of the selected ordered pool
```

Daily and weekly fallback decisions remain independent. An unusable daily manager result must not force the weekly facade to abandon a valid manager result, and vice versa.

## Component Changes

### `scripts/core/data_manager.gd`

Add only the ownership required for this document:

1. Register `CHALLENGES_PATH` from `DataPaths`.
2. Add constants for the `daily_challenges` and `weekly_challenges` keys.
3. Add two typed array fields:
   - `_daily_challenge_definitions: Array[Dictionary]`;
   - `_weekly_challenge_definitions: Array[Dictionary]`.
4. Clear both arrays at the start of `load_all()`.
5. Load `CHALLENGES_PATH` once with `_load_json_document()`.
6. Extract both arrays with the existing `_get_dictionary_array()` helper.
7. Add `get_daily_challenge_definitions()` and `get_weekly_challenge_definitions()`, each returning `duplicate(true)`.

The two arrays must not be combined or inserted into `DataDefinitionIndex`. Current consumers need ordered category pools, not ID lookup.

### `scripts/game/game_data.gd`

Keep both public signatures unchanged:

```gdscript
static func get_daily_challenge_pool() -> Array[Dictionary]
static func get_weekly_challenge_pool() -> Array[Dictionary]
```

Each method must:

1. request its matching manager accessor through `_get_pool_from_data_manager()`;
2. return the non-empty manager pool;
3. otherwise obtain the same keyed array from the existing JSON cache;
4. return a deep duplicate of that fallback array.

No generic helper is added to `GameDataAccess`. The existing manager helper is sufficient, and local fallback duplication prevents this batch from changing unrelated facade behavior.

### `scripts/game/run_progression_service.gd`

No modification is expected. `_update_fixed_challenges()` continues to call the two existing `GameData` methods and preserves its current combination and evaluation order.

### `scripts/game/save_manager.gd`

No modification is allowed. `SECTION_CHALLENGES`, completion keys, idempotence, serialization, and persisted results remain outside this batch.

### `data/progression/challenges.json`

No modification is allowed. Its schema, values, order, and IDs are behavioral baselines for this refactor.

## Data Contract

The following properties are invariants:

1. The daily manager pool equals the parsed `daily_challenges` source array.
2. The weekly manager pool equals the parsed `weekly_challenges` source array.
3. Each normal facade result equals its corresponding manager result.
4. Each fallback result equals its corresponding source array.
5. Daily and weekly categories remain separate.
6. Challenge ordering within each category is unchanged.
7. Modifier ordering within each challenge is unchanged.
8. All scalar values and nested scope values are unchanged.
9. Mutating a manager result cannot affect a later manager read.
10. Mutating a normal facade result cannot affect a later facade or manager read.
11. Mutating a fallback result cannot affect a later fallback read.
12. The normal facade path does not populate the challenge JSON cache.
13. The compatibility path does populate the challenge JSON cache.
14. An empty result for one manager pool triggers fallback only for that facade.

## Verification Design

### Static boundary verifier

Add `tools/verify/verify_data_access_challenge_pools_boundary.js` and a matching package script.

It must verify that:

- `DataManager` registers the canonical challenge path and both keys;
- `load_all()` clears both fields, loads one challenge document, and extracts both arrays;
- both manager accessors exist and return deep duplicates;
- both `GameData` methods call the matching manager accessor first;
- both methods return the manager value when non-empty;
- both JSON fallbacks remain present and deeply duplicate their results;
- manager-first ordering is explicit;
- `RunProgressionService` continues through both `GameData` methods;
- `RunProgressionService` and `SaveManager` do not gain direct `DataManager` dependencies.

The verifier must guard against the known false-positive shape where a facade calls the manager but discards its result.

### Runtime verifier

Add `tools/verify/verify_data_access_challenge_pools.gd` and a matching package script.

The verifier must:

1. Parse `challenges.json` independently.
2. Obtain the active `DataManager`.
3. confirm both manager accessors exist.
4. Compare both complete manager pools with their source arrays.
5. Compare challenge ID, modifier, and nested scope sequences exactly.
6. Clear the `GameData` document cache before normal facade calls.
7. Compare both normal facade results with their manager pools.
8. Prove the normal path did not populate the challenge document cache.
9. Mutate nested daily and weekly manager results and prove fresh manager reads are unchanged.
10. Mutate nested normal facade results and prove fresh facade and manager reads are unchanged.
11. Temporarily hide the fixed root manager path using the proven Stage 5B isolation pattern.
12. Call both fallback facades and prove the challenge document cache was populated.
13. Compare both fallback results with their source arrays.
14. Mutate nested fallback results and prove fresh fallback reads are unchanged.
15. Restore the manager name before evaluating final assertions or reporting completion.
16. Prove the restored facades return manager-backed values.

The fallback probe must never free, replace, or permanently detach the autoload. It contains no `await` and no early return while the manager name is changed.

### Regression gate

Run at minimum:

- `node tools/validate/check_text_encoding.js`;
- `node tools/validate/validate_enemy_configs.js`;
- `node tools/validate/validate_modifier_effects.js`;
- the new challenge-pools static boundary verifier;
- the new challenge-pools runtime verifier;
- Stage 5A status-pool static and runtime verifiers;
- Stage 5B progression-goals static and runtime verifiers;
- the result-screen diagnostic static verifier;
- the result-unlock cache lifetime runtime verifier;
- direct Godot headless project startup;
- `git diff --check`.

Godot commands must run one at a time as direct executable invocations inside the managed Windows sandbox. They must not be chained through a wrapper or launched through npm in that environment.

## Failure Handling

If verification fails:

1. stop Stage 5C scope expansion;
2. record the exact command and relevant output;
3. classify the failure as pre-existing, environmental, or introduced by Stage 5C;
4. restore any temporarily renamed autoload before further investigation;
5. do not change challenge data, save logic, assertions, or thresholds to manufacture a pass.

## Risks and Controls

### Daily and weekly pools accidentally merged

Separate fields, accessors, facade methods, and source comparisons preserve category identity.

### Nested modifier mutation

Manager accessors and local facade fallbacks return deep duplicates. Runtime tests mutate nested `modifiers` and `scope` values on all paths.

### Manager-first facade silently falls through

Static checks require returning the manager value, while runtime checks prove the normal path leaves the JSON cache empty.

### Repeated document loading

The static boundary verifier requires one challenge-document load in `load_all()`, followed by extraction of both arrays.

### Scope expansion into progression or persistence

`RunProgressionService`, `SaveManager`, and `challenges.json` are protected unchanged files. Any discovered rule or save defect must be reported and handled in a separate approved batch.

## Rollback

Stage 5C is independently reversible:

1. remove the challenge path, key constants, two fields, clear steps, one load step, extraction steps, and two accessors from `DataManager`;
2. restore the two `GameData` methods to their current direct `_get_dictionary_array()` implementations;
3. remove the two Stage 5C verifier files and their package entries;
4. revert only the Stage 5C engineering-document statements.

The original JSON fallback then resumes normal-runtime loading. No configuration or save migration is required.

## Completion Criteria

Stage 5C is complete only when:

- `DataManager` supplies both ordered challenge pools during normal runtime;
- both existing `GameData` signatures and return types are unchanged;
- source, manager, facade, and fallback values match for both pools;
- category, challenge, modifier, and scope ordering are preserved;
- nested outputs are mutation-isolated on every path;
- normal and fallback sources are proven rather than inferred from equal values;
- progression consumers, save logic, and challenge configuration remain unchanged;
- all specified verification commands pass with no new attributable warning;
- the diff contains no upgrade-domain migration or unrelated refactor;
- documentation states that Stage 5C consolidates challenge pools only.
