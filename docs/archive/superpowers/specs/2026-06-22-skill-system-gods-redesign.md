# Skill System Gods Redesign Design

## Summary

The game will replace the weapon-bound skill progression model with a god-system skill pool. Weapons, weapon branches, weapon-bound starting skills, and weapon evolution are removed from the player-facing run flow. Gods are defined separately in `data/gods.json`; player skills are defined in `data/skills.json` and reference their owning god with `god_id`.

The first implementation batch defines all six gods and implements the Fire god's 60 skills. The other five gods are present as data definitions only, with their skill pools to be implemented in later batches.

## Goals

- Define six gods independently in `data/gods.json`: fire, thunder, frost, curse, holy, chaos.
- Implement the Fire god's 60 documented skills in `data/skills.json`.
- Ensure every implemented Fire skill can appear in the level-up pool according to the current rarity weights.
- Ensure every implemented Fire skill has real in-run behavior after selection.
- Remove the weapon concept from the main run flow rather than hiding it behind compatibility fields.
- Use simple `GPUParticles2D`-based 2D effects for all skill visuals.
- Keep combat outcomes routed through the existing damage, status, critical, target, and mitigation systems.
- Replace the enemy numeric health display with a visual health bar that eases when damage is taken.

## Non-Goals

- Do not implement the remaining five gods' skills in this batch.
- Do not preserve weapon branch or weapon evolution behavior.
- Do not build full bespoke presentation systems for complex skills in the first batch.
- Do not add a separate UI presentation layer for advanced skill state unless it is required for basic usability.
- Do not keep skill cards that do nothing in combat.

## User-Approved Implementation Standard

Each Fire skill must satisfy these requirements:

1. It appears in the upgrade pool with rarity probability aligned to the current game settings: common 60, rare 28, epic 10, legendary 2.
2. Selecting it has a concrete in-run effect. Valid effects include damage, status application, passive triggers, cooldown changes, range changes, projectile count changes, shields, retaliation, revive, delayed damage, or equivalent combat behavior derived from the skill description.
3. It cannot be only a card in the upgrade pool. If a skill is selectable, it must affect the active run.
4. Skill visuals use simple 2D particles implemented with `GPUParticles2D`.
5. Complex descriptions may be implemented as simplified but real first-pass mechanics. For example, `太阳熔炉` can periodically empower the next Fire skill with damage, area, or projectile count and play a short forge particle burst, without a persistent forge entity, dedicated UI, or custom animation system.
6. Every skill must declare a runtime family. If no existing runtime family fits the skill description, add a new family, its runtime rule support, and a documentation note instead of forcing the skill into a mismatched family.
7. The first-pass visual for the character starting skill can use simple rectangle or circle particles/shapes; it does not need bespoke art.
8. `mars_spark_missile` is the first Fire learnable skill and particle profile, not the character starting attack. Preserve the current default starting attack as `fireball` by migrating it out of weapon resolution.
9. After Fire skills are implemented, the current dev tools must expose a debug entry that can validate the full chain without entering the normal progression flow: select skill card -> grant skill -> cast/trigger skill -> enemy damage, status, particles, and damage popup feedback.

## Data Design

### `data/gods.json`

The file contains a top-level `gods` array. Each god definition uses stable English ids and Chinese display text.

Required fields:

- `id`: stable id such as `fire`.
- `display_name`: Chinese name such as `火焰`.
- `title`: document heading style name such as `火之神`.
- `description`: short gameplay identity.
- `tags`: god-level tags used by skill weighting and synergy.
- `color`: RGBA color for generic particles and UI accents.
- `implemented`: whether the god has a playable skill pool in the current batch.

First-batch gods:

- `fire`: implemented, 60 skills.
- `thunder`: definition only.
- `frost`: definition only.
- `curse`: definition only.
- `holy`: definition only.
- `chaos`: definition only.

### `data/skills.json`

The file contains a top-level `skills` array and optional `skill_upgrade_cards` generation metadata if needed by the implementation. Fire skills are concrete runtime definitions, not placeholder records.

Required fields per skill:

- `id`: stable snake_case id, generated from meaning rather than pinyin where practical.
- `display_name`: Chinese skill name from the document.
- `god_id`: `fire` for all first-batch skills.
- `rarity`: internal rarity key: `common`, `rare`, `epic`, `legendary`.
- `source_rarity`: Chinese source rarity: `普通`, `稀有`, `史诗`, `传说`.
- `description`: skill effect from the document, edited only for clarity.
- `vfx_description`: visual description from the document.
- `build_hint`: follow-up build notes from the document.
- `category`: `active` or `passive`.
- `runtime_family`: the skill's runtime family, such as `projectile`, `cone_area`, or `stack_mark`. New runtime families must be documented with their supported behavior and matching skills.
- `tags`: normalized tags such as `fire`, `projectile`, `burn`, `shield`, `retaliation`, `boss`, `cooldown`, `summon`, `execute`.
- `max_level`: skill level cap data. The first version must not hard-code active skill count or skill level to 5; later progression limits can provide a more scientific cap.
- `base`: numeric runtime stats needed by components and actions.
- `components`: cooldown, targeting, persistent orbit, or passive trigger components.
- `events`: actions to execute on cast, hit, kill, damage taken, status expired, or other supported triggers.
- `particle`: `GPUParticles2D` visual profile reference or inline particle parameters.

Optional fields:

- `runtime_rules`: named first-pass rule data for behaviors that need custom code.
- `offer_rules`: availability and weight adjustments.
- `skill_modifiers`: passive modifiers granted while the skill is owned.

## Rarity Mapping

The source table maps to the runtime keys as follows:

- `普通` -> `common`
- `稀有` -> `rare`
- `史诗` -> `epic`
- `传说` -> `legendary`

The first Fire batch has:

- 24 common skills.
- 18 rare skills.
- 12 epic skills.
- 6 legendary skills.

The upgrade pool uses the existing rarity weights unless the user later requests god-specific tuning.

## Runtime Architecture

### Data Loading

`DataManager` becomes the primary loader for:

- `data/gods.json`
- `data/skills.json`
- existing non-weapon data such as enemies, waves, status effects, relics, synergies, maps, upgrades, and characters

`DataManager` no longer indexes player skills from `primary_attack.json` or `learnable_skills.json`. `GameData` mirrors this behavior in its fallback functions.

### Loadout

`RunLoadout` stores character data only. It no longer stores `weapon_id`, `weapon_data`, or `weapon_definition`.

`CharacterLoadoutService` validates characters only. Character definitions no longer need `allowed_weapon_ids`.

`PlayerController.reset_for_loadout()` initializes the selected character, clears run skill state, applies character stats and traits, and grants the current starting skill. The starting skill is preserved as a run-start mechanic, but it is no longer resolved through weapons. The implementation can store this as a character field, run config field, or explicit default starting skill id; it must not require a weapon definition.

### Removed Main-Flow Systems

The following concepts are removed from the active run flow:

- Weapon selection.
- Weapon equip validation.
- Weapon visual refresh.
- Weapon-bound starting skills.
- Weapon branch choice.
- Weapon branch level-up cards.
- Weapon evolution cards.
- Current weapon skill checks.
- Weapon-specific debug full matrix flow.

Old files may remain on disk during the first implementation if removing them would create unnecessary Godot resource churn, but no main flow or validation path should depend on them.

### Upgrade Pool

The level-up pool becomes skill-first:

- If a skill is not owned and the active skill limit allows it, generate a learn-skill option.
- If a skill is owned and the skill supports leveling, generate an upgrade-skill option.
- The configured starting skill is already owned at run start and is not offered as a duplicate learn-skill card.
- Non-skill survival and meta upgrades may remain if they do not require weapon tags.
- Existing weapon-tagged upgrades are removed, disabled, or migrated to generic skill tags.
- Branch and evolution options are never generated.

### Skill Execution

Existing systems remain the core execution path:

- `SkillManager` owns active and passive skills.
- `SkillExecutor` ticks active skills.
- `SkillComponentRunner` handles cooldown and targeting.
- `SkillEventBus` dispatches skill events.
- `SkillActionExecutor` spawns projectiles, areas, orbit objects, traps, status effects, healing, modifiers, and damage.
- Existing damage services calculate final damage.

