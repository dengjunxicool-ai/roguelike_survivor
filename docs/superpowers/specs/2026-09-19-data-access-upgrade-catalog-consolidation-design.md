# Stage 5D Data Access Upgrade Catalog Consolidation Design

## Status

Approved architecture and detailed design. This document defines the implementation boundary for Stage 5D. It does not authorize production-code implementation until the written implementation plan is reviewed and its execution method is selected.

## Context

Stage 5A made `DataManager` the normal-runtime owner of status definitions. Stage 5B extended the same ownership model to progression goals, and Stage 5C consolidated the daily and weekly challenge pools. These stages established the project pattern:

- `DataManager` loads and owns runtime configuration;
- `GameData` remains the stable public facade;
- JSON reads remain compatibility fallbacks while migration evidence is incomplete;
- manager, facade, and fallback results are isolated from caller mutation;
- each data domain moves in a separately verifiable and reversible batch.

The remaining normal-runtime reads from `res://data/upgrades/upgrades.json` are closely related:

- `curse_choices`;
- `level_up_upgrades`;
- `permanent_upgrades`;
- `rarity_weights`;
- the permanent-upgrade lookup facade.

`DataManager` already parses this document once and builds a combined upgrade ID index plus a level-up-upgrade index. However, it does not preserve all three category pools as explicit ordered data, and it does not own `rarity_weights`. Consequently, several `GameData` facades still use the JSON cache as their normal path.

Stage 5D consolidates all upgrade-catalog surfaces in one batch because they share one source document and one ownership boundary. The batch does not change upgrade selection, weighting, application, persistence, presentation, or configuration values.

## Goals

1. Make `DataManager` the normal-runtime owner of all three ordered upgrade category pools.
2. Make `DataManager` the normal-runtime owner of rarity weights.
3. Preserve all existing `GameData` public method names and return shapes.
4. Preserve the existing combined upgrade ID lookup and its callers.
5. Preserve source category order exactly.
6. Preserve independent JSON fallback for every pool and for rarity weights.
7. Make manager, facade, and fallback results safe from nested caller mutation.
8. Prove the owner/facade/fallback contract with static and runtime verification.
9. Keep every consumer, gameplay rule, configuration value, UI flow, and save result unchanged.

## Non-goals

Stage 5D does not:

- change any entry in `data/upgrades/upgrades.json`;
- change upgrade IDs, order, rarity names, weights, modifiers, descriptions, or maximum levels;
- change random-number generation or the number or order of random calls;
- change upgrade filtering, guaranteed choices, duplicate prevention, or availability rules;
- change curse choice count or curse application;
- change permanent-upgrade pricing, ownership, aggregation, or save data;
- change player upgrade application;
- remove the `GameData` document cache or compatibility fallback;
- remove the combined `_upgrade_definitions` index;
- remove the existing `_level_up_upgrade_definitions` index;
- introduce a generic string-keyed category API;
- migrate consumer-owned fallback logic outside the five named `GameData` facades;
- refactor `UpgradePool`, `UpgradeSelectionHelper`, `SaveManager`, UI controllers, or player code;
- perform performance work without measurements;
- modify damage, status, death, reward, or save pipelines.

## Current Evidence

### Source document

`data/upgrades/upgrades.json` contains one dictionary with four relevant top-level keys:

- `rarity_weights`: dictionary;
- `curse_choices`: ordered array of dictionaries;
- `permanent_upgrades`: ordered array of dictionaries;
- `level_up_upgrades`: ordered array of dictionaries.

### Existing owner behavior

`scripts/core/data_manager.gd` loads `UPGRADES_PATH` once. It loops over `UPGRADE_KEYS` and delegates indexing to `DataDefinitionIndex.index_upgrade_definitions()`. The combined `_upgrade_definitions` index contains all category entries. `_level_up_upgrade_definitions` contains only level-up entries.

The existing public methods are:

- `get_upgrade_definition()`;
- `get_upgrade_definitions()`;
- `get_level_up_upgrade_definitions()`.

The level-up pool accessor currently derives its return value from dictionary values rather than an explicit ordered category array. There are no dedicated owner accessors for curse choices, permanent upgrades, or rarity weights.

### Existing facade behavior

`scripts/game/game_data.gd` currently provides:

