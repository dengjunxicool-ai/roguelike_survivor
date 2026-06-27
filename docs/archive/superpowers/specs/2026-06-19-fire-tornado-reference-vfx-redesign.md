# Fire Tornado Reference VFX Redesign

## Goal

Improve the existing debug-only fire tornado VFX so it reads closer to the provided reference image: a dense vertical fire column with bright spiral flame bands, a hot erupting base, ember spray, and darker smoky outer motion.

This remains a visual-only debug effect. It must not affect combat, damage, status effects, cooldowns, targeting, skill data, or weapon configuration.

## Current Context

The current implementation consists of:

- `scenes/effects/fire_tornado_effect.tscn`
- `scripts/effects/fire_tornado_effect.gd`
- `scripts/debug/dev_debug_panel.gd` spawning the scene through the existing `Fire Tornado` Utility button
- `tools/verify_fire_tornado_debug_vfx.js`
- `tools/verify_fire_tornado_effect_runtime.gd`

The current VFX uses a few `CPUParticles2D` emitters and simple glow drawing. It is functional, but it does not yet create the reference image's strong continuous tornado silhouette or bright wrapped fire ribbons.

## Visual Target

The redesigned effect should emphasize:

- A wide, erupting base with orange sparks and ground-level flare.
- A thick vertical fire column that narrows slightly toward the middle and opens near the top.
- Multiple bright yellow-orange spiral flame ribbons wrapping around the column.
- Dark red smoky outer wisps and ember streaks around the silhouette.
- A hot center with pulsing orange/yellow glow.

## Approach

Use a hybrid of approach 1 and approach 2:

1. Add stronger procedural drawing in `FireTornadoEffect._draw()`:
   - Draw several animated spiral ribbon bands with `draw_polyline()` or layered line segments.
   - Use multiple widths/colors for each ribbon: dark orange body, bright yellow core, faint red outer glow.
   - Draw a tapered tornado body using ellipses/circles at several vertical levels.
   - Draw base flare arcs and hot cracks/sparks near the bottom.

2. Improve particle support:
   - Keep existing `CPUParticles2D` emitters.
   - Retune emitters to produce denser base sparks, rising embers, and smoky outer flecks.
   - Add one or two additional emitters only if needed for separation between sparks and dark smoke.

The effect should still be self-contained in the existing VFX scene/script pair.

## Behavior

The effect remains:

- Spawned by the existing debug panel button.
- Auto-cleaned by lifetime.
- Visual-only.
- Safe to instantiate in headless runtime checks.

No new combat nodes, areas, status calls, skill events, or weapon data changes are allowed.

## Testing

Update verification to catch the richer visual contract:

- Static verifier confirms the script contains the new spiral ribbon drawing path.
- Static verifier confirms no unsupported `CPUParticles2D.visibility_rect` usage returns.
- Runtime verifier loads and instantiates the scene for a few frames without errors.

Run:

- `node tools/verify_fire_tornado_debug_vfx.js`
- `node tools/validate_weapon_authoring_pipeline.js`
- `D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify_fire_tornado_effect_runtime.gd`
- `D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --check-only --script res://scripts/effects/fire_tornado_effect.gd`

## Acceptance Criteria

- The tornado has a clear vertical fire-column silhouette.
- Bright spiral fire ribbons are visible and animated.
- The base reads as hotter and more explosive than the current version.
- Particles add sparks/smoke around the drawn flame shape rather than carrying the whole effect alone.
- Existing debug button behavior is unchanged.
- Static and runtime verification pass.
