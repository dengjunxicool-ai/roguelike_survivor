# Skill Runtime Families

This document records the first data contract for learnable god skills. Runtime code is not implemented in this task; "runtime support" below describes the adapter behavior expected from later tasks.

## Common Fields

Every learnable skill in `data/skills/skills.json` has:

- `id`, `display_name`, `god_id`, `rarity`, `source_rarity`
- `description`, `vfx_description`, `build_hint`
- `category`, `runtime_family`, `tags`
- `particle.profile`
- one runtime payload: `events` with actions, `skill_modifiers`, or `runtime_rules`

## `projectile`

Semantics: fires one or more fire projectiles that damage enemies on hit.

Required fields: `components`, `events`, `events[].actions`, projectile id, speed, lifetime, collision radius, damage action.

Runtime support: existing projectile-style actions can spawn a projectile, detect hit, deal fire damage, and spawn particles.

Adapted skills: 火星飞弹, 熔芯箭, 烈焰回旋.

First version simplification: homing, pierce, return paths, and boss-specific tuning are represented as parameters for later runtime interpretation.

## `cone_area`

Semantics: creates a short forward cone area from the player.

Required fields: cooldown component, `spawn_area`, `position_mode`, radius, `cone_width_degrees`, duration, tick interval, damage.

Runtime support: area spawners should read cone width and caster-forward position.

Adapted skills: 焰舌喷吐.

First version simplification: cone aiming is nearest-enemy or facing-direction driven by the later runtime adapter.

## `radial_pulse`

Semantics: creates an expanding fire area centered on the player.

Required fields: cooldown component, `spawn_area`, `position_mode: caster`, radius, expansion radius, duration, damage, optional knockback.

Runtime support: area spawners should resolve expanding rings and radial hit checks.

Adapted skills: 灼热脉冲, 热浪推击, 日冕爆发, 灭世炎轮.

First version simplification: two-stage pulses such as 日冕爆发 are encoded as one expanding pulse for now.

## `orbit`

Semantics: summons orbiting fire objects that periodically hit nearby enemies.

Required fields: `spawn_orbitals`, count, orbit radius, rotation speed, duration, hit interval, damage.

Runtime support: orbitals should attach to the player and apply fire hits by interval.

Adapted skills: 火羽刃, 赤火护星.

First version simplification: projectile release from护星 is encoded as orbital collision damage.

## `targeted_strike`

Semantics: directly strikes a priority target with fire damage.

Required fields: targeting component, cooldown component, `deal_damage`, target mode, damage, particle profile.

Runtime support: target selection should support nearest, low-health, burning-preferred, and priority-fire modes.

Adapted skills: 火焰鞭影, 燃血刺, 炽热凝视, 赤日连祷.

First version simplification: line, whip, gaze, and falling-strike visuals share one targeted strike data shape.

## `summon`

Semantics: creates a temporary fire helper that attacks nearby enemies.

Required fields: `spawn_summon`, summon id, duration, attack interval, damage, target mode.

Runtime support: summon runtime should spawn a temporary actor or virtual attacker.

Adapted skills: 灯芯守卫.

First version simplification: fire raven and phoenix-style spawned attacks use trigger families until a richer summon runtime exists.

## `passive_modifier`

Semantics: passively changes fire skill damage, projectile count, return chance, or related stats.

Required fields: `skill_modifiers`, stat, operation, value, and scope.

Runtime support: the stat pipeline should apply scoped modifiers to fire skills.

Adapted skills: 火纹护甲, 火苗复制, 灼心弱点, 熔屑飞溅, 火油亲和, 黑焰附着, 炼狱连弹, 融甲灼烧, 炽热回流, 灰烬复燃, 黑日降临.

First version simplification: conditional text such as burning-only or blackflame conversion is represented as scoped modifier data for later refinement.

## `stack_mark`

Semantics: fire hits add stacks to a target or player state; reaching a threshold consumes stacks for burst or empowerment.

Required fields: `runtime_rules.rule`, `stack_id`, required stacks, max stacks, consume effect, consume damage.

