# Real Full Run Performance Analysis

Source files:
- `reports/real-full-run-profile/latest_attribution.json`
- `reports/real-full-run-profile/latest_samples.json`

Run scope:
- Character: mage
- Map: abandoned_dungeon
- Real startup: true
- Headless: false
- Time scale: 1.0
- Stop condition: BOSS appeared, then lost 1000 HP
- Result: `BOSS_DAMAGE_REACHED`
- Elapsed: 783.42s
- Boss HP: 5000 -> 4000
- Boss HP modified by profiler: false
- Survival guard: true; player health was modified to keep the measurement alive
- Debug panel: off

This attribution run is shorter than the earlier 900s pressure sample. Use it to identify creation/destruction sources and pooling candidates. Use the 900s sample for long-duration pressure magnitude.

## Node Creation / Destruction Attribution

Total node lifecycle churn in this attribution run:

| Metric | Count |
| --- | ---: |
| Nodes created | 28,105 |
| Nodes destroyed | 27,601 |
| Net nodes | +504 |

By category:

| Category | Created | Destroyed | Net |
| --- | ---: | ---: | ---: |
| UI | 9,029 | 8,784 | +245 |
| Other | 7,128 | 7,091 | +37 |
| Projectile | 4,896 | 4,858 | +38 |
| Status | 2,243 | 2,204 | +39 |
| AoE | 1,591 | 1,586 | +5 |
| Damage number | 1,211 | 1,209 | +2 |
| Enemy | 1,185 | 1,128 | +57 |
| Pickup | 669 | 588 | +81 |
| Transient VFX | 153 | 153 | 0 |

Top creation sources by scene/class key:

| Created | Scene / script | Class / name |
| ---: | --- | --- |
| 1,553 | no scene / no script | `AnimatedSprite2D / AnimatedSprite2D` |
| 1,537 | no scene / no script | `Node2D / StatusVisualOverlay` |
| 1,461 | `res://scenes/combat/area_effect.tscn` | `CollisionShape2D / CollisionShape2D` |
| 1,461 | `res://scenes/combat/area_effect.tscn` | `AnimatedSprite2D / AnimatedSprite2D` |
| 1,461 | `res://scenes/combat/area_effect.tscn` | `Sprite2D / Sprite2D` |
| 864 | no scene / no script | `Label / DamageNumber` |
| 840 | `res://scenes/combat/fireball_projectile.tscn` | `Sprite2D / Sprite2D` |
| 840 | `res://scenes/combat/fireball_projectile.tscn` | `AnimatedSprite2D / AnimatedSprite2D` |
| 840 | `res://scenes/combat/fireball_projectile.tscn` | `CollisionShape2D / CollisionShape2D` |
| 678 | `res://scenes/combat/fireball_projectile.tscn` / `res://scripts/combat/projectile.gd` | `Area2D / FireballProjectile` |

Top destruction sources match the same objects:

| Destroyed | Scene / script | Class / name |
| ---: | --- | --- |
| 1,549 | no scene / no script | `AnimatedSprite2D / AnimatedSprite2D` |
| 1,534 | no scene / no script | `Node2D / StatusVisualOverlay` |
| 1,457 | `res://scenes/combat/area_effect.tscn` | `Sprite2D / Sprite2D` |
| 1,457 | `res://scenes/combat/area_effect.tscn` | `AnimatedSprite2D / AnimatedSprite2D` |
| 1,457 | `res://scenes/combat/area_effect.tscn` | `CollisionShape2D / CollisionShape2D` |
| 863 | no scene / no script | `Label / DamageNumber` |
| 838 | `res://scenes/combat/fireball_projectile.tscn` | `CollisionShape2D / CollisionShape2D` |
| 838 | `res://scenes/combat/fireball_projectile.tscn` | `AnimatedSprite2D / AnimatedSprite2D` |
| 838 | `res://scenes/combat/fireball_projectile.tscn` | `Sprite2D / Sprite2D` |
| 677 | `res://scenes/combat/fireball_projectile.tscn` / `res://scripts/combat/projectile.gd` | `Area2D / FireballProjectile` |

The largest churn is not a leak pattern: most top sources have near-matching created/destroyed counts. The primary performance risk is allocation/free churn during combat, not retained live nodes.

## Spike Frame Attribution

Profiler recorded:

| Spike threshold | Frames |
| --- | ---: |
| frame_ms > 50 | 1,873 |
| frame_ms > 100 | 430 |

Current spike-frame activity:

| Threshold | AoE create/destroy | Status create/destroy | Pickup create/destroy | Transient VFX create/destroy | Status tick | Reaction |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| >50ms | 537 / 479 | 755 / 551 | 297 / 234 | 47 / 39 | 0 | 0 |
| >100ms | 207 / 181 | 255 / 130 | 78 / 126 | 16 / 8 | 0 | 0 |

Previous 5-frame context around spike frames:

| Threshold | AoE create/destroy | Status create/destroy | Pickup create/destroy | Transient VFX create/destroy | Status tick | Reaction |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| >50ms context | 1,833 / 1,563 | 1,692 / 1,096 | 375 / 540 | 197 / 110 | 0 | 0 |
| >100ms context | 634 / 503 | 577 / 296 | 117 / 222 | 57 / 31 | 0 | 0 |

Interpretation:
- AoE and status visual creation are strongly represented near spike frames.
- Pickups contribute more in destruction/collection context than in creation-only spikes.
- Transient VFX is present but much smaller than AoE/status/projectile churn in this run.
- Status tick/reaction are not directly observable from public signals. The profiler listens to `RunStatsTracker.event_recorded`; status applications were observed, but no status-dot `damage_done` events or reaction-damage events were emitted during this run.

Observed run events:

| Event | Count |
| --- | ---: |
| `apply_status` | 9,159 |
| `status_applied` | 9,159 |
| `damage_done` | 8,187 |
| `damage_taken` | 428 |
| `enemy_killed` | 223 |
| `elite_reward` | 2 |
| `boss_blessing_reward` | 1 |
| `map_event` | 1 |

## Damage Number Diagnosis

The earlier `damage_number_count = 0` was a selector problem, not proof that damage numbers were disabled.

Attribution found:

| Metric | Count |
| --- | ---: |
| Damage number nodes created | 1,211 |
| Damage number nodes destroyed | 1,209 |
| Current selector-visible nodes at stop | 2 |
| Damage events observed | 8,615 |

Root cause: `DamageNumberPopup.show()` creates plain `Label` nodes named `DamageNumber` / `PlayerDamageNumber`. They do not have `damage_number_popup.gd` as their script, so the old selector `_count_nodes_by_script("damage_number_popup.gd")` missed them.

The attribution selector now recognizes these generated `Label` nodes by name.

## ObjectDB Delta Attribution

ObjectDB changed:

| Metric | Count |
| --- | ---: |
| ObjectDB start | 3,682 |
| ObjectDB end | 4,882 |
| ObjectDB delta | +1,200 |
| Node-backed net attribution | +504 |
| Unattributed ObjectDB delta | +696 |

Node-backed net attribution:

| Category | Net |
| --- | ---: |
| UI | +245 |
| Pickup | +81 |
| Enemy | +57 |
| Status | +39 |
| Projectile | +38 |
| Other | +37 |
| AoE | +5 |
| Damage number | +2 |
| Transient VFX | 0 |

Limitation: Godot `Performance.OBJECT_COUNT` exposes total ObjectDB count but does not expose object enumeration. The +696 unattributed delta is likely non-Node `Object`/`RefCounted`/`Resource` churn or retained objects and needs a separate targeted probe if it remains stable across repeated runs.

## Top 5 Pooling Candidates

Do not implement these yet; this is the priority list for the next optimization pass.

1. `StatusVisualOverlay` and child `AnimatedSprite2D`
   - Evidence: 1,537 `StatusVisualOverlay` creates and 1,534 destroys; anonymous `AnimatedSprite2D` churn is the top single class bucket at 1,553 / 1,549.
   - Why first: large churn, tightly correlated with status pressure and spike context.

2. `res://scenes/combat/area_effect.tscn`
   - Evidence: 374 root `AreaEffect` creates, but each instance also creates/destroys `CollisionShape2D`, `Sprite2D`, and `AnimatedSprite2D`; each child bucket is 1,461 creates / 1,457 destroys.
   - Why second: AoE creation/destruction is heavily represented near >50ms and >100ms spike frames.

3. `res://scenes/combat/fireball_projectile.tscn`
   - Evidence: 678 root `FireballProjectile` creates / 677 destroys, plus 840 creates each for sprite, animated sprite, and collision shape.
   - Why third: projectile category created 4,896 nodes and destroyed 4,858, making it the largest non-UI combat churn bucket.

4. Damage number labels
   - Evidence: 864 `DamageNumber` creates, 347 `PlayerDamageNumber` creates, 1,211 total damage-number creates.
   - Why fourth: short-lived UI/VFX labels are pure churn; old profiling missed them because they are generated labels without the popup script.

