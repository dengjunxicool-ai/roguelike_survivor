# Stage 5B Data Access Progression Goals Consolidation Design

## Status

Approved architecture and design. This document defines the implementation boundary for Stage 5B. It does not authorize unrelated data-domain migration.

## Context

Stage 5A established the intended configuration ownership model with the status-definition pool:

- `DataManager` owns normal-runtime configuration loading and returns isolated copies;
- `GameData` remains the stable consumer-facing facade;
- direct JSON loading remains a compatibility fallback when the autoload is unavailable or cannot provide the requested data;
- manager, facade, and fallback paths are verified against the source document.

The next confirmed normal-runtime fallback is the progression-goals document at `res://data/progression/progression_goals.json`. `GameData.get_progression_goals()` currently reads this document directly through the `GameDataAccess` cache. `RunProgressionService` calls that facade when resolving character specialization goals and map objectives.

Stage 5B applies the Stage 5A ownership contract to this single low-risk document. It does not change progression rules or migrate adjacent challenge and upgrade domains.

## Goals

1. Make `DataManager` the normal-runtime owner of the complete progression-goals document.
2. Preserve `GameData.get_progression_goals()` as the public compatibility facade.
3. Preserve direct JSON loading as the fallback when `DataManager` is unavailable or returns an empty document.
4. Prove exact value, array-order, and nested-mutation isolation across source, manager, facade, and fallback paths.
5. Keep `RunProgressionService`, `SaveManager`, goal IDs, objective IDs, and save behavior unchanged.

## Non-goals

Stage 5B does not:

- consolidate daily or weekly challenge pools;
- consolidate curse choices, permanent upgrades, level-up upgrades, or rarity weights;
- change the progression-goals JSON schema or any configured ID;
- index character specialization entries or map challenge entries by ID;
- add new progression goals or change goal evaluation formulas;
- remove the `GameData` document cache or compatibility fallback;
- modify result UI, unlock text, save sections, or completion state;
- introduce a new repository, service, registry, resource type, or data framework;
- claim a performance improvement.

## Current Evidence

### Source document

`data/progression/progression_goals.json` contains two ordered arrays:

- `character_specializations`, whose entries contain `character_id` and ordered `goals` arrays;
- `map_challenges`, whose entries contain `map_id` and ordered `objectives` arrays.

There is no top-level definition ID suitable for the existing `DataDefinitionIndex` contract. The complete document is therefore the ownership unit.

### Current facade

`scripts/game/game_data.gd` exposes:

```gdscript
static func get_progression_goals() -> Dictionary:
	return _load_document(PROGRESSION_GOALS_PATH).duplicate(true)
```

This means direct JSON loading is currently the normal path.

### Current consumers

`scripts/game/run_progression_service.gd` calls `GameData.get_progression_goals()` from:

- `_get_character_goal_ids()`;
- `_get_map_objectives()`.

Those consumers iterate the configured arrays and compare existing character and map IDs. They do not need to change when the facade becomes manager-first.

## Architecture

### Normal runtime

```text
progression_goals.json
        |
        v
DataManager.load_all()
        |
        v
DataManager._progression_goals
        |
        v
DataManager.get_progression_goals() -- deep copy
        |
        v
GameData.get_progression_goals()
        |
        v
RunProgressionService
```

### Compatibility environment

```text
DataManager unavailable or empty
        |
        v
GameData.get_progression_goals()
        |
        v
existing GameDataAccess JSON cache
        |
        v
deep-copied progression-goals document
```

No consumer may depend on which branch supplied the document.

## Component Changes

### `scripts/core/data_manager.gd`

Add only the document ownership required for this domain:

1. Register `PROGRESSION_GOALS_PATH` from `DataPaths`.
2. Add `_progression_goals: Dictionary`.
3. Clear `_progression_goals` at the beginning of `load_all()`.
4. Load the complete document during `load_all()` with the existing `_load_json_document()` helper.
5. Add `get_progression_goals() -> Dictionary`, returning `_progression_goals.duplicate(true)`.

The document is not inserted into `DataDefinitionIndex`. Preserving its complete structure and configured order is safer than inventing a new index contract that no current consumer needs.

### `scripts/game/game_data.gd`

Keep the public signature unchanged:

```gdscript
static func get_progression_goals() -> Dictionary
```

The method must:

1. request the root `DataManager` through the existing access helper;
2. verify that the node implements `get_progression_goals`;
3. accept only a non-empty `Dictionary` result;
4. return that manager-provided isolated dictionary when usable;
5. otherwise return the existing JSON-backed document copy.

This should follow the existing `get_wave_config()` manager-first pattern. Stage 5B does not add a generic dictionary-access abstraction to `GameDataAccess`, because only one new dictionary document is being migrated and the existing local pattern is sufficient.

### `scripts/game/run_progression_service.gd`

No modification is expected. Both call sites continue to use `GameData.get_progression_goals()`.

### `scripts/game/save_manager.gd`