- `get_curse_choice_pool()` through JSON;
- `get_level_up_upgrade_pool()` through `DataManager`, with JSON fallback;
- `get_permanent_upgrade_pool()` through JSON;
- `get_permanent_upgrade(id)` through JSON;
- `get_rarity_weights()` through JSON.

These public methods are compatibility contracts and must remain callable with the same names and argument shapes.

### Existing consumers

The primary consumers are:

- `UpgradePool`, which reads level-up upgrades and rarity weights;
- `RunChoiceModalController`, which reads curse choices;
- `SaveManager`, which reads permanent-upgrade definitions and the permanent pool;
- `MetaUpgradeViewModelBuilder`, which reads the permanent pool;
- `Player`, which ultimately applies upgrade definitions through existing methods.

Stage 5D treats these files as protected consumers and regression-test targets, not implementation targets.

### Existing mutation risk

`GameDataAccess.get_dictionary_array()` builds a new outer typed array but retains dictionary references from the cached source document. `GameDataAccess.find_by_id()` also returns the matching dictionary reference. The current rarity facade returns the cached dictionary directly. A caller can therefore mutate nested configuration and contaminate later fallback reads.

Stage 5D hardens only the affected upgrade facades by deep-duplicating their fallback results. It does not change the generic helper, which would broaden the behavioral surface beyond this batch.

## Chosen Architecture

### Explicit category ownership

`DataManager` will retain the existing indexes and add explicit state for:

- the ordered curse-choice pool;
- the ordered level-up-upgrade pool;
- the ordered permanent-upgrade pool;
- rarity weights.

Recommended private field names are:

```gdscript
var _curse_choice_pool: Array[Dictionary] = []
var _level_up_upgrade_pool: Array[Dictionary] = []
var _permanent_upgrade_pool: Array[Dictionary] = []
var _rarity_weights: Dictionary = {}
```

The existing `_upgrade_definitions` and `_level_up_upgrade_definitions` dictionaries remain intact. This avoids changing `DataDefinitionIndex`, lookup behavior, or unrelated callers merely to remove internal duplication.

### Dedicated owner accessors

`DataManager` will expose:

```gdscript
func get_curse_choice_definitions() -> Array[Dictionary]
func get_level_up_upgrade_definitions() -> Array[Dictionary]
func get_permanent_upgrade_definitions() -> Array[Dictionary]
func get_rarity_weights() -> Dictionary
```

The existing `get_level_up_upgrade_definitions()` name is retained, but its source becomes the explicit ordered category pool. Every accessor returns `duplicate(true)` or an equivalent deep copy.

No generic `get_upgrade_pool(category)` method is introduced. Dedicated methods keep category keys out of callers and make missing or incorrect ownership visible to static verification.

### Single document load

`DataManager.load_all()` must continue to call `_load_json_document(UPGRADES_PATH)` exactly once. From that same parsed dictionary it will:

1. preserve the three source arrays in their source order;
2. copy the rarity-weight dictionary;
3. build the existing combined and level-up indexes.

The four new fields must be cleared at the beginning of every `load_all()` call so reload behavior remains deterministic.

Valid configuration must not emit new warnings or errors. Malformed type handling may follow existing `DataManager` validation conventions, but it must resolve to an empty owner value so the corresponding `GameData` facade can use its compatibility fallback.

## Facade Design

### Pool facades

The following methods remain public and manager-first:

```gdscript
GameData.get_curse_choice_pool()
GameData.get_level_up_upgrade_pool()
GameData.get_permanent_upgrade_pool()
```

Each method independently:

1. asks `_get_pool_from_data_manager()` for its dedicated accessor;
2. returns the manager value if it is a non-empty typed dictionary array;
3. otherwise reads only its own key from `UPGRADES_PATH`;
4. returns a deep duplicate of the fallback pool.

An unusable result for one category must not change the source selected by either of the other categories.

### Permanent-upgrade definition facade

`GameData.get_permanent_upgrade(upgrade_id)` remains public. It will:

1. call `_get_definition_from_data_manager("get_upgrade_definition", upgrade_id)`;
2. return a non-empty manager result;
3. otherwise find the ID only within the JSON `permanent_upgrades` array;
4. deep-duplicate the fallback definition before returning it.

