# Offscreen Target Filter Design

## Goal

Enemies outside the current camera view must not be selected by automatic skill targeting or primary-attack targeting, even when they are still within numeric range.

## Confirmed Behavior

- Boundary definition: the active `Camera2D` visible world rectangle.
- If an enemy is outside the current camera view, automatic targeting must ignore it.
- If an enemy is inside the current camera view and otherwise valid, existing range, priority, status, health, and boss/elite rules still apply.
- If no active camera or viewport is available, targeting keeps the existing behavior and does not reject enemies by visibility. This keeps headless verification and isolated tool scenes stable.

## Architecture

Use `TargetingService` as the central source of enemy target validity.

`TargetingService._is_valid_enemy()` already rejects invalid, queued, dead-state, zero-health, and `_is_dead` enemies. Add a camera-visibility check to that same validity path so all `find_target()` and `find_targets()` modes inherit the rule:

- nearest enemy
- highest HP enemy
- elite/highest-health priority
- densest cluster targeting
- status-priority targeting
- random enemy targeting
- enemies around player
- skill retargeting after target death

Primary attack and projectile homing paths that currently perform their own target validity checks should reuse `TargetingService.is_valid_target()` instead of duplicating partial logic. This keeps primary attacks and skills consistent.

## Visibility Calculation

The visibility check should compute a world-space rectangle from the active viewport camera:

1. Get the `SceneTree` from `Engine.get_main_loop()`.
2. Get the root viewport and its active `Camera2D`.
3. Convert the viewport visible size into world units by dividing by the camera zoom.
4. Center the rectangle on `camera.global_position`.
5. Accept enemies whose `global_position` is inside that rectangle.

No buffer is applied because the selected requirement is strict current-camera visibility.

## Error Handling

- Missing `SceneTree`, root viewport, visible rect, or active camera: return true for visibility so non-run scenes and headless verification do not fail because they lack a camera.
- Invalid enemy nodes remain rejected before the visibility calculation.
- The check only applies to enemy target validity. It does not change collision damage after a projectile has already hit a body.

## Testing

Add a static verification script, exposed through `package.json`, to guard the contract:

- `TargetingService._is_valid_enemy()` must include the scene-view visibility check.
- The visibility helper must use the active camera, visible viewport rect, camera zoom, and enemy `global_position`.
- `TargetingService.is_valid_target()` must continue to reuse `_is_valid_enemy()`.
- The existing death and health checks must remain present.
- Projectile/homing primary-attack target validity must call `TargetingService.is_valid_target()` so primary attack target selection follows the same screen-visible rule as skills.

Run targeted verification plus nearby existing checks:

- `npm run verify:offscreen-target-filter`
- `npm run verify:skill-retarget-dead-target`
- `npm run verify:player-dash`
- `npm run verify:enemy-motion-neighbor-limit`

Known unrelated context: `verify:fire-skill-runtime-smoke` and `verify:frost-skill-runtime-smoke` currently fail before this feature path because their smoke setup assumes full direct learning of fire/frost/fusion skill sets while the current `SkillManager` enforces the god-school learning cap.

## Out Of Scope

- Changing enemy spawn or despawn behavior.
- Changing map/background bounds.
- Adding an offscreen buffer.
- Changing projectile collision behavior after a target has already been hit.
- Fixing existing fire/frost smoke failures caused by skill learning rules.