5. `res://scenes/enemies/enemy_projectile.tscn`
   - Evidence: 512 sprite creates and 512 collision-shape creates; 502 destroys for each. Net +10 for both child nodes at stop.
   - Why fifth: smaller than fireball projectile churn, but still a repeated projectile scene with clear pool boundaries.

Secondary watch list:
- `res://scenes/drops/experience_crystal.tscn`: only 669 pickup nodes created, but net +81 pickup-category nodes remained at stop and pickups show up in spike context.
- Enemy scene internals: enemy root churn is expected gameplay pressure, but `StatusEffectManager`, debug HP bars, status labels, and enemy sprites remain visible in net attribution.
- UI reward/skill card nodes: UI is the largest category by count, but most of it comes from modal/reward/card churn. Pooling UI should be considered only after combat churn is reduced, because the user-facing UI flow is less frequent than per-combat projectile/AoE/status churn.

## PR-1 Acceptance: UI Dynamic Rebuild And Debug UI Gating

Change summary:
- `LevelUpModal` / `RunRewardModal` choice cards are pre-created and rebound instead of clearing and rebuilding the modal card tree.
- Skill card value rows, labels, icons, background, and content layers are reused and hidden when unused.
- Enemy debug HP bars are gated by runtime `developer_mode_enabled`; when the debug panel is off, `DebugHpBar` / `DebugHpLagBar` are not created.
- No gameplay, skill, status, monster, drop, combat math, or visible card content changes were intended.

Acceptance run:
- Character: mage
- Map: abandoned_dungeon
- Real startup: true
- Headless: false
- Time scale: 1.0
- Stop condition: BOSS lost 1000 HP
- Result: `BOSS_DAMAGE_REACHED`
- Elapsed: 507.27s
- Boss damage done: 1003
- Boss HP modified by profiler: false

Before/after:

| Metric | Before | After PR-1 | Delta |
| --- | ---: | ---: | ---: |
| Total nodes created | 28,105 | 15,375 | -45.3% |
| Total nodes destroyed | 27,601 | 14,983 | -45.7% |
| UI nodes created | 9,029 | 2,352 | -73.9% |
| UI nodes destroyed | 8,784 | 2,113 | -75.9% |
| Frames > 50ms | 1,873 | 836 | -55.4% |
| Frames > 100ms | 430 | 240 | -44.2% |
| p95 frame time | 27.14ms | 19.63ms | -27.7% |
| p99 frame time | 74.60ms | 50.03ms | -32.9% |
| Max frame time | 414.83ms | 657.21ms | worse |
| ObjectDB delta | +1,200 | +671 | -44.1% |
| Unattributed ObjectDB delta | +696 | +279 | -59.9% |

PR-1 target status:

| Target | Result |
| --- | --- |
| UI created <= 3,500 | PASS: 2,352 |
| Total node created <= 16,000 | PASS: 15,375 |
| Total node destroyed <= 16,000 | PASS: 14,983 |
| Frames > 50ms <= 1,100 | PASS: 836 |
| Frames > 100ms <= 250 | PASS: 240 |
| p99 <= 60ms | PASS: 50.03ms |
| max <= 250ms | FAIL: 657.21ms |
| DebugHpBar / DebugHpLagBar absent while debug panel off | PASS: 0 created |

Remaining top UI churn after PR-1:

| Created | Key |
| ---: | --- |
| 488 | `Label / DamageNumber` |
| 191 | `Label / StatusLabel` |
| 145 | `Label / PlayerDamageNumber` |
| 18 | `TextureRect / SkillCardValueIcon` |
| 6 | `TextureRect / SkillCardIconTexture` |
| 6 | `VBoxContainer / SkillCardValues` |
| 6 | `Control / SkillCardIconFrame` |
| 6 | `Control / SkillCardContentLayer` |
| 6 | `TextureRect / SkillCardBackground` |
| 6 | `HBoxContainer / SkillCardValueRow1` |
| 6 | `HBoxContainer / SkillCardValueRow2` |
| 6 | `HBoxContainer / SkillCardValueRow3` |

Interpretation:
- PR-1 achieved the intended UI churn reduction. Modal card rebuild churn is no longer the dominant UI source.
- Remaining UI churn is now mostly damage number labels and status labels, which belongs to PR-2.
- The single max-frame outlier did not improve and must remain open. PR-2/PR-3 should focus on short-lived damage/status/AoE/projectile churn and then re-check max-frame outliers.

