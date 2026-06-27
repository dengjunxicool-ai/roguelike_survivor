# 2D Oblique Top-Down Perspective Design

## Goal

Convert the current pure 2D run presentation into an oblique top-down / isometric-feeling view similar to the provided reference image, while preserving the existing 2D gameplay coordinate system, combat math, collision, targeting, enemy movement, and debug tooling.

This is a visual and presentation change, not a conversion to 3D.

## Reference Direction

The target look is not a strict 90-degree top-down camera. It is a 2D oblique top-down scene:

- The floor reads as a tilted arena plane.
- Characters remain readable from the front/side rather than only from the crown of the head.
- The scene uses dark foreground framing, atmospheric lighting, and a brighter playable center.
- Depth is suggested through sprite layering, Y ordering, shadows, and foreground occluders.

## Non-Goals

- Do not convert the project to 3D.
- Do not rotate or skew the whole gameplay world.
- Do not change collision shapes, attack radii, explosion radii, pickup radii, enemy AI distances, or skill targeting math.
- Do not rework the combat system, damage system, upgrade system, or debug record logic.

## Approach

Use a staged 2D visual migration.

Stage 1: Camera and scene presentation

- Keep `Camera2D` attached to `Player`.
- Tune camera zoom and smoothing only if needed for the new arena scale.
- Replace or add a map/background asset that is drawn in an oblique top-down style.
- Add a foreground/depth layer for dark occluders and edge framing.
- Keep UI CanvasLayer behavior unchanged.

Stage 2: Sprite readability and depth

- Add consistent ground shadows under player, enemies, pickups, projectiles, and important combat objects.
- Enable or enforce Y-based visual ordering for player/enemies/drops where needed.
- Ensure foreground props can visually cover actors only when intended.

Stage 3: Actor animation direction

- Move from side-only movement visuals to oblique top-down directional states.
- Prefer at least four actor facing states: down/front, up/back, left, right.
- If final assets are unavailable, use a temporary compatibility layer with existing sprites, shadows, and scale/offset adjustments.

Stage 4: Effect projection polish

- Keep range, explosion, and pickup debug overlays mathematically correct.
- Only after gameplay validation, optionally render some non-debug visual effects as ellipses or tilted decals to better match the oblique floor.
- Debug overlays should continue to expose true gameplay values.

## System Boundaries

Camera:

- `scenes/main.tscn` owns `Player/Camera2D`.
- Initial implementation should not rotate `Camera2D`.
- Camera bounds continue to be driven by the responsive background and player movement bounds.

Map:

- `DungeonBackground` remains the main world background hook.
- New oblique map art should fit the existing movement-bounds model, or the bounds calculation must be updated in a contained way.

Actors:

- Player and enemy world positions remain ordinary `Vector2` positions.
- CharacterBody2D movement remains unchanged.
- Visual offsets and shadows should live under actor scenes or visual controllers, not gameplay code.

Sorting:

- Y ordering should be handled through scene structure, `z_index`, or a small dedicated sorting helper if existing Godot ordering is insufficient.
- Sorting must not alter physics or target selection.

Debug:

- Dev Tool overlays should stay truthful to runtime logic.
- Attack range, explosion range, and pickup range should continue to show actual gameplay geometry.

## Testing Strategy

Automated checks should cover:

- `Camera2D` still exists under Player and remains enabled.
- Camera zoom stays within the intended run exploration range.
- Player movement bounds and camera limits still initialize.
- Enemy movement, enemy collision blocking, projectile spawning, pickup behavior, and debug overlays remain functional.
- UI remains in CanvasLayer space and is not affected by visual depth layers.

Manual visual checks should cover:

- Player remains readable at the intended zoom.
- Enemy silhouettes remain readable in crowds.
- Foreground framing does not hide critical combat information.
- Debug overlays and actual hit ranges still visually align enough for testing.

## Acceptance Criteria

- The run scene reads as oblique top-down in normal play.
- No combat numeric behavior changes are introduced by the perspective work.
- Existing debug mode remains usable.
- Range and damage debug tools continue to represent runtime truth.
- The change can ship incrementally, with temporary placeholder visuals allowed during Stage 1.
