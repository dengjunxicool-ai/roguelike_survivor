# Dev Debug Effects Page Extraction Design

## Context

`scripts/debug/dev_debug_panel.gd` currently owns the complete developer-toolbar shell, seven page layouts, option population, debug actions, runtime state summaries, and effect-specific spawning logic. The Effects page is a suitable first extraction because it has a narrow UI surface, only two effect types, existing static and runtime verification, and no authority over gameplay state, saves, combat resolution, or configuration data.

This change establishes one page-level extraction pattern without introducing a general page framework or changing any other debug page.

## Goal

Move the complete Effects page content and effect execution logic into a focused component while preserving the existing developer-toolbar behavior, visual layout, debug entry points, option IDs, spawn positions, log semantics, and effect scenes.

## Non-Goals

- Do not split the other Debug pages in this batch.
- Do not create a generic plugin, page registry, dependency-injection framework, or UI toolkit.
- Do not change Fire Tornado or Mars Spark Missile visuals or runtime behavior.
- Do not change gameplay, combat state, damage, skills, enemy behavior, saves, configuration schemas, or production UI.
- Do not rename the `effects` category, visible button text, or effect option IDs.
- Do not remove compatibility methods from `DevDebugPanel` in this batch.

## Selected Architecture

Create `scripts/debug/pages/dev_debug_effects_page.gd` as a `VBoxContainer` component named `DevDebugEffectsPage`.

The component owns:

- the Effects page content below the category wrapper;
- the Effect `OptionButton`;
- the continuous and single-fire buttons;
- the effect option definitions;
- effect selection and dispatch;
- Fire Tornado and Mars Spark Missile scene dependencies;
- effect instantiation, parent resolution, and spawn-position calculation.

`DevDebugPanel` remains the shell and compatibility facade. It owns:

- category navigation and the `effects` category wrapper;
- creation and attachment of `DevDebugEffectsPage`;
- player and nearest-enemy lookup callbacks;
- forwarding page log events to the existing debug log;
- thin compatibility methods matching the current method names.

No other runtime system references the new page directly.

## Component Interface

`DevDebugEffectsPage` exposes a deliberately small interface:

```gdscript
signal log_requested(level: StringName, message: String)

func setup(get_player: Callable, get_nearest_enemy: Callable) -> void
func build() -> void
func populate_options() -> void
func start_continuous_effect() -> void
func fire_single_effect() -> void
func trigger_selected_effect(continuous: bool) -> void
func spawn_fire_tornado_effect() -> void
func spawn_mars_spark_missile_effect(continuous: bool) -> void
func resolve_fire_tornado_spawn_position(player: Node2D) -> Vector2
func resolve_mars_spark_missile_spawn_position(player: Node2D) -> Vector2
func resolve_mars_spark_missile_target_position(player: Node2D, origin: Vector2) -> Vector2
func get_effect_option() -> OptionButton
```

The lookup callbacks preserve the existing Panel lookup behavior without giving the page a reference to the entire `DevDebugPanel`. The page uses its own scene-tree access only for the current-scene fallback parent after consulting the selected player's parent.

`build()` is idempotent: repeated calls must not duplicate controls or signal connections. `populate_options()` is also idempotent and must retain the existing IDs:

- `fire_tornado`
- `mars_spark_missile`

## Panel Integration

`DevDebugPanel._build_effects_page()` continues to create the category wrapper through `_add_category_page(page_root, "effects", "Effects")`. It then creates and configures one `DevDebugEffectsPage` child.

The Panel retains `_effect_option` as a compatibility alias assigned from `DevDebugEffectsPage.get_effect_option()`. The page remains the owner of that control and its selection state.

The following Panel methods remain present as thin delegates:

- `_populate_effect_options()`
- `_start_continuous_effect_fire()`
- `_fire_single_effect()`
- `_trigger_selected_effect(continuous)`
- `_spawn_fire_tornado_effect()`
- `_spawn_mars_spark_missile_effect(continuous)`
- `_resolve_fire_tornado_spawn_position(player)`
- `_resolve_mars_spark_missile_spawn_position(player)`
- `_resolve_mars_spark_missile_target_position(player, origin)`

All retained methods contain delegation only. They do not keep independent option, spawning, or position-calculation logic in the Panel.