The implementation may add a focused Fire rules layer for behaviors that cannot be expressed with the current generic actions. This layer must be data-driven by `runtime_rules`, not hard-coded by card text.

## Visual Effects

All first-batch skill visuals use simple particle effects.

The implementation should add a reusable particle path such as:

- a generic `skill_particle_effect.tscn` based on `GPUParticles2D`, or
- a `SkillParticleFactory` that creates `GPUParticles2D` nodes from data.

Particle profiles should support:

- color and secondary color.
- lifetime.
- emission shape.
- amount.
- initial velocity.
- spread.
- scale.
- radial, cone, burst, trail, orbit, and impact modes when practical.
- simple circle or rectangle profiles for the starting skill placeholder.

The goal is clear gameplay feedback, not bespoke animation. A Fire projectile can use a small orange trail; a Fire pulse can use a radial burst; a Phoenix revive can use a larger gold-red burst.

## Fire Skill Implementation Rules

All 60 Fire skills must be implemented as simplified but real mechanics. Examples:

- Projectile skills use `spawn_projectile` or `spawn_projectiles_at_targets`, fire damage, and Fire particles.
- Cone or pulse skills use `spawn_area` with cone or radius parameters.
- Orbit skills use orbit objects or periodic radial areas.
- Mark skills apply status stacks and consume them through runtime rules.
- Kill-trigger skills subscribe to kill events and spawn follow-up damage or cooldown reduction.
- Retaliation skills respond to player damage with cooldown-gated effects.
- Shield and armor skills add shields, mitigation, or temporary modifiers.
- Boss and high-health skills use target health ratio, elite, or boss conditions.
- Legendary skills provide broad but concrete effects such as revive, periodic empowered skill, or Fire skill count scaling.

No Fire skill may be marked implemented if it lacks runtime impact.

## Error Handling

- Missing `god_id` or unknown gods fail validation.
- Missing particle profiles fall back to a simple Fire burst and log a warning.
- Unsupported action or runtime rule fails validation before runtime, rather than silently producing a dead card.
- Skills with invalid rarity are excluded from the pool and reported by validation.
- If active skill slots are full, learn-skill cards are not offered.

## Testing And Validation

Validation scripts should cover:

- `gods.json` has exactly six unique gods.
- `skills.json` contains exactly 60 Fire skills in the first batch.
- Every Fire skill references `god_id: "fire"`.
- Every Fire skill has valid rarity, display name, description, vfx description, build hint, category, tags, and particle data.
- Every selectable Fire skill has either executable components/events, passive modifiers, or supported runtime rules.
- Every Fire skill has a valid `runtime_family`; new families have documentation and runtime support.
- Upgrade pool can generate learn-skill cards using existing rarity weights.
- Selecting a Fire skill adds it to `SkillManager` or applies its passive runtime behavior.
- Automated smoke tests simulate selecting a skill card and attacking one enemy, then assert projectile or particle feedback, status application when relevant, damage popup creation, and damage results through the current damage formula chain.
- At least representative skills from each Fire mechanic family deal damage, apply status, modify cooldown, trigger on kill, trigger on damage taken, and display particles.
- Player loadout no longer requires weapons.
- Branch and evolution options are not generated.
- Old weapon data is not loaded into the player skill pool.
- Enemies show a visual health bar; damage updates both the immediate and eased bar values correctly.

Manual Godot smoke checks should include:

- Start a run with a character only.
- Confirm the current starting skill is granted without selecting or loading a weapon.
- Level up and select a Fire skill.
- Confirm particles appear.
- Confirm enemies take damage through the normal damage system.
- Confirm at least one status-based Fire skill applies or consumes a status.
- Confirm no weapon, branch, or evolution UI appears.
- Confirm enemy damage changes a visual health bar with easing while damage numbers still appear.

## Confirmed Additions

- The first version does not keep a hard active-skill-slot cap of 5; a more scientific progression cap will be added later.
- Skill levels and repeated growth are not hard-coded to 5 in this redesign.