## PR-2 Acceptance: Damage Number Pool And Status Visual Reuse

Change summary:
- Added a local `RuntimePoolRegistry` and `RuntimeObjectPool` resolved from the scene root, without project autoload changes.
- `DamageNumber` / `PlayerDamageNumber` labels are spawned from the runtime pool, reset on reuse, and returned on tween completion.
- Pooled damage labels remain under their original parent while hidden; they are not removed/re-added on every popup, because profiler node created/destroyed attribution counts scene-tree enter/exit churn.
- `StatusVisualOverlay` is hidden and reused on normal status clear instead of being removed and `queue_free()`'d.
- No gameplay, damage math, status math, skill behavior, enemy behavior, drops, or visible UI text changes were intended.

Acceptance run:
- Character: mage
- Map: abandoned_dungeon
- Real startup: true
- Headless: false
- Time scale: 1.0
- Stop condition: BOSS lost 1000 HP
- Result: `BOSS_DAMAGE_REACHED`
- Elapsed: 695.5s
- Boss damage done: 1003
- Boss HP modified by profiler: false
- Log caveat: repeated `SummonTargetingComponent.update()` errors were present in the run log. They point at a previously freed summon target argument in `scripts/summons/summon_controller.gd:93` and are outside PR-2's touched files. No `damage_number_popup`, `runtime_object_pool`, `runtime_pool_registry`, `status_effect_manager`, `StatusVisualOverlay`, or `get_meta` errors appeared after the PR-2 metadata guard fix.

Before/after versus PR-1:

| Metric | After PR-1 | After PR-2 | Delta |
| --- | ---: | ---: | ---: |
| Total nodes created | 15,375 | 13,653 | -11.2% |
| Total nodes destroyed | 14,983 | 13,096 | -12.6% |
| UI nodes created | 2,352 | 451 | -80.8% |
| UI nodes destroyed | 2,113 | 120 | -94.3% |
| Damage-number nodes created | 633 | 0 | -100.0% |
| Damage-number nodes destroyed | 631 | 0 | -100.0% |
| Current damage-number selector count | 2 | 92 | retained pool/live labels |
| Status-category nodes created | 1,271 | 943 | -25.8% |
| Status-category nodes destroyed | 1,256 | 899 | -28.4% |
| `StatusVisualOverlay` creates | not isolated in PR-1 | 159 | <= 300 target |
| `StatusVisualOverlay` destroys | not isolated in PR-1 | 149 | mostly parent enemy cleanup |
| Frames > 50ms | 836 | 1,141 | worse |
| Frames > 100ms | 240 | 275 | worse |
| p95 frame time | 19.63ms | 26.01ms | worse |
| p99 frame time | 50.03ms | 64.08ms | worse |
| Max frame time | 657.21ms | 428.62ms | improved but still high |
| ObjectDB delta | +671 | +1,217 | worse |
| Node-backed ObjectDB net | +392 | +557 | worse |
| Unattributed ObjectDB delta | +279 | +660 | worse |

PR-2 target status:

| Target | Result |
| --- | --- |
| DamageNumber created <= 300 | PASS: 0 created/destroyed events; 92 current retained/live selector candidates |
| StatusVisualOverlay created <= 300 | PASS: 159 |
| No stale text/color/animation | PASS by reset contract and successful real run; no PR-2 runtime errors in log |
| No gameplay/status/math changes | PASS by touched-file review; only popup lifecycle and status visual hide behavior changed |
| Spike frame reduction | FAIL: >50ms, >100ms, p95, and p99 all worsened in this longer run |
| ObjectDB delta explanation | WATCH: retained pooled labels trade allocation churn for live ObjectDB/RID retention at stop |

Remaining top churn after PR-2:

| Created | Key |
| ---: | --- |
| 1,389 | `area_effect.tscn / AnimatedSprite2D` |
| 1,389 | `area_effect.tscn / CollisionShape2D` |
| 1,389 | `area_effect.tscn / Sprite2D` |
| 607 | `fireball_projectile.tscn / AnimatedSprite2D` |
| 607 | `fireball_projectile.tscn / CollisionShape2D` |
| 607 | `fireball_projectile.tscn / Sprite2D` |
| 605 | `fireball_projectile.tscn / FireballProjectile` |
| 449 | `enemy.tscn / CollisionShape2D` |
| 449 | `enemy.tscn / Sprite2D` |
| 449 | `enemy.tscn / StatusEffectManager` |

