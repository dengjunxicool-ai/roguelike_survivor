# Dev Effects Panel VFX Design

## Goal

Add an extensible Effects category to the in-run developer debug panel. The new category lets the user choose a debug-only visual effect from a dropdown and play it either as a continuous demonstration or as a single-shot demonstration.

The first effects are:

- Fire Tornado
- 火星飞弹

火星飞弹 is a fire-element common-style effect: small orange-red spark missiles periodically launch toward the nearest enemy, leaving short ember trails. It is intended to preview projectile flow and burn setup visuals in the dev scene.

## Scope

This change is dev/debug presentation only.

- Do add an Effects category at the same level as Enemy Spawn.
- Do add an effect dropdown under the Effects category.
- Do add two buttons under the dropdown: continuous fire and single fire.
- Do keep Fire Tornado available through the new effect selector.
- Do implement 火星飞弹 with `GPUParticles2D` nodes using `ParticleProcessMaterial`.
- Do not add damage, status application, cooldown, upgrade data, or formal weapon-skill integration.

## Dev Panel UX

`DevDebugPanel` will add a new category button:

- Effects

The Effects page contains:

- Effect dropdown
  - `Fire Tornado`
  - `火星飞弹`
- `持续发射` button
- `单次发射` button

Button behavior:

- `持续发射`
  - Fire Tornado: spawn the existing fire tornado scene once at the resolved effect position.
  - 火星飞弹: spawn a short-lived debug emitter that launches multiple spark missiles over a few seconds.
- `单次发射`
  - Fire Tornado: spawn the existing fire tornado scene once.
  - 火星飞弹: launch one burst of spark missiles immediately.

The selected effect controls both buttons. The design intentionally avoids one button per effect so later effects can be added by extending the dropdown registry.

## 火星飞弹 VFX

Create a debug VFX scene for 火星飞弹. The scene uses a `Node2D` root and `GPUParticles2D` children configured with `ParticleProcessMaterial`.

Recommended scene structure:

- `MarsSparkMissileEffect` (`Node2D`)
  - `CoreParticles` (`GPUParticles2D`)
  - `TrailParticles` (`GPUParticles2D`)
  - `EmberParticles` (`GPUParticles2D`)

Visual behavior:

- Small orange-red spark core.
- Short warm trail behind the moving spark.
- A few drifting embers to imply heat and burn setup.
- Missile tracks nearest enemy from the player when possible.
- If no enemy exists, it flies in a default rightward direction for preview.
- It self-cleans after its lifetime.

Continuous behavior:

- Use a separate debug emitter node or helper method to spawn spark missiles at fixed intervals.
- The continuous emitter self-cleans after a short duration.
- The effect is visual only and should not create combat objects or call damage APIs.

## Integration

`DevDebugPanel` will keep a small effect registry, mapping an effect id to display text and trigger callbacks.

Initial ids:

- `fire_tornado`
- `mars_spark_missile`

The existing Fire Tornado spawn code will be routed through the new Effects page instead of being a standalone Utility button.

Spawn origin:

- Prefer the player as the source.
- Prefer nearest enemy as the target when available.
- Reuse the existing Fire Tornado spawn position helper for Fire Tornado.
- For 火星飞弹, spawn from near the player toward the nearest enemy.

## Verification

Add focused checks that prove the debug feature structure exists and the particle effect uses the requested node/material types.

Checks should verify:

- `DevDebugPanel` defines an Effects category.
- The Effects page has an effect dropdown.
- The dropdown population includes `Fire Tornado` and `火星飞弹`.
- The Effects page exposes `持续发射` and `单次发射` buttons.
- The Mars Spark Missile scene exists.
- The Mars Spark Missile scene contains `GPUParticles2D`.
- The Mars Spark Missile scene uses `ParticleProcessMaterial`.
- The Mars Spark Missile runtime scene instantiates and self-cleans without errors.

Existing verification should continue to pass:

- Fire Tornado debug VFX verification.
- Weapon authoring pipeline verification.
- Godot script parse checks for modified/new GDScript files.

## Out Of Scope

- Formal skill data in `primary_attack.json`.
- Weapon branch upgrades for 火星飞弹.
- Damage, burn application, or hit reactions.
- Production UI exposure outside the dev/debug panel.