The Panel connects `log_requested` once and maps levels as follows:

- `info` to `_log()`;
- `warning` to `_log_warn()`;
- `error` to `_log_error()`.

## UI And Behavior Invariants

The extracted page must preserve:

- category ID `effects` and title `Effects`;
- dropdown label `Effect`;
- button text `持续发射` and `单次发射`;
- button width `116`;
- option labels and IDs;
- continuous button calling Mars Spark Missile with continuous mode enabled;
- single button calling it with continuous mode disabled;
- Fire Tornado spawning 96 pixels from the player toward the nearest valid enemy, falling back to the right;
- Mars Spark Missile spawning 32 pixels toward the nearest valid enemy and targeting that enemy, with the existing 360-pixel forward fallback;
- parent preference: player parent, then current scene;
- existing success, warning, and error messages;
- existing VFX scene resources and their visual configuration.

## Failure Handling

Missing dependencies are handled inside the page and reported through `log_requested`:

- missing player: warning, no spawn;
- missing scene resource or invalid scene root: error, no spawn;
- missing parent: release the temporary instance, report error, no spawn;
- missing or unknown option: warning, no spawn.

The page must not throw because a lookup callback is invalid. An invalid callback is treated as a missing player or missing nearest enemy, depending on the callback.

## Compatibility And Dependency Rules

- `DevDebugPanel` remains the externally constructed `CanvasLayer` and keeps its existing public debug methods.
- `UIManager` continues to create `DevDebugPanel`; it does not know about page components.
- Scene paths and node paths outside the internal Effects content remain unchanged.
- No gameplay manager, player, enemy, or effect script gains a dependency on Debug UI.
- The page does not write saves, modify combat state, or bypass existing game pipelines.
- Existing uncommitted changes from Stage 1 remain untouched except where a verification command reads them.

## Verification Strategy

Use test-driven development.

1. Add a static boundary contract that fails until the new page exists, owns the effect scenes and execution methods, and is mounted by `DevDebugPanel`.
2. Update `verify_dev_effects_panel_vfx.js` so it follows the Panel delegates into `DevDebugEffectsPage` rather than requiring all implementation to remain in the Panel.
3. Add a Godot headless test that instantiates the page and verifies:
   - one dropdown and two buttons are created;
   - the two option IDs and labels remain unchanged;
   - repeated `build()` and `populate_options()` calls do not duplicate UI;
   - continuous and single actions dispatch the correct mode;
   - missing-player and missing-parent paths emit the expected log level without crashing.
4. Run the existing adjacent checks:
   - Dev Effects panel VFX contract;
   - Fire Tornado debug VFX contract;
   - Mars Spark Missile runtime verification;
   - DevDebugPanel skill-card and clear-skills checks;
   - Godot headless project startup.
5. Re-run the complete Stage 1 regression baseline before completion.

## Success Criteria

- The complete Effects page content and execution logic live in `DevDebugEffectsPage`.
- `DevDebugPanel` contains only category mounting, log forwarding, compatibility aliases, and thin delegates for Effects.
- All behavior invariants and existing debug entry points remain intact.
- New boundary and runtime tests demonstrate the extraction.
- All adjacent and Stage 1 verification commands pass.
- The diff contains no gameplay, numeric, resource, visual, save, or unrelated formatting changes.
- The batch can be rolled back by reverting the new page, its tests, and the small Panel integration diff.

## Risks And Mitigations

### Signal or control duplication

Repeated setup could create duplicate buttons or callbacks. `build()` and log-signal connection are explicitly idempotent and covered by headless verification.

### Hidden compatibility dependency

Existing tests and dynamic debug tooling may call the old Panel methods by string. Thin Panel delegates remain for the entire batch; removal is explicitly out of scope.

### Layout drift

The page recreates the existing row structure, labels, and fixed button widths exactly. The category wrapper remains owned by the Panel shell.

### Over-generalization

This batch creates one concrete Effects page component only. A shared page abstraction may be considered later only after at least two extracted pages demonstrate a repeated interface.

## Rollback

Rollback restores the Effects UI and spawn methods in `DevDebugPanel`, removes `dev_debug_effects_page.gd`, and removes the new boundary/runtime tests. No data migration, scene migration, or compatibility cleanup is required.