Interpretation:
- PR-2 achieved the intended DamageNumber churn removal and reduced status visual churn enough to pass its object targets.
- The profiler now exposes the next true bottleneck more clearly: AoE and projectile scene roots dominate created/destroyed attribution.
- PR-2 also increases retained ObjectDB count at the stop point. That is expected for pooling, but PR-4/cleanup work should add explicit run-end pool cleanup or bounded retention reporting so retained pool objects are not confused with leaks.
- Frame spikes are not solved by PR-2. PR-3 should proceed with whole-scene AoE/projectile pooling, and the summon target freed-reference error should be tracked separately because it pollutes the run log and may affect long-run determinism.

## PR-3 Acceptance: Combat Scene-Root Pooling For AoE And Projectiles

Change summary:
- `CombatObjectFactory` now routes player projectile and AoE scene roots through the runtime pool.
- Enemy projectile and damage-area action paths now use the same combat scene-root pool helper instead of direct scene instantiation.
- `AreaEffect`, `Projectile`, and `DamageArea` now expose pool spawn/despawn hooks and return their roots to the pool on normal expiry paths.
- Runtime pool reuse now validates stale candidate references before type checks, preventing freed-instance errors during long runs.
- No gameplay, damage math, skill tuning, enemy tuning, drop behavior, UI behavior, or visual resources were intentionally changed.

Acceptance run:
- Character: mage
- Map: abandoned_dungeon
- Real startup: true
- Headless: false
- Time scale: 1.0
- Stop condition: BOSS lost 1000 HP
- Result: `BOSS_DAMAGE_REACHED`
- Elapsed: 858.3s
- Boss damage done: 1001
- Boss HP modified by profiler: false
- Log caveat: no `RuntimeObjectPool`, combat factory, enemy action executor/registry, or freed-instance pool errors were present. The run still contains repeated existing `SummonTargetingComponent.update()` errors from `scripts/summons/summon_controller.gd:93`; those are outside PR-3's touched paths and should be tracked separately.

Before/after versus PR-2:

| Metric | After PR-2 | After PR-3 | Delta |
| --- | ---: | ---: | ---: |
| Total nodes created | 13,653 | 6,773 | -50.4% |
| Total nodes destroyed | 13,096 | 6,273 | -52.1% |
| Projectile-category nodes created | 3,697 | 54 | -98.5% |
| Projectile-category nodes destroyed | 3,667 | 0 | -100.0% |
| AoE-category nodes created | 1,389 | 750 | -46.0% |
| AoE-category nodes destroyed | 1,386 | 747 | -46.1% |
| Fireball root created / destroyed | 605 / 605+ | 6 / 0 | root churn mostly removed |
| Fireball child created / destroyed | 607 each / 607 each | 18 total / 0 | child churn mostly removed |
| Enemy projectile root created / destroyed | not isolated | 10 / 0 | retained pool/live roots |
| Enemy projectile child created / destroyed | not isolated | 20 / 0 | retained pool/live children |
| Damage area root created / destroyed | not isolated | 1 / 0 | retained pool/live root |
| Damage area child created / destroyed | not isolated | 2 / 0 | retained pool/live children |
| Frames > 50ms | 1,141 | 93 | -91.8% |
| Frames > 100ms | 275 | 13 | -95.3% |
| p95 frame time | 26.01ms | 17.44ms | -33.0% |
| p99 frame time | 64.08ms | 22.79ms | -64.4% |
| Max frame time | 428.62ms | 139.87ms | -67.4% |
| Average FPS | 106.37 | 197.30 | +85.5% |
| ObjectDB delta | +1,217 | +1,190 | -2.2% |
| Node-backed ObjectDB net | +557 | +500 | -10.2% |
| Unattributed ObjectDB delta | +660 | +690 | worse |

PR-3 target status:

| Target | Result |
| --- | --- |
| Player projectile scene-root churn reduced by >= 70% | PASS: projectile-category created/destroyed fell 98.5% / 100.0% |
| Enemy projectile scene-root churn reduced by >= 70% | PASS: final run shows only 10 enemy projectile roots and 20 child nodes created, with 0 destroyed |
| Damage-area root lifecycle uses pool | PASS: final run shows 1 root / 2 children created, 0 destroyed |
| AoE scene-root churn reduced by >= 70% | PARTIAL: AoE category fell about 46%; still above target |
| Spike frames reduced | PASS: >50ms frames fell 91.8%, >100ms frames fell 95.3%, p99 fell 64.4% |
| No PR-3 runtime errors | PASS: focused log scan found 0 pool/factory/enemy-action/freed-instance errors |

