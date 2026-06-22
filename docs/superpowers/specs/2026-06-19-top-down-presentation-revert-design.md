# Top-Down Presentation Revert Design

## Goal

Return the run scene to a pure 2D top-down presentation while preserving gameplay logic, existing shadows, weapon display, attack visuals, and the debug fire tornado effect.

## Scope

- Remove the oblique-only presentation layer from `scenes/main.tscn`.
- Remove `ObliqueVisualAdapter` usage from player, enemy, area, projectile, and weapon visuals.
- Restore programmatic area and projectile visuals to ordinary 2D shapes.
- Restore the fire tornado to its GIF-style effect without oblique projection.
- Add a focused runtime check that fails if oblique presentation hooks are reintroduced.

## Non-Goals

- Do not change combat math, collision, targeting, enemy AI, or skill configs.
- Do not remove basic ground shadows from actors and projectiles.
- Do not rewrite character or weapon art assets.