Runtime support: runtime should maintain stack counters and consume them on threshold.

Adapted skills: 焦灼标记, 赤焰连击, 火种积蓄, 炎爆火印, 灼魂清算, 火刑宣告, 焚心裁决, 火种裂变.

First version simplification: all mark variants share one stack-and-consume contract, with exact target selection and VFX deferred.

## `kill_trigger`

Semantics: a fire-related kill triggers a secondary effect such as ember attacks, summons, cooldown recovery, or snowball buffs.

Required fields: `runtime_rules.rule`, chance, cooldown, effect, optional damage.

Runtime support: runtime should listen for fire or burning kills and enforce internal cooldowns.

Adapted skills: 余烬火花, 火鸦群袭, 怒焰连杀, 烈焰偏转, 烈焰狂宴, 灭火成灰.

First version simplification: secondary projectiles, summons, and area buffs are named effects rather than fully expanded action graphs.

## `damage_taken_trigger`

Semantics: player damage triggers a fire retaliation after a cooldown.

Required fields: `runtime_rules.rule`, cooldown, actions.

Runtime support: runtime should listen for player damage events and execute retaliation actions.

Adapted skills: 火花反击.

First version simplification: attacker-source targeting is represented as a radial spark spray.

## `cooldown_reducer`

Semantics: reduces fire skill cooldowns from burning kills, burning enemies nearby, or overheat loops.

Required fields: `runtime_rules.rule`, reduction seconds, internal cooldown.

Runtime support: cooldown manager should accept scoped reductions for fire skills.

Adapted skills: 灰烬回收, 焦热狂热, 熔芯过载.

First version simplification: risk effects such as vulnerability from overuse are encoded as rule names for later runtime handling.

## `shield`

Semantics: grants a temporary fire shield from low health or accumulated fire hits, optionally retaliating.

Required fields: `runtime_rules.rule`, shield amount, duration, cooldown, retaliate damage.

Runtime support: shield runtime should apply temporary shield values and dispatch optional retaliation.

Adapted skills: 凤凰羽护, 赤阳护盾.

First version simplification: feather count and hit-based heat thresholds are represented as shield rules.

## `empower_next_fire`

Semantics: charges a state that empowers the next fire skill with damage, area, or projectile count.

Required fields: `runtime_rules.rule`, charges required, damage multiplier, area multiplier, projectile count add.

Runtime support: runtime should track charge sources and consume empowerment on the next fire cast.

Adapted skills: 焰影步, 双焰施放, 熔炉赐印, 余烬循环, 终焰王冠, 太阳熔炉.

First version simplification: movement, cast-count, and endgame-state empowerments share one charge contract.

## `delayed_damage`

Semantics: records or schedules fire damage and resolves it after a short delay.

Required fields: `runtime_rules.rule`, delay seconds, damage multiplier, radius, optional source damage portion.

Runtime support: runtime should schedule delayed damage against the original target or location.

Adapted skills: 日矛点名, 熔核回响, 燃尽余波, 炎爆序列, 黑火债务, 凤凰回翔.

First version simplification: different visual timings use a single delayed reckoning rule.

## `revive_once`

Semantics: prevents one lethal hit per run, restores health, causes a fire explosion, and applies a post-revive fire buff.

Required fields: `runtime_rules.rule`, revive health ratio, explosion radius, explosion damage, post-revive modifier.

Runtime support: death prevention should run before final player death resolution.

Adapted skills: 凤凰涅槃.

First version simplification: invulnerability windows and animation locks are not encoded yet.

## `fire_skill_count_scaling`

Semantics: scales fire skill power with the number of owned fire skills and reduces non-fire offer weight.

Required fields: `runtime_rules.rule`, per-fire-skill multipliers, non-fire offer multiplier, optional dynamic modifier.

Runtime support: upgrade and stat systems should expose owned fire skill count.

Adapted skills: 万火归一.

First version simplification: "extra effects" are represented as damage and radius scaling until the runtime has per-skill augment hooks.