The fallback must remain category-restricted. It must not return a curse or level-up definition that happens to share an ID.

### Rarity-weight facade

`GameData.get_rarity_weights()` remains public. It will use the same explicit dictionary delegation shape already proven by `get_progression_goals()`:

1. resolve `DataManager`;
2. require `get_rarity_weights()`;
3. accept a non-empty dictionary result;
4. otherwise read `rarity_weights` from the cached upgrade document;
5. return a deep duplicate of the fallback dictionary.

An empty manager rarity dictionary triggers only the rarity fallback. It must not force any category pool to fall back.

## Behavioral Invariants

Stage 5D must preserve all of the following:

1. Each category contains exactly the same definitions as its source array.
2. Each category preserves source order exactly.
3. Every ID and every nested field remains unchanged.
4. Rarity keys and numeric values remain unchanged.
5. `GameData` public method names and signatures remain unchanged.
6. Manager-first paths return manager-owned data rather than calling the manager and discarding the result.
7. Manager, facade, and fallback results are deeply isolated from later reads.
8. A single empty manager category triggers fallback only for that category.
9. Empty manager rarity weights trigger only the rarity fallback.
10. `get_permanent_upgrade(id)` remains restricted to permanent upgrades on fallback.
11. Missing IDs still return an empty dictionary.
12. Upgrade selection receives definitions and weights in the same order and with the same values.
13. Random-number generation and selection call order do not change.
14. Curse choice count and display order do not change.
15. Permanent-upgrade lookup, purchase, aggregation, display, and persistence do not change.
16. `load_all()` reloads every new owner field without retaining caller mutations or stale entries.

## Verification Design

### Static boundary verifier

Add `tools/verify/verify_data_access_upgrade_catalog_boundary.js` and register a matching package script.

The verifier must check at least:

- `DataManager` declares the four explicit owner fields;
- `load_all()` clears all four fields;
- the upgrade document is loaded once from `UPGRADES_PATH`;
- all three source categories and rarity weights are populated from that document;
- the combined upgrade index remains present;
- the existing level-up index remains present;
- all four owner accessors exist and return deep copies;
- the three pool facades call the intended owner accessor;
- each pool facade retains its own deep-copy JSON fallback;
- `get_permanent_upgrade()` delegates to `get_upgrade_definition` and retains a category-restricted deep-copy fallback;
- the rarity facade delegates to the owner and retains a deep-copy JSON fallback;
- no generic string-keyed category API is introduced;
- protected consumers and `upgrades.json` are not part of the implementation diff.

Static checks should enforce architectural contracts, not formatting or brittle whole-function snapshots.

### Runtime verifier

Add `tools/verify/verify_data_access_upgrade_catalog.gd` and register a matching package script.

The runtime verifier must cover:

1. load the source upgrade document independently;
2. obtain the real `DataManager` autoload;
3. compare all three manager pools with their source arrays;
4. compare manager rarity weights with the source dictionary;
5. compare all four `GameData` facades with source data;
6. verify category counts, IDs, order, fields, and values;
7. verify `get_permanent_upgrade()` for every permanent ID and for a missing ID;
8. mutate nested `modifiers`, `level_modifiers`, and `scope` values returned by manager accessors, then prove fresh manager reads are unchanged;
9. repeat nested mutation checks through every facade;
10. mutate a returned rarity weight and prove fresh manager and facade reads are unchanged;
11. temporarily substitute recognizable non-empty manager values and prove every facade actually returns its manager result;
12. make exactly one manager category empty and prove only that category uses JSON fallback;
13. make only manager rarity weights empty and prove only rarity uses JSON fallback;
14. temporarily hide the fixed root manager path using the proven Stage 5B/5C isolation pattern;
15. clear and observe the `GameData` document cache, call every fallback facade, and prove `UPGRADES_PATH` was loaded;
16. compare fallback values with source data;
17. mutate nested fallback results and prove later fallback reads are unchanged;
18. restore the autoload name, every temporary manager field, and the original document cache state before reporting completion.

The fallback probe must contain no `await` and no early return while the manager name or private fields are changed. Cleanup must run before final assertions and process termination.

### Existing regression gates

The Stage 5D gate must include:

- `node tools/validate/check_text_encoding.js`;
- `node tools/validate/validate_enemy_configs.js`;
- `node tools/validate/validate_modifier_effects.js`;
- Stage 5A status-pool static and runtime verification;
- Stage 5B progression-goals static and runtime verification;
- Stage 5C challenge-pool static and runtime verification;
- `verify:skill-growth-upgrade-pool`;
- `verify:upgrade-pool-no-relic-fireball-god-mix`;
- `verify:upgrade-pool-missing-rarity`;
- the result-unlock cache lifetime check because `SaveManager` is a protected consumer;
- direct Godot headless startup;
- `git diff --check`;
- a protected-file diff check.

### Godot execution environment

Godot commands must run one at a time as direct executable invocations. They must not be launched through npm, Node.js, Python, `cmd /c`, or a second PowerShell inside the managed Windows sandbox.

The current environment has two distinct setup constraints:

1. Godot 4.6.3 may crash during sandboxed initialization with `signal 11` / `0xC0000005`; an identical direct command outside the sandbox is the established diagnostic control.
2. A fresh isolated worktree has no ignored `.godot/global_script_class_cache.cfg`. Before ordinary headless verification, run one direct `--headless --editor --path . --quit` scan outside the sandbox. The scan may create ignored `.godot` content and untracked generated `.gd.uid` files. Remove only newly generated untracked UID files after confirming their exact paths; never delete user-authored or tracked UID files.

After the editor scan, the ordinary direct headless startup must complete without script parse errors. Exit code alone is insufficient: validation must inspect output for `SCRIPT ERROR` and `ERROR` lines.

## Failure Handling

If any validation fails:

1. stop Stage 5D scope expansion;
2. record the exact command and relevant output;
3. classify the failure as pre-existing, environment-related, or introduced by Stage 5D;
4. do not weaken assertions, thresholds, or protected-file checks;
5. use a failing contract before changing production code;
6. rerun the smallest affected gate, then the complete Stage 5D gate.

## Protected Files

The implementation must not modify:

- `scripts/upgrades/upgrade_pool.gd`;
- `scripts/upgrades/upgrade_selection_helper.gd`;
- `scripts/game/save_manager.gd`;
- `scripts/ui/modals/run_choice_modal_controller.gd`;
- `scripts/ui/screens/meta_upgrade_view_model_builder.gd`;
- `scripts/player/player_controller.gd`;
- `data/upgrades/upgrades.json`.

If implementation appears to require one of these files, stop and return to design approval rather than expanding scope.

## Expected Modified Files

The implementation batch is expected to touch only:

- `scripts/core/data_manager.gd`;
- `scripts/game/game_data.gd`;
- `package.json`;
- `tools/verify/verify_data_access_upgrade_catalog_boundary.js`;
- `tools/verify/verify_data_access_upgrade_catalog.gd`;
- `docs/PROJECT_SYSTEMS_OVERVIEW.md`;
- `docs/PROJECT_ENGINEERING_GUIDELINES.md`;
- `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`;
- the Stage 5D implementation plan.

This specification is committed separately before the implementation plan.

## Rollback

Stage 5D is independently reversible:

1. remove the four new owner fields and their load/reset logic;
2. restore the previous level-up accessor implementation;
3. remove the three new owner accessors;
4. restore the five `GameData` methods to their Stage 5C forms;
5. remove the two Stage 5D verifiers and package entries;
6. revert only the Stage 5D engineering-document statements.

The original JSON paths then resume normal-runtime reads. No configuration migration, save migration, resource conversion, or consumer rollback is required.

## Completion Criteria

Stage 5D is complete only when:

- `DataManager` loads the upgrade document once and owns all four upgrade-catalog surfaces;
- the three explicit manager pools match source category order and values;
- manager rarity weights match the source dictionary;
- all five `GameData` facades prefer usable manager values;
- all five facades retain independent compatibility fallbacks;
- manager, facade, and fallback results pass deep mutation-isolation checks;
- permanent-upgrade lookup remains category-correct;
- existing upgrade selection and save-related regression gates pass;
- ordinary headless startup has no script errors after isolated-worktree setup;
- protected files have no diff;
- the implementation diff contains no configuration, gameplay, UI, save, or unrelated refactor;
- documentation matches the implemented boundary;
- an independent whole-branch review finds no unresolved Critical or Important issues.