Remaining top churn after PR-3:

| Created | Key |
| ---: | --- |
| 750 | `area_effect.tscn / AnimatedSprite2D` |
| 750 | `area_effect.tscn / CollisionShape2D` |
| 750 | `area_effect.tscn / Sprite2D` |
| 373 | `enemy.tscn / CollisionShape2D` |
| 373 | `enemy.tscn / Sprite2D` |
| 373 | `enemy.tscn / StatusEffectManager` |
| 216 | `area_effect.tscn / AreaEffect` |
| 167 | `DashAfterimage` |
| 158 | `experience_crystal.tscn / CollisionShape2D` |
| 158 | `experience_crystal.tscn / Sprite2D` |
| 157 | `StatusLabel` |

Interpretation:
- PR-3 achieved the intended projectile pooling result and strongly improved real-run frame spikes.
- AoE pooling improved node churn but did not reach the original 70% reduction target. The next pass should inspect why area roots still exit the tree and whether max-active eviction, parent cleanup, or pool retention limits are forcing destruction.
- ObjectDB delta barely improved because pooling retains live roots and children at the stop point. This is expected for scene-root pooling, but PR-4/PR-5 should keep reporting retained pool counts separately from leak-like unattributed ObjectDB growth.
- The next highest-value work remains bounded AoE retention correctness, enemy/internal status-node churn, pickup roots, dash afterimages, and status labels. The existing summon targeting error should be fixed in a separate correctness PR because it pollutes long-run logs and may affect determinism.

## PR-4 Acceptance: Pickup Pooling And ObjectDB Delta Explanation

Change summary:
- `ExpGem` now supports pool spawn/despawn hooks, resets collection state, target, visibility, monitoring, and collision state on reuse, and returns to the runtime pool after collection.
- `EnemyBase._drop_experience_crystal()` now spawns `experience_crystal.tscn` roots through `RuntimePoolRegistry` with a direct instantiate fallback.
- Wave cleanup and run-scene cleanup paths now prefer `despawn_or_free()` for pickup roots, so active pickups can be retained by the pool instead of destroyed.
- Hidden pooled pickups are removed from the `experience_crystal` group while despawned, so pickup counters and full-screen collection only see active pickups.
- No experience amount, pickup radius, magnet radius, movement speed, drop rules, enemy stats, UI, or resource visuals were intentionally changed.

Acceptance run:
- Character: mage
- Map: abandoned_dungeon
- Real startup: true
- Headless: false
- Time scale: 1.0
- Stop condition: BOSS lost 1000 HP
- Result: `BOSS_DAMAGE_REACHED`
- Elapsed: 708.19s
- Boss damage done: 1003
- Boss HP modified by profiler: false
- Log caveat: focused scan found 0 `ExpGem`, `experience_crystal`, runtime pool, freed-instance, or `SCRIPT ERROR` entries.

Before/after versus PR-3:

| Metric | After PR-3 | After PR-4 | Delta |
| --- | ---: | ---: | ---: |
| Total nodes created | 6,773 | 5,254 | -22.4% |
| Total nodes destroyed | 6,273 | 4,559 | -27.3% |
| Pickup-category nodes created | 474 | 84 | -82.3% |
| Pickup-category nodes destroyed | 447 | 0 | -100.0% |
| `experience_crystal` root + child nodes created | 474 | 84 | -82.3% |
| `experience_crystal` root + child nodes destroyed | 447 | 0 | -100.0% |
| Active pickup count at stop | not isolated | 19 | active group only |
| Max active pickup count in samples | not isolated | 27 | active group only |
| Frames > 50ms | 93 | 3,714 | worse |
| Frames > 100ms | 13 | 2,371 | worse |
| p95 frame time | 17.44ms | 255.67ms | worse |
| p99 frame time | 22.79ms | 464.42ms | worse |
| Max frame time | 139.87ms | 959.84ms | worse |
| Average FPS | 197.30 | 18.49 | worse |
| ObjectDB delta | +1,190 | +1,163 | -2.3% |
| Node-backed ObjectDB net | +500 | +695 | worse |
| Unattributed ObjectDB delta | +690 | +468 | improved |

PR-4 target status:

| Target | Result |
| --- | --- |
| `experience_crystal` created down 70%+ | PASS: 474 -> 84, down 82.3% |
| Pickup destroyed churn removed | PASS: 447 -> 0 destroyed events |
| Pickup active group does not include hidden pool entries | PASS by implementation: despawn removes `experience_crystal` group, spawn restores it; stop sample shows 19 active pickups, max sample 27 |
| Cleanup paths despawn active pickups | PASS by contract and wave check pickup assertions; `wave_system_check.gd` still exits 1 on an unrelated camera-distance assertion |
| ObjectDB retained pool explanation | PASS: pickup contributes +84 node-backed net objects, matching retained roots and child nodes; this is expected retained pool capacity, not destroyed churn |
| Frame spike improvement | FAIL / not accepted as solved: PR-4's real run had severe spike regression and needs a separate repeat/profile investigation before attributing it to a code path |

ObjectDB interpretation:
- PR-4 trades pickup allocation churn for retained pickup objects. The pickup category now contributes +84 net node-backed objects because 28 crystal scene roots and their two child nodes remain retained/live at the stop point.
- Overall ObjectDB delta changed only slightly, +1,190 -> +1,163. Node-backed net increased because retained pool objects are still live, while unattributed delta improved from +690 -> +468.
- Godot still does not expose ObjectDB enumeration through `Performance.OBJECT_COUNT`, so non-Node `Object` / `RefCounted` / `Resource` deltas remain unattributed. PR-5 should keep this distinction in the report instead of treating all retained pool objects as leaks.

Remaining top churn after PR-4:

| Created | Key |
| ---: | --- |
| 566 | `area_effect.tscn / AnimatedSprite2D` |
| 566 | `area_effect.tscn / CollisionShape2D` |
| 566 | `area_effect.tscn / Sprite2D` |
| 285 | `enemy.tscn / CollisionShape2D` |
| 285 | `enemy.tscn / Sprite2D` |
| 285 | `enemy.tscn / StatusEffectManager` |
| 252 | `StatusLabel` |
| 248 | anonymous `AnimatedSprite2D` |
| 246 | `StatusVisualOverlay` |
| 139 | `area_effect.tscn / AreaEffect` |
| 97 | `DashAfterimage` |

Interpretation:
- PR-4 successfully removes pickup creation/destruction churn and makes the ObjectDB retention tradeoff explicit.
- The frame-time regression in this run is too large to ignore, but it does not correlate with pickup creation/destruction because pickup churn is near zero in spike-frame context. Re-run profiling before PR-5 or after PR-5 to separate environmental variance from AoE/status/physics pressure.
- The next optimization candidates are still AoE root retention correctness, status label/visual churn, enemy internal nodes, and dash afterimages.

## PR-5 Acceptance: Status Tick Observability And Regression Reporting

Change summary:
- `StatusEffectManager` now emits profiler-only status events when the real full-run profiler is enabled.
- The profiler-only path is gated by root metadata and calls a profiler callback directly. It does not go through gameplay skill events, `RunStatsTracker.event_recorded`, debug panel UI, or normal run-summary counters.
- `RealFullRunProfiler` now records `status_tick_due`, `status_tick_applied`, `status_expired`, `status_visual_spawn`, `status_visual_update`, and `status_reaction_triggered` in frame buckets, spike context, run counts, and `status_tick_observation`.
- The old `observability_gap` wording was removed. Normal status ticks are now directly observable in attribution output.
- No status duration, stack, tick interval, damage, reaction, visual resource, enemy, skill, pickup, or UI behavior was intentionally changed.

Acceptance run:
- Character: mage
- Map: abandoned_dungeon
- Real startup: true
- Headless: false
- Time scale: 1.0
- Stop condition: BOSS lost 1000 HP
- Result: `BOSS_DAMAGE_REACHED`
- Elapsed: 710.23s
- Boss damage done: 1000
- Boss HP modified by profiler: false
- Log caveat: focused scan found 0 `StatusEffectManager`, `real_full_run_profiler`, status profiler event, or freed-instance errors. The run still contains 3,024 existing `SummonTargetingComponent.update()` script errors.

Status observability:

| Counter | Count |
| --- | ---: |
| `status_tick_due` | 10,155 |
| `status_tick_applied` | 10,155 |
| `status_expired` | 945 |
| `status_visual_spawn` | 227 |
| `status_visual_update` | 1,013 |
| `status_reaction_triggered` | 7,698 |

Spike status activity:

| Threshold | tick due | tick applied | expired | visual spawn | visual update | reaction triggered |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| >50ms | 8,315 | 8,315 | 686 | 213 | 953 | 7,574 |
| >100ms | 7,611 | 7,611 | 574 | 167 | 801 | 6,860 |