No modification is allowed. Save sections, keys, increments, completed-objective state, and serialization behavior remain outside this batch.

## Data Contract

The following properties are behavioral invariants:

1. The complete manager result equals the parsed source document.
2. The facade result equals the manager result during normal runtime.
3. The fallback result equals the parsed source document.
4. `character_specializations` entry order is unchanged.
5. Each nested `goals` array preserves its exact order and values.
6. `map_challenges` entry order is unchanged.
7. Each nested `objectives` array preserves its exact order and values.
8. Mutating a returned manager dictionary cannot affect a later manager read.
9. Mutating a returned facade dictionary cannot affect a later facade or manager read.
10. Missing or unavailable manager access preserves the current fallback result.

An empty manager document does not become a new authoritative state. It causes the facade to use the compatibility fallback, matching the existing manager-first facade convention.

## Verification Design

### Static boundary verifier

Add `tools/verify/verify_data_access_progression_goals_boundary.js` and a matching package script.

It must verify that:

- `DataManager` registers the existing progression-goals path;
- the manager owns, clears, and loads one progression-goals document;
- `DataManager.get_progression_goals()` exists and returns a deep duplicate;
- `GameData.get_progression_goals()` requests the manager method first;
- the existing `PROGRESSION_GOALS_PATH` JSON fallback remains present;
- `RunProgressionService` continues to call the `GameData` facade;
- `RunProgressionService` and `SaveManager` do not acquire a direct `DataManager` dependency for this domain.

The verifier is a boundary guard, not a substitute for runtime value comparisons.

### Runtime verifier

Add `tools/verify/verify_data_access_progression_goals.gd` and a matching package script.

The verifier must:

1. Parse the source JSON document independently.
2. Obtain the active `DataManager` and call its new accessor.
3. Compare the complete manager result with the source document.
4. Call `GameData.get_progression_goals()` and compare the complete facade result.
5. Compare character IDs and nested goal sequences exactly.
6. Compare map IDs and nested objective sequences exactly.
7. Mutate nested manager output and prove a fresh manager read is unchanged.
8. Mutate nested facade output and prove fresh facade and manager reads are unchanged.
9. Temporarily make the fixed root manager path unavailable using the proven Stage 5A isolation pattern.
10. Call the facade and prove the fallback result equals the source document.
11. Restore the manager node name before reporting success or failure.

The fallback probe must never free, replace, or permanently detach the autoload.

### Regression gate

Run at minimum:

- `node tools/validate/check_text_encoding.js`;
- `node tools/validate/validate_enemy_configs.js`;
- `node tools/validate/validate_modifier_effects.js`;
- the new static progression-goals boundary verifier;
- the new progression-goals runtime verifier;
- `npm run verify:result-unlock-cache-lifetime` using direct Godot invocation inside the managed sandbox;
- the relevant result/progression static contract if one exists at implementation time;
- direct Godot headless project startup;
- `git diff --check`.

Godot commands must follow the documented Windows managed-sandbox rule: invoke Godot directly inside the sandbox, and use an out-of-sandbox npm run only when the npm wrapper itself is part of the verification target.

## Failure Handling

If a verification fails:

1. stop Stage 5B scope expansion;
2. record the exact command and relevant output;
3. classify the failure as pre-existing, environment-related, or introduced by Stage 5B;
4. restore any temporarily renamed autoload before further investigation;
5. do not change progression data, save logic, assertions, or thresholds to manufacture a pass.

## Risks and Controls

### Deep-copy regression

Returning the owned dictionary directly would allow progression processing or a future caller to corrupt the runtime source. Both manager and facade mutation-isolation tests guard this boundary.

### Silent order drift

Although current consumers search by IDs, array ordering is part of the existing document result. Full-value and explicit nested-sequence comparisons prevent accidental reordering.

### Empty manager result masking valid fallback data

The facade accepts only a non-empty manager dictionary. An empty result preserves the existing JSON path.

### Scope expansion into progression behavior

`RunProgressionService` and `SaveManager` are explicitly unchanged. Any discovered goal-evaluation or save defect must be reported and handled in a separate approved batch.

## Rollback

Stage 5B is independently reversible:

1. remove the new `DataManager` path constant, field, load step, clear step, and accessor;
2. restore the one-line JSON implementation of `GameData.get_progression_goals()`;
3. remove the two Stage 5B verifiers and package entries;
4. revert Stage 5B documentation statements.

The original JSON fallback then resumes normal runtime loading. No data or save migration is required.

## Completion Criteria

Stage 5B is complete only when:

- the normal-runtime manager path supplies the complete progression-goals document;
- the public `GameData` method and its return type remain unchanged;
- manager, facade, source, and fallback values match exactly;
- nested outputs are mutation-isolated;
- progression consumers and save logic remain unchanged;
- all specified verification commands pass with no new attributable warning;
- the diff contains no daily/weekly challenge or upgrade-domain migration;
- documentation reflects that only progression goals, not all Stage 5 data domains, have been consolidated.
