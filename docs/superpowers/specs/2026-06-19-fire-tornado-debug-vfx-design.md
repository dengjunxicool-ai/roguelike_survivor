# Fire Tornado Debug VFX Design

## Goal

Add a developer-mode-only fire tornado visual effect that can be manually spawned from the debug panel. The effect is a particle VFX preview, not a combat skill.

The feature must let developers inspect a dramatic fire tornado in the running scene without changing skill balance, damage, targeting, cooldowns, enemy behavior, or area-effect combat logic.

## Current Context

The project currently uses data-driven combat objects and programmatic visuals:

- `scripts/debug/dev_debug_panel.gd` owns the in-game developer toolbar and manual debug actions.
- `scripts/combat/area_effect.gd` draws existing area visuals with `_draw()` styles such as `fire_burst`, `lava_zone`, and `smoke_zone`.
- `scenes/area_effect.tscn` is tied to combat-area behavior and damage windows.
- There is no current project-wide particle VFX scene pattern based on `CPUParticles2D` or `GPUParticles2D`.

Because this request is debug-only and specifically asks for a particle effect, the fire tornado should use a dedicated VFX scene instead of extending `AreaEffect`.

## Scope

Create a self-contained particle VFX scene:

- `scenes/effects/fire_tornado_effect.tscn`
- `scripts/effects/fire_tornado_effect.gd`

Add a manual debug-panel spawn action:

- A button named `Fire Tornado` in the developer panel's `Utility` page.
- The button spawns the effect near the player. If a nearest enemy exists, the effect appears 96 pixels from the player toward that enemy. Otherwise, it appears 96 pixels to the player's right.
- The effect auto-cleans after its configured lifetime.

## Visual Design

The effect should read as a vertical, rotating fire tornado in the existing 2D top-down/oblique game view.

It will be built from layered `CPUParticles2D` emitters:

- Base fire ring: orange-red particles around a wide bottom radius to show ground ignition.
- Spiral body: two or three emitters whose local positions and rotation are driven by script to create a rotating column.
- Ember spray: smaller yellow-orange particles that drift outward and fade.
- Heat core: a lightweight glow or pulsing draw layer at the center to make the tornado feel hot and dense.

The default lifetime should be about 2.5 seconds. The effect should fade naturally before freeing itself.

## Behavior

The VFX scene is visual-only:

- It does not create an `Area2D`.
- It does not call `take_damage`.
- It does not apply statuses.
- It does not emit skill events.
- It does not register with `SkillManager`, `SkillExecutor`, or combat object data.

The debug panel spawns it only when developer mode/debug panel code is available. It should not appear in normal gameplay unless manually triggered from that debug path.

## Data Flow

1. The developer opens the debug panel.
2. The developer presses `Fire Tornado`.
3. `DevDebugPanel` resolves the player node.
4. `DevDebugPanel` instantiates `res://scenes/effects/fire_tornado_effect.tscn`.
5. The effect is added to the player's parent or current scene and positioned 96 pixels from the player toward the nearest enemy, falling back to the player's right side.
6. `FireTornadoEffect` starts its particle emitters and lifetime timer.
7. The effect fades and calls `queue_free()`.

## Error Handling

If the player cannot be found, the debug panel logs a warning and does not spawn the effect.

If the scene fails to load or instantiate, the debug panel logs an error and keeps running.

The VFX scene should tolerate missing child emitters by checking node references before using them. Missing emitters should reduce visual richness but not crash the debug panel.

## Testing

Add focused verification that does not require visual inspection:

- A Node verification script checks that the debug panel references `fire_tornado_effect.tscn` and exposes a `Fire Tornado` spawn path.
- The same script checks that the effect script has a lifetime/cleanup path.
- A Godot headless script or smoke check loads the scene and instantiates it without errors if the local Godot executable is available.

Run existing lightweight validation after implementation where possible:

- `node tools/validate_weapon_authoring_pipeline.js`
- `godot --headless --path . --quit` or the configured local Godot command, if available

## Acceptance Criteria

- Developer mode includes a manual button for spawning the fire tornado.
- Pressing the button spawns a visible particle tornado near the player.
- The effect uses particle nodes rather than only `_draw()` programmatic shapes.
- The effect automatically removes itself after its lifetime.
- No combat damage, targeting, status, cooldown, or skill data changes are introduced.
- Existing debug panel behavior continues to work.

## Non-Goals

- No new playable skill.
- No weapon, upgrade, or branch balance changes.
- No changes to `data/primary_attack.json`, `data/combat_objects.json`, or combat object behavior.
- No replacement of existing fireball, explosion, lava, or burning oil visuals.
- No new external art assets are required.