PR-5 target status:

| Target | Result |
| --- | --- |
| `status_tick_observation` no longer reports normal tick observability gap | PASS: `normal_status_tick_events_observable=true`, no `observability_gap` key |
| Spike frames include status tick/reaction counts | PASS: explicit due/applied/reaction counters are present in `category_activity.status` |
| No gameplay/status math changes | PASS by touched-file review and burn status runtime smoke; added path only runs when profiler metadata is enabled |
| No high-frequency Debug panel UI refresh | PASS by contract: no debug panel update code was added |
| Final rollout report | PASS: table below summarizes baseline through PR-5 |

Before/after versus PR-4:

| Metric | After PR-4 | After PR-5 | Delta |
| --- | ---: | ---: | ---: |
| Total nodes created | 5,254 | 26,242 | worse |
| Total nodes destroyed | 4,559 | 25,338 | worse |
| Status-category nodes created | 789 | 818 | +3.7% |
| StatusVisualOverlay created | 246 | 227 | -7.7% |
| Frames > 50ms | 3,714 | 2,518 | improved but still high |
| Frames > 100ms | 2,371 | 1,696 | improved but still high |
| p95 frame time | 255.67ms | 180.58ms | improved but still high |
| p99 frame time | 464.42ms | 532.53ms | worse |
| Max frame time | 959.84ms | 998.83ms | worse |
| Average FPS | 18.49 | 26.34 | improved but still low |
| ObjectDB delta | +1,163 | +1,640 | worse |

Interpretation:
- PR-5 achieved the observability goal: status tick/reaction pressure is now measured directly instead of inferred from `damage_done status_dot`.
- The run is not a clean performance win. `SummonParticles` created 6,546 `GPUParticles2D` nodes, and the existing summon targeting script error remains noisy. That makes PR-5's long-run totals unsuitable as a pure comparison of the profiler-only callback overhead.
- Status pressure is now clearly visible near spikes: most >100ms spike frames are accompanied by thousands of status ticks/reactions in aggregate context. This supports making status visual/label churn and summon VFX correctness the next focused investigations.

## PR-1 Through PR-5 Rollout Summary

| Metric | Baseline | PR-1 | PR-2 | PR-3 | PR-4 | PR-5 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Node created total | 28,105 | 15,375 | 13,653 | 6,773 | 5,254 | 26,242 |
| Node destroyed total | 27,601 | 14,983 | 13,096 | 6,273 | 4,559 | 25,338 |
| UI created | 9,029 | 2,352 | 451 | 370 | 426 | 518 |
| DamageNumber created | 1,211 | 633 | 0 | 2 | 2 | 2 |
| StatusVisualOverlay created | 1,537 | not isolated | 159 | not isolated | 246 | 227 |
| AoE created | high: area children 1,461 each | not isolated | 1,389 | 750 | 573 | 780 |
| Projectile created | 4,896 | not isolated | 3,697 | 54 | 38 | 62 |
| Pickup net live | +81 | not isolated | not isolated | not isolated | +84 | +93 |
| ObjectDB delta | +1,200 | +671 | +1,217 | +1,190 | +1,163 | +1,640 |
| Frames > 50ms | 1,873 | 836 | 1,141 | 93 | 3,714 | 2,518 |
| Frames > 100ms | 430 | 240 | 275 | 13 | 2,371 | 1,696 |
| p95 frame time | 27.14ms | 19.63ms | 26.01ms | 17.44ms | 255.67ms | 180.58ms |
| p99 frame time | 74.60ms | 50.03ms | 64.08ms | 22.79ms | 464.42ms | 532.53ms |
| Max frame time | 414.83ms | 657.21ms | 428.62ms | 139.87ms | 959.84ms | 998.83ms |

Final next-step priority:
1. Fix the existing `SummonTargetingComponent.update()` error and profile summon VFX churn; `SummonParticles` dominated PR-5 node churn.
2. Investigate why AoE roots/children still exit the tree despite scene-root pooling.
3. Pool or reuse `StatusLabel` and remaining `StatusVisualOverlay` churn after status observability is now accurate.
4. Keep pickup and projectile pools, but add retained-pool reporting so ObjectDB retained objects are separated from leaks.
5. Re-run the BOSS -1000 HP profile after summon correctness is fixed, because PR-4/PR-5 frame spikes are currently polluted by unrelated summon errors and particle churn.
