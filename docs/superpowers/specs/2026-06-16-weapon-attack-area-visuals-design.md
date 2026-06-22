# Weapon Attack Area Visuals Design

## Goal

Add clear, lightweight attack-area visuals for every current weapon using programmatic shapes and configured colors first. The feature must make attack coverage easier to read during play and debugging while keeping future art replacement data-driven.

This change is visual only. It must not change damage, targeting, cooldown, status application, max targets, or branch behavior.

## Current Context

Main weapon attacks are data-driven:

- `data/weapons.json` binds each weapon to a `starting_skill_id`.
- `data/primary_attack.json` defines cast events and action types.
- `data/combat_objects.json` defines projectile, area, trap, and orbit visuals.
- `scripts/combat/projectile.gd`, `scripts/combat/area_effect.gd`, and `scripts/combat/orbit_object.gd` render and apply combat objects.

`AreaEffect` already supports several programmatic styles such as poison, lava, smoke, and acid cone. Many other weapon objects still rely on a generic icon or generic animation config, so their readable attack shape is inconsistent.

## Visual Model

Each combat object gets a `visual_style` and color configuration in `data/combat_objects.json`.

The rendering layer uses `visual_style` as a programmatic fallback. If later art assets are supplied through `visual.texture`, `visual.sprite_frames`, or `visual.animations`, those assets can replace or augment the fallback without changing combat logic.

The visual contract is:

- `visual_style`: semantic style key used by code drawing.
- `visual_color`: main fill or body color.
- `visual_ring_color`: outline, edge, or highlight color where applicable.
- `visual`: optional art-resource config for future texture or animation replacement.

## Weapon Shapes

| Weapon | Primary Object | Suggested Shape | Suggested Color |
| --- | --- | --- | --- |
| Fire Staff | fireball projectile / explosion area | orange-red orb and circular blast | fire orange, yellow edge |
| Frost Staff | hail projectile / frost area | pale blue hail orb and circular frost patch | ice blue, white edge |
| Lightning Whip | lightning orb projectile | blue-white electric orb with arc hints | cyan, white edge |
| Spellbook | arcane page projectile | purple page-like diamond/rect silhouette | violet, pale magenta edge |
| Throwing Knife Belt | throwing knife projectile | narrow silver blade line | silver, cool blue edge |
| Hunter Bow | hunter arrow projectile | long golden arrow line | gold, amber edge |
| Trap Kit | bear trap area | tan circular trap footprint with teeth marks | sand gold, dark amber edge |
| Holy Shield | shield pulse / break areas | gold-white player-centered ring pulse | holy gold, white edge |
| Warhammer | hammer impact area | heavy circular shockwave | amber, orange edge |
| Cross Relic | holy field area | persistent holy circle / sanctuary field | gold, soft white edge |
| Toxic Vial | poison bottle / poison cloud | green bottle projectile and toxic cloud | poison green, lime edge |
| Fire Oil Canister | fire oil area | burning oil pool | orange-red, yellow edge |
| Acid Sprayer | acid cone area | yellow-green cone | acid green, bright lime edge |

## Implementation Approach

1. Add lightweight projectile programmatic drawing for projectile styles that do not use art assets or need a readable fallback.
2. Extend `AreaEffect` with named styles for trap, holy field, holy shield pulse, hammer shockwave, frost patch, and generic elemental burst.
3. Update `data/combat_objects.json` so all current primary attack combat objects declare a `visual_style` and colors.
4. Keep existing sprite animation loading intact. Programmatic drawing is the fallback and immediate readable baseline.
5. Add a verification script that checks every weapon's primary combat object has a `visual_style` or replaceable `visual` block.

## Data Flow

1. Skill action executor creates a projectile, area, trap, or orbit object.
2. Combat object factory merges `data/combat_objects.json` into runtime params.
3. The combat node reads `visual_style`, `visual_color`, and `visual_ring_color` during setup.
4. If a programmatic style is present, the node draws the shape with `_draw`.
5. If a future resource is configured through `visual`, the existing `VisualConfigApplier` path remains available.

## Non-Goals

- No new bitmap or sprite assets are required.
- No balance changes.
- No new attack behaviors.
- No UI or HUD changes.
- No replacement of the existing `VisualConfigApplier`.

## Testing

Add and run a Node verification script that asserts:

- Every weapon's `starting_skill_id` resolves to a primary attack.
- Every primary attack action that spawns a projectile, area, or trap references a known combat object.
- Every referenced combat object has either `visual_style` or `visual`.
- The 13 current weapons are covered by explicit visual styles or replaceable art config.

Run existing verification after implementation:

- `node tools/validate_weapon_authoring_pipeline.js`
- `Godot --headless --path . --script res://scripts/debug/visual_config_check.gd`
- `Godot --headless --path . --quit`

## Acceptance Criteria

- All 13 weapons have a visible attack-area or projectile shape in the current runtime.
- Visuals are distinguishable by shape and color.
- Future art replacement can be done by changing combat object visual config.
- Existing combat verification passes.
- No unrelated combat behavior changes are introduced.
